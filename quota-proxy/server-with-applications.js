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
      
      CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        name TEXT,
        purpose TEXT,
        expected_usage TEXT,
        status TEXT DEFAULT 'pending', -- pending, approved, rejected
        notes TEXT,
        created_at INTEGER NOT NULL,
        reviewed_at INTEGER,
        reviewed_by TEXT,
        trial_key TEXT,
        FOREIGN KEY (trial_key) REFERENCES trial_keys(key) ON DELETE SET NULL
      );
      
      CREATE INDEX IF NOT EXISTS idx_daily_usage_day ON daily_usage(day);
      CREATE INDEX IF NOT EXISTS idx_daily_usage_key ON daily_usage(trial_key);
      CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
      CREATE INDEX IF NOT EXISTS idx_applications_email ON applications(email);
    `);

    console.log(`[quota-proxy] SQLite database initialized with applications table: ${DB_PATH}`);
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
  return xk || null;
}

function requireAdmin(req, res, next) {
  const auth = req.headers['authorization'];
  if (!auth || !auth.toLowerCase().startsWith('bearer ')) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }
  
  const token = auth.slice(7).trim();
  if (token !== ADMIN_TOKEN) {
    return res.status(403).json({ error: 'Invalid admin token' });
  }
  
  next();
}

// 健康检查
app.get('/healthz', (req, res) => {
  res.json({ ok: true });
});

// 模型列表
app.get('/v1/models', async (req, res) => {
  const trialKey = getTrialKey(req);
  
  if (!trialKey) {
    return res.status(401).json({ error: 'Missing trial key' });
  }
  
  // 检查key是否存在（如果启用了持久化）
  if (DB_PATH) {
    try {
      const keyRecord = await db.get('SELECT key FROM trial_keys WHERE key = ?', trialKey);
      if (!keyRecord) {
        return res.status(401).json({ error: 'Invalid trial key' });
      }
    } catch (error) {
      console.error(`[quota-proxy] Database error checking key: ${error.message}`);
    }
  }
  
  // 转发到DeepSeek获取模型列表
  try {
    const response = await fetch(`${DEEPSEEK_BASE}/models`, {
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`DeepSeek API returned ${response.status}`);
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error(`[quota-proxy] Failed to fetch models: ${error.message}`);
    res.status(500).json({ error: 'Failed to fetch models' });
  }
});

// 聊天完成
app.post('/v1/chat/completions', async (req, res) => {
  const trialKey = getTrialKey(req);
  
  if (!trialKey) {
    return res.status(401).json({ error: 'Missing trial key' });
  }
  
  // 检查key是否存在（如果启用了持久化）
  if (DB_PATH) {
    try {
      const keyRecord = await db.get('SELECT key FROM trial_keys WHERE key = ?', trialKey);
      if (!keyRecord) {
        return res.status(401).json({ error: 'Invalid trial key' });
      }
    } catch (error) {
      console.error(`[quota-proxy] Database error checking key: ${error.message}`);
    }
  }
  
  // 检查每日限额
  const today = dayKey();
  if (DB_PATH) {
    try {
      const usage = await db.get(
        'SELECT requests FROM daily_usage WHERE day = ? AND trial_key = ?',
        today, trialKey
      );
      
      const currentRequests = usage ? usage.requests : 0;
      if (currentRequests >= DAILY_REQ_LIMIT) {
        return res.status(429).json({ 
          error: 'Daily request limit exceeded',
          limit: DAILY_REQ_LIMIT,
          used: currentRequests
        });
      }
      
      // 更新使用计数
      if (usage) {
        await db.run(
          'UPDATE daily_usage SET requests = requests + 1, updated_at = ? WHERE day = ? AND trial_key = ?',
          Date.now(), today, trialKey
        );
      } else {
        await db.run(
          'INSERT INTO daily_usage (day, trial_key, requests, updated_at) VALUES (?, ?, 1, ?)',
          today, trialKey, Date.now()
        );
      }
    } catch (error) {
      console.error(`[quota-proxy] Database error updating usage: ${error.message}`);
    }
  }
  
  // 转发到DeepSeek
  try {
    const response = await fetch(`${DEEPSEEK_BASE}/chat/completions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(req.body)
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`DeepSeek API returned ${response.status}: ${errorText}`);
    }
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error(`[quota-proxy] Failed to forward request: ${error.message}`);
    res.status(500).json({ error: 'Failed to forward request to DeepSeek' });
  }
});

// 管理员接口 - 获取所有keys
app.get('/admin/keys', requireAdmin, async (req, res) => {
  try {
    const keys = await db.all('SELECT key, label, created_at FROM trial_keys ORDER BY created_at DESC');
    res.json({ keys });
  } catch (error) {
    console.error(`[quota-proxy] Failed to fetch keys: ${error.message}`);
    res.status(500).json({ error: 'Failed to fetch keys' });
  }
});

// 管理员接口 - 创建key
app.post('/admin/keys', requireAdmin, async (req, res) => {
  const { label } = req.body;
  
  if (!label || typeof label !== 'string') {
    return res.status(400).json({ error: 'Label is required' });
  }
  
  const key = `sk-${crypto.randomBytes(24).toString('hex')}`;
  const createdAt = Date.now();
  
  try {
    await db.run(
      'INSERT INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)',
      key, label, createdAt
    );
    
    res.json({ 
      key, 
      label, 
      created_at: createdAt,
      message: 'Trial key created successfully'
    });
  } catch (error) {
    console.error(`[quota-proxy] Failed to create key: ${error.message}`);
    res.status(500).json({ error: 'Failed to create key' });
  }
});

// 管理员接口 - 删除key
app.delete('/admin/keys/:key', requireAdmin, async (req, res) => {
  const { key } = req.params;
  
  try {
    const result = await db.run('DELETE FROM trial_keys WHERE key = ?', key);
    
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Key not found' });
    }
    
    res.json({ message: 'Key deleted successfully' });
  } catch (error) {
    console.error(`[quota-proxy] Failed to delete key: ${error.message}`);
    res.status(500).json({ error: 'Failed to delete key' });
  }
});

// 管理员接口 - 获取使用情况
app.get('/admin/usage', requireAdmin, async (req, res) => {
  const { limit = 50, offset = 0 } = req.query;
  
  try {
    const usage = await db.all(`
      SELECT d.day, d.trial_key, d.requests, d.updated_at, t.label
      FROM daily_usage d
      LEFT JOIN trial_keys t ON d.trial_key = t.key
      ORDER BY d.day DESC, d.requests DESC
      LIMIT ? OFFSET ?
    `, limit, offset);
    
    res.json({ 
      items: usage,
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error(`[quota-proxy] Failed to fetch usage: ${error.message}`);
    res.status(500).json({ error: 'Failed to fetch usage' });
  }
});

// 管理员接口 - 重置使用计数
app.post('/admin/usage/reset', requireAdmin, async (req, res) => {
  const { day, trial_key } = req.body;
  
  try {
    if (day && trial_key) {
      // 重置特定key在特定日期的计数
      await db.run(
        'UPDATE daily_usage SET requests = 0, updated_at = ? WHERE day = ? AND trial_key = ?',
        Date.now(), day, trial_key
      );
      res.json({ message: `Usage reset for ${trial_key} on ${day}` });
    } else if (day) {
      // 重置特定日期的所有计数
      await db.run(
        'UPDATE daily_usage SET requests = 0, updated_at = ? WHERE day = ?',
        Date.now(), day
      );
      res.json({ message: `All usage reset for day ${day}` });
    } else {
      // 重置所有计数
      await db.run('UPDATE daily_usage SET requests = 0, updated_at = ?', Date.now());
      res.json({ message: 'All usage reset' });
    }
  } catch (error) {
    console.error(`[quota-proxy] Failed to reset usage: ${error.message}`);
    res.status(500).json({ error: 'Failed to reset usage' });
  }
});

// 申请接口 - 提交申请
app.post('/api/apply', async (req, res) => {
  const { email, name, purpose, expected_usage } = req.body;
  
  if (!email || !purpose) {
    return res.status(400).json({ error: 'Email and purpose are required' });
  }
  
  const createdAt = Date.now();
  
  try {
    const result = await db.run(
      'INSERT INTO applications (email, name, purpose, expected_usage, status, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      email, name || '', purpose, expected_usage || '', 'pending', createdAt
    );
    
    res.json({ 
      id: result.lastID,
      message: 'Application submitted successfully. An administrator will review it soon.',
      status: 'pending'
    });
  } catch (error) {
    console.error(`[quota-proxy] Failed to submit application: ${error.message}`);
    res.status(500).json({ error: 'Failed to submit application' });
  }
});

// 管理员接口 - 获取申请列表
app.get('/admin/applications', requireAdmin, async (req, res) => {
  const { status, limit = 50, offset = 0 } = req.query;
  
  try {
    let query = 'SELECT * FROM applications';
    const params = [];
    
    if (status) {
      query += ' WHERE status = ?';
      params.push(status);
    }
    
    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);
    
    const applications = await db.all(query, ...params);
    res.json({ applications });
  } catch (error) {
    console.error(`[quota-proxy] Failed to fetch applications: ${error.message}`);
    res.status(500).json({ error: 'Failed to fetch applications' });
  }
});

// 管理员接口 - 更新申请状态
app.put('/admin/applications/:id', requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { status, notes, trial_key } = req.body;
  
  if (!status || !['pending', 'approved', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Valid status is required' });
  }
  
  const reviewedAt = Date.now();
  
  try {
    await db.run(
      'UPDATE applications SET status = ?, notes = ?, reviewed_at = ?, trial_key = ? WHERE id = ?',
      status, notes || null, reviewedAt, trial_key || null, id
    );
    
    res.json({ 
      message: 'Application updated successfully',
      status,
      reviewed_at: reviewedAt
    });
  } catch (error) {
    console.error(`[quota-proxy] Failed to update application: ${error.message}`);
    res.status(500).json({ error: 'Failed to update application' });
  }
});

// 启动服务器
const PORT = process.env.PORT || 8787;

async function startServer() {
  await initDb();
  
  app.listen(PORT, () => {
    console.log(`[quota-proxy] Server running on port ${PORT}`);
    console.log(`[quota-proxy] Health check: http://localhost:${PORT}/healthz`);
    console.log(`[quota-proxy] Admin interface: http://localhost:${PORT}/admin`);
    console.log(`[quota-proxy] Apply interface: http://localhost:${PORT}/apply`);
  });
}

startServer().catch(error => {
  console.error(`[quota-proxy] Failed to start server: ${error.message}`);
  process.exit(1);
});