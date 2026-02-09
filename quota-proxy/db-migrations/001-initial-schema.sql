-- 数据库迁移脚本 v1.0
-- 版本: 001-initial-schema.sql
-- 描述: 创建初始数据库表结构
-- 创建时间: 2026-02-10
-- 作者: 中华AI共和国项目组

-- 创建 api_keys 表
CREATE TABLE IF NOT EXISTS api_keys (
    key TEXT PRIMARY KEY,
    label TEXT,
    total_quota INTEGER NOT NULL DEFAULT 1000,
    used_quota INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- 创建 usage_logs 表
CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    status_code INTEGER,
    FOREIGN KEY (api_key) REFERENCES api_keys(key)
);

-- 创建 migration_history 表（用于跟踪迁移状态）
CREATE TABLE IF NOT EXISTS migration_history (
    version TEXT PRIMARY KEY,
    filename TEXT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum TEXT
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_api_keys_label ON api_keys(label);
CREATE INDEX IF NOT EXISTS idx_usage_logs_api_key ON usage_logs(api_key);
CREATE INDEX IF NOT EXISTS idx_usage_logs_request_time ON usage_logs(request_time);

-- 插入初始数据（可选）
INSERT OR IGNORE INTO api_keys (key, label, total_quota, is_active) VALUES
    ('demo-key-123', '演示密钥', 1000, 1),
    ('test-key-456', '测试密钥', 500, 1);

-- 记录本次迁移
INSERT OR REPLACE INTO migration_history (version, filename, checksum) VALUES
    ('001', '001-initial-schema.sql', 'sha256:8f2c...');