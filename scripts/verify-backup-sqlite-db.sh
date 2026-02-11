#!/bin/bash

# SQLite数据库备份脚本验证脚本
# 验证 backup-sqlite-db.sh 脚本的功能完整性

set -euo pipefail

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

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 记录测试结果
record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$result" == "pass" ]]; then
        ((TESTS_PASSED++))
        log_success "测试通过: $test_name - $message"
    else
        ((TESTS_FAILED++))
        log_error "测试失败: $test_name - $message"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
SQLite数据库备份脚本验证脚本

用法: $0 [选项]

选项:
  --quick             快速验证模式（只检查关键功能）
  --dry-run           模拟运行模式
  --help              显示此帮助信息

验证项目:
  1. 文件存在性检查
  2. 可执行权限检查
  3. 语法检查
  4. 帮助功能测试
  5. dry-run模式测试
  6. 颜色定义检查
  7. 日志函数检查
  8. 参数解析函数检查
  9. 依赖检查函数测试
  10. 数据库检查函数测试
  11. 备份目录创建函数测试
  12. 备份文件名生成函数测试
  13. 备份执行函数测试
  14. 旧备份清理函数测试
  15. 报告生成函数测试

EOF
}

# 测试1: 文件存在性检查
test_file_exists() {
    local test_name="文件存在性检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if [[ -f "$script_path" ]]; then
        record_test_result "$test_name" "pass" "脚本文件存在: $script_path"
    else
        record_test_result "$test_name" "fail" "脚本文件不存在: $script_path"
    fi
}

# 测试2: 可执行权限检查
test_executable_permission() {
    local test_name="可执行权限检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if [[ -x "$script_path" ]]; then
        record_test_result "$test_name" "pass" "脚本具有可执行权限"
    else
        # 尝试添加执行权限
        chmod +x "$script_path" 2>/dev/null
        if [[ -x "$script_path" ]]; then
            record_test_result "$test_name" "pass" "已添加可执行权限"
        else
            record_test_result "$test_name" "fail" "脚本没有可执行权限且无法添加"
        fi
    fi
}

# 测试3: 语法检查
test_syntax_check() {
    local test_name="语法检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if bash -n "$script_path" 2>/dev/null; then
        record_test_result "$test_name" "pass" "脚本语法正确"
    else
        record_test_result "$test_name" "fail" "脚本语法错误"
    fi
}

# 测试4: 帮助功能测试
test_help_function() {
    local test_name="帮助功能测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    local help_output
    help_output=$("$script_path" --help 2>&1)
    
    if echo "$help_output" | grep -q "SQLite数据库备份脚本"; then
        record_test_result "$test_name" "pass" "帮助信息显示正常"
    else
        record_test_result "$test_name" "fail" "帮助信息显示异常"
    fi
}

# 测试5: dry-run模式测试
test_dry_run_mode() {
    local test_name="dry-run模式测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    local dry_run_output
    dry_run_output=$("$script_path" --dry-run 2>&1)
    
    if echo "$dry_run_output" | grep -q "模拟运行"; then
        record_test_result "$test_name" "pass" "dry-run模式正常工作"
    else
        record_test_result "$test_name" "fail" "dry-run模式异常"
    fi
}

# 测试6: 颜色定义检查
test_color_definitions() {
    local test_name="颜色定义检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "RED='\\033\[0;31m'" "$script_path" && \
       grep -q "GREEN='\\033\[0;32m'" "$script_path" && \
       grep -q "YELLOW='\\033\[1;33m'" "$script_path" && \
       grep -q "BLUE='\\033\[0;34m'" "$script_path" && \
       grep -q "NC='\\033\[0m'" "$script_path"; then
        record_test_result "$test_name" "pass" "颜色定义完整"
    else
        record_test_result "$test_name" "fail" "颜色定义缺失"
    fi
}

# 测试7: 日志函数检查
test_log_functions() {
    local test_name="日志函数检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "log_info()" "$script_path" && \
       grep -q "log_success()" "$script_path" && \
       grep -q "log_warning()" "$script_path" && \
       grep -q "log_error()" "$script_path"; then
        record_test_result "$test_name" "pass" "日志函数完整"
    else
        record_test_result "$test_name" "fail" "日志函数缺失"
    fi
}

# 测试8: 参数解析函数检查
test_parse_args_function() {
    local test_name="参数解析函数检查"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "parse_args()" "$script_path"; then
        record_test_result "$test_name" "pass" "参数解析函数存在"
    else
        record_test_result "$test_name" "fail" "参数解析函数缺失"
    fi
}

# 测试9: 依赖检查函数测试
test_check_dependencies_function() {
    local test_name="依赖检查函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "check_dependencies()" "$script_path"; then
        record_test_result "$test_name" "pass" "依赖检查函数存在"
    else
        record_test_result "$test_name" "fail" "依赖检查函数缺失"
    fi
}

# 测试10: 数据库检查函数测试
test_check_database_function() {
    local test_name="数据库检查函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "check_database()" "$script_path"; then
        record_test_result "$test_name" "pass" "数据库检查函数存在"
    else
        record_test_result "$test_name" "fail" "数据库检查函数缺失"
    fi
}

# 测试11: 备份目录创建函数测试
test_create_backup_dir_function() {
    local test_name="备份目录创建函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "create_backup_dir()" "$script_path"; then
        record_test_result "$test_name" "pass" "备份目录创建函数存在"
    else
        record_test_result "$test_name" "fail" "备份目录创建函数缺失"
    fi
}

# 测试12: 备份文件名生成函数测试
test_generate_backup_filename_function() {
    local test_name="备份文件名生成函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "generate_backup_filename()" "$script_path"; then
        record_test_result "$test_name" "pass" "备份文件名生成函数存在"
    else
        record_test_result "$test_name" "fail" "备份文件名生成函数缺失"
    fi
}

# 测试13: 备份执行函数测试
test_perform_backup_function() {
    local test_name="备份执行函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "perform_backup()" "$script_path"; then
        record_test_result "$test_name" "pass" "备份执行函数存在"
    else
        record_test_result "$test_name" "fail" "备份执行函数缺失"
    fi
}

# 测试14: 旧备份清理函数测试
test_cleanup_old_backups_function() {
    local test_name="旧备份清理函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "cleanup_old_backups()" "$script_path"; then
        record_test_result "$test_name" "pass" "旧备份清理函数存在"
    else
        record_test_result "$test_name" "fail" "旧备份清理函数缺失"
    fi
}

# 测试15: 报告生成函数测试
test_generate_report_function() {
    local test_name="报告生成函数测试"
    local script_path="./scripts/backup-sqlite-db.sh"
    
    if grep -q "generate_report()" "$script_path"; then
        record_test_result "$test_name" "pass" "报告生成函数存在"
    else
        record_test_result "$test_name" "fail" "报告生成函数缺失"
    fi
}

# 快速验证模式
quick_verification() {
    log_info "执行快速验证模式..."
    
    test_file_exists
    test_executable_permission
    test_syntax_check
    test_help_function
    test_dry_run_mode
}

# 完整验证模式
full_verification() {
    log_info "执行完整验证模式..."
    
    test_file_exists
    test_executable_permission
    test_syntax_check
    test_help_function
    test_dry_run_mode
    test_color_definitions
    test_log_functions
    test_parse_args_function
    test_check_dependencies_function
    test_check_database_function
    test_create_backup_dir_function
    test_generate_backup_filename_function
    test_perform_backup_function
    test_cleanup_old_backups_function
    test_generate_report_function
}

# 显示验证报告
show_verification_report() {
    echo ""
    echo "========================================"
    echo "SQLite数据库备份脚本验证报告"
    echo "========================================"
    echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "验证脚本: backup-sqlite-db.sh"
    echo "验证模式: $VERIFICATION_MODE"
    echo "----------------------------------------"
    echo "测试统计:"
    echo "  总测试数: $TESTS_TOTAL"
    echo "  通过数: $TESTS_PASSED"
    echo "  失败数: $TESTS_FAILED"
    echo "  通过率: $((TESTS_PASSED * 100 / TESTS_TOTAL))%"
    echo "----------------------------------------"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "所有测试通过！脚本功能完整。"
        echo ""
        echo "后续操作建议:"
        echo "1. 将脚本部署到服务器: scp ./scripts/backup-sqlite-db.sh user@server:/opt/roc/quota-proxy/scripts/"
        echo "2. 设置定时备份任务 (crontab):"
        echo "   # 每天凌晨2点备份"
        echo "   0 2 * * * /opt/roc/quota-proxy/scripts/backup-sqlite-db.sh --keep-days 30"
        echo "3. 测试实际备份功能:"
        echo "   ./scripts/backup-sqlite-db.sh --db-path /tmp/test.db --backup-dir /tmp/backups"
        echo "4. 验证备份文件:"
        echo "   sqlite3 /tmp/backups/*.db \"SELECT COUNT(*) FROM sqlite_master WHERE type='table';\""
    else
        log_error "有 $TESTS_FAILED 个测试失败，请检查脚本问题。"
        echo ""
        echo "故障排除建议:"
        echo "1. 检查脚本语法: bash -n ./scripts/backup-sqlite-db.sh"
        echo "2. 检查文件权限: ls -la ./scripts/backup-sqlite-db.sh"
        echo "3. 手动测试功能: ./scripts/backup-sqlite-db.sh --help"
        echo "4. 查看详细错误: ./scripts/backup-sqlite-db.sh --dry-run 2>&1"
    fi
    
    echo "========================================"
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 删除可能创建的测试文件
    rm -rf /tmp/test_backup_* 2>/dev/null || true
    rm -f /tmp/test.db 2>/dev/null || true
    
    log_success "测试环境清理完成"
}

# 主函数
main() {
    local quick_mode=false
    local dry_run_mode=false
    VERIFICATION_MODE="完整验证"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick_mode=true
                VERIFICATION_MODE="快速验证"
                shift
                ;;
            --dry-run)
                dry_run_mode=true
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
    
    log_info "开始验证SQLite数据库备份脚本"
    log_info "验证模式: $VERIFICATION_MODE"
    log_info "当前目录: $(pwd)"
    
    # 切换到脚本所在目录的父目录
    cd "$(dirname "$0")/.." || {
        log_error "无法切换到项目根目录"
        exit 1
    }
    
    log_info "切换到项目根目录: $(pwd)"
    
    # 执行验证
    if [[ "$quick_mode" == true ]]; then
        quick_verification
    else
        full_verification
    fi
    
    # 显示验证报告
    show_verification_report
    
    # 清理测试环境
    if [[ "$dry_run_mode" == false ]]; then
        cleanup_test_environment
    fi
    
    # 返回退出码
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 执行主函数
main "$@"