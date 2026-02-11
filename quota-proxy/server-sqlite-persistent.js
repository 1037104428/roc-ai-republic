// quota-proxy with SQLite persistence for trial keys and usage stats
// Simple version with admin-protected endpoints

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
      
      CREATE INDEX IF NOT EXISTS idx_usage_stats_day_key ON usage_stats(day, trial_key);
      CREATE INDEX IF NOT EXISTS idx_usage_stats_key ON usage_stats(trial_key);
    `);

    console.log(`[quota-proxy] SQLite database initialized at ${DB_PATH}`);
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

// -------------------------
// SQLite persistence functions
// -------------------------

async function ensureKeyKnown(trialKey) {
  try {
    const row = await db.get('SELECT key FROM trial_keys WHERE key = ? AND is_active = 1', trialKey);
    return !!row;
  } catch (error) {
    console.error(`[quota-proxy] Database error checking key: ${error.message}`);
    return false;
  }
}

async function incrUsage(trialKey) {
  const day = dayKey();
  const now = Date.now();
  
  try {
    // Try to update existing record
    const result = await db.run(
      'UPDATE usage_stats SET requests = requests + 1, updated_at = ? WHERE day = ? AND trial_key = ?',
      now, day, trialKey
    );
    
    // If no rows updated, insert new record
    if (result.changes === 0) {
      await db.run(
        'INSERT INTO usage_stats (trial_key, day, requests, updated_at) VALUES (?, ?, 1, ?)',
        trialKey, day, now
      );
    }
    
    return true;
  } catch (error) {
    console.error(`[quota-proxy] Database error incrementing usage: ${error.message}`);
    return false;
  }
}

async function getUsage(trialKey, day = null) {
  const targetDay = day || dayKey();
  
  try {
    const row = await db.get(
      'SELECT requests FROM usage_stats WHERE day = ? AND trial_key = ?',
      targetDay, trialKey
    );
    return row ? row.requests : 0;
  } catch (error) {
    console.error(`[quota-proxy] Database error getting usage: ${error.message}`);
    return 0;
  }
}

async function getDailyLimit(trialKey) {
  try {
    const row = await db.get('SELECT daily_limit FROM trial_keys WHERE key = ?', trialKey);
    return row ? row.daily_limit : DAILY_REQ_LIMIT;
  } catch (error) {
    console.error(`[quota-proxy] Database error getting daily limit: ${error.message}`);
    return DAILY_REQ_LIMIT;
  }
}

// -------------------------
// API Endpoints
// -------------------------

// Health check
app.get('/healthz', (req, res) => res.json({ ok: true }));

// Models endpoint (passthrough)
app.get('/v1/models', async (req, res) => {
  try {
    const resp = await fetch(`${DEEPSEEK_BASE}/models`, {
      headers: { 'Authorization': `Bearer ${DEEPSEEK_API_KEY}` }
    });
    const data = await resp.json();
    res.json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Chat completions with quota enforcement
app.post('/v1/chat/completions', async (req, res) => {
  const trialKey = getTrialKey(req);
  if (!trialKey) {
    return res.status(401).json({ error: 'Missing trial key' });
  }
  
  // Check if key exists in database
  const keyExists = await ensureKeyKnown(trialKey);
  if (!keyExists) {
    return res.status(403).json({ error: 'Invalid trial key' });
  }
  
  // Check daily quota
  const usage = await getUsage(trialKey);
  const limit = await getDailyLimit(trialKey);
  
  if (usage >= limit) {
    return res.status(429).json({ error: 'Daily quota exceeded' });
  }
  
  // Increment usage before making the request
  await incrUsage(trialKey);
  
  try {
    const resp = await fetch(`${DEEPSEEK_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`
      },
      body: JSON.stringify(req.body)
    });
    
    const data = await resp.json();
    res.status(resp.status).json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------------
// Admin Endpoints (protected by ADMIN_TOKEN)
// -------------------------

// Generate trial key
app.post('/admin/keys', async (req, res) => {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Admin token required' });
  }
  
  const label = req.body.label || '';
  const dailyLimit = req.body.daily_limit || DAILY_REQ_LIMIT;
  
  // Generate random key
  const key = 'roc_' + crypto.randomBytes(16).toString('hex');
  const now = Date.now();
  
  try {
    await db.run(
      'INSERT INTO trial_keys (key, label, created_at, daily_limit) VALUES (?, ?, ?, ?)',
      key, label, now, dailyLimit
    );
    
    res.json({
      key,
      label,
      created_at: now,
      daily_limit: dailyLimit
    });
  } catch (error) {
    console.error(`[quota-proxy] Database error creating key: ${error.message}`);
    res.status(500).json({ error: 'Failed to create trial key' });
  }
});

// List trial keys
app.get('/admin/keys', async (req, res) => {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Admin token required' });
  }
  
  try {
    const rows = await db.all(
      'SELECT key, label, created_at, daily_limit, is_active FROM trial_keys ORDER BY created_at DESC'
    );
    
    res.json(rows);
  } catch (error) {
    console.error(`[quota-proxy] Database error listing keys: ${error.message}`);
    res.status(500).json({ error: 'Failed to list trial keys' });
  }
});

// Delete trial key
app.delete('/admin/keys/:key', async (req, res) => {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Admin token required' });
  }
  
  const key = req.params.key;
  
  try {
    const result = await db.run('DELETE FROM trial_keys WHERE key = ?', key);
    
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Key not found' });
    }
    
    res.json({ ok: true });
  } catch (error) {
    console.error(`[quota-proxy] Database error deleting key: ${error.message}`);
    res.status(500).json({ error: 'Failed to delete trial key' });
  }
});

// Get usage statistics
app.get('/admin/usage', async (req, res) => {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Admin token required' });
  }
  
  const day = req.query.day || dayKey();
  
  try {
    const rows = await db.all(`
      SELECT 
        tk.key,
        tk.label,
        tk.created_at,
        tk.daily_limit,
        COALESCE(us.requests, 0) as requests,
        COALESCE(us.updated_at, 0) as updated_at
      FROM trial_keys tk
      LEFT JOIN usage_stats us ON tk.key = us.trial_key AND us.day = ?
      WHERE tk.is_active = 1
      ORDER BY tk.created_at DESC
    `, day);
    
    res.json({
      day,
      total_keys: rows.length,
      total_requests: rows.reduce((sum, row) => sum + (row.requests || 0), 0),
      keys: rows
    });
  } catch (error) {
    console.error(`[quota-proxy] Database error getting usage: ${error.message}`);
    res.status(500).json({ error: 'Failed to get usage statistics' });
  }
});

// Reset usage for a specific day
app.post('/admin/usage/reset', async (req, res) => {
  if (!isAdmin(req)) {
    return res.status(401).json({ error: 'Admin token required' });
  }
  
  const day = req.body.day || dayKey();
  
  try {
    await db.run('DELETE FROM usage_stats WHERE day = ?', day);
    res.json({ ok: true, day });
  } catch (error) {
    console.error(`[quota-proxy] Database error resetting usage: ${error.message}`);
    res.status(500).json({ error: 'Failed to reset usage statistics' });
  }
});

// -------------------------
// Server startup
// -------------------------

async function startServer() {
  await initDatabase();
  
  const port = process.env.PORT || 8787;
  app.listen(port, () => {
    console.log(`[quota-proxy] SQLite persistent server listening on port ${port}`);
    console.log(`[quota-proxy] Admin token: ${ADMIN_TOKEN ? 'Set' : 'Not set (use ADMIN_TOKEN env var)'}`);
    console.log(`[quota-proxy] Daily request limit: ${DAILY_REQ_LIMIT}`);
    console.log(`[quota-proxy] Database: ${DB_PATH}`);
  });
}

startServer().catch(error => {
  console.error(`[quota-proxy] Failed to start server: ${error.message}`);
  process.exit(1);
});