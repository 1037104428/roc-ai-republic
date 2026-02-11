#!/bin/bash

# SQLite数据库初始化脚本
# 用于创建quota-proxy所需的数据库表结构

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助信息
show_help() {
    cat << 'HELP'
SQLite数据库初始化脚本

用法: ./init-sqlite-db.sh [选项]

选项:
  --db-path PATH     数据库文件路径 (默认: ./quota-proxy.db)
  --dry-run          干运行模式，显示SQL但不执行
  --help             显示此帮助信息
  --verbose          详细输出模式

示例:
  ./init-sqlite-db.sh --db-path /opt/roc/quota-proxy/quota-proxy.db
  ./init-sqlite-db.sh --dry-run --verbose

功能:
  1. 创建API密钥表 (api_keys)
  2. 创建使用记录表 (usage_records)
  3. 创建应用表 (applications)
  4. 创建索引以提高查询性能
HELP
}

# 默认参数
DB_PATH="./quota-proxy.db"
DRY_RUN=false
VERBOSE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查sqlite3命令是否存在
if ! command -v sqlite3 &> /dev/null; then
    log_error "sqlite3命令未找到，请先安装sqlite3"
    exit 1
fi

# SQL语句定义
SQL_STATEMENTS=$(cat << 'SQL'
-- 创建API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL UNIQUE,
    key_type TEXT NOT NULL CHECK (key_type IN ('admin', 'trial', 'regular')),
    name TEXT,
    description TEXT,
    rate_limit_per_minute INTEGER DEFAULT 60,
    rate_limit_per_hour INTEGER DEFAULT 1000,
    rate_limit_per_day INTEGER DEFAULT 10000,
    total_requests INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    metadata TEXT
);

-- 创建使用记录表
CREATE TABLE IF NOT EXISTS usage_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    request_size INTEGER,
    response_size INTEGER,
    user_agent TEXT,
    ip_address TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_hash) REFERENCES api_keys(key_hash) ON DELETE CASCADE
);

-- 创建应用表
CREATE TABLE IF NOT EXISTS applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    owner TEXT,
    contact_email TEXT,
    website TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_type ON api_keys(key_type);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_usage_records_key_hash ON usage_records(key_hash);
CREATE INDEX IF NOT EXISTS idx_usage_records_timestamp ON usage_records(timestamp);
CREATE INDEX IF NOT EXISTS idx_usage_records_endpoint ON usage_records(endpoint);
CREATE INDEX IF NOT EXISTS idx_applications_name ON applications(name);
CREATE INDEX IF NOT EXISTS idx_applications_is_active ON applications(is_active);

-- 插入默认管理员密钥（仅用于演示，生产环境应使用安全的方式生成）
INSERT OR IGNORE INTO api_keys (key_hash, key_type, name, description, rate_limit_per_minute, rate_limit_per_hour, rate_limit_per_day, is_active) 
VALUES ('admin_demo_hash_do_not_use_in_production', 'admin', '默认管理员', '演示用管理员密钥，生产环境请替换', 1000, 50000, 1000000, 1);

-- 插入默认试用密钥
INSERT OR IGNORE INTO api_keys (key_hash, key_type, name, description, rate_limit_per_minute, rate_limit_per_hour, rate_limit_per_day, expires_at, is_active) 
VALUES ('trial_demo_hash_do_not_use_in_production', 'trial', '默认试用密钥', '演示用试用密钥，30天后过期', 10, 100, 1000, datetime('now', '+30 days'), 1);

-- 插入示例应用
INSERT OR IGNORE INTO applications (name, description, owner, contact_email, website, is_active)
VALUES ('示例应用', 'quota-proxy演示应用', '演示用户', 'demo@example.com', 'https://example.com', 1);
SQL
)

# 执行初始化
log_info "开始初始化SQLite数据库: $DB_PATH"

if [ "$DRY_RUN" = true ]; then
    log_info "干运行模式，显示SQL语句但不执行:"
    echo "$SQL_STATEMENTS"
    log_success "干运行完成，SQL语句已显示"
    exit 0
fi

# 检查数据库文件是否已存在
if [ -f "$DB_PATH" ]; then
    log_warning "数据库文件已存在: $DB_PATH"
    read -p "是否继续？这将添加缺失的表但不删除现有数据 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
fi

# 创建数据库目录（如果不存在）
DB_DIR=$(dirname "$DB_PATH")
if [ ! -d "$DB_DIR" ]; then
    log_info "创建数据库目录: $DB_DIR"
    mkdir -p "$DB_DIR"
fi

# 执行SQL语句
if [ "$VERBOSE" = true ]; then
    log_info "执行SQL语句:"
    echo "$SQL_STATEMENTS"
fi

echo "$SQL_STATEMENTS" | sqlite3 "$DB_PATH"

if [ $? -eq 0 ]; then
    log_success "数据库初始化成功: $DB_PATH"
    
    # 显示数据库信息
    log_info "数据库信息:"
    echo "文件大小: $(du -h "$DB_PATH" 2>/dev/null | cut -f1 || echo '未知')"
    
    # 显示表信息
    TABLES_INFO=$(sqlite3 "$DB_PATH" << 'SQL_QUERY'
.tables
SELECT '表数量: ' || COUNT(*) FROM sqlite_master WHERE type='table';
SQL_QUERY
    )
    
    echo "$TABLES_INFO"
    
    # 显示各表记录数
    log_info "表记录统计:"
    sqlite3 "$DB_PATH" << 'SQL_QUERY'
SELECT 'api_keys: ' || COUNT(*) FROM api_keys;
SELECT 'usage_records: ' || COUNT(*) FROM usage_records;
SELECT 'applications: ' || COUNT(*) FROM applications;
SQL_QUERY
    
    log_success "数据库初始化完成，可以开始使用quota-proxy持久化功能"
else
    log_error "数据库初始化失败"
    exit 1
fi
