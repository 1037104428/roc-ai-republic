#!/bin/bash

# quota-proxy 数据库初始化检查脚本
# 用法: ./check-db.sh [--init] [--verify] [--clean]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DB_FILE="${DATABASE_PATH:-./quota.db}"
INIT_SCRIPT="${DATABASE_INIT_SCRIPT:-./init-db.sql}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

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

# 检查SQLite是否安装
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "SQLite3 未安装！"
        echo "请安装 SQLite3："
        echo "  Ubuntu/Debian: sudo apt-get install sqlite3"
        echo "  CentOS/RHEL:   sudo yum install sqlite"
        echo "  macOS:         brew install sqlite"
        exit 1
    fi
    log_success "SQLite3 已安装 ($(sqlite3 --version | head -n1))"
}

# 初始化数据库
init_database() {
    log_info "正在初始化数据库..."
    
    if [ ! -f "$INIT_SCRIPT" ]; then
        log_error "初始化脚本不存在: $INIT_SCRIPT"
        exit 1
    fi
    
    # 备份现有数据库
    if [ -f "$DB_FILE" ]; then
        backup_database
        log_warning "数据库已存在，已创建备份"
    fi
    
    # 执行初始化脚本
    sqlite3 "$DB_FILE" < "$INIT_SCRIPT"
    
    if [ $? -eq 0 ]; then
        log_success "数据库初始化成功！"
    else
        log_error "数据库初始化失败！"
        exit 1
    fi
}

# 备份数据库
backup_database() {
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/quota-backup-$timestamp.db"
    
    sqlite3 "$DB_FILE" ".backup '$backup_file'"
    
    if [ $? -eq 0 ]; then
        log_success "数据库备份成功: $backup_file"
    else
        log_error "数据库备份失败！"
        exit 1
    fi
}

# 验证数据库结构
verify_database() {
    log_info "正在验证数据库结构..."
    
    if [ ! -f "$DB_FILE" ]; then
        log_error "数据库文件不存在: $DB_FILE"
        exit 1
    fi
    
    # 检查表数量
    local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
    
    if [ "$table_count" -ge 4 ]; then
        log_success "数据库包含 $table_count 个表（符合预期）"
    else
        log_error "数据库表数量不足: $table_count（预期至少4个）"
        exit 1
    fi
    
    # 检查必需的表
    local required_tables=("api_keys" "request_logs" "admins" "system_config")
    local missing_tables=()
    
    for table in "${required_tables[@]}"; do
        if ! sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
            missing_tables+=("$table")
        fi
    done
    
    if [ ${#missing_tables[@]} -eq 0 ]; then
        log_success "所有必需的表都存在"
    else
        log_error "缺少必需的表: ${missing_tables[*]}"
        exit 1
    fi
    
    # 检查视图
    local view_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")
    
    if [ "$view_count" -ge 2 ]; then
        log_success "数据库包含 $view_count 个视图（符合预期）"
    else
        log_warning "数据库视图数量较少: $view_count（预期至少2个）"
    fi
    
    # 检查系统配置
    local config_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM system_config;")
    
    if [ "$config_count" -ge 6 ]; then
        log_success "系统配置已初始化 ($config_count 条记录)"
    else
        log_warning "系统配置记录较少: $config_count（预期至少6条）"
    fi
    
    # 检查数据库完整性
    log_info "检查数据库完整性..."
    local integrity_check=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" | head -n1)
    
    if [ "$integrity_check" = "ok" ]; then
        log_success "数据库完整性检查通过"
    else
        log_error "数据库完整性检查失败: $integrity_check"
        exit 1
    fi
}

# 清理数据库（仅用于测试）
clean_database() {
    log_warning "正在清理数据库..."
    
    if [ -f "$DB_FILE" ]; then
        backup_database
        rm -f "$DB_FILE"
        log_success "数据库已清理"
    else
        log_info "数据库文件不存在，无需清理"
    fi
}

# 显示数据库信息
show_database_info() {
    log_info "数据库信息:"
    echo "  文件: $DB_FILE"
    
    if [ -f "$DB_FILE" ]; then
        local size=$(du -h "$DB_FILE" | cut -f1)
        echo "  大小: $size"
        
        local table_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
        echo "  表数量: $table_count"
        
        local view_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")
        echo "  视图数量: $view_count"
        
        local total_records=$(sqlite3 "$DB_FILE" "SELECT SUM(cnt) FROM (SELECT COUNT(*) as cnt FROM api_keys UNION ALL SELECT COUNT(*) FROM request_logs UNION ALL SELECT COUNT(*) FROM admins UNION ALL SELECT COUNT(*) FROM system_config);")
        echo "  总记录数: ${total_records:-0}"
        
        # 显示表列表
        echo "  表列表:"
        sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | while read -r table; do
            local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM \"$table\";")
            echo "    - $table ($count 条记录)"
        done
    else
        echo "  状态: 不存在"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --init     初始化数据库"
    echo "  --verify   验证数据库结构"
    echo "  --clean    清理数据库（创建备份后删除）"
    echo "  --info     显示数据库信息"
    echo "  --help     显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  DATABASE_PATH         数据库文件路径（默认: ./quota.db）"
    echo "  DATABASE_INIT_SCRIPT  初始化脚本路径（默认: ./init-db.sql）"
    echo "  BACKUP_DIR            备份目录（默认: ./backups）"
    echo ""
    echo "示例:"
    echo "  $0 --init             初始化数据库"
    echo "  $0 --verify           验证数据库"
    echo "  $0 --info             显示数据库信息"
    echo "  DATABASE_PATH=/data/quota.db $0 --init"
}

# 主函数
main() {
    check_sqlite
    
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --init)
            init_database
            verify_database
            ;;
        --verify)
            verify_database
            ;;
        --clean)
            clean_database
            ;;
        --info)
            show_database_info
            ;;
        --help)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"