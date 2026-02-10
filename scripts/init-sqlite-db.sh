#!/bin/bash
# quota-proxy SQLite数据库初始化脚本
# 为quota-proxy提供SQLite数据库初始化功能，支持密钥表、使用统计表创建
# 用法: ./init-sqlite-db.sh [--db-path <路径>] [--help]

set -e

# 默认配置
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"
DB_PATH="$DEFAULT_DB_PATH"
VERBOSE=true
DRY_RUN=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助
show_help() {
    cat << EOF
quota-proxy SQLite数据库初始化脚本

用法: $0 [选项]

选项:
  --db-path <路径>     SQLite数据库文件路径 (默认: $DEFAULT_DB_PATH)
  --dry-run           只显示将要执行的SQL语句，不实际执行
  --quiet             安静模式，只显示错误和重要信息
  --help              显示此帮助信息

示例:
  $0                    # 使用默认路径初始化数据库
  $0 --db-path ./test.db  # 使用自定义路径
  $0 --dry-run         # 显示SQL语句但不执行

功能:
  1. 创建SQLite数据库文件（如果不存在）
  2. 创建密钥表 (api_keys)
  3. 创建使用统计表 (usage_stats)
  4. 创建索引以提高查询性能
  5. 验证数据库结构和完整性

注意:
  - 需要sqlite3命令行工具
  - 数据库目录会自动创建
  - 如果数据库已存在，会检查表结构但不覆盖数据
EOF
}

# 解析参数
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
        --quiet)
            VERBOSE=false
            shift
            ;;
        --help|-h)
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

# 检查sqlite3是否安装
check_dependencies() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3未安装，请先安装:"
        echo "  Ubuntu/Debian: sudo apt-get install sqlite3"
        echo "  CentOS/RHEL: sudo yum install sqlite"
        echo "  macOS: brew install sqlite"
        exit 1
    fi
    log_info "依赖检查通过: sqlite3已安装"
}

# 创建数据库目录
create_db_directory() {
    local db_dir=$(dirname "$DB_PATH")
    
    if [ ! -d "$db_dir" ]; then
        log_info "创建数据库目录: $db_dir"
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$db_dir"
            log_success "数据库目录创建成功"
        else
            log_info "[DRY RUN] 将创建目录: $db_dir"
        fi
    else
        log_info "数据库目录已存在: $db_dir"
    fi
}

# SQL语句定义
SQL_CREATE_TABLES="
-- 创建API密钥表
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    name TEXT,
    description TEXT,
    total_quota INTEGER DEFAULT 1000,
    used_quota INTEGER DEFAULT 0,
    remaining_quota INTEGER DEFAULT 1000,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    metadata TEXT
);

-- 创建使用统计表
CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    request_count INTEGER DEFAULT 1,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_id) REFERENCES api_keys(id) ON DELETE CASCADE
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_usage_stats_key_id ON usage_stats(key_id);
CREATE INDEX IF NOT EXISTS idx_usage_stats_endpoint ON usage_stats(endpoint);
CREATE INDEX IF NOT EXISTS idx_usage_stats_last_used ON usage_stats(last_used);
"

# 初始化数据库
init_database() {
    log_info "初始化SQLite数据库: $DB_PATH"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将执行的SQL语句:"
        echo "$SQL_CREATE_TABLES"
        return 0
    fi
    
    # 执行SQL语句
    if echo "$SQL_CREATE_TABLES" | sqlite3 "$DB_PATH"; then
        log_success "数据库表结构创建成功"
    else
        log_error "数据库初始化失败"
        return 1
    fi
}

# 验证数据库
verify_database() {
    log_info "验证数据库结构..."
    
    local verify_sql="
.tables
SELECT 'api_keys表结构:' as info;
PRAGMA table_info(api_keys);
SELECT 'usage_stats表结构:' as info;
PRAGMA table_info(usage_stats);
SELECT '索引列表:' as info;
SELECT name FROM sqlite_master WHERE type='index';
"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 验证SQL:"
        echo "$verify_sql"
        return 0
    fi
    
    if [ -f "$DB_PATH" ]; then
        log_info "数据库文件大小: $(du -h "$DB_PATH" | cut -f1)"
        echo "$verify_sql" | sqlite3 "$DB_PATH" 2>/dev/null || {
            log_error "数据库验证失败"
            return 1
        }
        log_success "数据库验证通过"
    else
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
}

# 生成使用示例
generate_examples() {
    log_info "生成使用示例..."
    
    cat << EOF

=== 数据库使用示例 ===

1. 查看所有表:
   sqlite3 "$DB_PATH" '.tables'

2. 查看表结构:
   sqlite3 "$DB_PATH" 'PRAGMA table_info(api_keys);'

3. 插入测试密钥:
   sqlite3 "$DB_PATH" "
   INSERT INTO api_keys (key, name, total_quota) 
   VALUES ('test-key-123', '测试密钥', 1000);
   "

4. 查询密钥:
   sqlite3 "$DB_PATH" "
   SELECT key, name, total_quota, used_quota, remaining_quota 
   FROM api_keys;
   "

5. 记录使用统计:
   sqlite3 "$DB_PATH" "
   INSERT INTO usage_stats (key_id, endpoint) 
   VALUES (1, '/api/v1/chat');
   "

6. 更新配额使用:
   sqlite3 "$DB_PATH" "
   UPDATE api_keys 
   SET used_quota = used_quota + 1, 
       remaining_quota = total_quota - (used_quota + 1),
       updated_at = CURRENT_TIMESTAMP
   WHERE key = 'test-key-123';
   "

=== 与quota-proxy集成 ===

在quota-proxy的.env配置文件中添加:
DB_PATH=$DB_PATH

然后在代码中连接数据库:
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database(process.env.DB_PATH);

EOF
}

# 主函数
main() {
    log_info "开始初始化quota-proxy SQLite数据库"
    log_info "数据库路径: $DB_PATH"
    log_info "运行模式: $( [ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "实际执行" )"
    
    # 检查依赖
    check_dependencies
    
    # 创建目录
    create_db_directory
    
    # 初始化数据库
    if ! init_database; then
        log_error "数据库初始化失败"
        exit 1
    fi
    
    # 验证数据库
    if ! verify_database; then
        log_error "数据库验证失败"
        exit 1
    fi
    
    # 生成示例
    generate_examples
    
    log_success "SQLite数据库初始化完成!"
    log_info "数据库文件: $DB_PATH"
    log_info "下一步: 配置quota-proxy使用此数据库文件"
}

# 运行主函数
main