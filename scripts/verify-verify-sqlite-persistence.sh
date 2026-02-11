#!/bin/bash

# verify-verify-sqlite-persistence.sh - 验证verify-sqlite-persistence.sh脚本
# 确保SQLite持久化验证脚本功能完整可靠

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

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 记录测试结果
record_test() {
    local test_name="$1"
    local result="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "pass" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "测试通过: $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "测试失败: $test_name"
    fi
}

# 测试1: 检查文件存在性
test_file_exists() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if [ -f "$script_path" ]; then
        record_test "文件存在性检查" "pass"
    else
        record_test "文件存在性检查" "fail"
    fi
}

# 测试2: 检查可执行权限
test_executable_permission() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if [ -x "$script_path" ]; then
        record_test "可执行权限检查" "pass"
    else
        record_test "可执行权限检查" "fail"
    fi
}

# 测试3: 检查语法
test_syntax() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if bash -n "$script_path" 2>/dev/null; then
        record_test "语法检查" "pass"
    else
        record_test "语法检查" "fail"
    fi
}

# 测试4: 检查帮助功能
test_help_function() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if "$script_path" --help 2>&1 | head -1 | grep -q "验证SQLite持久化功能脚本"; then
        record_test "帮助功能检查" "pass"
    else
        record_test "帮助功能检查" "fail"
    fi
}

# 测试5: 检查dry-run模式
test_dry_run_mode() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if "$script_path" --dry-run 2>&1 | grep -q "模拟运行模式"; then
        record_test "dry-run模式检查" "pass"
    else
        record_test "dry-run模式检查" "fail"
    fi
}

# 测试6: 检查颜色定义
test_color_definitions() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if grep -q "RED='\\033\[0;31m'" "$script_path" &&
       grep -q "GREEN='\\033\[0;32m'" "$script_path" &&
       grep -q "YELLOW='\\033\[1;33m'" "$script_path" &&
       grep -q "BLUE='\\033\[0;34m'" "$script_path"; then
        record_test "颜色定义检查" "pass"
    else
        record_test "颜色定义检查" "fail"
    fi
}

# 测试7: 检查日志函数
test_log_functions() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if grep -q "log_info()" "$script_path" &&
       grep -q "log_success()" "$script_path" &&
       grep -q "log_warning()" "$script_path" &&
       grep -q "log_error()" "$script_path"; then
        record_test "日志函数检查" "pass"
    else
        record_test "日志函数检查" "fail"
    fi
}

# 测试8: 检查依赖检查函数
test_dependency_check() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if grep -q "check_dependencies()" "$script_path"; then
        record_test "依赖检查函数检查" "pass"
    else
        record_test "依赖检查函数检查" "fail"
    fi
}

# 测试9: 检查数据库检查函数
test_database_check_functions() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if grep -q "check_sqlite_file()" "$script_path" &&
       grep -q "check_table_structure()" "$script_path" &&
       grep -q "check_data_persistence()" "$script_path"; then
        record_test "数据库检查函数检查" "pass"
    else
        record_test "数据库检查函数检查" "fail"
    fi
}

# 测试10: 检查清理函数
test_cleanup_function() {
    local script_path="./scripts/verify-sqlite-persistence.sh"
    
    if grep -q "cleanup()" "$script_path"; then
        record_test "清理函数检查" "pass"
    else
        record_test "清理函数检查" "fail"
    fi
}

# 运行所有测试
run_all_tests() {
    log_info "开始验证 verify-sqlite-persistence.sh 脚本"
    
    test_file_exists
    test_executable_permission
    test_syntax
    test_help_function
    test_dry_run_mode
    test_color_definitions
    test_log_functions
    test_dependency_check
    test_database_check_functions
    test_cleanup_function
    
    # 输出测试报告
    echo ""
    log_info "=== 测试报告 ==="
    log_info "总测试数: $TESTS_TOTAL"
    log_success "通过: $TESTS_PASSED"
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "失败: $TESTS_FAILED"
    else
        log_error "失败: $TESTS_FAILED"
    fi
    
    local pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    log_info "通过率: $pass_rate%"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "有测试失败，请检查脚本"
        return 1
    fi
}

# 主程序
main() {
    local quick_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick_mode=true
                shift
                ;;
            --help)
                echo "用法: $0 [--quick] [--help]"
                echo "  --quick  快速模式，只运行基本测试"
                echo "  --help   显示帮助信息"
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    if [ "$quick_mode" = true ]; then
        log_info "快速模式 - 只运行基本测试"
        test_file_exists
        test_executable_permission
        test_syntax
        test_help_function
        test_dry_run_mode
        
        log_info "快速测试完成"
        return 0
    fi
    
    run_all_tests
}

# 运行主程序
main "$@"