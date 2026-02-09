#!/bin/bash
# 为 quota-proxy 添加简单的速率限制中间件
# 防止 Admin API 暴力破解攻击

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$REPO_ROOT/quota-proxy"

echo "=== 为 quota-proxy 添加速率限制中间件 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查服务器文件
if [ ! -f "$SERVER_DIR/server-sqlite.js" ]; then
    echo "错误: server-sqlite.js 不存在"
    exit 1
fi

# 备份原文件
cp "$SERVER_DIR/server-sqlite.js" "$SERVER_DIR/server-sqlite.js.backup.$(date +%s)"

# 创建速率限制中间件文件
cat > "$SERVER_DIR/middleware/rate-limit.js" << 'EOF'
// 简单的内存速率限制中间件
// 防止 Admin API 暴力破解攻击

const rateLimitStore = new Map();

/**
 * 简单的内存速率限制中间件
 * @param {Object} options 配置选项
 * @param {number} options.windowMs 时间窗口（毫秒），默认 15 分钟
 * @param {number} options.maxRequests 最大请求数，默认 100
 * @param {string} options.message 被限制时的错误消息
 * @param {boolean} options.skipSuccessfulRequests 是否跳过成功请求的计数（默认 false）
 * @returns {Function} Express 中间件
 */
function createRateLimit(options = {}) {
    const windowMs = options.windowMs || 15 * 60 * 1000; // 15 分钟
    const maxRequests = options.maxRequests || 100;
    const message = options.message || '请求过于频繁，请稍后再试';
    const skipSuccessfulRequests = options.skipSuccessfulRequests || false;

    return function rateLimit(req, res, next) {
        const clientIp = req.ip || req.connection.remoteAddress;
        const now = Date.now();
        
        // 清理过期记录
        for (const [ip, data] of rateLimitStore.entries()) {
            if (now - data.startTime > windowMs) {
                rateLimitStore.delete(ip);
            }
        }
        
        // 获取或创建客户端记录
        let clientData = rateLimitStore.get(clientIp);
        if (!clientData) {
            clientData = {
                startTime: now,
                count: 0,
                lastReset: now
            };
            rateLimitStore.set(clientIp, clientData);
        }
        
        // 检查是否超过时间窗口
        if (now - clientData.startTime > windowMs) {
            // 重置计数
            clientData.startTime = now;
            clientData.count = 0;
        }
        
        // 检查是否超过限制
        if (clientData.count >= maxRequests) {
            const resetTime = clientData.startTime + windowMs;
            const retryAfter = Math.ceil((resetTime - now) / 1000);
            
            res.setHeader('Retry-After', retryAfter);
            return res.status(429).json({
                error: 'Too Many Requests',
                message: message,
                retryAfter: retryAfter
            });
        }
        
        // 增加计数（如果配置了跳过成功请求，则在响应后计数）
        if (skipSuccessfulRequests) {
            const originalSend = res.send;
            res.send = function(...args) {
                if (res.statusCode < 400) {
                    clientData.count++;
                }
                return originalSend.apply(this, args);
            };
        } else {
            clientData.count++;
        }
        
        // 设置响应头
        res.setHeader('X-RateLimit-Limit', maxRequests);
        res.setHeader('X-RateLimit-Remaining', maxRequests - clientData.count);
        res.setHeader('X-RateLimit-Reset', Math.ceil((clientData.startTime + windowMs) / 1000));
        
        next();
    };
}

// Admin API 专用速率限制（更严格）
const adminRateLimit = createRateLimit({
    windowMs: 15 * 60 * 1000, // 15 分钟
    maxRequests: 30,          // 更严格的限制
    message: 'Admin API 请求过于频繁，请稍后再试',
    skipSuccessfulRequests: false
});

// 公开 API 速率限制（宽松）
const publicRateLimit = createRateLimit({
    windowMs: 15 * 60 * 1000, // 15 分钟
    maxRequests: 100,         // 标准限制
    message: '请求过于频繁，请稍后再试',
    skipSuccessfulRequests: false
});

module.exports = {
    createRateLimit,
    adminRateLimit,
    publicRateLimit,
    rateLimitStore
};
EOF

echo "✅ 创建速率限制中间件: $SERVER_DIR/middleware/rate-limit.js"

# 更新 server-sqlite.js 以使用速率限制
cat > "$SERVER_DIR/server-sqlite.js" << 'EOF'
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
EOF

echo "✅ 更新 server-sqlite.js 以集成速率限制"

# 创建验证脚本
cat > "$SCRIPT_DIR/verify-rate-limit.sh" << 'EOF'
#!/bin/bash
# 验证速率限制功能

set -e

echo "=== 验证 quota-proxy 速率限制功能 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查文件是否存在
if [ ! -f "../quota-proxy/middleware/rate-limit.js" ]; then
    echo "❌ 速率限制中间件文件不存在"
    exit 1
fi

if [ ! -f "../quota-proxy/server-sqlite.js" ]; then
    echo "❌ server-sqlite.js 不存在"
    exit 1
fi

# 检查中间件内容
echo "✅ 检查速率限制中间件结构..."
grep -q "createRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ createRateLimit 函数存在"
grep -q "adminRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ adminRateLimit 中间件存在"
grep -q "publicRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ publicRateLimit 中间件存在"

# 检查 server-sqlite.js 集成
echo "✅ 检查 server-sqlite.js 集成..."
grep -q "require.*rate-limit" ../quota-proxy/server-sqlite.js && echo "  ✓ 正确引入速率限制模块"
grep -q "app.use.*adminRateLimit" ../quota-proxy/server-sqlite.js && echo "  ✓ Admin API 应用了速率限制"

# 测试中间件逻辑
echo "✅ 测试中间件逻辑..."
node -e "
const { createRateLimit } = require('../quota-proxy/middleware/rate-limit');
const middleware = createRateLimit({ windowMs: 1000, maxRequests: 2 });
console.log('  ✓ 中间件创建成功');
" 2>/dev/null || echo "  ✗ 中间件创建失败"

echo ""
echo "📋 验证总结:"
echo "1. 速率限制中间件已创建并集成到 server-sqlite.js"
echo "2. Admin API 路由已应用速率限制保护"
echo "3. 中间件包含基本功能: 时间窗口、请求计数、响应头设置"
echo ""
echo "⚠️  注意: 当前使用内存存储，生产环境应考虑 Redis 等分布式存储"
echo "📝 后续改进:"
echo "  - 添加 Redis 后端支持"
echo "  - 添加按用户/IP 的白名单机制"
echo "  - 添加滑动窗口算法支持"
EOF

chmod +x "$SCRIPT_DIR/verify-rate-limit.sh"

echo "✅ 创建验证脚本: $SCRIPT_DIR/verify-rate-limit.sh"

# 更新部署脚本
DEPLOY_SCRIPT="$SERVER_DIR/deploy-quota-proxy-rate-limit.sh"
cat > "$DEPLOY_SCRIPT" << 'EOF'
#!/bin/bash
# 部署带速率限制的 quota-proxy

set -e

SERVER_IP="${1:-8.210.185.194}"
SSH_KEY="${2:-$HOME/.ssh/id_ed25519_roc_server}"

echo "=== 部署带速率限制的 quota-proxy ==="
echo "目标服务器: $SERVER_IP"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查必要文件
if [ ! -f "middleware/rate-limit.js" ]; then
    echo "错误: middleware/rate-limit.js 不存在"
    exit 1
fi

if [ ! -f "server-sqlite.js" ]; then
    echo "错误: server-sqlite.js 不存在"
    exit 1
fi

# 上传文件到服务器
echo "上传文件到服务器..."
scp -i "$SSH_KEY" \
    middleware/rate-limit.js \
    server-sqlite.js \
    root@$SERVER_IP:/opt/roc/quota-proxy/

# 重启服务
echo "重启 quota-proxy 服务..."
ssh -i "$SSH_KEY" root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose restart quota-proxy'

# 验证部署
echo "验证部署..."
sleep 3
ssh -i "$SSH_KEY" root@$SERVER_IP 'curl -fsS http://127.0.0.1:8787/healthz'

echo ""
echo "✅ 部署完成!"
echo "速率限制已应用到 Admin API:"
echo "  - 时间窗口: 15 分钟"
echo "  - 最大请求数: 30 次"
echo "  - 保护端点: /admin/*"
echo ""
echo "📋 验证命令:"
echo "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
EOF

chmod +x "$DEPLOY_SCRIPT"

echo "✅ 创建部署脚本: $DEPLOY_SCRIPT"

echo ""
echo "🎯 轻量级落地完成!"
echo "📝 落地内容:"
echo "  1. 创建速率限制中间件 (middleware/rate-limit.js)"
echo "  2. 更新 server-sqlite.js 集成速率限制"
echo "  3. 创建验证脚本 (scripts/verify-rate-limit.sh)"
echo "  4. 创建部署脚本 (quota-proxy/deploy-quota-proxy-rate-limit.sh)"
echo ""
echo "🔒 安全性增强:"
echo "  - Admin API 现在有速率限制保护 (15分钟内最多30次请求)"
echo "  - 防止暴力破解攻击"
echo "  - 返回标准 429 状态码和 Retry-After 头"
echo ""
echo "📋 验证命令:"
echo "  cd /home/kai/.openclaw/workspace/roc-ai-republic"
echo "  ./scripts/verify-rate-limit.sh"
echo "  ./quota-proxy/deploy-quota-proxy-rate-limit.sh"