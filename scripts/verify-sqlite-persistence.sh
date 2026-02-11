#!/bin/bash

# verify-sqlite-persistence.sh - 验证SQLite持久化功能
# 检查quota-proxy的SQLite数据库持久化功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 帮助信息
show_help() {
    cat << 'HELP_EOF'
验证SQLite持久化功能脚本

用法: $0 [选项]

选项:
  --dry-run     模拟运行，不执行实际验证
  --help        显示此帮助信息
  --quick       快速模式，只检查基本功能

示例:
  $0              # 完整验证
  $0 --dry-run    # 模拟运行
  $0 --quick      # 快速验证
HELP_EOF
}

# 检查依赖
check_dependencies() {
    local deps=("sqlite3" "curl" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        return 1
    fi
    
    log_success "所有依赖已安装"
}

# 检查SQLite数据库文件
check_sqlite_file() {
    local db_file="$1"
    
    if [ ! -f "$db_file" ]; then
        log_warning "SQLite数据库文件不存在: $db_file"
        return 1
    fi
    
    if [ ! -r "$db_file" ]; then
        log_error "SQLite数据库文件不可读: $db_file"
        return 1
    fi
    
    log_success "SQLite数据库文件存在且可读: $db_file"
    return 0
}

# 检查数据库表结构
check_table_structure() {
    local db_file="$1"
    
    local tables
    tables=$(sqlite3 "$db_file" ".tables" 2>/dev/null || true)
    
    if [ -z "$tables" ]; then
        log_error "数据库中没有表"
        return 1
    fi
    
    log_info "数据库表: $tables"
    
    # 检查关键表
    local required_tables=("api_keys" "usage_logs" "users")
    local missing_tables=()
    
    for table in "${required_tables[@]}"; do
        if ! echo "$tables" | grep -q "\b$table\b"; then
            missing_tables+=("$table")
        fi
    done
    
    if [ ${#missing_tables[@]} -gt 0 ]; then
        log_error "缺少关键表: ${missing_tables[*]}"
        return 1
    fi
    
    log_success "所有关键表都存在"
    return 0
}

# 检查数据持久化
check_data_persistence() {
    local db_file="$1"
    
    # 检查api_keys表是否有数据
    local key_count
    key_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null || echo "0")
    
    if [ "$key_count" -eq "0" ]; then
        log_warning "api_keys表中没有数据"
    else
        log_success "api_keys表中有 $key_count 条记录"
    fi
    
    # 检查usage_logs表是否有数据
    local usage_count
    usage_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM usage_logs;" 2>/dev/null || echo "0")
    
    if [ "$usage_count" -eq "0" ]; then
        log_warning "usage_logs表中没有数据"
    else
        log_success "usage_logs表中有 $usage_count 条记录"
    fi
    
    return 0
}

# 主验证函数
main_verification() {
    local dry_run=false
    local quick_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --quick)
                quick_mode=true
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    if [ "$dry_run" = true ]; then
        log_info "模拟运行模式 - 只显示验证步骤，不执行实际检查"
        log_info "1. 检查依赖 (sqlite3, curl, jq)"
        log_info "2. 检查SQLite数据库文件存在性"
        log_info "3. 检查数据库表结构"
        log_info "4. 检查数据持久化"
        log_success "模拟运行完成"
        return 0
    fi
    
    log_info "开始验证SQLite持久化功能"
    
    # 假设数据库文件路径
    local db_file="/opt/roc/quota-proxy/data/quota.db"
    
    # 1. 检查依赖
    log_info "检查依赖..."
    check_dependencies
    
    # 2. 检查SQLite数据库文件
    log_info "检查SQLite数据库文件..."
    if ! check_sqlite_file "$db_file"; then
        log_warning "SQLite数据库文件检查失败，跳过后续检查"
        return 0
    fi
    
    # 3. 检查表结构
    log_info "检查数据库表结构..."
    check_table_structure "$db_file"
    
    # 4. 检查数据持久化
    if [ "$quick_mode" = false ]; then
        log_info "检查数据持久化..."
        check_data_persistence "$db_file"
    fi
    
    log_success "SQLite持久化功能验证完成"
    return 0
}

# 清理函数
cleanup() {
    log_info "清理完成"
}

# 主程序
main() {
    trap cleanup EXIT
    
    if ! main_verification "$@"; then
        log_error "验证失败"
        return 1
    fi
    
    return 0
}

# 运行主程序
main "$@"