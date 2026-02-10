const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const { adminRateLimit } = require('./middleware/rate-limit');
const { createAdminIpWhitelist } = require('./middleware/ip-whitelist');
const { createAuditLogMiddleware, createAuditLogApi } = require('./middleware/audit-log');

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

// 数据库性能监控中间件
const queryPerformance = {
    stats: {},
    
    // 记录查询耗时
    recordQuery: function(query, duration) {
        if (!this.stats[query]) {
            this.stats[query] = {
                count: 0,
                totalTime: 0,
                minTime: Infinity,
                maxTime: 0,
                lastExecuted: null
            };
        }
        
        const stat = this.stats[query];
        stat.count++;
        stat.totalTime += duration;
        stat.minTime = Math.min(stat.minTime, duration);
        stat.maxTime = Math.max(stat.maxTime, duration);
        stat.lastExecuted = new Date().toISOString();
        
        // 如果查询耗时超过阈值，记录警告
        if (duration > 100) { // 100ms 阈值
            console.warn(`Slow query detected: ${query} took ${duration}ms`);
        }
    },
    
    // 包装数据库查询方法
    wrapDatabase: function(db) {
        const originalAll = db.all.bind(db);
        const originalRun = db.run.bind(db);
        const originalGet = db.get.bind(db);
        
        db.all = function(sql, params, callback) {
            const start = Date.now();
            return originalAll(sql, params, (err, rows) => {
                const duration = Date.now() - start;
                queryPerformance.recordQuery(sql, duration);
                if (callback) callback(err, rows);
            });
        };
        
        db.run = function(sql, params, callback) {
            const start = Date.now();
            return originalRun(sql, params, function(err) {
                const duration = Date.now() - start;
                queryPerformance.recordQuery(sql, duration);
                if (callback) callback.apply(this, arguments);
            });
        };
        
        db.get = function(sql, params, callback) {
            const start = Date.now();
            return originalGet(sql, params, (err, row) => {
                const duration = Date.now() - start;
                queryPerformance.recordQuery(sql, duration);
                if (callback) callback(err, row);
            });
        };
        
        return db;
    },
    
    // 获取性能统计
    getStats: function() {
        const statsArray = Object.entries(this.stats).map(([query, data]) => ({
            query: query.length > 100 ? query.substring(0, 100) + '...' : query,
            count: data.count,
            avgTime: data.count > 0 ? Math.round(data.totalTime / data.count) : 0,
            minTime: data.minTime === Infinity ? 0 : data.minTime,
            maxTime: data.maxTime,
            lastExecuted: data.lastExecuted
        }));
        
        // 按执行次数排序
        statsArray.sort((a, b) => b.count - a.count);
        
        return {
            totalQueries: Object.values(this.stats).reduce((sum, stat) => sum + stat.count, 0),
            uniqueQueries: Object.keys(this.stats).length,
            slowQueries: statsArray.filter(stat => stat.avgTime > 50).length,
            stats: statsArray.slice(0, 20) // 只返回前20个查询
        };
    }
};

// 包装数据库对象
queryPerformance.wrapDatabase(db);

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

// Admin API - 受速率限制、IP白名单保护
app.use('/admin', adminRateLimit);

// Admin IP 白名单中间件（如果设置了 ADMIN_IP_WHITELIST 环境变量）
const adminIpWhitelist = createAdminIpWhitelist();
app.use('/admin', adminIpWhitelist);

// 审计日志中间件（记录所有 Admin API 操作）
const auditLogMiddleware = createAuditLogMiddleware();
app.use('/admin', auditLogMiddleware);

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
    const { label, totalQuota = 1000, expiresAt } = req.body;
    const key = `sk-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    // 验证过期时间格式（如果提供）
    let expiresAtValue = null;
    if (expiresAt) {
        const expiresDate = new Date(expiresAt);
        if (isNaN(expiresDate.getTime())) {
            return res.status(400).json({ error: 'Invalid expiresAt format. Use ISO 8601 format (e.g., 2026-12-31T23:59:59Z)' });
        }
        expiresAtValue = expiresDate.toISOString();
    }
    
    db.run(
        'INSERT INTO api_keys (key, label, total_quota, expires_at) VALUES (?, ?, ?, ?)',
        [key, label, totalQuota, expiresAtValue],
        function(err) {
            if (err) {
                return res.status(500).json({ error: 'Failed to create key' });
            }
            res.json({
                success: true,
                key,
                label,
                totalQuota,
                expiresAt: expiresAtValue,
                id: this.lastID
            });
        }
    );
});

// 列出所有密钥
app.get('/admin/keys', adminAuth, (req, res) => {
    const { limit = 100, offset = 0, activeOnly = false } = req.query;
    
    let whereClause = '';
    let params = [];
    
    if (activeOnly === 'true') {
        whereClause = 'WHERE (expires_at IS NULL OR expires_at > datetime("now"))';
    }
    
    const query = `
        SELECT 
            id,
            key,
            label,
            total_quota,
            used_quota,
            created_at,
            expires_at,
            CASE 
                WHEN expires_at IS NULL THEN 'active'
                WHEN expires_at > datetime("now") THEN 'active'
                ELSE 'expired'
            END as status
        FROM api_keys
        ${whereClause}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    `;
    
    params.push(parseInt(limit), parseInt(offset));
    
    db.all(query, params, (err, rows) => {
        if (err) {
            console.error('Error fetching keys:', err);
            return res.status(500).json({ error: 'Failed to fetch keys' });
        }
        
        // 获取总数
        const countQuery = `SELECT COUNT(*) as total FROM api_keys ${whereClause}`;
        db.get(countQuery, whereClause ? [] : [], (countErr, countResult) => {
            if (countErr) {
                console.error('Error counting keys:', countErr);
                return res.status(500).json({ error: 'Failed to count keys' });
            }
            
            res.json({
                success: true,
                keys: rows,
                pagination: {
                    total: countResult.total,
                    limit: parseInt(limit),
                    offset: parseInt(offset),
                    hasMore: (parseInt(offset) + rows.length) < countResult.total
                }
            });
        });
    });
});

// 删除密钥
app.delete('/admin/keys/:key', adminAuth, (req, res) => {
    const { key } = req.params;
    
    if (!key) {
        return res.status(400).json({ error: 'Key parameter is required' });
    }
    
    db.run('DELETE FROM api_keys WHERE key = ?', [key], function(err) {
        if (err) {
            console.error('Error deleting key:', err);
            return res.status(500).json({ error: 'Failed to delete key' });
        }
        
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Key not found' });
        }
        
        res.json({ 
            success: true, 
            message: `Key ${key} deleted successfully`,
            deleted: this.changes
        });
    });
});

// 更新密钥标签
app.put('/admin/keys/:key', adminAuth, (req, res) => {
    const { key } = req.params;
    const { label, expiresAt } = req.body;
    
    if (!key) {
        return res.status(400).json({ error: 'Key parameter is required' });
    }
    
    // 至少需要一个字段来更新
    if (!label && !expiresAt) {
        return res.status(400).json({ error: 'At least one field (label or expiresAt) is required for update' });
    }
    
    // 验证过期时间格式（如果提供）
    let expiresAtValue = null;
    if (expiresAt !== undefined) {
        if (expiresAt === null) {
            expiresAtValue = null; // 清除过期时间
        } else {
            const expiresDate = new Date(expiresAt);
            if (isNaN(expiresDate.getTime())) {
                return res.status(400).json({ error: 'Invalid expiresAt format. Use ISO 8601 format (e.g., 2026-12-31T23:59:59Z) or null to clear expiration' });
            }
            expiresAtValue = expiresDate.toISOString();
        }
    }
    
    // 构建更新语句
    const updates = [];
    const params = [];
    
    if (label !== undefined) {
        const trimmedLabel = label ? label.trim() : '';
        if (trimmedLabel === '') {
            return res.status(400).json({ error: 'Label cannot be empty if provided' });
        }
        updates.push('label = ?');
        params.push(trimmedLabel);
    }
    
    if (expiresAt !== undefined) {
        updates.push('expires_at = ?');
        params.push(expiresAtValue);
    }
    
    params.push(key);
    
    const updateQuery = `UPDATE api_keys SET ${updates.join(', ')} WHERE key = ?`;
    
    db.run(updateQuery, params, function(err) {
        if (err) {
            console.error('Error updating key:', err);
            return res.status(500).json({ error: 'Failed to update key' });
        }
        
        if (this.changes === 0) {
            return res.status(404).json({ error: 'Key not found' });
        }
        
        res.json({ 
            success: true, 
            message: `Key ${key} updated successfully`,
            key,
            label: label !== undefined ? (label ? label.trim() : '') : undefined,
            expiresAt: expiresAt !== undefined ? expiresAtValue : undefined,
            updated: this.changes
        });
    });
});

// 数据库性能统计
app.get('/admin/performance', adminAuth, (req, res) => {
    const stats = queryPerformance.getStats();
    res.json({
        success: true,
        data: stats,
        timestamp: new Date().toISOString()
    });
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

// POST /admin/reset-usage - 重置使用统计
app.post('/admin/reset-usage', adminAuth, (req, res) => {
    const { key, reset_logs = false } = req.body;
    
    if (key) {
        // 重置特定密钥的使用量
        db.run('UPDATE api_keys SET used_quota = 0 WHERE key = ?', [key], function(err) {
            if (err) {
                return res.status(500).json({ error: 'Database error' });
            }
            
            if (this.changes === 0) {
                return res.status(404).json({ error: 'Key not found' });
            }
            
            let message = `Successfully reset usage for key: ${key}`;
            
            // 如果请求重置日志，则删除相关日志
            if (reset_logs === true || reset_logs === 'true') {
                db.run('DELETE FROM usage_log WHERE api_key = ?', [key], function(logErr) {
                    if (logErr) {
                        return res.status(500).json({ error: 'Failed to delete usage logs' });
                    }
                    message += ` and deleted ${this.changes} usage log entries`;
                    res.json({ success: true, message });
                });
            } else {
                res.json({ success: true, message });
            }
        });
    } else {
        // 重置所有密钥的使用量
        db.run('UPDATE api_keys SET used_quota = 0', function(err) {
            if (err) {
                return res.status(500).json({ error: 'Database error' });
            }
            
            let message = `Successfully reset usage for all ${this.changes} keys`;
            
            // 如果请求重置日志，则删除所有日志
            if (reset_logs === true || reset_logs === 'true') {
                db.run('DELETE FROM usage_log', function(logErr) {
                    if (logErr) {
                        return res.status(500).json({ error: 'Failed to delete usage logs' });
                    }
                    message += ` and deleted all usage log entries`;
                    res.json({ success: true, message });
                });
            } else {
                res.json({ success: true, message });
            }
        });
    }
});

// 审计日志查询端点（需要管理员认证）
app.get('/admin/audit-logs', adminAuth, createAuditLogApi());

// 启动服务器
app.listen(PORT, () => {
    console.log(`Quota proxy server running on port ${PORT}`);
    console.log(`Admin token: ${ADMIN_TOKEN}`);
    console.log(`Health check: http://localhost:${PORT}/healthz`);
    console.log(`Apply page: http://localhost:${PORT}/apply/`);
    console.log(`Audit logs: http://localhost:${PORT}/admin/audit-logs`);
});
