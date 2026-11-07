'use strict';
const fs = require('fs');
const path = require('path');
const http = require('http');

// Tiny .env loader (avoids an extra dependency).
const envFile = path.join(__dirname, '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const express = require('express');
const { WebSocketServer } = require('ws');
const store = require('./store');
const ai = require('./ai');

const PORT = Number(process.env.PORT) || 8787;
const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '200kb' }));

// CORS: the Flutter dev server runs on another origin.
app.use((req, res, next) => {
  res.set({
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  });
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Simple per-IP rate limit for AI routes (protects your API key).
const hits = new Map();
function aiLimit(req, res, next) {
  const ip = req.ip || 'x';
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60000);
  if (recent.length >= 20) return res.status(429).json({ error: 'Too many AI requests, wait a minute.' });
  recent.push(now);
  hits.set(ip, recent);
  next();
}
setInterval(() => {
  const now = Date.now();
  for (const [ip, arr] of hits) if (!arr.some((t) => now - t < 60000)) hits.delete(ip);
}, 60000).unref();

const wrap = (fn) => (req, res) =>
  Promise.resolve(fn(req, res)).catch((e) => {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  });

app.get('/api/health', (req, res) => {
  res.json({ ok: true, ai: ai.mode(), model: ai.hasKey() ? ai.MODEL() : null });
});

app.post('/api/households', (req, res) => {
  res.json({ code: store.create() });
});

app.get('/api/households/:code', (req, res) => {
  const code = store.normalizeCode(req.params.code);
  const s = store.get(code);
  if (!s) return res.status(404).json({ exists: false });
  res.json({ exists: true, rev: s.rev });
});

app.post('/api/ai/meal', aiLimit, wrap(async (req, res) => {
  const { prompt, servings } = req.body || {};
  if (typeof prompt !== 'string' || prompt.trim().length < 2) return res.status(400).json({ error: 'Describe the meal first.' });
  res.json(await ai.generateMeal({ prompt, servings }));
}));

app.post('/api/ai/plan', aiLimit, wrap(async (req, res) => {
  const { preferences, meals, slots, allowNew } = req.body || {};
  res.json(await ai.planWeek({ preferences, meals, slots, allowNew: !!allowNew }));
}));

app.post('/api/ai/normalize', aiLimit, wrap(async (req, res) => {
  res.json(await ai.normalize({ names: (req.body || {}).names }));
}));

// Serve the built Flutter web app if present (single-origin deployment).
const webDir = path.resolve(__dirname, '..', 'build', 'web');
if (fs.existsSync(webDir)) {
  app.use(express.static(webDir));
  app.get(/^\/(?!api|ws).*/, (req, res) => res.sendFile(path.join(webDir, 'index.html')));
}

// ------------------------------------------------------------------ realtime
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true, maxPayload: 512 * 1024 });
const rooms = new Map(); // code -> Set<ws>

server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname !== '/ws') return socket.destroy();
  const code = store.normalizeCode(url.searchParams.get('code'));
  wss.handleUpgrade(req, socket, head, (ws) => {
    ws.code = code;
    wss.emit('connection', ws);
  });
});

const send = (ws, msg) => ws.readyState === 1 && ws.send(JSON.stringify(msg));

function broadcast(code, msg, except) {
  for (const c of rooms.get(code) || []) if (c !== except) send(c, msg);
}

function presence(code) {
  const n = (rooms.get(code) || new Set()).size;
  broadcast(code, { type: 'presence', peers: n });
}

wss.on('connection', (ws) => {
  const code = ws.code;
  const state = store.get(code);
  if (!state) {
    send(ws, { type: 'fatal', error: 'unknown_household' });
    return ws.close(4004, 'unknown household');
  }
  if (!rooms.has(code)) rooms.set(code, new Set());
  rooms.get(code).add(ws);
  ws.alive = true;
  ws.on('pong', () => (ws.alive = true));

  send(ws, { type: 'state', state: store.snapshot(state) });
  presence(code);

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch (_) {
      return;
    }
    const cur = store.get(code);
    if (!cur) return;
    if (msg.type === 'ops' && Array.isArray(msg.ops)) {
      const applied = store.applyOps(code, msg.ops);
      if (applied.length) broadcast(code, { type: 'ops', ops: applied, rev: cur.rev }, ws);
    } else if (msg.type === 'snapshot') {
      // First upload only: accepted while the household is still empty.
      if (cur.rev === 0) {
        const next = store.replace(code, msg.state);
        broadcast(code, { type: 'state', state: store.snapshot(next) });
      } else {
        send(ws, { type: 'state', state: store.snapshot(cur) });
      }
    } else if (msg.type === 'replace') {
      const next = store.replace(code, msg.state);
      if (next) broadcast(code, { type: 'state', state: store.snapshot(next) }, ws);
    }
  });

  ws.on('close', () => {
    const set = rooms.get(code);
    if (set) {
      set.delete(ws);
      if (set.size === 0) rooms.delete(code);
      else presence(code);
    }
  });
});

// Heartbeat: drop dead connections so presence counts stay right.
const beat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.alive) { ws.terminate(); continue; }
    ws.alive = false;
    ws.ping();
  }
}, 25000);
beat.unref();

function shutdown() {
  store.flushAll();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`Mise server on http://localhost:${PORT}`);
    console.log(ai.hasKey() ? `AI: Groq (${ai.MODEL()})` : 'AI: offline engine (set GROQ_API_KEY to enable Groq)');
    console.log(fs.existsSync(webDir) ? `Serving web app from ${webDir}` : 'No build/web found - run the Flutter app separately.');
  });
}

module.exports = { server };
