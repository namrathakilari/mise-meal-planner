'use strict';
// Household store: one JSON file per household, with an in-memory cache.
// State shape: { rev, meals: {id: meal}, plan: {"week|day|slot": mealId},
//                checked: {"week|itemKey": true}, aliases: {"variant": "Canonical"} }
const fs = require('fs');
const path = require('path');

const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, 'data'));
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
const CODE_RE = /^[A-Z2-9]{6}$/;

fs.mkdirSync(DATA_DIR, { recursive: true });

const cache = new Map();
const timers = new Map();

function emptyState() {
  return { rev: 0, meals: {}, plan: {}, checked: {}, aliases: {} };
}

function normalizeCode(code) {
  return String(code || '').trim().toUpperCase();
}

function isValidCode(code) {
  return CODE_RE.test(code);
}

function fileFor(code) {
  return path.join(DATA_DIR, `${code}.json`);
}

function newCode() {
  for (let attempt = 0; attempt < 50; attempt++) {
    let c = '';
    for (let i = 0; i < 6; i++) c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
    if (!exists(c)) return c;
  }
  throw new Error('Could not allocate a household code');
}

function exists(code) {
  return cache.has(code) || fs.existsSync(fileFor(code));
}

function create() {
  const code = newCode();
  const state = emptyState();
  cache.set(code, state);
  persistNow(code);
  return code;
}

function get(code) {
  if (!isValidCode(code)) return null;
  if (cache.has(code)) return cache.get(code);
  const f = fileFor(code);
  if (!fs.existsSync(f)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(f, 'utf8'));
    const state = { ...emptyState(), ...raw };
    cache.set(code, state);
    return state;
  } catch (_) {
    return null;
  }
}

function persistNow(code) {
  const state = cache.get(code);
  if (!state) return;
  const tmp = fileFor(code) + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(state));
  fs.renameSync(tmp, fileFor(code));
}

function persistSoon(code) {
  if (timers.has(code)) return;
  timers.set(
    code,
    setTimeout(() => {
      timers.delete(code);
      try {
        persistNow(code);
      } catch (e) {
        console.error('persist failed', code, e.message);
      }
    }, 300)
  );
}

function flushAll() {
  for (const [code, t] of timers) {
    clearTimeout(t);
    try {
      persistNow(code);
    } catch (_) {}
  }
  timers.clear();
}

// ---------------------------------------------------------------- validation
const CATEGORIES = ['produce', 'dairy', 'meat', 'pantry', 'frozen', 'other'];
const str = (v, max) => String(v ?? '').slice(0, max);

function cleanMeal(m) {
  if (!m || typeof m !== 'object' || typeof m.id !== 'string' || !m.id || m.id.length > 60) return null;
  const ingredients = (Array.isArray(m.ingredients) ? m.ingredients : []).slice(0, 60).map((i) => {
    const q = typeof i?.quantity === 'number' && isFinite(i.quantity) && i.quantity > 0 ? i.quantity : null;
    return {
      name: str(i?.name, 80),
      quantity: q,
      unit: str(i?.unit, 20),
      category: CATEGORIES.includes(i?.category) ? i.category : 'other',
    };
  });
  return {
    id: m.id,
    name: str(m.name, 100),
    emoji: str(m.emoji || '🍽️', 16),
    colorIndex: Number.isInteger(m.colorIndex) ? Math.abs(m.colorIndex) % 64 : 0,
    servings: Number.isInteger(m.servings) ? Math.min(Math.max(m.servings, 1), 50) : 2,
    ingredients,
  };
}

const PLAN_KEY_RE = /^\d{4}-\d{2}-\d{2}\|[0-6]\|[0-2]$/;

/** Applies one operation. Returns true when the state changed. */
function applyOp(state, op) {
  if (!op || typeof op !== 'object') return false;
  switch (op.t) {
    case 'meal.set': {
      const m = cleanMeal(op.meal);
      if (!m) return false;
      state.meals[m.id] = m;
      return true;
    }
    case 'meal.del': {
      if (typeof op.id !== 'string' || !(op.id in state.meals)) return false;
      delete state.meals[op.id];
      for (const k of Object.keys(state.plan)) if (state.plan[k] === op.id) delete state.plan[k];
      return true;
    }
    case 'plan.set': {
      if (typeof op.key !== 'string' || !PLAN_KEY_RE.test(op.key) || typeof op.id !== 'string') return false;
      state.plan[op.key] = op.id;
      return true;
    }
    case 'plan.del': {
      if (typeof op.key !== 'string' || !(op.key in state.plan)) return false;
      delete state.plan[op.key];
      return true;
    }
    case 'check.set': {
      if (typeof op.key !== 'string' || op.key.length > 200) return false;
      if (op.on) state.checked[op.key] = true;
      else delete state.checked[op.key];
      return true;
    }
    case 'alias.set': {
      const from = str(op.from, 80).trim().toLowerCase();
      if (!from) return false;
      const to = str(op.to, 80).trim();
      if (to) state.aliases[from] = to;
      else delete state.aliases[from];
      return true;
    }
    default:
      return false;
  }
}

function applyOps(code, ops) {
  const state = get(code);
  if (!state) return [];
  const applied = [];
  for (const op of ops.slice(0, 500)) {
    if (applyOp(state, op)) applied.push(op);
  }
  if (applied.length) {
    state.rev += 1;
    persistSoon(code);
  }
  return applied;
}

/** Replaces the whole state (used for the first upload and "reset to samples"). */
function replace(code, incoming) {
  const state = get(code);
  if (!state) return null;
  const next = emptyState();
  for (const m of Object.values(incoming?.meals || {})) {
    const c = cleanMeal(m);
    if (c) next.meals[c.id] = c;
  }
  for (const [k, v] of Object.entries(incoming?.plan || {})) {
    if (PLAN_KEY_RE.test(k) && typeof v === 'string') next.plan[k] = v;
  }
  const checked = Array.isArray(incoming?.checked) ? incoming.checked : Object.keys(incoming?.checked || {});
  for (const k of checked.slice(0, 5000)) if (typeof k === 'string' && k.length <= 200) next.checked[k] = true;
  for (const [k, v] of Object.entries(incoming?.aliases || {})) {
    const from = str(k, 80).trim().toLowerCase();
    const to = str(v, 80).trim();
    if (from && to) next.aliases[from] = to;
  }
  next.rev = state.rev + 1;
  cache.set(code, next);
  persistSoon(code);
  return next;
}

/** Wire format sent to clients (checked becomes a list, meals a list). */
function snapshot(state) {
  return {
    rev: state.rev,
    meals: Object.values(state.meals),
    plan: state.plan,
    checked: Object.keys(state.checked),
    aliases: state.aliases,
  };
}

module.exports = {
  create, get, exists, applyOps, replace, snapshot, flushAll,
  normalizeCode, isValidCode, CATEGORIES,
};
