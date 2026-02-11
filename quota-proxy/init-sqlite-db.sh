#!/bin/bash
# SQLite数据库初始化脚本
# 用于初始化quota-proxy的SQLite数据库，创建必要的表结构

set -e

DB_FILE="${1:-./data/quota.db}"
DATA_DIR="$(dirname "$DB_FILE")"

echo "🔧 初始化SQLite数据库: $DB_FILE"

# 创建数据目录
if [ ! -d "$DATA_DIR" ]; then
    echo "📁 创建数据目录: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# 检查sqlite3命令是否存在
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ sqlite3命令未找到，请安装sqlite3:"
    echo "  Ubuntu/Debian: sudo apt-get install sqlite3"
    echo "  CentOS/RHEL: sudo yum install sqlite"
    echo "  macOS: brew install sqlite"
    exit 1
fi

# 初始化数据库
echo "📊 创建数据库表结构..."

sqlite3 "$DB_FILE" << 'EOF'
-- quota-proxy SQLite数据库表结构
-- 版本: 1.0.0
-- 创建时间: $(date)

-- API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT UNIQUE NOT NULL,           -- 密钥ID
    api_key TEXT UNIQUE NOT NULL,          -- API密钥
    name TEXT,                             -- 密钥名称
    description TEXT,                      -- 密钥描述
    rate_limit INTEGER DEFAULT 100,        -- 速率限制（每分钟请求数）
    quota_daily INTEGER DEFAULT 1000,      -- 每日配额
    quota_monthly INTEGER DEFAULT 30000,   -- 每月配额
    is_active INTEGER DEFAULT 1,           -- 是否激活 (0=禁用, 1=激活)
    is_trial INTEGER DEFAULT 0,            -- 是否为试用密钥 (0=正式, 1=试用)
    trial_days INTEGER DEFAULT 7,          -- 试用天数（仅试用密钥有效）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,                  -- 过期时间（可选）
    metadata TEXT                          -- 元数据（JSON格式）
);

-- 请求日志表
CREATE TABLE IF NOT EXISTS request_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL,                  -- 密钥ID
    api_key TEXT NOT NULL,                 -- API密钥（用于快速查询）
    endpoint TEXT NOT NULL,                -- 请求端点
    method TEXT NOT NULL,                  -- HTTP方法
    status_code INTEGER NOT NULL,          -- 状态码
    response_time INTEGER,                 -- 响应时间（毫秒）
    request_size INTEGER,                  -- 请求大小（字节）
    response_size INTEGER,                 -- 响应大小（字节）
    user_agent TEXT,                       -- User-Agent
    client_ip TEXT,                        -- 客户端IP
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT                          -- 元数据（JSON格式）
);

-- 用量统计表（每日汇总）
CREATE TABLE IF NOT EXISTS daily_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL,                  -- 密钥ID
    date DATE NOT NULL,                    -- 统计日期
    request_count INTEGER DEFAULT 0,       -- 请求次数
    success_count INTEGER DEFAULT 0,       -- 成功次数
    error_count INTEGER DEFAULT 0,         -- 错误次数
    total_response_time INTEGER DEFAULT 0, -- 总响应时间（毫秒）
    total_request_size INTEGER DEFAULT 0,  -- 总请求大小（字节）
    total_response_size INTEGER DEFAULT 0, -- 总响应大小（字节）
    UNIQUE(key_id, date)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key_id ON api_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_api_key ON api_keys(api_key);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_trial ON api_keys(is_trial);
CREATE INDEX IF NOT EXISTS idx_request_logs_key_id ON request_logs(key_id);
CREATE INDEX IF NOT EXISTS idx_request_logs_timestamp ON request_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_request_logs_endpoint ON request_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_daily_usage_key_id_date ON daily_usage(key_id, date);

-- 插入示例数据（试用密钥）
INSERT OR IGNORE INTO api_keys (key_id, api_key, name, description, rate_limit, quota_daily, quota_monthly, is_active, is_trial, trial_days, expires_at, metadata) VALUES
('trial_001', 'trial_key_abc123def456', '试用密钥示例', '7天试用期示例密钥', 50, 500, 15000, 1, 1, 7, datetime('now', '+7 days'), '{"source": "demo", "contact": "demo@example.com"}'),
('admin_001', 'admin_key_xyz789uvw012', '管理员密钥', '系统管理员密钥', 1000, 10000, 300000, 1, 0, NULL, NULL, '{"role": "admin", "permissions": ["read", "write", "delete"]}');

-- 创建视图：今日用量统计
CREATE VIEW IF NOT EXISTS v_today_usage AS
SELECT 
    k.key_id,
    k.name,
    k.api_key,
    k.is_trial,
    COALESCE(d.request_count, 0) as today_requests,
    COALESCE(d.success_count, 0) as today_success,
    COALESCE(d.error_count, 0) as today_errors,
    k.quota_daily,
    CASE 
        WHEN k.quota_daily > 0 THEN ROUND((COALESCE(d.request_count, 0) * 100.0 / k.quota_daily), 2)
        ELSE 0
    END as daily_usage_percent
FROM api_keys k
LEFT JOIN daily_usage d ON k.key_id = d.key_id AND d.date = date('now')
WHERE k.is_active = 1;

-- 创建视图：试用密钥状态
CREATE VIEW IF NOT EXISTS v_trial_keys_status AS
SELECT 
    key_id,
    name,
    api_key,
    trial_days,
    created_at,
    expires_at,
    julianday(expires_at) - julianday('now') as days_remaining,
    CASE 
        WHEN julianday(expires_at) - julianday('now') <= 0 THEN 'expired'
        WHEN julianday(expires_at) - julianday('now') <= 2 THEN 'expiring_soon'
        ELSE 'active'
    END as status
FROM api_keys
WHERE is_trial = 1 AND is_active = 1;

EOF

# 验证数据库
echo "✅ 数据库初始化完成"
echo "📋 验证数据库表结构..."

sqlite3 "$DB_FILE" << 'EOF'
.tables
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;
EOF

echo ""
echo "📊 示例数据统计:"
sqlite3 "$DB_FILE" << 'EOF'
SELECT 'API密钥数量:' as label, COUNT(*) as count FROM api_keys
UNION ALL
SELECT '激活的API密钥:' as label, COUNT(*) as count FROM api_keys WHERE is_active = 1
UNION ALL
SELECT '试用密钥:' as label, COUNT(*) as count FROM api_keys WHERE is_trial = 1
UNION ALL
SELECT '今日用量视图记录:' as label, COUNT(*) as count FROM v_today_usage;
EOF

echo ""
echo "🔑 试用密钥状态:"
sqlite3 "$DB_FILE" << 'EOF'
SELECT key_id, name, status, days_remaining FROM v_trial_keys_status;
EOF

echo ""
echo "📁 数据库文件信息:"
ls -lh "$DB_FILE"

echo ""
echo "🎉 SQLite数据库初始化完成！"
echo "💡 使用以下命令连接数据库:"
echo "   sqlite3 $DB_FILE"
echo ""
echo "🚀 快速查询示例:"
echo "   查看所有API密钥: sqlite3 $DB_FILE 'SELECT key_id, name, is_active, is_trial FROM api_keys;'"
echo "   查看今日用量: sqlite3 $DB_FILE 'SELECT * FROM v_today_usage;'"
echo "   查看试用密钥状态: sqlite3 $DB_FILE 'SELECT * FROM v_trial_keys_status;'"