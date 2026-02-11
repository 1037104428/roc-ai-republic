#!/bin/bash
# verify-request-trial-key.sh - 验证 TRIAL_KEY 申请脚本
# 版本: 2026.02.11.1603

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 日志函数
log_test() {
    local test_num=$1
    local description=$2
    local status=$3
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}[✓]${NC} 测试 $test_num: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[✗]${NC} 测试 $test_num: $description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理函数
cleanup() {
    log_info "清理测试文件..."
    rm -f test_output.txt test_error.txt
}

# 设置陷阱
trap cleanup EXIT

# 测试 1: 检查脚本文件存在性
test_1() {
    local script_path="scripts/request-trial-key.sh"
    
    if [[ -f "$script_path" ]]; then
        log_test "1.1" "脚本文件存在" "PASS"
    else
        log_test "1.1" "脚本文件存在" "FAIL"
        return 1
    fi
    
    if [[ -x "$script_path" ]]; then
        log_test "1.2" "脚本有执行权限" "PASS"
    else
        log_test "1.2" "脚本有执行权限" "FAIL"
        return 1
    fi
    
    return 0
}

# 测试 2: 检查帮助功能
test_2() {
    log_info "测试帮助功能..."
    
    if ./scripts/request-trial-key.sh --help 2>&1 | grep -q "TRIAL_KEY 申请脚本"; then
        log_test "2.1" "帮助信息包含标题" "PASS"
    else
        log_test "2.1" "帮助信息包含标题" "FAIL"
    fi
    
    if ./scripts/request-trial-key.sh --help 2>&1 | grep -q "用途：通过命令行快速申请 quota-proxy 试用密钥"; then
        log_test "2.2" "帮助信息包含用途描述" "PASS"
    else
        log_test "2.2" "帮助信息包含用途描述" "FAIL"
    fi
    
    if ./scripts/request-trial-key.sh --help 2>&1 | grep -q "示例："; then
        log_test "2.3" "帮助信息包含示例" "PASS"
    else
        log_test "2.3" "帮助信息包含示例" "FAIL"
    fi
    
    return 0
}

# 测试 3: 检查干运行模式
test_3() {
    log_info "测试干运行模式..."
    
    # 测试干运行模式
    local output
    output=$(./scripts/request-trial-key.sh --dry-run --token "test_token" --email "test@example.com" 2>&1)
    
    if echo "$output" | grep -q "干运行模式 - 只显示命令，不实际执行"; then
        log_test "3.1" "干运行模式提示正确" "PASS"
    else
        log_test "3.1" "干运行模式提示正确" "FAIL"
    fi
    
    if echo "$output" | grep -q "将执行的 curl 命令:"; then
        log_test "3.2" "干运行显示curl命令" "PASS"
    else
        log_test "3.2" "干运行显示curl命令" "FAIL"
    fi
    
    if echo "$output" | grep -q "curl -X POST"; then
        log_test "3.3" "干运行包含POST请求" "PASS"
    else
        log_test "3.3" "干运行包含POST请求" "FAIL"
    fi
    
    return 0
}

# 测试 4: 检查参数验证
test_4() {
    log_info "测试参数验证..."
    
    # 测试缺少令牌的情况
    local output
    output=$(./scripts/request-trial-key.sh --email "test@example.com" 2>&1)
    
    if echo "$output" | grep -q "管理员令牌未提供"; then
        log_test "4.1" "缺少令牌时显示错误" "PASS"
    else
        log_test "4.1" "缺少令牌时显示错误" "FAIL"
    fi
    
    # 测试无效参数
    output=$(./scripts/request-trial-key.sh --invalid-param 2>&1)
    
    if echo "$output" | grep -q "未知参数"; then
        log_test "4.2" "无效参数时显示错误" "PASS"
    else
        log_test "4.2" "无效参数时显示错误" "FAIL"
    fi
    
    return 0
}

# 测试 5: 检查脚本语法
test_5() {
    log_info "测试脚本语法..."
    
    if bash -n scripts/request-trial-key.sh 2>&1; then
        log_test "5.1" "脚本语法正确" "PASS"
    else
        log_test "5.1" "脚本语法正确" "FAIL"
        return 1
    fi
    
    # 检查脚本行数（确保不是空脚本）
    local line_count
    line_count=$(wc -l < scripts/request-trial-key.sh)
    
    if [[ $line_count -gt 50 ]]; then
        log_test "5.2" "脚本有足够的内容（$line_count 行）" "PASS"
    else
        log_test "5.2" "脚本有足够的内容（$line_count 行）" "FAIL"
    fi
    
    return 0
}

# 测试 6: 检查颜色定义
test_6() {
    log_info "测试颜色定义..."
    
    if grep -q "RED='\\033\[0;31m'" scripts/request-trial-key.sh; then
        log_test "6.1" "红色颜色定义存在" "PASS"
    else
        log_test "6.1" "红色颜色定义存在" "FAIL"
    fi
    
    if grep -q "GREEN='\\033\[0;32m'" scripts/request-trial-key.sh; then
        log_test "6.2" "绿色颜色定义存在" "PASS"
    else
        log_test "6.2" "绿色颜色定义存在" "FAIL"
    fi
    
    if grep -q "BLUE='\\033\[0;34m'" scripts/request-trial-key.sh; then
        log_test "6.3" "蓝色颜色定义存在" "PASS"
    else
        log_test "6.3" "蓝色颜色定义存在" "FAIL"
    fi
    
    if grep -q "NC='\\033\[0m'" scripts/request-trial-key.sh; then
        log_test "6.4" "无色定义存在" "PASS"
    else
        log_test "6.4" "无色定义存在" "FAIL"
    fi
    
    return 0
}

# 测试 7: 检查日志函数
test_7() {
    log_info "测试日志函数..."
    
    if grep -q "log_info()" scripts/request-trial-key.sh; then
        log_test "7.1" "log_info函数存在" "PASS"
    else
        log_test "7.1" "log_info函数存在" "FAIL"
    fi
    
    if grep -q "log_success()" scripts/request-trial-key.sh; then
        log_test "7.2" "log_success函数存在" "PASS"
    else
        log_test "7.2" "log_success函数存在" "FAIL"
    fi
    
    if grep -q "log_error()" scripts/request-trial-key.sh; then
        log_test "7.3" "log_error函数存在" "PASS"
    else
        log_test "7.3" "log_error函数存在" "FAIL"
    fi
    
    if grep -q "log_warning()" scripts/request-trial-key.sh; then
        log_test "7.4" "log_warning函数存在" "PASS"
    else
        log_test "7.4" "log_warning函数存在" "FAIL"
    fi
    
    return 0
}

# 测试 8: 检查版本信息
test_8() {
    log_info "测试版本信息..."
    
    if grep -q "# 版本:" scripts/request-trial-key.sh; then
        log_test "8.1" "版本注释存在" "PASS"
    else
        log_test "8.1" "版本注释存在" "FAIL"
    fi
    
    if grep -q "2026.02" scripts/request-trial-key.sh; then
        log_test "8.2" "版本日期格式正确" "PASS"
    else
        log_test "8.2" "版本日期格式正确" "FAIL"
    fi
    
    return 0
}

# 主测试函数
main() {
    echo "════════════════════════════════════════════════════════════════"
    echo "  验证 TRIAL_KEY 申请脚本 - request-trial-key.sh"
    echo "  开始时间: $(date)"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # 运行所有测试
    test_1
    test_2
    test_3
    test_4
    test_5
    test_6
    test_7
    test_8
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  测试结果汇总"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # 显示测试结果
    echo "总测试数: $TESTS_TOTAL"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo ""
    
    # 计算通过率
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo "通过率: $pass_rate%"
    fi
    
    # 最终结果
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "所有测试通过！TRIAL_KEY 申请脚本验证成功。"
        echo ""
        echo "脚本功能："
        echo "  ✓ 文件存在且可执行"
        echo "  ✓ 帮助功能完整"
        echo "  ✓ 干运行模式正常"
        echo "  ✓ 参数验证正确"
        echo "  ✓ 语法正确"
        echo "  ✓ 颜色和日志功能完整"
        echo "  ✓ 版本信息完整"
        echo ""
        echo "使用示例："
        echo "  ./scripts/request-trial-key.sh --help"
        echo "  ./scripts/request-trial-key.sh --dry-run --token \"admin_token\""
        echo ""
        return 0
    else
        log_error "有 $TESTS_FAILED 个测试失败，请检查脚本。"
        echo ""
        echo "建议："
        echo "  1. 检查脚本文件权限：chmod +x scripts/request-trial-key.sh"
        echo "  2. 检查脚本语法：bash -n scripts/request-trial-key.sh"
        echo "  3. 查看详细错误信息"
        echo ""
        return 1
    fi
}

# 运行主函数
main "$@"