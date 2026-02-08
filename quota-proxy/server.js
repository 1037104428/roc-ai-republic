import express from 'express';

const app = express();
app.use(express.json({ limit: '2mb' }));

const DEEPSEEK_BASE = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

// v0 quota: extremely simple (per trial key per day requests)
const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);
const usage = new Map(); // key: `${yyyy-mm-dd}:${trialKey}` -> count

function dayKey() {
  const d = new Date();
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

app.get('/v1/models', async (req, res) => {
  // minimal model list for OpenAI-compatible clients
  return res.json({
    object: 'list',
    data: [
      { id: 'deepseek-chat', object: 'model', owned_by: 'deepseek' },
      { id: 'deepseek-reasoner', object: 'model', owned_by: 'deepseek' }
    ]
  });
});

app.post('/v1/chat/completions', async (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) return res.status(401).json({ error: { message: 'Missing trial key (use Authorization: Bearer <TRIAL_KEY>)' } });

  const k = `${dayKey()}:${trialKey}`;
  const c = (usage.get(k) || 0) + 1;
  usage.set(k, c);
  if (c > DAILY_REQ_LIMIT) {
    return res.status(429).json({ error: { message: `Trial quota exceeded (daily requests>${DAILY_REQ_LIMIT}).` } });
  }

  const upstream = `${DEEPSEEK_BASE}/chat/completions`;
  const r = await fetch(upstream, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'authorization': `Bearer ${DEEPSEEK_API_KEY}`
    },
    body: JSON.stringify(req.body)
  });

  const text = await r.text();
  res.status(r.status);
  // Pass-through content-type
  res.setHeader('content-type', r.headers.get('content-type') || 'application/json');
  return res.send(text);
});

app.get('/healthz', (req, res) => res.json({ ok: true }));

const port = Number(process.env.PORT || 8787);
app.listen(port, () => {
  console.log(`[quota-proxy] listening on :${port} -> ${DEEPSEEK_BASE}`);
});
