import express from 'express';
import crypto from 'crypto';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';

const app = express();
app.use(express.json({ limit: '2mb' }));

const DEEPSEEK_BASE = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const DATABASE_PATH = process.env.DATABASE_PATH || './quota-proxy.db';

// SQLite数据库初始化
let db;
async function initDatabase() {
  db = await open({
    filename: DATABASE_PATH,
    driver: sqlite3.Database
  });

  // 创建表
  await db.exec(`
    CREATE TABLE IF NOT EXISTS trial_keys (
      key TEXT PRIMARY KEY,
      label TEXT,
      created_at INTEGER NOT NULL,
      expires_at INTEGER
    )
  `);

  await db.exec(`
    CREATE TABLE IF NOT EXISTS usage_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trial_key TEXT NOT NULL,
      day TEXT NOT NULL,  -- YYYY-MM-DD格式
      requests INTEGER DEFAULT 0,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (trial_key) REFERENCES trial_keys(key) ON DELETE CASCADE
    )
  `);

  // 创建索引
  await db.exec('CREATE INDEX IF NOT EXISTS idx_usage_logs_day_key ON usage_logs(day, trial_key)');
  await db.exec('CREATE INDEX IF NOT EXISTS idx_usage_logs_updated_at ON usage_logs(updated_at)');

  console.log(`[quota-proxy] SQLite database initialized: ${DATABASE_PATH}`);
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
  const row = await db.get('SELECT key FROM trial_keys WHERE key = ?', trialKey);
  return !!row;
}

async function incrUsage(trialKey) {
  const day = dayKey();
  const now = Date.now();
  
  // 使用事务确保原子性
  await db.run('BEGIN TRANSACTION');
  try {
    // 检查是否已有记录
    const existing = await db.get(
      'SELECT id, requests FROM usage_logs WHERE day = ? AND trial_key = ?',
      day, trialKey
    );
    
    if (existing) {
      // 更新现有记录
      await db.run(
        'UPDATE usage_logs SET requests = requests + 1, updated_at = ? WHERE id = ?',
        now, existing.id
      );
      await db.run('COMMIT');
      return { day, requests: existing.requests + 1 };
    } else {
      // 插入新记录
      await db.run(
        'INSERT INTO usage_logs (trial_key, day, requests, updated_at) VALUES (?, ?, 1, ?)',
        trialKey, day, now
      );
      await db.run('COMMIT');
      return { day, requests: 1 };
    }
  } catch (error) {
    await db.run('ROLLBACK');
    throw error;
  }
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

  if (!(await ensureKeyKnown(trialKey))) {
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
    await db.run(
      'INSERT INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)',
      trialKey, label, now
    );
    
    return res.json({ key: trialKey, label, created_at: now });
  } catch (error) {
    console.error('[quota-proxy] Error creating trial key:', error);
    return res.status(500).json({ error: { message: 'Failed to create trial key' } });
  }
});

app.get('/admin/keys', async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  try {
    const keys = await db.all(
      'SELECT key, label, created_at, expires_at FROM trial_keys ORDER BY created_at DESC LIMIT 100'
    );
    return res.json({ keys });
  } catch (error) {
    console.error('[quota-proxy] Error fetching trial keys:', error);
    return res.status(500).json({ error: { message: 'Failed to fetch trial keys' } });
  }
});

app.get('/admin/usage', async (req, res) => {
  if (!isAdmin(req)) return res.status(401).json({ error: { message: 'admin auth required' } });

  const qDay = (req.query?.day && String(req.query.day)) || null; // YYYY-MM-DD格式
  const qKey = (req.query?.key && String(req.query.key)) || null;
  const limit = Math.min(500, Math.max(1, Number(req.query?.limit || 50)));

  try {
    if (qDay) {
      // 按天查询
      let query = `
        SELECT 
          u.trial_key as key,
          t.label,
          u.day,
          u.requests as req_count,
          u.updated_at
        FROM usage_logs u
        LEFT JOIN trial_keys t ON u.trial_key = t.key
        WHERE u.day = ?
      `;
      const params = [qDay];
      
      if (qKey) {
        query += ' AND u.trial_key = ?';
        params.push(qKey);
      }
      
      query += ' ORDER BY u.updated_at DESC';
      
      const items = await db.all(query, params);
      return res.json({ day: qDay, mode: 'sqlite', items });
    } else {
      // 查询所有使用记录（限制数量）
      const items = await db.all(`
        SELECT 
          u.trial_key as key,
          t.label,
          u.day,
          u.requests as req_count,
          u.updated_at
        FROM usage_logs u
        LEFT JOIN trial_keys t ON u.trial_key = t.key
        ORDER BY u.updated_at DESC
        LIMIT ?
      `, limit);
      
      return res.json({ mode: 'sqlite', items });
    }
  } catch (error) {
    console.error('[quota-proxy] Error fetching usage:', error);
    return res.status(500).json({ error: { message: 'Failed to fetch usage data' } });
  }
});

// 启动服务器
async function startServer() {
  await initDatabase();
  
  const port = Number(process.env.PORT || 8787);
  app.listen(port, () => {
    console.log(`[quota-proxy] SQLite version listening on :${port} -> ${DEEPSEEK_BASE} (limit=${DAILY_REQ_LIMIT}/day)`);
    console.log(`[quota-proxy] Database: ${DATABASE_PATH}`);
    console.log(`[quota-proxy] Admin token: ${ADMIN_TOKEN ? 'set' : 'not set (use ADMIN_TOKEN env)'}`);
  });
}

startServer().catch(err => {
  console.error('[quota-proxy] Failed to start server:', err);
  process.exit(1);
});