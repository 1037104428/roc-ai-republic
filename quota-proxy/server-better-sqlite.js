import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import crypto from 'crypto';
import Database from 'better-sqlite3';

const app = express();
app.use(express.json({ limit: '2mb' }));

// 静态文件服务 - 管理界面
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
app.use('/admin', express.static(join(__dirname, 'admin')));

const DEEPSEEK_BASE = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);

// SQLite database path
const DB_PATH = process.env.SQLITE_PATH || '/data/quota.db';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';

// Database connection
let db = null;

function initDb() {
  try {
    db = new Database(DB_PATH);
    
    // Create tables if they don't exist
    db.exec(`
      CREATE TABLE IF NOT EXISTS trial_keys (
        key TEXT PRIMARY KEY,
        label TEXT,
        created_at INTEGER NOT NULL
      );
      
      CREATE TABLE IF NOT EXISTS daily_usage (
        day TEXT NOT NULL,
        trial_key TEXT NOT NULL,
        requests INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (day, trial_key)
      );
    `);
    
    console.log(`[quota-proxy] SQLite database initialized at ${DB_PATH}`);
  } catch (err) {
    console.error('[quota-proxy] Failed to initialize database:', err.message);
    process.exit(1);
  }
}

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

// Initialize database
initDb();

// -------------------------
// Routes
// -------------------------

// Health check
app.get('/healthz', (req, res) => {
  try {
    // Simple database check
    db.prepare('SELECT 1 as ok').get();
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// DeepSeek proxy
app.all('/v1/*', async (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) {
    return res.status(401).json({ error: { message: 'Missing trial key' } });
  }

  // Check if key exists
  const keyRow = db.prepare('SELECT key FROM trial_keys WHERE key = ?').get(trialKey);
  if (!keyRow) {
    return res.status(403).json({ error: { message: 'Invalid trial key' } });
  }

  const today = dayKey();
  
  // Get or create daily usage
  let usageRow = db.prepare('SELECT requests FROM daily_usage WHERE day = ? AND trial_key = ?').get(today, trialKey);
  if (!usageRow) {
    db.prepare('INSERT INTO daily_usage (day, trial_key, requests, updated_at) VALUES (?, ?, 0, ?)')
      .run(today, trialKey, Date.now());
    usageRow = { requests: 0 };
  }

  // Check daily limit
  if (usageRow.requests >= DAILY_REQ_LIMIT) {
    return res.status(429).json({ 
      error: { 
        message: `Daily limit exceeded (${DAILY_REQ_LIMIT} requests). Reset at midnight UTC.` 
      } 
    });
  }

  // Increment usage
  db.prepare('UPDATE daily_usage SET requests = requests + 1, updated_at = ? WHERE day = ? AND trial_key = ?')
    .run(Date.now(), today, trialKey);

  // Forward to DeepSeek
  const deepseekUrl = `${DEEPSEEK_BASE}${req.path.replace('/v1', '')}`;
  const headers = {
    'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
    'Content-Type': req.headers['content-type'] || 'application/json',
  };

  try {
    const response = await fetch(deepseekUrl, {
      method: req.method,
      headers,
      body: req.method !== 'GET' && req.method !== 'HEAD' ? JSON.stringify(req.body) : undefined,
    });

    const data = await response.json();
    res.status(response.status).json(data);
  } catch (err) {
    console.error('[quota-proxy] DeepSeek request failed:', err.message);
    res.status(500).json({ error: { message: 'Proxy error' } });
  }
});

// Admin: List all trial keys
app.get('/admin/keys', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  
  const keys = db.prepare('SELECT key, label, created_at FROM trial_keys ORDER BY created_at DESC').all();
  res.json({ keys });
});

// Admin: Create new trial key
app.post('/admin/keys', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  
  const { label = '' } = req.body;
  const key = `sk-${crypto.randomBytes(24).toString('hex')}`;
  const now = Date.now();
  
  try {
    db.prepare('INSERT INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)')
      .run(key, label, now);
    
    res.json({ key, label, created_at: now });
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_PRIMARYKEY') {
      // Retry with new key (extremely unlikely collision)
      const newKey = `sk-${crypto.randomBytes(24).toString('hex')}`;
      db.prepare('INSERT INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)')
        .run(newKey, label, now);
      res.json({ key: newKey, label, created_at: now });
    } else {
      res.status(500).json({ error: { message: 'Failed to create key' } });
    }
  }
});

// Admin: Delete trial key
app.delete('/admin/keys/:key', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  
  const { key } = req.params;
  const stmt = db.prepare('DELETE FROM trial_keys WHERE key = ?');
  const result = stmt.run(key);
  
  if (result.changes > 0) {
    // Also delete usage records
    db.prepare('DELETE FROM daily_usage WHERE trial_key = ?').run(key);
    res.json({ deleted: true });
  } else {
    res.status(404).json({ error: { message: 'Key not found' } });
  }
});

// Admin: Get usage statistics
app.get('/admin/usage', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  
  const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
  const offset = Math.max(parseInt(req.query.offset) || 0, 0);
  
  const usage = db.prepare(`
    SELECT d.day, d.trial_key, t.label, d.requests, d.updated_at
    FROM daily_usage d
    LEFT JOIN trial_keys t ON d.trial_key = t.key
    ORDER BY d.day DESC, d.requests DESC
    LIMIT ? OFFSET ?
  `).all(limit, offset);
  
  const total = db.prepare('SELECT COUNT(*) as count FROM daily_usage').get().count;
  
  res.json({
    items: usage,
    total,
    limit,
    offset,
    has_more: offset + usage.length < total
  });
});

// Admin: Reset usage for a specific day/key
app.post('/admin/usage/reset', (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });
  
  const { day, trial_key } = req.body;
  
  if (!day || !trial_key) {
    return res.status(400).json({ error: { message: 'Missing day or trial_key' } });
  }
  
  const stmt = db.prepare('UPDATE daily_usage SET requests = 0, updated_at = ? WHERE day = ? AND trial_key = ?');
  const result = stmt.run(Date.now(), day, trial_key);
  
  if (result.changes > 0) {
    res.json({ reset: true, day, trial_key });
  } else {
    res.status(404).json({ error: { message: 'Usage record not found' } });
  }
});

// Models endpoint (for compatibility)
app.get('/v1/models', (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) {
    return res.status(401).json({ error: { message: 'Missing trial key' } });
  }
  
  // Check if key exists
  const keyRow = db.prepare('SELECT key FROM trial_keys WHERE key = ?').get(trialKey);
  if (!keyRow) {
    return res.status(403).json({ error: { message: 'Invalid trial key' } });
  }
  
  res.json({
    object: 'list',
    data: [
      {
        id: 'deepseek-chat',
        object: 'model',
        created: 1686935000,
        owned_by: 'deepseek'
      },
      {
        id: 'deepseek-coder',
        object: 'model',
        created: 1686935000,
        owned_by: 'deepseek'
      }
    ]
  });
});

const PORT = process.env.PORT || 8787;
app.listen(PORT, () => {
  console.log(`[quota-proxy] SQLite version listening on port ${PORT}`);
  console.log(`[quota-proxy] Database: ${DB_PATH}`);
  console.log(`[quota-proxy] Daily limit: ${DAILY_REQ_LIMIT} requests per key`);
});


// 管理界面健康检查
app.get('/admin/healthz', (req, res) => {
    res.json({ ok: true, service: 'quota-proxy-admin', timestamp: Date.now() });
});