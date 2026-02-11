#!/bin/bash

# 验证数据库索引创建脚本

set -euo pipefail

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 日志函数
log_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$status" == "PASS" ]]; then
        echo "[PASS] $test_name: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$status" == "FAIL" ]]; then
        echo "[FAIL] $test_name: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [[ "$status" == "SKIP" ]]; then
        echo "[SKIP] $test_name: $message"
    else
        echo "[INFO] $test_name: $message"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
验证数据库索引创建脚本

用法: $0 [选项]

选项:
  --quick      快速验证模式（只检查基本功能）
  --dry-run    模拟运行模式
  --verbose    详细输出模式
  --help       显示此帮助信息

示例:
  $0 --quick
  $0 --dry-run
  $0 --verbose
EOF
}

# 默认参数
QUICK_MODE=false
DRY_RUN=false
VERBOSE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
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
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 测试1: 检查脚本文件存在性
test_script_exists() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if [[ -f "$script_path" ]]; then
        log_test "文件存在性检查" "PASS" "脚本文件存在: $script_path"
        return 0
    else
        log_test "文件存在性检查" "FAIL" "脚本文件不存在: $script_path"
        return 1
    fi
}

# 测试2: 检查脚本可执行权限
test_script_executable() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if [[ -x "$script_path" ]]; then
        log_test "可执行权限检查" "PASS" "脚本具有可执行权限"
        return 0
    else
        log_test "可执行权限检查" "FAIL" "脚本缺少可执行权限"
        return 1
    fi
}

# 测试3: 检查脚本语法
test_script_syntax() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if bash -n "$script_path" 2>/dev/null; then
        log_test "语法检查" "PASS" "脚本语法正确"
        return 0
    else
        log_test "语法检查" "FAIL" "脚本语法错误"
        return 1
    fi
}

# 测试4: 检查帮助功能
test_help_function() {
    local script_path="./scripts/create-db-indexes.sh"
    
    # 使用LC_ALL=C来避免编码问题
    if LC_ALL=C "$script_path" --help 2>&1 | grep -q "数据库索引创建脚本" 2>/dev/null; then
        log_test "帮助功能检查" "PASS" "帮助功能正常"
        return 0
    else
        log_test "帮助功能检查" "FAIL" "帮助功能异常"
        return 1
    fi
}

# 测试5: 检查dry-run模式
test_dry_run_mode() {
    local script_path="./scripts/create-db-indexes.sh"
    
    # 使用LC_ALL=C来避免编码问题，并检查是否有DRY-RUN输出
    if LC_ALL=C "$script_path" --dry-run 2>&1 | grep -q "DRY-RUN"; then
        log_test "dry-run模式检查" "PASS" "dry-run模式正常"
        return 0
    else
        log_test "dry-run模式检查" "FAIL" "dry-run模式异常"
        return 1
    fi
}

# 测试6: 检查颜色定义
test_color_definitions() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if grep -q "RED='\\033\[0;31m'" "$script_path" && \
       grep -q "GREEN='\\033\[0;32m'" "$script_path" && \
       grep -q "YELLOW='\\033\[1;33m'" "$script_path" && \
       grep -q "BLUE='\\033\[0;34m'" "$script_path"; then
        log_test "颜色定义检查" "PASS" "颜色定义完整"
        return 0
    else
        log_test "颜色定义检查" "FAIL" "颜色定义不完整"
        return 1
    fi
}

# 测试7: 检查日志函数
test_log_functions() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if grep -q "log_info()" "$script_path" && \
       grep -q "log_success()" "$script_path" && \
       grep -q "log_warning()" "$script_path" && \
       grep -q "log_error()" "$script_path"; then
        log_test "日志函数检查" "PASS" "日志函数完整"
        return 0
    else
        log_test "日志函数检查" "FAIL" "日志函数不完整"
        return 1
    fi
}

# 测试8: 检查索引创建函数
test_index_creation_functions() {
    local script_path="./scripts/create-db-indexes.sh"
    
    if grep -q "create_index()" "$script_path" && \
       grep -q "check_index_exists()" "$script_path"; then
        log_test "索引函数检查" "PASS" "索引创建函数完整"
        return 0
    else
        log_test "索引函数检查" "FAIL" "索引创建函数不完整"
        return 1
    fi
}

# 测试9: 检查索引列表
test_index_list() {
    local script_path="./scripts/create-db-indexes.sh"
    
    local expected_indexes=5
    local found_indexes=$(grep -c "idx_" "$script_path" | head -1)
    
    if [[ $found_indexes -ge $expected_indexes ]]; then
        log_test "索引列表检查" "PASS" "找到 $found_indexes 个索引定义（预期≥$expected_indexes）"
        return 0
    else
        log_test "索引列表检查" "FAIL" "只找到 $found_indexes 个索引定义（预期≥$expected_indexes）"
        return 1
    fi
}

# 测试10: 检查清理函数（如果有）
test_cleanup_functions() {
    local script_path="./scripts/create-db-indexes.sh"
    
    # 检查是否有清理或重置功能
    if grep -q -i "cleanup\|reset\|remove" "$script_path"; then
        log_test "清理函数检查" "PASS" "包含清理功能"
        return 0
    else
        log_test "清理函数检查" "SKIP" "未找到显式清理函数（可选）"
        return 0
    fi
}

# 快速验证模式
run_quick_tests() {
    echo "=== 快速验证模式 ==="
    
    test_script_exists
    test_script_executable
    test_script_syntax
    test_help_function
    test_dry_run_mode
    
    echo "=== 快速验证完成 ==="
}

# 完整验证模式
run_full_tests() {
    echo "=== 完整验证模式 ==="
    
    test_script_exists
    test_script_executable
    test_script_syntax
    test_help_function
    test_dry_run_mode
    test_color_definitions
    test_log_functions
    test_index_creation_functions
    test_index_list
    test_cleanup_functions
    
    echo "=== 完整验证完成 ==="
}

# 生成测试报告
generate_report() {
    echo ""
    echo "=== 验证报告 ==="
    echo "测试总数: $TESTS_TOTAL"
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo "跳过: $((TESTS_TOTAL - TESTS_PASSED - TESTS_FAILED))"
    
    local pass_rate=0
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    fi
    
    echo "通过率: $pass_rate%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✅ 所有测试通过！"
        return 0
    else
        echo "❌ 有 $TESTS_FAILED 个测试失败"
        return 1
    fi
}

# 主函数
main() {
    echo "开始验证数据库索引创建脚本"
    echo "模式: $([[ "$QUICK_MODE" == "true" ]] && echo "快速" || echo "完整")"
    echo "模拟运行: $DRY_RUN"
    echo "详细输出: $VERBOSE"
    echo ""
    
    # 切换到脚本目录的父目录（项目根目录）
    local script_dir="$(cd "$(dirname "$0")/.." && pwd)"
    cd "$script_dir" || exit 1
    
    # 运行测试
    if [[ "$QUICK_MODE" == "true" ]]; then
        run_quick_tests
    else
        run_full_tests
    fi
    
    # 生成报告
    generate_report
    
    # 返回测试结果
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 执行主函数
main "$@"