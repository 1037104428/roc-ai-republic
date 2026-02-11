-- quota-proxy SQLite 数据库初始化脚本
-- 创建API密钥表和用量统计表

-- API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL UNIQUE,          -- API密钥的哈希值（SHA256）
    key_type TEXT NOT NULL DEFAULT 'trial', -- 密钥类型: trial, standard, premium
    name TEXT,                              -- 密钥名称/描述
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,                   -- 过期时间，NULL表示永不过期
    total_quota INTEGER DEFAULT 1000,       -- 总配额（请求次数）
    used_quota INTEGER DEFAULT 0,           -- 已用配额
    is_active BOOLEAN DEFAULT 1,            -- 是否激活
    metadata TEXT                           -- JSON格式的元数据
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_type ON api_keys(key_type);
CREATE INDEX IF NOT EXISTS idx_api_keys_expires_at ON api_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);

-- 请求日志表（用于审计和调试）
CREATE TABLE IF NOT EXISTS request_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL,                  -- 关联的API密钥哈希
    endpoint TEXT NOT NULL,                  -- 请求的端点
    method TEXT NOT NULL,                    -- HTTP方法
    status_code INTEGER,                     -- 响应状态码
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,                -- 响应时间（毫秒）
    user_agent TEXT,                         -- 用户代理
    remote_ip TEXT,                          -- 客户端IP
    metadata TEXT                            -- JSON格式的额外信息
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_request_logs_key_hash ON request_logs(key_hash);
CREATE INDEX IF NOT EXISTS idx_request_logs_request_time ON request_logs(request_time);
CREATE INDEX IF NOT EXISTS idx_request_logs_endpoint ON request_logs(endpoint);

-- 管理员表（用于管理界面认证）
CREATE TABLE IF NOT EXISTS admins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,             -- bcrypt哈希
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- 系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入默认配置
INSERT OR IGNORE INTO system_config (key, value, description) VALUES
    ('trial_quota', '1000', '试用密钥默认配额'),
    ('standard_quota', '10000', '标准密钥默认配额'),
    ('premium_quota', '100000', '高级密钥默认配额'),
    ('rate_limit_per_minute', '60', '每分钟请求限制'),
    ('rate_limit_per_hour', '1000', '每小时请求限制'),
    ('default_key_expiry_days', '30', '试用密钥默认有效期（天）');

-- 创建视图：密钥使用情况汇总
CREATE VIEW IF NOT EXISTS key_usage_summary AS
SELECT 
    key_type,
    COUNT(*) as total_keys,
    SUM(total_quota) as total_quota,
    SUM(used_quota) as total_used,
    AVG(used_quota * 100.0 / total_quota) as avg_usage_percent,
    SUM(CASE WHEN expires_at < CURRENT_TIMESTAMP THEN 1 ELSE 0 END) as expired_keys,
    SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) as inactive_keys
FROM api_keys
GROUP BY key_type;

-- 创建视图：最近24小时请求统计
CREATE VIEW IF NOT EXISTS recent_requests_24h AS
SELECT 
    endpoint,
    method,
    COUNT(*) as request_count,
    AVG(response_time_ms) as avg_response_time,
    MIN(request_time) as first_request,
    MAX(request_time) as last_request
FROM request_logs
WHERE request_time > datetime('now', '-24 hours')
GROUP BY endpoint, method;

-- 打印初始化完成信息
SELECT '数据库初始化完成！' as message;
SELECT '创建的表：' as info;
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;
SELECT '创建的视图：' as info;
SELECT name FROM sqlite_master WHERE type='view' ORDER BY name;