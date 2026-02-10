#!/bin/bash
# quota-proxy SQLite数据库初始化脚本
# 创建数据库表结构，用于API密钥和使用情况持久化存储

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认数据库路径
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"

# 显示帮助信息
show_help() {
    cat << EOH
quota-proxy SQLite数据库初始化脚本

用法: $0 [选项]

选项:
  -d, --db-path PATH    数据库文件路径 (默认: $DEFAULT_DB_PATH)
  -f, --force           强制覆盖现有数据库
  -v, --verbose         详细输出模式
  -h, --help            显示此帮助信息
  --dry-run             模拟运行，不实际创建数据库

示例:
  $0                    使用默认路径创建数据库
  $0 -d ./test.db       在当前目录创建测试数据库
  $0 --dry-run          模拟运行检查
  $0 -f                 强制覆盖现有数据库

说明:
  此脚本创建quota-proxy所需的SQLite数据库表结构，包括：
  - api_keys: API密钥存储
  - usage_logs: 使用情况日志
  - trial_keys: 试用密钥管理
EOH
}

# 解析命令行参数
DB_PATH="$DEFAULT_DB_PATH"
FORCE=false
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--db-path)
            DB_PATH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查SQLite3是否可用
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}错误: sqlite3 命令未找到，请先安装SQLite3${NC}"
    exit 1
fi

# 创建数据库目录
DB_DIR=$(dirname "$DB_PATH")
if [ ! -d "$DB_DIR" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[模拟] 将创建目录: $DB_DIR${NC}"
    else
        mkdir -p "$DB_DIR"
        echo -e "${GREEN}✓ 创建目录: $DB_DIR${NC}"
    fi
fi

# 检查数据库文件是否存在
if [ -f "$DB_PATH" ]; then
    if [ "$FORCE" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[模拟] 将删除现有数据库: $DB_PATH${NC}"
        else
            rm -f "$DB_PATH"
            echo -e "${YELLOW}⚠ 删除现有数据库: $DB_PATH${NC}"
        fi
    else
        echo -e "${RED}错误: 数据库文件已存在: $DB_PATH${NC}"
        echo -e "使用 -f 选项强制覆盖，或指定不同的数据库路径"
        exit 1
    fi
fi

# SQL初始化语句
SQL_INIT=$(cat << SQL
-- quota-proxy 数据库初始化
-- 创建时间: $(date '+%Y-%m-%d %H:%M:%S')

-- API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT UNIQUE NOT NULL,           -- API密钥ID
    api_key TEXT UNIQUE NOT NULL,          -- API密钥值
    name TEXT,                             -- 密钥名称/描述
    total_quota INTEGER DEFAULT 1000,      -- 总配额
    used_quota INTEGER DEFAULT 0,          -- 已使用配额
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,                  -- 过期时间（NULL表示永不过期）
    is_active BOOLEAN DEFAULT 1,           -- 是否激活
    metadata TEXT                          -- 额外元数据（JSON格式）
);

-- 使用情况日志表
CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL,                  -- 关联的API密钥ID
    endpoint TEXT NOT NULL,                -- 调用的端点
    request_size INTEGER,                  -- 请求大小（字节）
    response_size INTEGER,                 -- 响应大小（字节）
    status_code INTEGER,                   -- 状态码
    duration_ms INTEGER,                   -- 处理时长（毫秒）
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address TEXT,                       -- 客户端IP地址
    user_agent TEXT,                       -- 用户代理
    FOREIGN KEY (key_id) REFERENCES api_keys(key_id) ON DELETE CASCADE
);

-- 试用密钥表
CREATE TABLE IF NOT EXISTS trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trial_key TEXT UNIQUE NOT NULL,        -- 试用密钥
    email TEXT,                            -- 用户邮箱（可选）
    total_quota INTEGER DEFAULT 100,       -- 试用配额
    used_quota INTEGER DEFAULT 0,          -- 已使用配额
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activated_at TIMESTAMP,                -- 激活时间
    expires_at TIMESTAMP DEFAULT (datetime('now', '+7 days')), -- 7天有效期
    is_used BOOLEAN DEFAULT 0              -- 是否已使用
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key_id ON api_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_api_key ON api_keys(api_key);
CREATE INDEX IF NOT EXISTS idx_api_keys_expires ON api_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_usage_logs_key_id ON usage_logs(key_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_timestamp ON usage_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_trial_keys_trial_key ON trial_keys(trial_key);
CREATE INDEX IF NOT EXISTS idx_trial_keys_expires ON trial_keys(expires_at);

-- 插入示例数据（仅用于测试）
INSERT OR IGNORE INTO api_keys (key_id, api_key, name, total_quota, used_quota) VALUES
    ('demo-key-001', 'sk_demo_1234567890abcdef', '演示密钥', 1000, 150),
    ('admin-key-001', 'sk_admin_0987654321fedcba', '管理员密钥', 10000, 0);

INSERT OR IGNORE INTO trial_keys (trial_key, email) VALUES
    ('trial_7day_free_001', 'user1@example.com'),
    ('trial_7day_free_002', 'user2@example.com');

-- 创建触发器：更新updated_at时间戳
CREATE TRIGGER IF NOT EXISTS update_api_keys_timestamp 
AFTER UPDATE ON api_keys
BEGIN
    UPDATE api_keys SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- 显示表信息
SELECT '数据库初始化完成' as message;
SELECT '表列表:' as header;
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;
SQL
)

# 执行数据库初始化
if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}=== 模拟运行 ===${NC}"
    echo -e "数据库路径: $DB_PATH"
    echo -e "SQL语句行数: $(echo "$SQL_INIT" | wc -l)"
    echo -e "${GREEN}✓ 模拟运行完成，无错误${NC}"
    exit 0
fi

# 实际创建数据库
echo -e "${BLUE}正在创建数据库: $DB_PATH${NC}"
if echo "$SQL_INIT" | sqlite3 "$DB_PATH"; then
    echo -e "${GREEN}✓ 数据库创建成功${NC}"
    
    # 验证数据库
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}=== 数据库验证 ===${NC}"
        sqlite3 "$DB_PATH" << VERIFY
.headers on
.mode column
SELECT 'api_keys表记录:' as header;
SELECT key_id, name, total_quota, used_quota FROM api_keys;
SELECT 'trial_keys表记录:' as header;
SELECT trial_key, email, expires_at FROM trial_keys;
SELECT '数据库大小:' as header;
SELECT page_count * page_size as bytes FROM pragma_page_count, pragma_page_size;
VERIFY
    fi
    
    # 显示基本信息
    DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    echo -e "${GREEN}✓ 数据库文件大小: $(numfmt --to=iec --format="%.1f" $DB_SIZE 2>/dev/null || echo "${DB_SIZE} bytes")${NC}"
    
    # 生成使用示例
    cat << EXAMPLE

${BLUE}=== 使用示例 ===${NC}

1. 查询API密钥:
   sqlite3 "$DB_PATH" "SELECT key_id, name, total_quota, used_quota FROM api_keys;"

2. 添加新API密钥:
   sqlite3 "$DB_PATH" "INSERT INTO api_keys (key_id, api_key, name) VALUES ('new-key', 'sk_new_$(openssl rand -hex 10)', '新密钥');"

3. 查询使用情况:
   sqlite3 "$DB_PATH" "SELECT key_id, endpoint, COUNT(*) as calls FROM usage_logs GROUP BY key_id, endpoint;"

4. 备份数据库:
   sqlite3 "$DB_PATH" ".backup backup_$(date +%Y%m%d_%H%M%S).db"

${GREEN}数据库已准备好供quota-proxy使用！${NC}
EXAMPLE
    
    exit 0
else
    echo -e "${RED}✗ 数据库创建失败${NC}"
    exit 1
fi
