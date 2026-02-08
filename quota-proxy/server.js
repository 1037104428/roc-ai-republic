import express from 'express';
import crypto from 'crypto';
import Database from 'better-sqlite3';

const app = express();
app.use(express.json({ limit: '2mb' }));

const DEEPSEEK_BASE = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);

const SQLITE_PATH = process.env.SQLITE_PATH || null;
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';

function dayKey(d = new Date()) {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function getTrialKey(req) {
  // Prefer Authorization: Bearer <trialKey>
  const auth = req.headers['authorization'];
  if (auth && typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ')) {
    return auth.slice(7).trim();
  }
  // Or x-trial-key
  const xk = req.headers['x-trial-key'];
  if (typeof xk === 'string' && xk.trim()) return xk.trim();
  return null;
}

function isAdmin(req) {
  if (!ADMIN_TOKEN) return false;
  const auth = req.headers['authorization'];
  if (auth && typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ')) {
    return auth.slice(7).trim() === ADMIN_TOKEN;
  }
  const xk = req.headers['x-admin-token'];
  if (typeof xk === 'string' && xk.trim()) return xk.trim() === ADMIN_TOKEN;
  return false;
}

// -------------------------
// Persistence (SQLite) v1
// -------------------------
let db = null;
let stmts = null;

function initDb() {
  if (!SQLITE_PATH) return;
  db = new Database(SQLITE_PATH);
  db.pragma('journal_mode = WAL');

  db.exec(`
    CREATE TABLE IF NOT EXISTS keys (
      key TEXT PRIMARY KEY,
      label TEXT,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS usage (
      day TEXT NOT NULL,
      key TEXT NOT NULL,
      requests INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY(day, key)
    );
  `);

  stmts = {
    key_insert: db.prepare('INSERT INTO keys(key,label,created_at) VALUES(?,?,?)'),
    key_exists: db.prepare('SELECT 1 FROM keys WHERE key=?'),
    key_list: db.prepare('SELECT key,label,created_at FROM keys ORDER BY created_at DESC LIMIT ?'),

    usage_get: db.prepare('SELECT requests FROM usage WHERE day=? AND key=?'),
    usage_upsert: db.prepare(
      'INSERT INTO usage(day,key,requests,updated_at) VALUES(?,?,?,?) '
      + 'ON CONFLICT(day,key) DO UPDATE SET requests=excluded.requests, updated_at=excluded.updated_at'
    ),
    usage_recent: db.prepare('SELECT day,key,requests,updated_at FROM usage ORDER BY updated_at DESC LIMIT ?'),
  };

  console.log(`[quota-proxy] sqlite enabled: ${SQLITE_PATH}`);
}

initDb();

function ensureKeyKnown(trialKey) {
  // If sqlite enabled, require key exists (issued by admin). If sqlite disabled, allow any key.
  if (!db) return true;
  return !!stmts.key_exists.get(trialKey);
}

function incrUsage(trialKey) {
  const day = dayKey();
  const now = Date.now();

  if (!db) {
    // in-memory fallback
    const k = `${day}:${trialKey}`;
    const c = (inMemoryUsage.get(k) || 0) + 1;
    inMemoryUsage.set(k, c);
    return { day, requests: c };
  }

  const row = stmts.usage_get.get(day, trialKey);
  const next = (row?.requests || 0) + 1;
  stmts.usage_upsert.run(day, trialKey, next, now);
  return { day, requests: next };
}

// In-memory usage (fallback if sqlite disabled)
const inMemoryUsage = new Map();

// -------------------------
// Public endpoints
// -------------------------

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.get('/v1/models', async (req, res) => {
  // minimal model list for OpenAI-compatible clients
  return res.json({
    object: 'list',
    data: [
      { id: 'deepseek-chat', object: 'model', owned_by: 'deepseek' },
      { id: 'deepseek-reasoner', object: 'model', owned_by: 'deepseek' },
    ],
  });
});

app.post('/v1/chat/completions', async (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) {
    return res.status(401).json({
      error: { message: 'Missing trial key (use Authorization: Bearer <TRIAL_KEY>)' },
    });
  }

  if (!ensureKeyKnown(trialKey)) {
    return res.status(401).json({
      error: { message: 'Unknown TRIAL_KEY (not issued). Please request a trial key.' },
    });
  }

  const { requests } = incrUsage(trialKey);
  if (requests > DAILY_REQ_LIMIT) {
    return res.status(429).json({
      error: { message: `Trial quota exceeded (daily requests>${DAILY_REQ_LIMIT}).` },
    });
  }

  const upstream = `${DEEPSEEK_BASE}/chat/completions`;
  const r = await fetch(upstream, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify(req.body),
  });

  const text = await r.text();
  res.status(r.status);
  res.setHeader('content-type', r.headers.get('content-type') || 'application/json');
  return res.send(text);
});

// -------------------------
// Admin endpoints (v1)
// -------------------------

app.post('/admin/keys', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  if (!db) return res.status(400).json({ error: { message: 'sqlite not enabled (set SQLITE_PATH)' } });

  const label = (req.body?.label && String(req.body.label)) || null;
  const trialKey = `trial_${crypto.randomBytes(18).toString('hex')}`;
  const now = Date.now();
  stmts.key_insert.run(trialKey, label, now);
  return res.json({ key: trialKey, label, created_at: now });
});

app.get('/admin/usage', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const limit = Math.min(500, Math.max(1, Number(req.query?.limit || 50)));

  if (!db) {
    // return in-memory snapshot
    const day = dayKey();
    const out = [];
    for (const [k, v] of inMemoryUsage.entries()) {
      const [d, key] = k.split(':');
      if (d !== day) continue;
      out.push({ day: d, key, requests: v });
    }
    return res.json({ mode: 'memory', items: out.slice(0, limit) });
  }

  const items = stmts.usage_recent.all(limit);
  return res.json({ mode: 'sqlite', items });
});

const port = Number(process.env.PORT || 8787);
app.listen(port, () => {
  console.log(`[quota-proxy] listening on :${port} -> ${DEEPSEEK_BASE} (limit=${DAILY_REQ_LIMIT}/day)`);
});
