import express from 'express';
import crypto from 'crypto';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const app = express();
app.use(express.json({ limit: '2mb' }));

// 静态文件服务 - 管理界面
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
app.use('/admin', express.static(join(__dirname, 'admin')));
app.use('/apply', express.static(join(__dirname, 'apply')));

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

async function initDb() {
  try {
    db = await open({
      filename: DB_PATH,
      driver: sqlite3.Database
    });

    // Create tables if they don't exist
    await db.exec(`
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
        PRIMARY KEY (day, trial_key),
        FOREIGN KEY (trial_key) REFERENCES trial_keys(key) ON DELETE CASCADE
      );
      
      CREATE INDEX IF NOT EXISTS idx_daily_usage_day ON daily_usage(day);
      CREATE INDEX IF NOT EXISTS idx_daily_usage_key ON daily_usage(trial_key);
    `);

    console.log(`[quota-proxy] SQLite database initialized: ${DB_PATH}`);
  } catch (error) {
    console.error(`[quota-proxy] Failed to initialize database: ${error.message}`);
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

async function ensureKeyKnown(trialKey) {
  try {
    const row = await db.get('SELECT key FROM trial_keys WHERE key = ?', trialKey);
    return !!row;
  } catch (error) {
    console.error(`[quota-proxy] Database error in ensureKeyKnown: ${error.message}`);
    return false;
  }
}

async function incrUsage(trialKey) {
  const day = dayKey();
  const now = Date.now();
  
  try {
    // Insert or update daily usage
    await db.run(`
      INSERT INTO daily_usage (day, trial_key, requests, updated_at)
      VALUES (?, ?, 1, ?)
      ON CONFLICT(day, trial_key) DO UPDATE SET
        requests = requests + 1,
        updated_at = ?
    `, [day, trialKey, now, now]);

    // Get current count
    const row = await db.get(
      'SELECT requests FROM daily_usage WHERE day = ? AND trial_key = ?',
      [day, trialKey]
    );
    
    return { day, requests: row?.requests || 1 };
  } catch (error) {
    console.error(`[quota-proxy] Database error in incrUsage: ${error.message}`);
    return { day, requests: 1 };
  }
}

// Initialize database
await initDb();

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

  const known = await ensureKeyKnown(trialKey);
  if (!known) {
    return res.status(401).json({
      error: { message: 'Unknown TRIAL_KEY (not issued). Please request a trial key.' },
    });
  }

  const { requests } = await incrUsage(trialKey);
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

app.post('/admin/keys', async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const label = (req.body?.label && String(req.body.label)) || null;
  const trialKey = `trial_${crypto.randomBytes(18).toString('hex')}`;
  const now = Date.now();
  
  try {
    await db.run('INSERT INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)', 
      [trialKey, label, now]);
    
    return res.json({ key: trialKey, label, created_at: now });
  } catch (error) {
    console.error(`[quota-proxy] Database error in POST /admin/keys: ${error.message}`);
    return res.status(500).json({ error: { message: 'Database error' } });
  }
});

app.get('/admin/usage', async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const qDay = (req.query?.day && String(req.query.day)) || null; // YYYY-MM-DD
  const qKey = (req.query?.key && String(req.query.key)) || null;
  const limit = Math.min(500, Math.max(1, Number(req.query?.limit || 50)));

  try {
    if (qDay) {
      let query = `
        SELECT du.trial_key as key, du.requests as req_count, du.updated_at, tk.label
        FROM daily_usage du
        LEFT JOIN trial_keys tk ON du.trial_key = tk.key
        WHERE du.day = ?
      `;
      const params = [qDay];
      
      if (qKey) {
        query += ' AND du.trial_key = ?';
        params.push(qKey);
      }
      
      query += ' ORDER BY du.updated_at DESC';
      
      const items = await db.all(query, params);
      return res.json({ day: qDay, mode: 'sqlite', items });
    }

    // Recent usage across all days
    const items = await db.all(`
      SELECT du.day, du.trial_key as key, du.requests as req_count, du.updated_at, tk.label
      FROM daily_usage du
      LEFT JOIN trial_keys tk ON du.trial_key = tk.key
      ORDER BY du.updated_at DESC
      LIMIT ?
    `, [limit]);
    
    return res.json({ mode: 'sqlite', items });
  } catch (error) {
    console.error(`[quota-proxy] Database error in GET /admin/usage: ${error.message}`);
    return res.status(500).json({ error: { message: 'Database error' } });
  }
});

app.get('/admin/keys', async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  try {
    const keys = await db.all(`
      SELECT key, label, created_at
      FROM trial_keys
      ORDER BY created_at DESC
    `);
    
    return res.json({ mode: 'sqlite', keys });
  } catch (error) {
    console.error(`[quota-proxy] Database error in GET /admin/keys: ${error.message}`);
    return res.status(500).json({ error: { message: 'Database error' } });
  }
});

// Serve admin interface
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Serve static admin interface
app.get('/admin', (req, res) => {
  if (!ADMIN_TOKEN) {
    return res.status(404).send('Admin interface disabled (no ADMIN_TOKEN set)');
  }
  
  // Check if admin.html exists
  const adminHtmlPath = join(__dirname, 'admin.html');
  res.sendFile(adminHtmlPath, (err) => {
    if (err) {
      console.error(`[quota-proxy] Error serving admin interface: ${err.message}`);
      res.status(404).send('Admin interface not found');
    }
  });
});

// Simple health check endpoint for admin interface
app.get('/admin/health', (req, res) => {
  res.json({ 
    ok: true, 
    mode: 'sqlite',
    db_path: DB_PATH,
    admin_interface: ADMIN_TOKEN ? 'enabled' : 'disabled'
  });
});

// Start server
const PORT = process.env.PORT || 8787;
app.listen(PORT, () => {
  console.log(`[quota-proxy] SQLite version listening on port ${PORT}`);
  console.log(`[quota-proxy] Database: ${DB_PATH}`);
  console.log(`[quota-proxy] Daily limit: ${DAILY_REQ_LIMIT}`);
  console.log(`[quota-proxy] Admin interface: ${ADMIN_TOKEN ? 'enabled at /admin' : 'disabled (no ADMIN_TOKEN)'}`);
});


// 管理界面健康检查
app.get('/admin/healthz', (req, res) => {
    res.json({ ok: true, service: 'quota-proxy-admin', timestamp: Date.now() });
});