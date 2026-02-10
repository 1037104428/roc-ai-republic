#!/bin/bash
# 验证 quota-proxy SQLite 数据库初始化功能
set -e

echo "🔍 验证 SQLite 数据库初始化功能"
echo "========================================"

# 检查 SQLite3 是否可用
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ sqlite3 命令未找到，请安装：sudo apt-get install sqlite3"
    exit 1
fi

# 创建测试数据库
TEST_DB="/tmp/test-quota-proxy-$(date +%s).db"
echo "📁 创建测试数据库: $TEST_DB"

# 初始化数据库表
sqlite3 "$TEST_DB" << 'SQL'
-- 创建 API 密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    name TEXT,
    quota_daily INTEGER DEFAULT 100,
    quota_monthly INTEGER DEFAULT 1000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建使用记录表
CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    response_time_ms INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key);
CREATE INDEX IF NOT EXISTS idx_usage_logs_api_key_id ON usage_logs(api_key_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_timestamp ON usage_logs(timestamp);
SQL

echo "✅ 数据库表结构创建完成"

# 验证表结构
echo "📊 验证表结构:"
sqlite3 "$TEST_DB" ".schema"

# 插入测试数据
echo "📝 插入测试数据:"
sqlite3 "$TEST_DB" << 'SQL'
INSERT OR IGNORE INTO api_keys (key, name, quota_daily, quota_monthly) 
VALUES ('test-key-123', '测试密钥', 100, 1000);

INSERT INTO usage_logs (api_key_id, endpoint, response_time_ms)
VALUES (1, '/api/v1/chat', 150);
SQL

# 查询验证
echo "🔍 查询验证数据:"
sqlite3 -header -column "$TEST_DB" "SELECT * FROM api_keys;"
sqlite3 -header -column "$TEST_DB" "SELECT * FROM usage_logs;"

# 清理
rm -f "$TEST_DB"
echo "🧹 清理测试数据库"

echo ""
echo "✅ SQLite 数据库初始化验证完成"
echo "📋 下一步："
echo "  1. 在 quota-proxy 中集成此数据库结构"
echo "  2. 实现 /admin/keys 端点使用此数据库"
echo "  3. 实现 /admin/usage 端点查询使用记录"
