'use strict';
// End-to-end smoke test: realtime sync between two clients + AI endpoints.
// Run: npm test   (uses a temp data dir and the offline AI engine)
const os = require('os');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'mise-'));
delete process.env.GROQ_API_KEY;

const WebSocket = require('ws');
const { server } = require('../server');
const ai = require('../ai');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const meal = (id, name) => ({ id, name, emoji: '🍝', colorIndex: 1, servings: 2,
  ingredients: [{ name: 'Tomato', quantity: 4, unit: '', category: 'produce' }] });

function client(base, code) {
  const ws = new WebSocket(`${base.replace('http', 'ws')}/ws?code=${code}`);
  const inbox = [];
  ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
  return new Promise((res, rej) => { ws.on('open', () => res({ ws, inbox })); ws.on('error', rej); });
}

(async () => {
  await new Promise((r) => server.listen(0, r));
  const base = `http://localhost:${server.address().port}`;
  const post = (p, b) => fetch(base + p, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) }).then((r) => r.json());

  const health = await (await fetch(base + '/api/health')).json();
  assert.strictEqual(health.ai, 'offline');

  const { code } = await post('/api/households', {});
  assert.match(code, /^[A-Z2-9]{6}$/);

  const a = await client(base, code);
  await sleep(100);
  assert.strictEqual(a.inbox[0].type, 'state');
  assert.strictEqual(a.inbox[0].state.rev, 0);

  // A uploads its local data as the first snapshot
  a.ws.send(JSON.stringify({ type: 'snapshot', state: { meals: [meal('m1', 'Pasta')], plan: { '2026-11-02|0|2': 'm1' }, checked: [], aliases: {} } }));
  await sleep(100);

  // B joins and receives it live
  const b = await client(base, code);
  await sleep(100);
  const st = b.inbox.find((m) => m.type === 'state').state;
  assert.strictEqual(st.meals.length, 1);
  assert.strictEqual(st.plan['2026-11-02|0|2'], 'm1');
  assert(a.inbox.some((m) => m.type === 'presence' && m.peers === 2), 'presence shows 2 online');

  // B edits, A sees the op immediately
  b.ws.send(JSON.stringify({ type: 'ops', ops: [
    { t: 'meal.set', meal: meal('m2', 'Soup') },
    { t: 'plan.set', key: '2026-11-02|1|1', id: 'm2' },
    { t: 'check.set', key: '2026-11-02|tomato|', on: true },
    { t: 'alias.set', from: 'Tomatoes', to: 'Tomato' },
    { t: 'plan.set', key: 'garbage', id: 'x' },
  ] }));
  await sleep(100);
  const ops = a.inbox.filter((m) => m.type === 'ops').flatMap((m) => m.ops);
  assert.strictEqual(ops.length, 4, 'invalid op rejected, 4 valid ones relayed');

  // deleting a meal cascades to the plan for everyone
  a.ws.send(JSON.stringify({ type: 'ops', ops: [{ t: 'meal.del', id: 'm1' }] }));
  await sleep(100);
  const c = await client(base, code);
  await sleep(100);
  const s2 = c.inbox.find((m) => m.type === 'state').state;
  assert.deepStrictEqual(s2.meals.map((m) => m.id), ['m2']);
  assert(!('2026-11-02|0|2' in s2.plan), 'plan entry removed with meal');
  assert.deepStrictEqual(s2.checked, ['2026-11-02|tomato|']);
  assert.strictEqual(s2.aliases.tomatoes, 'Tomato');

  // unknown household
  const bad = await client(base, 'ZZZZZZ');
  await sleep(100);
  assert.strictEqual(bad.inbox[0].type, 'fatal');

  // persistence survives a cache flush
  require('../store').flushAll();
  assert(fs.existsSync(path.join(process.env.DATA_DIR, `${code}.json`)));

  // AI (offline engine)
  const m = await post('/api/ai/meal', { prompt: 'vegetarian lentil soup', servings: 4 });
  assert.strictEqual(m.source, 'offline');
  assert.strictEqual(m.meal.name, 'Lentil soup');
  const m2 = await post('/api/ai/meal', { prompt: 'zzz unknown dish', servings: 3 });
  assert(m2.meal.ingredients.length > 0);

  const slots = [];
  for (let d = 0; d < 7; d++) for (let s = 0; s < 3; s++) slots.push({ day: d, slot: s });
  const plan = await post('/api/ai/plan', { preferences: 'vegetarian', allowNew: true, slots,
    meals: [{ id: 'm2', name: 'Soup', ingredients: [{ name: 'Tomato', category: 'produce' }] }] });
  assert.strictEqual(plan.assignments.length, 21);
  const newIds = new Set(plan.newMeals.map((x) => x.tempId));
  for (const as of plan.assignments) assert(as.mealId === 'm2' || newIds.has(as.mealId));
  for (const nm of plan.newMeals) assert(!nm.ingredients.some((i) => i.category === 'meat'), 'vegetarian respected');

  const norm = await post('/api/ai/normalize', { names: ['Tomato', 'Tomatoes', 'Eggs', 'Egg', 'Onion', 'Red onion', 'Hummus'] });
  assert.strictEqual(norm.aliases.tomatoes, 'Tomato');
  assert.strictEqual(norm.aliases.eggs, 'Egg');
  assert(!('red onion' in norm.aliases) && !('hummus' in norm.aliases));

  // Groq path with a mocked API (no network, no key needed)
  process.env.GROQ_API_KEY = 'test-key';
  const realFetch = global.fetch;
  global.fetch = async (url, opts) => {
    if (!String(url).includes('api.groq.com')) return realFetch(url, opts);
    const body = JSON.parse(opts.body);
    assert.strictEqual(opts.headers.authorization, 'Bearer test-key');
    assert(body.model && body.messages[0].role === 'system' && body.messages[1].content);
    const reply = body.messages[0].content.includes('aliases')
      ? '```json\n{"aliases":{"scallion":"Spring onion","Tomatoes":"Tomato","nonsense":"Tomato"}}\n```'
      : '{"name":"Test curry","emoji":"🍛","servings":4,"ingredients":[{"name":"Rice","quantity":2,"unit":"cup","category":"pantry"},{"name":"","quantity":1}]}';
    return { ok: true, json: async () => ({ choices: [{ message: { content: reply } }] }) };
  };
  const cm = await ai.generateMeal({ prompt: 'curry', servings: 4 });
  assert.strictEqual(cm.source, 'groq');
  assert.strictEqual(cm.meal.ingredients.length, 1, 'blank ingredient dropped');
  const cn = await ai.normalize({ names: ['Scallion', 'Spring onion', 'Tomatoes', 'Tomato'] });
  assert.deepStrictEqual(cn.aliases, { scallion: 'Spring onion', tomatoes: 'Tomato' });
  global.fetch = async () => ({ ok: false, status: 401, text: async () => 'bad key' });
  const fb = await ai.generateMeal({ prompt: 'lentil soup', servings: 2 });
  assert.strictEqual(fb.source, 'offline', 'falls back when Groq errors');

  console.log('All smoke tests passed');
  server.close();
  process.exit(0);
})().catch((e) => { console.error('FAILED:', e); process.exit(1); });
