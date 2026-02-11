#!/bin/bash
# quota-proxy SQLite数据库初始化脚本
# 创建SQLite数据库文件并初始化表结构

set -e

# 配置
DB_FILE="${DB_FILE:-/tmp/quota-proxy.db}"
SCHEMA_FILE="${SCHEMA_FILE:-./schema.sql}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查sqlite3命令
check_dependencies() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3命令未找到，请安装sqlite3"
        exit 1
    fi
}

# 创建数据库文件
create_db_file() {
    if [ -f "$DB_FILE" ]; then
        log_warn "数据库文件已存在: $DB_FILE"
        read -p "是否覆盖现有文件? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "使用现有数据库文件"
            return 0
        fi
    fi
    
    log_info "创建数据库文件: $DB_FILE"
    touch "$DB_FILE"
}

# 初始化表结构
init_tables() {
    log_info "初始化表结构..."
    
    # 创建API密钥表
    sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT UNIQUE NOT NULL,
    name TEXT,
    quota_daily INTEGER DEFAULT 100,
    quota_monthly INTEGER DEFAULT 3000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1
);
SQL

    # 创建使用统计表
    sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT NOT NULL,
    date DATE NOT NULL,
    count_daily INTEGER DEFAULT 0,
    count_monthly INTEGER DEFAULT 0,
    last_used TIMESTAMP,
    FOREIGN KEY (key_id) REFERENCES api_keys(key_id),
    UNIQUE(key_id, date)
);
SQL

    # 创建试用密钥表
    sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id TEXT UNIQUE NOT NULL,
    email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_used INTEGER DEFAULT 0,
    used_at TIMESTAMP
);
SQL

    # 创建索引
    sqlite3 "$DB_FILE" << 'SQL'
CREATE INDEX IF NOT EXISTS idx_api_keys_key_id ON api_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_usage_stats_key_id ON usage_stats(key_id);
CREATE INDEX IF NOT EXISTS idx_usage_stats_date ON usage_stats(date);
CREATE INDEX IF NOT EXISTS idx_trial_keys_key_id ON trial_keys(key_id);
CREATE INDEX IF NOT EXISTS idx_trial_keys_expires_at ON trial_keys(expires_at);
SQL
}

# 插入示例数据（可选）
insert_sample_data() {
    if [ "${INSERT_SAMPLES:-0}" = "1" ]; then
        log_info "插入示例数据..."
        
        # 插入示例API密钥
        sqlite3 "$DB_FILE" << 'SQL'
INSERT OR IGNORE INTO api_keys (key_id, name, quota_daily, quota_monthly) VALUES
('test-key-123', '测试密钥', 100, 3000),
('admin-key-456', '管理员密钥', 1000, 30000);
SQL

        # 插入示例使用统计
        sqlite3 "$DB_FILE" << 'SQL'
INSERT OR IGNORE INTO usage_stats (key_id, date, count_daily, count_monthly) VALUES
('test-key-123', date('now'), 5, 45),
('admin-key-456', date('now'), 25, 320);
SQL

        # 插入示例试用密钥
        sqlite3 "$DB_FILE" << 'SQL'
INSERT OR IGNORE INTO trial_keys (key_id, email, expires_at) VALUES
('trial-abc-789', 'user@example.com', datetime('now', '+7 days'));
SQL
    fi
}

# 验证数据库
verify_database() {
    log_info "验证数据库..."
    
    # 检查表是否存在
    tables=$(sqlite3 "$DB_FILE" ".tables")
    required_tables=("api_keys" "usage_stats" "trial_keys")
    
    for table in "${required_tables[@]}"; do
        if echo "$tables" | grep -q "\b$table\b"; then
            log_info "✓ 表 '$table' 存在"
        else
            log_error "✗ 表 '$table' 不存在"
            return 1
        fi
    done
    
    # 检查行数
    for table in "${required_tables[@]}"; do
        count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
        log_info "表 '$table' 有 $count 行数据"
    done
    
    log_info "数据库验证完成"
}

# 显示数据库信息
show_db_info() {
    log_info "数据库信息:"
    echo "文件: $DB_FILE"
    echo "大小: $(du -h "$DB_FILE" 2>/dev/null | cut -f1) (如果文件存在)"
    echo "表结构:"
    sqlite3 "$DB_FILE" ".schema" 2>/dev/null || echo "无法读取表结构"
}

# 主函数
main() {
    log_info "开始初始化SQLite数据库"
    
    check_dependencies
    create_db_file
    init_tables
    insert_sample_data
    verify_database
    show_db_info
    
    log_info "数据库初始化完成"
    log_info "使用方法:"
    echo "  # 使用默认配置"
    echo "  ./init-sqlite-db.sh"
    echo ""
    echo "  # 自定义数据库文件路径"
    echo "  DB_FILE=/path/to/quota.db ./init-sqlite-db.sh"
    echo ""
    echo "  # 插入示例数据"
    echo "  INSERT_SAMPLES=1 ./init-sqlite-db.sh"
    echo ""
    echo "  # 查询数据库"
    echo "  sqlite3 \$DB_FILE '.tables'"
    echo "  sqlite3 \$DB_FILE 'SELECT * FROM api_keys;'"
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
