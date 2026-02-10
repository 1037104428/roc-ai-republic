-- v1.0.0: 初始数据库结构
-- 创建时间: 2026-02-10
-- 描述: 创建quota-proxy初始数据库结构，包含API密钥管理、使用日志记录和试用密钥功能

-- 创建API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,           -- API密钥
    name TEXT NOT NULL,                  -- 密钥名称
    owner TEXT,                          -- 所有者
    max_requests_per_day INTEGER DEFAULT 1000,  -- 每日最大请求数
    enabled BOOLEAN DEFAULT 1,           -- 是否启用
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 创建使用日志表
CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,               -- API密钥
    endpoint TEXT NOT NULL,              -- 访问端点
    method TEXT NOT NULL,                -- HTTP方法
    status_code INTEGER,                 -- 状态码
    duration_ms INTEGER,                 -- 处理时长(毫秒)
    user_agent TEXT,                     -- 用户代理
    ip_address TEXT,                     -- IP地址
    timestamp TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 创建试用密钥表
CREATE TABLE IF NOT EXISTS trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,           -- 试用密钥
    email TEXT,                          -- 邮箱
    name TEXT,                           -- 姓名
    max_requests_per_day INTEGER DEFAULT 100,   -- 试用期每日最大请求数
    expiry_days INTEGER DEFAULT 7,       -- 有效期(天)
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    activated_at TEXT,                   -- 激活时间
    expires_at TEXT                      -- 过期时间
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key);
CREATE INDEX IF NOT EXISTS idx_api_keys_enabled ON api_keys(enabled);
CREATE INDEX IF NOT EXISTS idx_usage_logs_api_key ON usage_logs(api_key);
CREATE INDEX IF NOT EXISTS idx_usage_logs_timestamp ON usage_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_trial_keys_key ON trial_keys(key);
CREATE INDEX IF NOT EXISTS idx_trial_keys_expires_at ON trial_keys(expires_at);

-- 创建更新时间戳触发器
CREATE TRIGGER IF NOT EXISTS update_api_keys_timestamp
AFTER UPDATE ON api_keys
BEGIN
    UPDATE api_keys SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- 插入示例数据
INSERT OR IGNORE INTO api_keys (key, name, owner, max_requests_per_day) VALUES
('test-key-123', '测试密钥', 'admin', 1000),
('demo-key-456', '演示密钥', 'demo', 500);

INSERT OR IGNORE INTO trial_keys (key, email, name, max_requests_per_day, expiry_days) VALUES
('trial-001', 'user1@example.com', '试用用户1', 100, 7),
('trial-002', 'user2@example.com', '试用用户2', 100, 7);