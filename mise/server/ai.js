'use strict';
// AI layer. Uses the Groq API when GROQ_API_KEY is set, and falls back
// to the offline engine if the key is missing or a call fails, so the app
// always returns something usable.
const offline = require('./offline_recipes');
const { CATEGORIES } = require('./store');

const MODEL = () => process.env.GROQ_MODEL || 'openai/gpt-oss-120b';
const hasKey = () => !!(process.env.GROQ_API_KEY || '').trim();
const mode = () => (hasKey() ? 'groq' : 'offline');

async function callLLM(system, user, maxTokens = 1500) {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${process.env.GROQ_API_KEY.trim()}`,
    },
    body: JSON.stringify({
      model: MODEL(),
      max_tokens: Math.max(maxTokens, 4000),
      temperature: 0.4,
      ...(MODEL().includes('gpt-oss') ? { reasoning_effort: 'low' } : {}),
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    }),
    signal: AbortSignal.timeout(45000),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Groq API ${res.status}: ${body.slice(0, 200)}`);
  }
  const data = await res.json();
  return data.choices?.[0]?.message?.content || '';
}

function extractJson(text) {
  const a = text.indexOf('{');
  const b = text.lastIndexOf('}');
  if (a < 0 || b <= a) throw new Error('No JSON in model response');
  return JSON.parse(text.slice(a, b + 1));
}

const clip = (v, n) => String(v ?? '').trim().slice(0, n);

function cleanIngredient(i) {
  const q = Number(i?.quantity);
  return {
    name: clip(i?.name, 60),
    quantity: isFinite(q) && q > 0 ? Math.round(q * 100) / 100 : null,
    unit: clip(i?.unit, 12),
    category: CATEGORIES.includes(i?.category) ? i.category : 'other',
  };
}

function cleanMeal(m, servingsFallback) {
  if (!m || typeof m !== 'object') return null;
  const name = clip(m.name, 80);
  const ingredients = (Array.isArray(m.ingredients) ? m.ingredients : [])
    .map(cleanIngredient)
    .filter((i) => i.name)
    .slice(0, 25);
  if (!name || ingredients.length === 0) return null;
  const s = Number(m.servings);
  return {
    name,
    emoji: clip(m.emoji, 8) || '🍽️',
    servings: Number.isInteger(s) && s >= 1 && s <= 12 ? s : servingsFallback || 2,
    ingredients,
  };
}

const MEAL_SCHEMA = `{"name": string, "emoji": one food emoji, "servings": integer,
 "ingredients": [{"name": string (singular, plain, e.g. "Tomato"), "quantity": number or null for "to taste",
 "unit": one of "", "g", "kg", "ml", "l", "tsp", "tbsp", "cup", "cloves", "bunch", "head", "can", "slices", "pinch",
 "category": one of "produce","dairy","meat","pantry","frozen","other"}]}`;

// ---------------------------------------------------------------- meal
async function generateMeal({ prompt, servings }) {
  const s = Number.isInteger(servings) ? Math.min(Math.max(servings, 1), 12) : 2;
  const ask = clip(prompt, 300);
  if (hasKey()) {
    try {
      const text = await callLLM(
        'You are a practical home-cooking assistant inside a meal-planning app. ' +
          'Reply with ONE JSON object only, no prose, no markdown. Schema: ' + MEAL_SCHEMA +
          '. Use realistic grocery quantities for the requested servings. 5-14 ingredients. ' +
          'Use the same singular ingredient name every time (Tomato, not Tomatoes). Never include cooking steps.',
        `Create a meal for ${s} servings: ${ask}`
      );
      const meal = cleanMeal(extractJson(text), s);
      if (meal) return { source: 'groq', meal };
      throw new Error('Model returned an unusable meal');
    } catch (e) {
      console.error('[ai.meal] falling back to offline:', e.message);
      return { source: 'offline', note: 'The AI service was unreachable, used the built-in recipe engine.', meal: offline.generateMeal(ask, s) };
    }
  }
  return { source: 'offline', note: 'No API key set on the server, used the built-in recipe engine.', meal: offline.generateMeal(ask, s) };
}

// ---------------------------------------------------------------- plan
const SLOT_NAMES = ['breakfast', 'lunch', 'dinner'];

function mealIsVeg(meal) {
  return !meal.ingredients.some((i) => i.category === 'meat');
}

function offlinePlan({ preferences, meals, slots, allowNew }) {
  const prefs = String(preferences || '').toLowerCase();
  const veg = /vegetarian|vegan|veggie/.test(prefs);
  const avoid = [...prefs.matchAll(/\b(?:no|without|avoid|allergic to)\s+([a-z]+)/g)].map((m) => m[1]);
  const ok = (m) =>
    (!veg || mealIsVeg(m)) &&
    !avoid.some((a) => m.name.toLowerCase().includes(a) || m.ingredients.some((i) => i.name.toLowerCase().includes(a)));

  const pool = meals.filter(ok).map((m) => ({ id: m.id, name: m.name, ingredients: m.ingredients, slots: guessSlots(m) }));
  const newMeals = [];
  if (allowNew || pool.length < 4) {
    const have = new Set(meals.map((m) => m.name.toLowerCase()));
    offline.RECIPES.forEach((r, idx) => {
      if (have.has(r.name.toLowerCase())) return;
      if (veg && !offline.isVegetarian(r)) return;
      if (avoid.some((a) => r.name.toLowerCase().includes(a) || r.ingredients.some((i) => i.name.toLowerCase().includes(a)))) return;
      const tempId = `new${idx}`;
      newMeals.push({ tempId, name: r.name, emoji: r.emoji, servings: r.servings, ingredients: r.ingredients });
      pool.push({ id: tempId, name: r.name, ingredients: r.ingredients, slots: r.slots });
    });
  }
  const assignments = [];
  const used = new Map();
  const lastByDay = new Map();
  for (const { day, slot } of slots) {
    const code = 'bld'[slot];
    let candidates = pool.filter((p) => p.slots.includes(code));
    if (!candidates.length) candidates = pool;
    if (!candidates.length) continue;
    candidates = [...candidates].sort((a, b) => (used.get(a.id) || 0) - (used.get(b.id) || 0) || a.name.localeCompare(b.name));
    const prev = lastByDay.get(slot);
    const pick = candidates.find((c) => c.id !== prev) || candidates[0];
    used.set(pick.id, (used.get(pick.id) || 0) + 1);
    lastByDay.set(slot, pick.id);
    assignments.push({ day, slot, mealId: pick.id });
  }
  const usedIds = new Set(assignments.map((a) => a.mealId));
  return { newMeals: newMeals.filter((m) => usedIds.has(m.tempId)), assignments };
}

function guessSlots(m) {
  const t = (m.name + ' ' + m.ingredients.map((i) => i.name).join(' ')).toLowerCase();
  if (/oat|pancake|toast|smoothie|omelet|omelette|granola|shakshuka|cereal|yogurt/.test(t) && !/curry|stir|pasta|soup/.test(t)) return 'b';
  if (/salad|sandwich|wrap|soup/.test(t)) return 'l';
  return 'd';
}

async function planWeek({ preferences, meals, slots, allowNew }) {
  const prefs = clip(preferences, 400);
  const safeMeals = (Array.isArray(meals) ? meals : []).slice(0, 80).map((m) => ({
    id: clip(m.id, 60),
    name: clip(m.name, 80),
    ingredients: (Array.isArray(m.ingredients) ? m.ingredients : []).slice(0, 30).map((i) => ({
      name: clip(i.name, 60),
      category: CATEGORIES.includes(i.category) ? i.category : 'other',
    })),
  }));
  const safeSlots = (Array.isArray(slots) ? slots : [])
    .filter((s) => Number.isInteger(s.day) && s.day >= 0 && s.day <= 6 && Number.isInteger(s.slot) && s.slot >= 0 && s.slot <= 2)
    .slice(0, 21);
  if (!safeSlots.length) return { source: mode(), note: 'No empty slots to fill.', newMeals: [], assignments: [] };

  if (hasKey()) {
    try {
      const text = await callLLM(
        'You plan a week of meals for a household. Reply with ONE JSON object only, no prose, no markdown. ' +
          'Schema: {"newMeals":[{"tempId": string like "new1", ...meal}], "assignments":[{"day":0-6 (0=Monday),"slot":0-2 (0=breakfast,1=lunch,2=dinner),"mealId": string}]}. ' +
          'Meal schema: ' + MEAL_SCHEMA + '. ' +
          'Fill EVERY requested slot. Prefer meals from the existing library (use their ids); ' +
          (allowNew ? 'you may invent up to 6 new meals for variety (reference them by tempId). ' : 'do NOT invent new meals, newMeals must be []. ') +
          'Put breakfast-style meals in breakfast slots, avoid the same meal on consecutive days in the same slot, ' +
          'and reuse ingredients across meals to reduce shopping. Respect the stated preferences strictly.',
        JSON.stringify({ preferences: prefs || 'none', library: safeMeals, slotsToFill: safeSlots })
      );
      const raw = extractJson(text);
      const newMeals = [];
      if (allowNew) {
        for (const nm of (Array.isArray(raw.newMeals) ? raw.newMeals : []).slice(0, 8)) {
          const c = cleanMeal(nm, 2);
          const tempId = clip(nm?.tempId, 20);
          if (c && tempId) newMeals.push({ tempId, ...c });
        }
      }
      const valid = new Set([...safeMeals.map((m) => m.id), ...newMeals.map((m) => m.tempId)]);
      const wanted = new Set(safeSlots.map((s) => `${s.day}|${s.slot}`));
      const seen = new Set();
      const assignments = [];
      for (const a of Array.isArray(raw.assignments) ? raw.assignments : []) {
        const k = `${a?.day}|${a?.slot}`;
        if (!wanted.has(k) || seen.has(k) || !valid.has(a?.mealId)) continue;
        seen.add(k);
        assignments.push({ day: a.day, slot: a.slot, mealId: a.mealId });
      }
      if (!assignments.length) throw new Error('Model returned no valid assignments');
      const usedIds = new Set(assignments.map((a) => a.mealId));
      return { source: 'groq', newMeals: newMeals.filter((m) => usedIds.has(m.tempId)), assignments };
    } catch (e) {
      console.error('[ai.plan] falling back to offline:', e.message);
      return { source: 'offline', note: 'The AI service was unreachable, used the built-in planner.', ...offlinePlan({ preferences: prefs, meals: safeMeals, slots: safeSlots, allowNew }) };
    }
  }
  return { source: 'offline', note: 'No API key set on the server, used the built-in planner.', ...offlinePlan({ preferences: prefs, meals: safeMeals, slots: safeSlots, allowNew }) };
}

// ---------------------------------------------------------------- normalize
const NO_SINGULAR = new Set(['hummus', 'asparagus', 'couscous', 'molasses', 'swiss', 'citrus', 'lemongrass', 'watercress']);

function singular(word) {
  const w = word.toLowerCase().trim();
  if (NO_SINGULAR.has(w) || w.length < 4) return w;
  if (/(tomato|potato|mango|avocado)es$/.test(w)) return w.slice(0, -2);
  if (/ies$/.test(w)) return w.slice(0, -3) + 'y';
  if (/(ch|sh|x|z|ss)es$/.test(w)) return w.slice(0, -2);
  if (/ss$/.test(w)) return w;
  if (/s$/.test(w)) return w.slice(0, -1);
  return w;
}

function offlineNormalize(names) {
  const groups = new Map();
  for (const n of names) {
    const key = n.toLowerCase().split(/\s+/).map(singular).join(' ');
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(n);
  }
  const aliases = {};
  for (const variants of groups.values()) {
    const distinct = [...new Set(variants.map((v) => v.trim()))];
    if (distinct.length < 2) continue;
    // Prefer the shortest spelling (usually the singular) as the canonical one.
    const canon = [...distinct].sort((a, b) => a.length - b.length || a.localeCompare(b))[0];
    for (const v of distinct) if (v.toLowerCase() !== canon.toLowerCase()) aliases[v.toLowerCase()] = canon;
  }
  return aliases;
}

async function normalize({ names }) {
  const list = [...new Set((Array.isArray(names) ? names : []).map((n) => clip(n, 60)).filter(Boolean))].slice(0, 200);
  if (list.length < 2) return { source: mode(), aliases: {} };
  if (hasKey()) {
    try {
      const text = await callLLM(
        'You clean up grocery ingredient names. Reply with ONE JSON object only: {"aliases": {"variant": "canonical"}}. ' +
          'Only merge names that are truly the same grocery item (plural/singular like Tomatoes->Tomato, ' +
          'synonyms like Scallion->Spring onion, Coriander->Cilantro, Aubergine->Eggplant, spelling variants). ' +
          'NEVER merge different items (e.g. Red onion vs Onion, Chicken breast vs Chicken thigh, Butter vs Peanut butter). ' +
          'Both the variant and the canonical must be copied exactly from the input list. Omit names that need no change.',
        JSON.stringify({ names: list })
      );
      const raw = extractJson(text).aliases || {};
      const byLower = new Map(list.map((n) => [n.toLowerCase(), n]));
      const aliases = {};
      for (const [from, to] of Object.entries(raw)) {
        const f = byLower.get(String(from).toLowerCase());
        const t = byLower.get(String(to).toLowerCase());
        if (f && t && f.toLowerCase() !== t.toLowerCase()) aliases[f.toLowerCase()] = t;
      }
      // Resolve chains (a->b, b->c  =>  a->c, b->c) and drop cycles.
      for (const k of Object.keys(aliases)) {
        let t = aliases[k];
        const seen = new Set([k]);
        while (aliases[t.toLowerCase()] && !seen.has(t.toLowerCase())) {
          seen.add(t.toLowerCase());
          t = aliases[t.toLowerCase()];
        }
        if (seen.has(t.toLowerCase())) delete aliases[k];
        else aliases[k] = t;
      }
      return { source: 'groq', aliases };
    } catch (e) {
      console.error('[ai.normalize] falling back to offline:', e.message);
      return { source: 'offline', note: 'The AI service was unreachable, used the built-in matcher.', aliases: offlineNormalize(list) };
    }
  }
  return { source: 'offline', note: 'No API key set on the server, used the built-in matcher.', aliases: offlineNormalize(list) };
}

module.exports = { mode, hasKey, generateMeal, planWeek, normalize, offlineNormalize, extractJson, MODEL, SLOT_NAMES };
