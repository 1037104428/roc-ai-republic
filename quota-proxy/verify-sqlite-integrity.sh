#!/bin/bash

# SQLite数据库完整性验证脚本
# 用于验证quota-proxy SQLite数据库的完整性和一致性
# 版本: 2026.02.11.15

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

# 帮助信息
show_help() {
    cat << EOF
SQLite数据库完整性验证脚本

用法: $0 [选项]

选项:
  --db-path PATH      SQLite数据库文件路径 (默认: ./data/quota.db)
  --dry-run          只显示将要执行的检查，不实际执行
  --quick            快速检查模式，只执行关键检查
  --verbose          详细输出模式
  --help             显示此帮助信息

示例:
  $0 --db-path /opt/roc/quota-proxy/data/quota.db
  $0 --dry-run
  $0 --quick

检查项目:
  1. 数据库文件存在性和权限检查
  2. SQLite版本兼容性检查
  3. 数据库完整性检查 (PRAGMA integrity_check)
  4. 外键约束检查
  5. 表结构完整性检查
  6. 索引完整性检查
  7. 数据一致性检查
  8. 备份完整性检查 (如果存在备份)

EOF
}

# 默认参数
DB_PATH="./data/quota.db"
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false

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
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v sqlite3 &> /dev/null; then
        log_error "未找到 sqlite3 命令，请安装: sudo apt-get install sqlite3"
        return 1
    fi
    
    if ! command -v jq &> /dev/null && [[ "$VERBOSE" == true ]]; then
        log_warning "未找到 jq 命令，JSON输出将使用替代格式"
    fi
    
    log_success "依赖检查完成"
}

# 检查数据库文件
check_database_file() {
    log_info "检查数据库文件: $DB_PATH"
    
    if [[ ! -f "$DB_PATH" ]]; then
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
    
    if [[ ! -r "$DB_PATH" ]]; then
        log_error "数据库文件不可读: $DB_PATH"
        return 1
    fi
    
    if [[ ! -w "$DB_PATH" ]]; then
        log_warning "数据库文件不可写: $DB_PATH"
    fi
    
    local file_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    log_info "数据库文件大小: $(numfmt --to=iec $file_size)"
    
    log_success "数据库文件检查完成"
}

# 检查SQLite版本兼容性
check_sqlite_version() {
    log_info "检查SQLite版本兼容性..."
    
    local sqlite_version=$(sqlite3 --version | head -n1 | awk '{print $1}')
    local required_version="3.35.0"  # 支持RETURNING子句的最低版本
    
    log_info "当前SQLite版本: $sqlite_version"
    log_info "要求的最低版本: $required_version (支持RETURNING子句)"
    
    # 简单的版本比较
    if [[ "$(printf '%s\n' "$required_version" "$sqlite_version" | sort -V | head -n1)" == "$required_version" ]]; then
        log_success "SQLite版本兼容性检查通过"
    else
        log_warning "SQLite版本可能过低，某些功能可能不可用"
    fi
}

# 执行数据库完整性检查
check_database_integrity() {
    log_info "执行数据库完整性检查..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 将执行: PRAGMA integrity_check"
        return 0
    fi
    
    local integrity_result=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null)
    
    if [[ "$integrity_result" == "ok" ]]; then
        log_success "数据库完整性检查通过: $integrity_result"
    else
        log_error "数据库完整性检查失败: $integrity_result"
        return 1
    fi
}

# 检查外键约束
check_foreign_keys() {
    log_info "检查外键约束..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 将检查外键约束状态"
        return 0
    fi
    
    local foreign_keys_status=$(sqlite3 "$DB_PATH" "PRAGMA foreign_keys;" 2>/dev/null)
    
    if [[ "$foreign_keys_status" == "1" ]]; then
        log_success "外键约束已启用"
    else
        log_warning "外键约束未启用"
    fi
}

# 检查表结构
check_table_structure() {
    log_info "检查表结构完整性..."
    
    local expected_tables=("users" "api_keys" "usage_logs" "rate_limits" "admin_logs")
    local missing_tables=()
    
    for table in "${expected_tables[@]}"; do
        local table_exists=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" 2>/dev/null)
        
        if [[ -z "$table_exists" ]]; then
            missing_tables+=("$table")
        else
            if [[ "$VERBOSE" == true ]]; then
                local column_count=$(sqlite3 "$DB_PATH" "PRAGMA table_info($table);" 2>/dev/null | wc -l)
                log_info "表 '$table' 存在，包含 $column_count 个列"
            fi
        fi
    done
    
    if [[ ${#missing_tables[@]} -eq 0 ]]; then
        log_success "所有预期表都存在"
    else
        log_error "缺少表: ${missing_tables[*]}"
        return 1
    fi
}

# 检查索引
check_indexes() {
    log_info "检查索引..."
    
    local index_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" 2>/dev/null)
    
    if [[ "$index_count" -gt 0 ]]; then
        log_success "找到 $index_count 个索引"
        
        if [[ "$VERBOSE" == true ]]; then
            sqlite3 "$DB_PATH" "SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' ORDER BY name;" 2>/dev/null | while read -r line; do
                log_info "索引: $line"
            done
        fi
    else
        log_warning "未找到索引，考虑添加索引以提高查询性能"
    fi
}

# 检查数据一致性
check_data_consistency() {
    log_info "检查数据一致性..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 将检查数据一致性"
        return 0
    fi
    
    # 检查api_keys表中的user_id是否在users表中存在
    local orphaned_keys=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM api_keys ak 
        LEFT JOIN users u ON ak.user_id = u.id 
        WHERE u.id IS NULL AND ak.user_id IS NOT NULL;
    " 2>/dev/null)
    
    if [[ "$orphaned_keys" -eq 0 ]]; then
        log_success "api_keys表数据一致性检查通过"
    else
        log_error "发现 $orphaned_keys 个孤立的api_key记录（user_id在users表中不存在）"
        return 1
    fi
    
    # 检查usage_logs表中的key_id是否在api_keys表中存在
    local orphaned_logs=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM usage_logs ul 
        LEFT JOIN api_keys ak ON ul.key_id = ak.id 
        WHERE ak.id IS NULL AND ul.key_id IS NOT NULL;
    " 2>/dev/null)
    
    if [[ "$orphaned_logs" -eq 0 ]]; then
        log_success "usage_logs表数据一致性检查通过"
    else
        log_error "发现 $orphaned_logs 个孤立的usage_log记录（key_id在api_keys表中不存在）"
        return 1
    fi
}

# 检查备份文件
check_backups() {
    log_info "检查备份文件..."
    
    local backup_dir=$(dirname "$DB_PATH")/backups
    local backup_count=0
    
    if [[ -d "$backup_dir" ]]; then
        backup_count=$(find "$backup_dir" -name "*.db" -o -name "*.db.backup" -o -name "*.sqlite" 2>/dev/null | wc -l)
        
        if [[ "$backup_count" -gt 0 ]]; then
            log_success "找到 $backup_count 个备份文件"
            
            if [[ "$VERBOSE" == true ]]; then
                find "$backup_dir" -name "*.db" -o -name "*.db.backup" -o -name "*.sqlite" 2>/dev/null | head -5 | while read -r backup; do
                    local backup_size=$(stat -c%s "$backup" 2>/dev/null || stat -f%z "$backup" 2>/dev/null)
                    local backup_time=$(stat -c%y "$backup" 2>/dev/null || stat -f%Sm "$backup" 2>/dev/null)
                    log_info "备份: $(basename "$backup") - 大小: $(numfmt --to=iec $backup_size) - 时间: $backup_time"
                done
            fi
        else
            log_warning "备份目录存在但未找到备份文件"
        fi
    else
        log_warning "备份目录不存在: $backup_dir"
    fi
}

# 生成报告
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)
    local db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    
    cat << EOF

========================================
SQLite数据库完整性验证报告
========================================
时间: $timestamp
主机: $hostname
数据库: $DB_PATH
大小: $(numfmt --to=iec $db_size)
模式: ${DRY_RUN:+DRY-RUN }${QUICK_MODE:+QUICK }${VERBOSE:+VERBOSE}
----------------------------------------

检查结果摘要:
1. 数据库文件检查: $(check_database_file >/dev/null 2>&1 && echo "通过" || echo "失败")
2. SQLite版本检查: $(check_sqlite_version >/dev/null 2>&1 && echo "通过" || echo "警告")
3. 数据库完整性: $(check_database_integrity >/dev/null 2>&1 && echo "通过" || echo "失败")
4. 外键约束: $(check_foreign_keys >/dev/null 2>&1 && echo "启用" || echo "未启用")
5. 表结构检查: $(check_table_structure >/dev/null 2>&1 && echo "通过" || echo "失败")
6. 索引检查: $(check_indexes >/dev/null 2>&1 && echo "存在" || echo "无索引")
7. 数据一致性: $(check_data_consistency >/dev/null 2>&1 && echo "通过" || echo "失败")
8. 备份检查: $(check_backups >/dev/null 2>&1 && echo "存在" || echo "无备份")

建议:
$(generate_recommendations)

========================================
验证完成
========================================
EOF
}

# 生成建议
generate_recommendations() {
    local recommendations=""
    
    # 检查外键约束
    local foreign_keys_status=$(sqlite3 "$DB_PATH" "PRAGMA foreign_keys;" 2>/dev/null 2>/dev/null)
    if [[ "$foreign_keys_status" != "1" ]]; then
        recommendations+="- 建议启用外键约束: PRAGMA foreign_keys = ON;\n"
    fi
    
    # 检查索引数量
    local index_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='index';" 2>/dev/null)
    if [[ "$index_count" -eq 0 ]]; then
        recommendations+="- 建议为常用查询字段添加索引以提高性能\n"
    fi
    
    # 检查备份
    local backup_dir=$(dirname "$DB_PATH")/backups
    if [[ ! -d "$backup_dir" ]]; then
        recommendations+="- 建议设置定期备份策略，创建备份目录: $backup_dir\n"
    fi
    
    if [[ -z "$recommendations" ]]; then
        recommendations="数据库状态良好，继续保持当前维护策略。"
    fi
    
    echo -e "$recommendations"
}

# 主函数
main() {
    log_info "开始SQLite数据库完整性验证"
    log_info "数据库路径: $DB_PATH"
    log_info "模式: ${DRY_RUN:+DRY-RUN }${QUICK_MODE:+QUICK }${VERBOSE:+VERBOSE}"
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 执行检查
    local checks_passed=0
    local checks_total=0
    
    # 基本检查
    check_database_file && ((checks_passed++))
    ((checks_total++))
    
    check_sqlite_version && ((checks_passed++))
    ((checks_total++))
    
    # 完整性检查
    check_database_integrity && ((checks_passed++))
    ((checks_total++))
    
    check_foreign_keys && ((checks_passed++))
    ((checks_total++))
    
    # 结构检查
    check_table_structure && ((checks_passed++))
    ((checks_total++))
    
    check_indexes && ((checks_passed++))
    ((checks_total++))
    
    # 数据检查（如果不是快速模式）
    if [[ "$QUICK_MODE" != true ]]; then
        check_data_consistency && ((checks_passed++))
        ((checks_total++))
        
        check_backups && ((checks_passed++))
        ((checks_total++))
    fi
    
    # 生成报告
    generate_report
    
    # 输出总结
    log_info "检查完成: $checks_passed/$checks_total 项检查通过"
    
    if [[ $checks_passed -eq $checks_total ]]; then
        log_success "所有检查通过，数据库状态良好"
        exit 0
    else
        log_warning "部分检查未通过，请查看详细报告"
        exit 1
    fi
}

# 运行主函数
main "$@"