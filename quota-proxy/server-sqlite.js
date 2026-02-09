const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const { adminRateLimit } = require('./middleware/rate-limit');

const app = express();
const PORT = process.env.PORT || 8787;
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'dev-admin-token-change-in-production';

// 数据库初始化
const db = new sqlite3.Database(':memory:'); // 使用内存数据库，生产环境应改为文件
db.serialize(() => {
    db.run(`
        CREATE TABLE IF NOT EXISTS api_keys (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            label TEXT,
            total_quota INTEGER DEFAULT 1000,
            used_quota INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME
        )
    `);
    
    db.run(`
        CREATE TABLE IF NOT EXISTS usage_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_key TEXT,
            endpoint TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            response_time INTEGER,
            status_code INTEGER
        )
    `);
});

// 中间件
app.use(express.json());

// 静态文件服务 - 用于 /apply 页面
app.use('/apply', express.static(path.join(__dirname, 'apply')));

// 健康检查端点
app.get('/healthz', (req, res) => {
    res.json({ ok: true });
});

// API 网关端点
app.post('/gateway', (req, res) => {
    const apiKey = req.headers['x-api-key'] || req.query.api_key;
    
    if (!apiKey) {
        return res.status(401).json({ error: 'Missing API key' });
    }
    
    // 检查 API key 有效性
    db.get('SELECT * FROM api_keys WHERE key = ? AND (expires_at IS NULL OR expires_at > datetime("now"))', [apiKey], (err, row) => {
        if (err || !row) {
            return res.status(403).json({ error: 'Invalid or expired API key' });
        }
        
        // 检查配额
        if (row.used_quota >= row.total_quota) {
            return res.status(429).json({ error: 'Quota exceeded' });
        }
        
        // 模拟 API 调用
        const responseTime = Math.floor(Math.random() * 100) + 50;
        
        // 记录使用情况
        db.run(
            'INSERT INTO usage_log (api_key, endpoint, response_time, status_code) VALUES (?, ?, ?, ?)',
            [apiKey, '/gateway', responseTime, 200]
        );
        
        // 更新已用配额
        db.run('UPDATE api_keys SET used_quota = used_quota + 1 WHERE key = ?', [apiKey]);
        
        // 返回模拟响应
        setTimeout(() => {
            res.json({
                success: true,
                data: {
                    message: 'API request processed',
                    responseTime: `${responseTime}ms`,
                    remainingQuota: row.total_quota - (row.used_quota + 1)
                }
            });
        }, responseTime);
    });
});

// Admin API - 受速率限制保护
app.use('/admin', adminRateLimit);

// Admin 认证中间件
const adminAuth = (req, res, next) => {
    const token = req.headers['authorization']?.replace('Bearer ', '') || 
                  req.headers['x-admin-token'] || 
                  req.query.admin_token;
    
    if (token !== ADMIN_TOKEN) {
        return res.status(401).json({ error: 'Invalid admin token' });
    }
    next();
};

// 生成试用密钥
app.post('/admin/keys', adminAuth, (req, res) => {
    const { label, totalQuota = 1000 } = req.body;
    const key = `sk-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    db.run(
        'INSERT INTO api_keys (key, label, total_quota) VALUES (?, ?, ?)',
        [key, label, totalQuota],
        function(err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to create key' });
            }
            res.json({
                success: true,
                key,
                label,
                totalQuota,
                id: this.lastID
            });
        }
    );
});

// 查看使用情况
app.get('/admin/usage', adminAuth, (req, res) => {
    const { key, days = 7 } = req.query;
    
    let query = `
        SELECT 
            ak.key,
            ak.label,
            ak.total_quota,
            ak.used_quota,
            ak.created_at,
            COUNT(ul.id) as request_count,
            AVG(ul.response_time) as avg_response_time
        FROM api_keys ak
        LEFT JOIN usage_log ul ON ak.key = ul.api_key
            AND ul.timestamp > datetime('now', ?)
        GROUP BY ak.id
    `;
    
    const params = [`-${days} days`];
    
    if (key) {
        query += ' WHERE ak.key = ?';
        params.push(key);
    }
    
    db.all(query, params, (err, rows) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        res.json({ success: true, data: rows });
    });
});

// 启动服务器
app.listen(PORT, () => {
    console.log(`Quota proxy server running on port ${PORT}`);
    console.log(`Admin token: ${ADMIN_TOKEN}`);
    console.log(`Health check: http://localhost:${PORT}/healthz`);
    console.log(`Apply page: http://localhost:${PORT}/apply/`);
});
