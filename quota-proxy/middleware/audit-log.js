/**
 * 操作日志记录中间件
 * 记录所有 Admin API 操作（谁在何时做了什么）
 */

const db = require('better-sqlite3')('/data/quota.db');

// 创建操作日志表（如果不存在）
function initAuditLogTable() {
    const createTable = db.prepare(`
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            ip TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            action TEXT NOT NULL,
            key_affected TEXT,
            admin_token_hash TEXT,
            details TEXT
        )
    `);
    createTable.run();
    
    // 创建索引以提高查询性能
    const createIndex = db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp 
        ON audit_log(timestamp)
    `);
    createIndex.run();
    
    const createIndex2 = db.prepare(`
        CREATE INDEX IF NOT EXISTS idx_audit_log_action 
        ON audit_log(action)
    `);
    createIndex2.run();
    
    console.log('Audit log table initialized');
}

// 初始化表
initAuditLogTable();

/**
 * 记录操作日志
 * @param {Object} req - Express 请求对象
 * @param {Object} res - Express 响应对象
 * @param {String} action - 操作描述
 * @param {String} keyAffected - 受影响的密钥（可选）
 * @param {Object} details - 额外详情（可选）
 */
function logAdminAction(req, res, action, keyAffected = null, details = null) {
    try {
        const ip = req.ip || req.connection.remoteAddress;
        const method = req.method;
        const path = req.path;
        
        // 获取管理员令牌哈希（保护隐私）
        const adminToken = req.headers.authorization?.replace('Bearer ', '') || 
                          req.headers['x-admin-token'] || 
                          req.query.admin_token;
        const adminTokenHash = adminToken ? 
            require('crypto').createHash('sha256').update(adminToken).digest('hex').substring(0, 16) : 
            null;
        
        const insertLog = db.prepare(`
            INSERT INTO audit_log 
            (ip, method, path, action, key_affected, admin_token_hash, details)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);
        
        const detailsStr = details ? JSON.stringify(details) : null;
        insertLog.run(ip, method, path, action, keyAffected, adminTokenHash, detailsStr);
        
        console.log(`[AUDIT] ${new Date().toISOString()} - ${ip} - ${method} ${path} - ${action}`);
    } catch (error) {
        console.error('Failed to log audit action:', error);
        // 不中断请求，仅记录错误
    }
}

/**
 * 审计日志中间件
 * 自动记录 Admin API 操作
 */
function createAuditLogMiddleware() {
    return function auditLogMiddleware(req, res, next) {
        // 保存原始的 res.json 方法
        const originalJson = res.json;
        
        // 重写 res.json 以在响应后记录操作
        res.json = function(body) {
            // 先调用原始的 res.json
            originalJson.call(this, body);
            
            // 记录操作（仅对 Admin API）
            if (req.path.startsWith('/admin')) {
                let action = '';
                let keyAffected = null;
                let details = null;
                
                // 根据路径和方法确定操作类型
                if (req.path === '/admin/keys' && req.method === 'POST') {
                    action = 'CREATE_KEY';
                    keyAffected = body.key;
                    details = { label: req.body.label };
                } else if (req.path === '/admin/keys' && req.method === 'GET') {
                    action = 'LIST_KEYS';
                } else if (req.path.startsWith('/admin/keys/') && req.method === 'DELETE') {
                    action = 'DELETE_KEY';
                    keyAffected = req.params.key;
                } else if (req.path.startsWith('/admin/keys/') && req.method === 'PUT') {
                    action = 'UPDATE_KEY';
                    keyAffected = req.params.key;
                    details = { label: req.body.label };
                } else if (req.path === '/admin/usage' && req.method === 'GET') {
                    action = 'VIEW_USAGE';
                } else if (req.path === '/admin/reset-usage' && req.method === 'POST') {
                    action = 'RESET_USAGE';
                    details = { 
                        key: req.body.key,
                        delete_logs: req.body.delete_logs 
                    };
                } else if (req.path === '/admin/performance' && req.method === 'GET') {
                    action = 'VIEW_PERFORMANCE';
                } else {
                    action = 'OTHER_ADMIN_ACTION';
                }
                
                // 记录操作
                logAdminAction(req, res, action, keyAffected, details);
            }
        };
        
        next();
    };
}

/**
 * 获取操作日志的 API 端点
 */
function createAuditLogApi() {
    return function getAuditLog(req, res) {
        try {
            const limit = parseInt(req.query.limit) || 100;
            const offset = parseInt(req.query.offset) || 0;
            const action = req.query.action;
            
            let query = 'SELECT * FROM audit_log';
            let params = [];
            
            if (action) {
                query += ' WHERE action = ?';
                params.push(action);
            }
            
            query += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
            params.push(limit, offset);
            
            const stmt = db.prepare(query);
            const logs = stmt.all(...params);
            
            // 获取总数
            let countQuery = 'SELECT COUNT(*) as total FROM audit_log';
            let countParams = [];
            if (action) {
                countQuery += ' WHERE action = ?';
                countParams.push(action);
            }
            const countStmt = db.prepare(countQuery);
            const total = countStmt.get(...countParams).total;
            
            res.json({
                logs,
                pagination: {
                    total,
                    limit,
                    offset,
                    hasMore: offset + logs.length < total
                }
            });
        } catch (error) {
            console.error('Failed to get audit logs:', error);
            res.status(500).json({ error: 'Failed to retrieve audit logs' });
        }
    };
}

module.exports = {
    createAuditLogMiddleware,
    createAuditLogApi,
    logAdminAction,
    initAuditLogTable
};
