#!/bin/bash
# 数据库健康检查脚本
# 用于定期检查 SQLite 数据库的健康状态

set -euo pipefail

# 默认数据库路径
DEFAULT_DB_PATH="/data/quota.db"
DB_PATH="${DB_PATH:-$DEFAULT_DB_PATH}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查数据库文件是否存在
check_database_file() {
    log_info "检查数据库文件: $DB_PATH"
    
    if [[ ! -f "$DB_PATH" ]]; then
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
    
    local file_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    log_info "数据库文件大小: $file_size 字节"
    
    if [[ $file_size -eq 0 ]]; then
        log_warning "数据库文件为空"
        return 2
    fi
    
    log_success "数据库文件存在且非空"
    return 0
}

# 检查数据库完整性
check_database_integrity() {
    log_info "检查数据库完整性..."
    
    if ! command -v sqlite3 &> /dev/null; then
        log_warning "sqlite3 命令未找到，跳过完整性检查"
        return 0
    fi
    
    if ! sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        log_error "数据库完整性检查失败"
        return 1
    fi
    
    log_success "数据库完整性检查通过"
    return 0
}

# 检查数据库表结构
check_database_tables() {
    log_info "检查数据库表结构..."
    
    if ! command -v sqlite3 &> /dev/null; then
        log_warning "sqlite3 命令未找到，跳过表结构检查"
        return 0
    fi
    
    local tables=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)
    
    if [[ -z "$tables" ]]; then
        log_error "数据库中没有表"
        return 1
    fi
    
    log_info "数据库表列表:"
    echo "$tables" | tr ' ' '\n' | while read -r table; do
        if [[ -n "$table" ]]; then
            echo "  - $table"
        fi
    done
    
    # 检查关键表是否存在
    local required_tables=("api_keys" "usage_logs")
    local missing_tables=()
    
    for table in "${required_tables[@]}"; do
        if ! echo "$tables" | grep -q "\b$table\b"; then
            missing_tables+=("$table")
        fi
    done
    
    if [[ ${#missing_tables[@]} -gt 0 ]]; then
        log_warning "缺少关键表: ${missing_tables[*]}"
        return 2
    fi
    
    log_success "数据库表结构检查通过"
    return 0
}

# 检查数据库连接数
check_database_connections() {
    log_info "检查数据库连接状态..."
    
    # 尝试打开数据库连接
    if command -v sqlite3 &> /dev/null; then
        if ! sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
            log_error "无法连接到数据库"
            return 1
        fi
        
        log_success "数据库连接正常"
    else
        log_warning "sqlite3 命令未找到，跳过连接测试"
    fi
    
    return 0
}

# 生成健康报告
generate_health_report() {
    local report_file="${REPORT_FILE:-/tmp/database-health-report-$(date +%Y%m%d-%H%M%S).txt}"
    
    log_info "生成健康报告: $report_file"
    
    {
        echo "数据库健康检查报告"
        echo "=================="
        echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "数据库路径: $DB_PATH"
        echo ""
        
        # 文件信息
        echo "1. 文件状态:"
        if [[ -f "$DB_PATH" ]]; then
            local file_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
            local file_mtime=$(stat -c%y "$DB_PATH" 2>/dev/null || stat -f%Sm "$DB_PATH" 2>/dev/null)
            echo "   - 存在: 是"
            echo "   - 大小: $file_size 字节"
            echo "   - 修改时间: $file_mtime"
        else
            echo "   - 存在: 否"
        fi
        echo ""
        
        # 完整性检查
        echo "2. 完整性检查:"
        if command -v sqlite3 &> /dev/null; then
            local integrity_result=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | head -1)
            echo "   - 结果: $integrity_result"
        else
            echo "   - sqlite3 未安装，跳过"
        fi
        echo ""
        
        # 表结构
        echo "3. 表结构:"
        if command -v sqlite3 &> /dev/null; then
            local tables=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)
            if [[ -n "$tables" ]]; then
                echo "   - 表数量: $(echo "$tables" | wc -w)"
                echo "   - 表列表: $tables"
            else
                echo "   - 无表"
            fi
        else
            echo "   - sqlite3 未安装，跳过"
        fi
        echo ""
        
        # 连接测试
        echo "4. 连接测试:"
        if command -v sqlite3 &> /dev/null; then
            if sqlite3 "$DB_PATH" "SELECT 1;" >/dev/null 2>&1; then
                echo "   - 状态: 正常"
            else
                echo "   - 状态: 失败"
            fi
        else
            echo "   - sqlite3 未安装，跳过"
        fi
        echo ""
        
        echo "检查完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "总体状态: $OVERALL_STATUS"
        
    } > "$report_file"
    
    log_success "健康报告已保存到: $report_file"
    echo "报告路径: $report_file"
}

# 主函数
main() {
    log_info "开始数据库健康检查"
    log_info "数据库路径: $DB_PATH"
    
    local checks_passed=0
    local checks_total=0
    local failed_checks=()
    
    # 执行检查
    if check_database_file; then
        ((checks_passed++))
    else
        failed_checks+=("文件检查")
    fi
    ((checks_total++))
    
    if check_database_integrity; then
        ((checks_passed++))
    else
        failed_checks+=("完整性检查")
    fi
    ((checks_total++))
    
    if check_database_tables; then
        ((checks_passed++))
    else
        failed_checks+=("表结构检查")
    fi
    ((checks_total++))
    
    if check_database_connections; then
        ((checks_passed++))
    else
        failed_checks+=("连接检查")
    fi
    ((checks_total++))
    
    # 汇总结果
    log_info "检查完成: $checks_passed/$checks_total 项通过"
    
    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        log_warning "失败的检查项: ${failed_checks[*]}"
        OVERALL_STATUS="警告"
    else
        log_success "所有检查项通过"
        OVERALL_STATUS="健康"
    fi
    
    # 生成报告
    if [[ "${GENERATE_REPORT:-true}" == "true" ]]; then
        generate_health_report
    fi
    
    # 返回状态码
    if [[ $checks_passed -eq $checks_total ]]; then
        return 0
    else
        return 3
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
数据库健康检查脚本

用法: $0 [选项]

选项:
  -d, --db-path PATH     数据库文件路径 (默认: /data/quota.db)
  -r, --no-report        不生成健康报告
  -h, --help             显示此帮助信息
  -v, --version          显示版本信息

环境变量:
  DB_PATH                数据库文件路径
  GENERATE_REPORT        是否生成报告 (true/false, 默认: true)
  REPORT_FILE            报告文件路径 (默认: /tmp/database-health-report-<timestamp>.txt)

示例:
  $0
  $0 --db-path /opt/roc/quota.db
  DB_PATH=/custom/path.db $0 --no-report

退出码:
  0 - 所有检查通过
  1 - 数据库文件不存在或为空
  2 - 数据库表结构问题
  3 - 部分检查失败
  4 - 参数错误

EOF
}

# 显示版本信息
show_version() {
    echo "数据库健康检查脚本 v1.0.0"
    echo "创建时间: 2026-02-11"
    echo "用途: 检查 SQLite 数据库的健康状态"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--db-path)
                if [[ -n "${2:-}" ]]; then
                    DB_PATH="$2"
                    shift 2
                else
                    log_error "--db-path 需要参数值"
                    exit 4
                fi
                ;;
            -r|--no-report)
                GENERATE_REPORT="false"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 4
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
    exit $?
fi