import express from 'express';
import crypto from 'crypto';
import fs from 'fs';

const app = express();
app.use(express.json({ limit: '2mb' }));

const DEEPSEEK_BASE = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);

// Persistence file (we keep the env name SQLITE_PATH for compatibility, but v0 stores JSON)
const STORE_PATH = process.env.SQLITE_PATH || null;
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';

function dayKey(d = new Date()) {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function getTrialKey(req) {
  const auth = req.headers['authorization'];
  if (auth && typeof auth === 'string' && auth.toLowerCase().startsWith('bearer ')) {
    return auth.slice(7).trim();
  }
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
// JSON persistence (v0.1)
// -------------------------

const state = {
  keys: {}, // trialKey -> {label, created_at}
  usage: {}, // day -> { trialKey -> {requests, updated_at} }
};

function loadStore() {
  if (!STORE_PATH) return;
  try {
    const raw = fs.readFileSync(STORE_PATH, 'utf8');
    const j = JSON.parse(raw);
    if (j && typeof j === 'object') {
      state.keys = j.keys || {};
      state.usage = j.usage || {};
    }
    console.log(`[quota-proxy] store loaded: ${STORE_PATH}`);
  } catch (e) {
    // ok if missing or invalid
    console.log(`[quota-proxy] store init: ${STORE_PATH}`);
  }
}

let saveTimer = null;
function saveStoreSoon() {
  if (!STORE_PATH) return;
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    try {
      fs.mkdirSync(require('path').dirname(STORE_PATH), { recursive: true });
    } catch {}
    fs.writeFileSync(STORE_PATH, JSON.stringify({ keys: state.keys, usage: state.usage }, null, 0));
  }, 250);
}

loadStore();

function ensureKeyKnown(trialKey) {
  // If persistence enabled, require key exists (issued by admin). If disabled, allow any key.
  if (!STORE_PATH) return true;
  return !!state.keys[trialKey];
}

function incrUsage(trialKey) {
  const day = dayKey();
  const now = Date.now();
  state.usage[day] ||= {};
  const row = state.usage[day][trialKey] || { requests: 0, updated_at: now };
  row.requests += 1;
  row.updated_at = now;
  state.usage[day][trialKey] = row;
  saveStoreSoon();
  return { day, requests: row.requests };
}

// -------------------------
// Public endpoints
// -------------------------

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.get('/v1/models', async (req, res) => {
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
    return res.status(401).json({ error: { message: 'Missing trial key (use Authorization: Bearer <TRIAL_KEY>)' } });
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
// Admin endpoints
// -------------------------

app.post('/admin/keys', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  if (!STORE_PATH) return res.status(400).json({ error: { message: 'persistence disabled (set SQLITE_PATH)' } });

  const label = (req.body?.label && String(req.body.label)) || null;
  const trialKey = `trial_${crypto.randomBytes(18).toString('hex')}`;
  const now = Date.now();
  state.keys[trialKey] = { label, created_at: now };
  saveStoreSoon();
  return res.json({ key: trialKey, label, created_at: now });
});

app.delete('/admin/keys/:key', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  if (!STORE_PATH) return res.status(400).json({ error: { message: 'persistence disabled (set SQLITE_PATH)' } });

  const key = String(req.params.key || '').trim();
  if (!key) return res.status(400).json({ error: { message: 'missing key' } });

  const existed = !!state.keys[key];
  delete state.keys[key];
  saveStoreSoon();
  return res.json({ deleted: existed, key });
});

app.post('/admin/usage/reset', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const key = (req.query?.key && String(req.query.key)) || null;
  if (!key) return res.status(400).json({ error: { message: 'missing key (use ?key=trial_xxx)' } });

  const d = (req.query?.day && String(req.query.day)) || dayKey();
  const now = Date.now();
  state.usage[d] ||= {};
  state.usage[d][key] = { requests: 0, updated_at: now };
  saveStoreSoon();
  return res.json({ reset: true, key, day: d });
});

app.get('/admin/usage', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const qDay = (req.query?.day && String(req.query.day)) || null; // YYYY-MM-DD
  const qKey = (req.query?.key && String(req.query.key)) || null;

  // Preferred mode: query by day (optionally by key) → stable, predictable output
  if (qDay) {
    const byKey = state.usage[qDay] || {};
    let items = Object.entries(byKey).map(([key, row]) => ({
      key,
      label: state.keys?.[key]?.label ?? null,
      req_count: row?.requests || 0,
      updated_at: row?.updated_at || null,
    }));
    if (qKey) items = items.filter((x) => x.key === qKey);
    items.sort((a, b) => (b.updated_at || 0) - (a.updated_at || 0));
    return res.json({ day: qDay, mode: STORE_PATH ? 'file' : 'memory', items });
  }

  // Back-compat mode: recent usage rows across all days
  const limit = Math.min(500, Math.max(1, Number(req.query?.limit || 50)));
  const items = [];
  for (const [day, byKey] of Object.entries(state.usage)) {
    for (const [key, row] of Object.entries(byKey)) {
      items.push({ day, key, label: state.keys?.[key]?.label ?? null, req_count: row.requests, updated_at: row.updated_at });
    }
  }
  items.sort((a, b) => (b.updated_at || 0) - (a.updated_at || 0));
  return res.json({ mode: STORE_PATH ? 'file' : 'memory', items: items.slice(0, limit) });
});

const port = Number(process.env.PORT || 8787);
app.listen(port, () => {
  console.log(`[quota-proxy] listening on :${port} -> ${DEEPSEEK_BASE} (limit=${DAILY_REQ_LIMIT}/day)`);
  if (STORE_PATH) console.log(`[quota-proxy] persistence=on (file): ${STORE_PATH}`);
});
