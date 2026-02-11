// quota-proxy with SQLite persistence and Admin API
// Focus on Admin endpoints: POST /admin/keys and GET /admin/usage

import express from 'express';
import crypto from 'crypto';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';

const app = express();
app.use(express.json({ limit: '2mb' }));

const DEEPSEEK_BASE = process.env.DEEPSEEK_API_BASE_URL || 'https://api.deepseek.com/v1';
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error('[quota-proxy] Missing DEEPSEEK_API_KEY');
  process.exit(1);
}

const DAILY_REQ_LIMIT = Number(process.env.DAILY_REQ_LIMIT || 200);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const DB_PATH = process.env.SQLITE_DB_PATH || './quota-proxy.db';

// SQLite database initialization
let db;

async function initDatabase() {
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
        created_at INTEGER NOT NULL,
        daily_limit INTEGER DEFAULT ${DAILY_REQ_LIMIT},
        is_active INTEGER DEFAULT 1
      );
      
      CREATE TABLE IF NOT EXISTS usage_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trial_key TEXT NOT NULL,
        day TEXT NOT NULL,
        requests INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (trial_key) REFERENCES trial_keys(key)
      );
      
      CREATE TABLE IF NOT EXISTS request_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trial_key TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        endpoint TEXT,
        status_code INTEGER,
        response_time_ms INTEGER,
        FOREIGN KEY (trial_key) REFERENCES trial_keys(key)
      );
    `);

    console.log(`[quota-proxy] SQLite database initialized at ${DB_PATH}`);
  } catch (err) {
    console.error('[quota-proxy] Failed to initialize database:', err);
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

// Admin middleware
function requireAdmin(req, res, next) {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Unauthorized: Admin token required' });
  }
  next();
}

// Generate a random trial key
function generateTrialKey() {
  return 'trial_' + crypto.randomBytes(16).toString('hex');
}

// -------------------------
// Admin API Endpoints
// -------------------------

// POST /admin/keys - Generate a new trial key
app.post('/admin/keys', requireAdmin, async (req, res) => {
  try {
    const { label, daily_limit } = req.body;
    const key = generateTrialKey();
    const now = Date.now();
    
    await db.run(
      'INSERT INTO trial_keys (key, label, created_at, daily_limit, is_active) VALUES (?, ?, ?, ?, ?)',
      [key, label || null, now, daily_limit || DAILY_REQ_LIMIT, 1]
    );
    
    console.log(`[admin] Generated new trial key: ${key}${label ? ` (${label})` : ''}`);
    
    res.json({
      success: true,
      key,
      label: label || null,
      daily_limit: daily_limit || DAILY_REQ_LIMIT,
      created_at: now,
      message: 'Trial key generated successfully'
    });
  } catch (err) {
    console.error('[admin] Error generating trial key:', err);
    res.status(500).json({ error: 'Failed to generate trial key', details: err.message });
  }
});

// GET /admin/usage - Get usage statistics
app.get('/admin/usage', requireAdmin, async (req, res) => {
  try {
    const { key, days = 7 } = req.query;
    
    let query = `
      SELECT 
        tk.key,
        tk.label,
        tk.created_at,
        tk.daily_limit,
        tk.is_active,
        us.day,
        us.requests,
        us.updated_at
      FROM trial_keys tk
      LEFT JOIN usage_stats us ON tk.key = us.trial_key
      WHERE us.day >= date('now', ? || ' days')
    `;
    
    const params = [`-${days}`];
    
    if (key) {
      query += ' AND tk.key = ?';
      params.push(key);
    }
    
    query += ' ORDER BY tk.created_at DESC, us.day DESC';
    
    const rows = await db.all(query, params);
    
    // Group by trial key
    const usageByKey = {};
    rows.forEach(row => {
      if (!usageByKey[row.key]) {
        usageByKey[row.key] = {
          key: row.key,
          label: row.label,
          created_at: row.created_at,
          daily_limit: row.daily_limit,
          is_active: row.is_active,
          usage: []
        };
      }
      
      if (row.day) {
        usageByKey[row.key].usage.push({
          day: row.day,
          requests: row.requests,
          updated_at: row.updated_at
        });
      }
    });
    
    // Get total request count from logs
    const totalRequests = await db.get(
      'SELECT COUNT(*) as count FROM request_logs WHERE timestamp >= ?',
      [Date.now() - (days * 24 * 60 * 60 * 1000)]
    );
    
    // Get active keys count
    const activeKeys = await db.get(
      'SELECT COUNT(*) as count FROM trial_keys WHERE is_active = 1'
    );
    
    res.json({
      success: true,
      summary: {
        total_requests_last_days: totalRequests?.count || 0,
        active_keys: activeKeys?.count || 0,
        days: parseInt(days)
      },
      usage: Object.values(usageByKey)
    });
  } catch (err) {
    console.error('[admin] Error fetching usage stats:', err);
    res.status(500).json({ error: 'Failed to fetch usage statistics', details: err.message });
  }
});

// GET /admin/keys - List all trial keys
app.get('/admin/keys', requireAdmin, async (req, res) => {
  try {
    const { active_only } = req.query;
    
    let query = 'SELECT key, label, created_at, daily_limit, is_active FROM trial_keys';
    const params = [];
    
    if (active_only === 'true') {
      query += ' WHERE is_active = 1';
    }
    
    query += ' ORDER BY created_at DESC';
    
    const keys = await db.all(query, params);
    
    // Get today's usage for each key
    const today = dayKey();
    for (const key of keys) {
      const usage = await db.get(
        'SELECT requests FROM usage_stats WHERE trial_key = ? AND day = ?',
        [key.key, today]
      );
      key.today_requests = usage?.requests || 0;
      key.remaining = Math.max(0, key.daily_limit - key.today_requests);
    }
    
    res.json({
      success: true,
      keys,
      count: keys.length
    });
  } catch (err) {
    console.error('[admin] Error listing trial keys:', err);
    res.status(500).json({ error: 'Failed to list trial keys', details: err.message });
  }
});

// -------------------------
// Main proxy endpoint
// -------------------------

app.post('/v1/chat/completions', async (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) {
    return res.status(401).json({ error: 'Missing trial key in Authorization header or X-Trial-Key' });
  }
  
  try {
    // Check if trial key exists and is active
    const keyInfo = await db.get(
      'SELECT daily_limit, is_active FROM trial_keys WHERE key = ?',
      [trialKey]
    );
    
    if (!keyInfo) {
      return res.status(401).json({ error: 'Invalid trial key' });
    }
    
    if (!keyInfo.is_active) {
      return res.status(403).json({ error: 'Trial key is inactive' });
    }
    
    // Check daily limit
    const today = dayKey();
    let usage = await db.get(
      'SELECT requests FROM usage_stats WHERE trial_key = ? AND day = ?',
      [trialKey, today]
    );
    
    if (!usage) {
      await db.run(
        'INSERT INTO usage_stats (trial_key, day, requests, updated_at) VALUES (?, ?, ?, ?)',
        [trialKey, today, 0, Date.now()]
      );
      usage = { requests: 0 };
    }
    
    if (usage.requests >= keyInfo.daily_limit) {
      return res.status(429).json({ 
        error: 'Daily request limit exceeded', 
        limit: keyInfo.daily_limit,
        used: usage.requests,
        remaining: 0
      });
    }
    
    // Forward request to DeepSeek API
    const startTime = Date.now();
    const deepseekRes = await fetch(`${DEEPSEEK_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`
      },
      body: JSON.stringify(req.body)
    });
    
    const responseTime = Date.now() - startTime;
    const responseBody = await deepseekRes.text();
    
    // Log the request
    await db.run(
      'INSERT INTO request_logs (trial_key, timestamp, endpoint, status_code, response_time_ms) VALUES (?, ?, ?, ?, ?)',
      [trialKey, startTime, '/v1/chat/completions', deepseekRes.status, responseTime]
    );
    
    // Update usage
    await db.run(
      'UPDATE usage_stats SET requests = requests + 1, updated_at = ? WHERE trial_key = ? AND day = ?',
      [Date.now(), trialKey, today]
    );
    
    // Return response
    res.status(deepseekRes.status)
       .set(Object.fromEntries(deepseekRes.headers.entries()))
       .send(responseBody);
    
  } catch (err) {
    console.error('[proxy] Error:', err);
    res.status(500).json({ error: 'Internal server error', details: err.message });
  }
});

// Health check endpoint
app.get('/healthz', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: Date.now(),
    service: 'quota-proxy-admin',
    version: '1.0.0'
  });
});

// -------------------------
// Start server
// -------------------------

async function startServer() {
  await initDatabase();
  
  const PORT = process.env.PORT || 8787;
  app.listen(PORT, () => {
    console.log(`[quota-proxy] Admin API server listening on port ${PORT}`);
    console.log(`[quota-proxy] Admin endpoints protected with ADMIN_TOKEN`);
    console.log(`[quota-proxy] Database: ${DB_PATH}`);
  });
}

startServer().catch(err => {
  console.error('[quota-proxy] Failed to start server:', err);
  process.exit(1);
});