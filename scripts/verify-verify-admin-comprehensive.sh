#!/bin/bash
# verify-verify-admin-comprehensive.sh - 验证verify-admin-comprehensive.sh脚本
# 确保综合性管理API验证脚本功能正常

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 使用量
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_TESTS=0

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

# 测试结果记录
record_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$result" in
        "PASS")
            PASS_COUNT=$((PASS_COUNT + 1))
            echo -e "${GREEN}✓${NC} $test_name: $message"
            ;;
        "FAIL")
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo -e "${RED}✗${NC} $test_name: $message"
            ;;
        "SKIP")
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo -e "${YELLOW}↷${NC} $test_name: $message"
            ;;
    esac
}

# 测试1: 检查脚本文件存在
test_script_exists() {
    local test_name="脚本文件存在性检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    log_info "检查路径: $script_path"
    
    if [ -f "$script_path" ]; then
        record_result "$test_name" "PASS" "脚本文件存在"
        return 0
    else
        record_result "$test_name" "FAIL" "脚本文件不存在"
        return 1
    fi
}

# 测试2: 检查脚本可执行权限
test_script_executable() {
    local test_name="脚本可执行权限检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    if [ -x "$script_path" ]; then
        record_result "$test_name" "PASS" "脚本具有可执行权限"
        return 0
    else
        # 尝试添加执行权限
        if chmod +x "$script_path" 2>/dev/null; then
            record_result "$test_name" "PASS" "已添加脚本执行权限"
            return 0
        else
            record_result "$test_name" "FAIL" "脚本无执行权限且无法添加"
            return 1
        fi
    fi
}

# 测试3: 检查脚本语法
test_script_syntax() {
    local test_name="脚本语法检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    if bash -n "$script_path" 2>/dev/null; then
        record_result "$test_name" "PASS" "脚本语法正确"
        return 0
    else
        record_result "$test_name" "FAIL" "脚本语法错误"
        return 1
    fi
}

# 测试4: 检查帮助功能
test_help_function() {
    local test_name="帮助功能检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    if "$script_path" --help 2>&1 | grep -q "综合性quota-proxy管理API验证脚本"; then
        record_result "$test_name" "PASS" "帮助功能正常"
        return 0
    else
        record_result "$test_name" "FAIL" "帮助功能异常"
        return 1
    fi
}

# 测试5: 检查dry-run模式
test_dry_run_mode() {
    local test_name="dry-run模式检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    local output
    if output=$("$script_path" --dry-run 2>&1); then
        if echo "$output" | grep -q "模拟运行模式"; then
            record_result "$test_name" "PASS" "dry-run模式正常"
            return 0
        else
            record_result "$test_name" "FAIL" "dry-run模式输出异常"
            return 1
        fi
    else
        record_result "$test_name" "FAIL" "dry-run模式执行失败"
        return 1
    fi
}

# 测试6: 检查脚本功能模块
test_script_functions() {
    local test_name="脚本功能模块检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    # 检查关键函数是否存在
    local required_functions=("main" "show_help" "check_dependencies" "test_health_check")
    
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$script_path"; then
            log_info "  ✓ 函数 $func 存在"
        else
            record_result "$test_name" "FAIL" "缺少函数: $func"
            return 1
        fi
    done
    
    record_result "$test_name" "PASS" "所有关键函数存在"
    return 0
}

# 测试7: 检查颜色定义
test_color_definitions() {
    local test_name="颜色定义检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    local required_colors=("RED=" "GREEN=" "YELLOW=" "BLUE=" "NC=")
    
    for color in "${required_colors[@]}"; do
        if grep -q "$color" "$script_path"; then
            log_info "  ✓ 颜色定义 $color 存在"
        else
            record_result "$test_name" "FAIL" "缺少颜色定义: $color"
            return 1
        fi
    done
    
    record_result "$test_name" "PASS" "所有颜色定义存在"
    return 0
}

# 测试8: 检查日志函数
test_log_functions() {
    local test_name="日志函数检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    local required_logs=("log_info" "log_success" "log_warning" "log_error")
    
    for log_func in "${required_logs[@]}"; do
        if grep -q "^$log_func()" "$script_path"; then
            log_info "  ✓ 日志函数 $log_func 存在"
        else
            record_result "$test_name" "FAIL" "缺少日志函数: $log_func"
            return 1
        fi
    done
    
    record_result "$test_name" "PASS" "所有日志函数存在"
    return 0
}

# 测试9: 检查测试函数
test_test_functions() {
    local test_name="测试函数检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    local required_tests=("test_health_check" "test_admin_health" "test_create_trial_key" "test_list_keys" "test_get_usage")
    
    for test_func in "${required_tests[@]}"; do
        if grep -q "^$test_func()" "$script_path"; then
            log_info "  ✓ 测试函数 $test_func 存在"
        else
            record_result "$test_name" "FAIL" "缺少测试函数: $test_func"
            return 1
        fi
    done
    
    record_result "$test_name" "PASS" "所有测试函数存在"
    return 0
}

# 测试10: 检查清理函数
test_cleanup_function() {
    local test_name="清理函数检查"
    local script_path="./scripts/verify-admin-comprehensive.sh"
    
    log_info "测试: $test_name"
    
    if grep -q "^cleanup_test_key()" "$script_path"; then
        record_result "$test_name" "PASS" "清理函数存在"
        return 0
    else
        record_result "$test_name" "FAIL" "缺少清理函数"
        return 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
verify-admin-comprehensive.sh验证脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  --quick        快速验证模式（只检查关键功能）
  --full         完整验证模式（检查所有功能）

示例:
  $0
  $0 --quick
  $0 --full

EOF
}

# 主函数
main() {
    local mode="normal"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --quick)
                mode="quick"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "开始验证 verify-admin-comprehensive.sh 脚本"
    log_info "验证模式: $mode"
    
    # 执行测试
    log_info "执行验证测试..."
    
    # 基本测试（所有模式都执行）
    test_script_exists
    test_script_executable
    test_script_syntax
    test_help_function
    test_dry_run_mode
    
    if [ "$mode" = "quick" ]; then
        # 快速模式只检查基本功能
        test_script_functions
    elif [ "$mode" = "full" ] || [ "$mode" = "normal" ]; then
        # 完整/普通模式检查所有功能
        test_script_functions
        test_color_definitions
        test_log_functions
        test_test_functions
        test_cleanup_function
    fi
    
    # 显示验证结果
    echo ""
    echo "========================================"
    echo "验证完成摘要"
    echo "========================================"
    echo "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}跳过: $SKIP_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        log_success "所有验证通过！verify-admin-comprehensive.sh 脚本功能正常"
        exit 0
    else
        log_error "有 $FAIL_COUNT 个验证失败"
        log_info "建议修复失败的验证项"
        exit 1
    fi
}

# 运行主函数
main "$@"