#!/bin/bash
# quota-proxy 数据库初始化脚本
# 版本: 2026.02.11.1545
# 描述: 快速初始化SQLite数据库，创建表结构和初始数据

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 数据库初始化脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --db-path PATH  指定数据库文件路径 (默认: ./data/quota.db)
  -f, --force         强制覆盖现有数据库
  -v, --verbose       显示详细输出
  --dry-run           只显示将要执行的操作，不实际执行

示例:
  $0                    # 使用默认路径初始化数据库
  $0 -d /tmp/test.db    # 指定数据库路径
  $0 --dry-run          # 显示将要执行的操作
  $0 -f                 # 强制覆盖现有数据库

环境变量:
  DB_PATH             数据库文件路径 (优先级高于命令行参数)
EOF
}

# 默认值
DB_PATH="${DB_PATH:-./data/quota.db}"
FORCE=false
VERBOSE=false
DRY_RUN=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
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
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查SQLite是否可用
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "未找到 sqlite3 命令，请先安装 SQLite"
        log_info "安装命令:"
        log_info "  Ubuntu/Debian: sudo apt-get install sqlite3"
        log_info "  CentOS/RHEL: sudo yum install sqlite"
        log_info "  macOS: brew install sqlite"
        exit 1
    fi
    
    local version
    version=$(sqlite3 --version | head -n1)
    log_info "SQLite 版本: $version"
}

# 检查数据库文件
check_db_file() {
    local db_dir
    db_dir=$(dirname "$DB_PATH")
    
    # 创建目录
    if [[ ! -d "$db_dir" ]]; then
        log_info "创建数据库目录: $db_dir"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$db_dir"
        fi
    fi
    
    # 检查文件是否存在
    if [[ -f "$DB_PATH" ]]; then
        if [[ "$FORCE" == true ]]; then
            log_warning "数据库文件已存在，将强制覆盖: $DB_PATH"
            if [[ "$DRY_RUN" == false ]]; then
                rm -f "$DB_PATH"
            fi
        else
            log_error "数据库文件已存在: $DB_PATH"
            log_info "使用 -f 参数强制覆盖，或指定不同的数据库路径"
            exit 1
        fi
    fi
}

# 执行SQL文件
execute_sql_file() {
    local sql_file="$1"
    local description="$2"
    
    log_info "执行: $description"
    
    if [[ "$VERBOSE" == true ]]; then
        log_info "SQL 文件内容:"
        cat "$sql_file" | sed 's/^/  /'
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        if sqlite3 "$DB_PATH" < "$sql_file"; then
            log_success "执行成功: $description"
        else
            log_error "执行失败: $description"
            exit 1
        fi
    else
        log_info "[DRY-RUN] 将执行: $description"
    fi
}

# 验证数据库
verify_database() {
    log_info "验证数据库..."
    
    local tables
    tables=$(sqlite3 "$DB_PATH" ".tables")
    
    if [[ "$DRY_RUN" == false ]]; then
        log_info "数据库中的表:"
        echo "$tables" | sed 's/^/  /'
        
        # 检查表数量
        local table_count
        table_count=$(echo "$tables" | wc -w)
        if [[ $table_count -ge 3 ]]; then
            log_success "数据库验证通过，找到 $table_count 个表"
        else
            log_error "数据库验证失败，表数量不足: $table_count"
            exit 1
        fi
        
        # 检查初始数据
        local demo_key_count
        demo_key_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM api_keys WHERE key = 'demo-key-123';")
        if [[ $demo_key_count -eq 1 ]]; then
            log_success "初始数据验证通过"
        else
            log_warning "初始数据可能未正确插入"
        fi
    else
        log_info "[DRY-RUN] 将验证数据库"
    fi
}

# 显示数据库信息
show_db_info() {
    if [[ "$DRY_RUN" == false ]]; then
        log_info "数据库信息:"
        log_info "  路径: $DB_PATH"
        log_info "  大小: $(du -h "$DB_PATH" | cut -f1)"
        
        local schema_info
        schema_info=$(sqlite3 "$DB_PATH" ".schema")
        log_info "  表结构:"
        echo "$schema_info" | sed 's/^/    /'
    fi
}

# 主函数
main() {
    log_info "开始初始化 quota-proxy 数据库"
    log_info "数据库路径: $DB_PATH"
    log_info "强制覆盖: $FORCE"
    log_info "详细输出: $VERBOSE"
    log_info "干运行模式: $DRY_RUN"
    
    # 检查依赖
    check_sqlite
    
    # 检查数据库文件
    check_db_file
    
    # 获取迁移文件目录
    local migration_dir
    migration_dir="$(dirname "$0")/db-migrations"
    
    if [[ ! -d "$migration_dir" ]]; then
        log_error "迁移文件目录不存在: $migration_dir"
        exit 1
    fi
    
    # 执行迁移文件
    local migration_file="$migration_dir/001-initial-schema.sql"
    if [[ ! -f "$migration_file" ]]; then
        log_error "迁移文件不存在: $migration_file"
        exit 1
    fi
    
    execute_sql_file "$migration_file" "创建初始数据库表结构"
    
    # 验证数据库
    verify_database
    
    # 显示数据库信息
    show_db_info
    
    log_success "数据库初始化完成"
    log_info "下一步:"
    log_info "  1. 启动 quota-proxy 服务"
    log_info "  2. 使用 curl 测试 API: curl -fsS http://127.0.0.1:8787/healthz"
    log_info "  3. 查看文档了解更多信息"
}

# 运行主函数
main "$@"