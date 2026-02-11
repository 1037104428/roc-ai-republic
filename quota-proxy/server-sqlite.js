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
    const healthStatus = {
        ok: true,
        timestamp: new Date().toISOString(),
        service: 'quota-proxy',
        version: '1.0.0',
        checks: {
            server: { ok: true, message: 'Express server is running' },
            database: { ok: false, message: 'Database check pending' }
        }
    };
    
    // 检查数据库连接
    db.get('SELECT 1 as test', (err, row) => {
        if (err) {
            healthStatus.checks.database = { 
                ok: false, 
                message: `Database error: ${err.message}`,
                error: err.message
            };
            healthStatus.ok = false;
        } else if (row && row.test === 1) {
            healthStatus.checks.database = { 
                ok: true, 
                message: 'Database connection is healthy',
                queryTest: 'SELECT 1 executed successfully'
            };
        } else {
            healthStatus.checks.database = { 
                ok: false, 
                message: 'Database query returned unexpected result'
            };
            healthStatus.ok = false;
        }
        
        // 检查数据库表结构
        db.all("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name", (err, tables) => {
            if (err) {
                healthStatus.checks.database.tables = { 
                    ok: false, 
                    message: `Failed to list tables: ${err.message}`,
                    error: err.message
                };
                healthStatus.ok = false;
            } else {
                const tableNames = tables.map(t => t.name);
                healthStatus.checks.database.tables = {
                    ok: true,
                    message: `Found ${tableNames.length} tables`,
                    tables: tableNames,
                    requiredTables: ['api_keys', 'usage_log'].filter(t => tableNames.includes(t))
                };
                
                // 检查必需的表是否存在
                const missingTables = ['api_keys', 'usage_log'].filter(t => !tableNames.includes(t));
                if (missingTables.length > 0) {
                    healthStatus.checks.database.tables.ok = false;
                    healthStatus.checks.database.tables.message = `Missing required tables: ${missingTables.join(', ')}`;
                    healthStatus.ok = false;
                }
            }
            
            // 返回完整的健康状态
            res.json(healthStatus);
        });
    });
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

// 查看使用情况（支持分页）
app.get('/admin/usage', adminAuth, (req, res) => {
    const { key, days = 7, page = 1, limit = 50 } = req.query;
    
    // 验证分页参数
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const offset = (pageNum - 1) * limitNum;
    
    if (pageNum < 1 || limitNum < 1 || limitNum > 100) {
        return res.status(400).json({ 
            error: 'Invalid pagination parameters. Page must be >= 1, limit must be between 1 and 100.' 
        });
    }
    
    let countQuery = `
        SELECT COUNT(DISTINCT ak.id) as total
        FROM api_keys ak
        LEFT JOIN usage_log ul ON ak.key = ul.api_key
            AND ul.timestamp > datetime('now', ?)
    `;
    
    let dataQuery = `
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
    const countParams = [...params];
    const dataParams = [...params];
    
    if (key) {
        const whereClause = ' WHERE ak.key = ?';
        countQuery += whereClause;
        dataQuery += whereClause;
        countParams.push(key);
        dataParams.push(key);
    }
    
    // 添加分页
    dataQuery += ' ORDER BY ak.created_at DESC LIMIT ? OFFSET ?';
    dataParams.push(limitNum, offset);
    
    // 先获取总数
    db.get(countQuery, countParams, (countErr, countResult) => {
        if (countErr) {
            return res.status(500).json({ error: 'Database error when counting records' });
        }
        
        const total = countResult.total || 0;
        const totalPages = Math.ceil(total / limitNum);
        
        // 再获取分页数据
        db.all(dataQuery, dataParams, (dataErr, rows) => {
            if (dataErr) {
                return res.status(500).json({ error: 'Database error when fetching records' });
            }
            
            res.json({ 
                success: true, 
                data: rows,
                pagination: {
                    page: pageNum,
                    limit: limitNum,
                    total,
                    totalPages,
                    hasNextPage: pageNum < totalPages,
                    hasPrevPage: pageNum > 1
                }
            });
        });
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

// 统计信息API
// 公开状态端点 - 无需认证，返回基本服务状态
app.get('/status', (req, res) => {
    const status = {
        timestamp: new Date().toISOString(),
        service: 'quota-proxy',
        version: 'v1.0',
        status: 'operational',
        uptime: process.uptime(),
        endpoints: {
            gateway: '/gateway',
            health: '/healthz',
            apply: '/apply/',
            status: '/status',
            admin: {
                keys: '/admin/keys',
                usage: '/admin/usage',
                stats: '/admin/stats',
                performance: '/admin/performance',
                audit_logs: '/admin/audit-logs'
            }
        }
    };
    
    // 检查数据库连接状态
    db.get('SELECT 1 as check', (err) => {
        if (err) {
            status.database = { connected: false, error: err.message };
            status.status = 'degraded';
        } else {
            status.database = { connected: true };
            
            // 获取基本统计（不包含敏感信息）
            db.get('SELECT COUNT(*) as total_keys FROM api_keys', (err, row) => {
                if (!err && row) {
                    status.database.total_keys = row.total_keys;
                }
                
                db.get('SELECT COUNT(*) as total_requests FROM usage_log', (err, row) => {
                    if (!err && row) {
                        status.database.total_requests = row.total_requests;
                    }
                    
                    res.json(status);
                });
            });
        }
    });
});

app.get('/admin/stats', adminAuth, (req, res) => {
    const stats = {
        timestamp: new Date().toISOString(),
        server: {
            uptime: process.uptime(),
            memory: process.memoryUsage(),
            version: 'quota-proxy/v1.0'
        }
    };
    
    // 获取数据库统计
    const queries = [
        'SELECT COUNT(*) as total_keys FROM api_keys',
        'SELECT COUNT(*) as active_keys FROM api_keys WHERE expires_at IS NULL OR expires_at > datetime("now")',
        'SELECT COUNT(*) as expired_keys FROM api_keys WHERE expires_at <= datetime("now")',
        'SELECT SUM(total_quota) as total_quota, SUM(used_quota) as used_quota FROM api_keys',
        'SELECT COUNT(*) as total_requests FROM usage_log',
        'SELECT COUNT(*) as today_requests FROM usage_log WHERE date(timestamp) = date("now")'
    ];
    
    let completed = 0;
    const results = {};
    
    queries.forEach((query, index) => {
        db.get(query, (err, row) => {
            if (err) {
                console.error(`统计查询失败: ${query}`, err);
                results[`query_${index}`] = { error: err.message };
            } else {
                results[`query_${index}`] = row;
            }
            
            completed++;
            if (completed === queries.length) {
                // 整理统计结果
                stats.database = {
                    total_keys: results.query_0?.total_keys || 0,
                    active_keys: results.query_1?.active_keys || 0,
                    expired_keys: results.query_2?.expired_keys || 0,
                    total_quota: results.query_3?.total_quota || 0,
                    used_quota: results.query_3?.used_quota || 0,
                    quota_usage_percent: results.query_3?.total_quota ? 
                        ((results.query_3.used_quota / results.query_3.total_quota) * 100).toFixed(2) : '0.00',
                    total_requests: results.query_4?.total_requests || 0,
                    today_requests: results.query_5?.today_requests || 0
                };
                
                res.json(stats);
            }
        });
    });
});

// 启动服务器
app.listen(PORT, () => {
    console.log(`Quota proxy server running on port ${PORT}`);
    console.log(`Admin token: ${ADMIN_TOKEN}`);
    console.log(`Health check: http://localhost:${PORT}/healthz`);
    console.log(`Status page: http://localhost:${PORT}/status`);
    console.log(`Apply page: http://localhost:${PORT}/apply/`);
    console.log(`Audit logs: http://localhost:${PORT}/admin/audit-logs`);
});
