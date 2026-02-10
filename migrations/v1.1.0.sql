-- v1.1.0: 添加API使用统计功能
-- 创建时间: 2026-02-10
-- 描述: 添加API使用统计表，支持按日、按月统计，优化查询性能

-- 创建API使用统计表
CREATE TABLE IF NOT EXISTS api_usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,               -- API密钥
    date TEXT NOT NULL,                  -- 日期 (YYYY-MM-DD)
    request_count INTEGER DEFAULT 0,     -- 请求次数
    total_duration_ms INTEGER DEFAULT 0, -- 总处理时长(毫秒)
    avg_duration_ms INTEGER DEFAULT 0,   -- 平均处理时长(毫秒)
    success_count INTEGER DEFAULT 0,     -- 成功请求数
    error_count INTEGER DEFAULT 0,       -- 错误请求数
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(api_key, date)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_usage_stats_date ON api_usage_stats(date);
CREATE INDEX IF NOT EXISTS idx_api_usage_stats_api_key ON api_usage_stats(api_key);
CREATE INDEX IF NOT EXISTS idx_api_usage_stats_api_key_date ON api_usage_stats(api_key, date);

-- 创建更新触发器
CREATE TRIGGER IF NOT EXISTS update_api_usage_stats_timestamp
AFTER UPDATE ON api_usage_stats
BEGIN
    UPDATE api_usage_stats SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- 创建每日统计更新触发器
CREATE TRIGGER IF NOT EXISTS update_daily_stats
AFTER INSERT ON usage_logs
BEGIN
    -- 更新每日统计
    INSERT OR REPLACE INTO api_usage_stats (api_key, date, request_count, total_duration_ms, avg_duration_ms, success_count, error_count)
    SELECT 
        api_key,
        DATE(timestamp) as date,
        COUNT(*) as request_count,
        SUM(duration_ms) as total_duration_ms,
        CASE 
            WHEN COUNT(*) > 0 THEN SUM(duration_ms) / COUNT(*) 
            ELSE 0 
        END as avg_duration_ms,
        SUM(CASE WHEN status_code BETWEEN 200 AND 299 THEN 1 ELSE 0 END) as success_count,
        SUM(CASE WHEN status_code < 200 OR status_code >= 300 THEN 1 ELSE 0 END) as error_count
    FROM usage_logs
    WHERE api_key = NEW.api_key AND DATE(timestamp) = DATE(NEW.timestamp)
    GROUP BY api_key, DATE(timestamp);
END;

-- 添加API密钥额外信息字段
ALTER TABLE api_keys ADD COLUMN description TEXT;
ALTER TABLE api_keys ADD COLUMN tags TEXT;
ALTER TABLE api_keys ADD COLUMN last_used_at TEXT;

-- 添加试用密钥状态字段
ALTER TABLE trial_keys ADD COLUMN status TEXT DEFAULT 'pending';  -- pending, activated, expired, revoked
ALTER TABLE trial_keys ADD COLUMN last_used_at TEXT;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_last_used_at ON api_keys(last_used_at);
CREATE INDEX IF NOT EXISTS idx_trial_keys_status ON trial_keys(status);

-- 更新示例数据
UPDATE api_keys SET 
    description = '用于测试环境的API密钥',
    tags = 'test,development'
WHERE key = 'test-key-123';

UPDATE api_keys SET 
    description = '用于演示环境的API密钥',
    tags = 'demo,presentation'
WHERE key = 'demo-key-456';

-- 创建月度统计视图
CREATE VIEW IF NOT EXISTS monthly_usage_stats AS
SELECT 
    api_key,
    strftime('%Y-%m', date) as month,
    SUM(request_count) as total_requests,
    SUM(total_duration_ms) as total_duration,
    AVG(avg_duration_ms) as avg_duration,
    SUM(success_count) as total_success,
    SUM(error_count) as total_errors,
    CASE 
        WHEN SUM(request_count) > 0 THEN 
            ROUND(SUM(success_count) * 100.0 / SUM(request_count), 2)
        ELSE 0 
    END as success_rate
FROM api_usage_stats
GROUP BY api_key, strftime('%Y-%m', date)
ORDER BY month DESC, api_key;

-- 创建活跃密钥视图
CREATE VIEW IF NOT EXISTS active_api_keys AS
SELECT 
    k.*,
    COALESCE(s.request_count, 0) as today_requests,
    COALESCE(s.avg_duration_ms, 0) as avg_duration_today
FROM api_keys k
LEFT JOIN api_usage_stats s ON k.key = s.api_key AND s.date = DATE('now')
WHERE k.enabled = 1
ORDER BY k.created_at DESC;