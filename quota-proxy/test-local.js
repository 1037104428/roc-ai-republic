import express from 'express';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';

const app = express();
const port = 3001;

// 中间件
app.use(express.json());

// 打开数据库
let db;
async function initDb() {
  db = await open({
    filename: './quota.db',
    driver: sqlite3.Database
  });
  
  // 创建表
  await db.exec(`
    CREATE TABLE IF NOT EXISTS quota_keys (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT UNIQUE NOT NULL,
      total_quota INTEGER DEFAULT 1000000,
      used_quota INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      expires_at DATETIME,
      note TEXT
    )
  `);
  
  console.log('Database initialized');
}

// 健康检查端点
app.get('/healthz', (req, res) => {
  res.json({ ok: true, service: 'quota-proxy-test' });
});

// 简单的密钥验证端点
app.post('/api/v1/chat/completions', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }
  
  const key = authHeader.substring(7);
  
  try {
    const row = await db.get('SELECT * FROM quota_keys WHERE key = ?', key);
    if (!row) {
      return res.status(401).json({ error: 'Invalid API key' });
    }
    
    if (row.used_quota >= row.total_quota) {
      return res.status(429).json({ error: 'Quota exhausted' });
    }
    
    // 模拟成功响应
    res.json({
      id: 'test-' + Date.now(),
      object: 'chat.completion',
      created: Math.floor(Date.now() / 1000),
      model: 'deepseek-chat',
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: 'This is a test response from local quota-proxy'
        },
        finish_reason: 'stop'
      }],
      usage: {
        prompt_tokens: 10,
        completion_tokens: 10,
        total_tokens: 20
      }
    });
    
    // 更新使用量
    await db.run('UPDATE quota_keys SET used_quota = used_quota + 20 WHERE key = ?', key);
    
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 启动服务器
async function start() {
  await initDb();
  
  app.listen(port, () => {
    console.log(`Test quota-proxy running on http://localhost:${port}`);
    console.log(`Health check: curl http://localhost:${port}/healthz`);
  });
}

start().catch(console.error);