const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');

const app = express();
app.use(cors());
app.use(express.json());

const port = process.env.PORT || 8787;
const adminToken = process.env.ADMIN_TOKEN || 'changeme';
const dbPath = process.env.SQLITE_DB_PATH || '/data/quota.db';

// 初始化数据库
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

// 创建表
db.exec(`
  CREATE TABLE IF NOT EXISTS api_keys (
    key TEXT PRIMARY KEY,
    label TEXT,
    quota INTEGER DEFAULT 1000,
    used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
  );
  
  CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT,
    endpoint TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_key) REFERENCES api_keys(key)
  );
`);

// 中间件：验证管理员 token
const requireAdmin = (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token !== adminToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
};

// 健康检查
app.get('/healthz', (req, res) => {
  res.json({ ok: true, mode: 'sqlite', db: dbPath });
});

// 管理接口：创建 key
app.post('/admin/keys', requireAdmin, (req, res) => {
  const { label, quota = 1000, expiresAt } = req.body;
  const key = 'clawd-' + require('crypto').randomBytes(16).toString('hex');
  
  const stmt = db.prepare(`
    INSERT INTO api_keys (key, label, quota, expires_at)
    VALUES (?, ?, ?, ?)
  `);
  
  try {
    stmt.run(key, label, quota, expiresAt);
    res.json({ key, label, quota, expiresAt });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 管理接口：获取使用情况
app.get('/admin/usage', requireAdmin, (req, res) => {
  const stmt = db.prepare(`
    SELECT key, label, quota, used, created_at, expires_at
    FROM api_keys
    ORDER BY created_at DESC
    LIMIT 50
  `);
  const items = stmt.all();
  res.json({ items, total: items.length });
});

// API 接口：验证 key
app.post('/v1/chat/completions', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing API key' });
  }
  
  const apiKey = authHeader.replace('Bearer ', '');
  const stmt = db.prepare('SELECT * FROM api_keys WHERE key = ?');
  const keyInfo = stmt.get(apiKey);
  
  if (!keyInfo) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  if (keyInfo.expires_at && new Date(keyInfo.expires_at) < new Date()) {
    return res.status(403).json({ error: 'API key expired' });
  }
  
  if (keyInfo.used >= keyInfo.quota) {
    return res.status(429).json({ error: 'Quota exceeded' });
  }
  
  // 记录使用
  const updateStmt = db.prepare('UPDATE api_keys SET used = used + 1 WHERE key = ?');
  updateStmt.run(apiKey);
  
  const logStmt = db.prepare('INSERT INTO usage_logs (api_key, endpoint) VALUES (?, ?)');
  logStmt.run(apiKey, '/v1/chat/completions');
  
  // 返回模拟响应
  res.json({
    id: 'chatcmpl-' + Date.now(),
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model: 'gpt-3.5-turbo',
    choices: [{
      index: 0,
      message: {
        role: 'assistant',
        content: '这是来自 SQLite 版本 quota-proxy 的测试响应。你的 API key 有效，剩余配额: ' + (keyInfo.quota - keyInfo.used - 1)
      },
      finish_reason: 'stop'
    }],
    usage: {
      prompt_tokens: 10,
      completion_tokens: 20,
      total_tokens: 30
    }
  });
});

// 启动服务器
app.listen(port, () => {
  console.log(`SQLite quota-proxy 运行在端口 ${port}`);
  console.log(`数据库: ${dbPath}`);
  console.log(`管理 token: ${adminToken.substring(0, 10)}...`);
});