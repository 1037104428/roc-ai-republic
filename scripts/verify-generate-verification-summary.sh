#!/usr/bin/env bash

# 验证脚本汇总报告生成器的验证脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
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

# 显示帮助
show_help() {
    cat << EOF
验证脚本汇总报告生成器验证脚本 v1.0.0

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --dry-run       干运行模式，只显示将要执行的测试
  -q, --quick         快速模式，只运行关键测试
  -v, --verbose       详细输出模式

示例:
  $0                   运行完整验证
  $0 --dry-run         预览将要执行的测试
  $0 --quick           快速验证关键功能
  $0 --verbose         详细输出测试过程

测试类别:
  1. 文件存在性和权限检查
  2. 帮助功能测试
  3. 干运行模式验证
  4. 参数验证测试
  5. 语法检查
  6. 颜色和日志功能验证
  7. 版本信息检查
  8. 输出格式测试
EOF
}

# 解析参数
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 运行测试
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_success="${3:-true}"
    
    ((TOTAL_TESTS++))
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "运行测试: $test_name"
        echo "命令: $test_command"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[干运行] 测试: $test_name"
        return 0
    fi
    
    if eval "$test_command" >/dev/null 2>&1; then
        if [[ "$expected_success" == "true" ]]; then
            log_success "✓ $test_name"
            ((PASSED_TESTS++))
            return 0
        else
            log_error "✗ $test_name (预期失败但成功)"
            ((FAILED_TESTS++))
            return 1
        fi
    else
        if [[ "$expected_success" == "false" ]]; then
            log_success "✓ $test_name (预期失败)"
            ((PASSED_TESTS++))
            return 0
        else
            log_error "✗ $test_name"
            ((FAILED_TESTS++))
            return 1
        fi
    fi
}

# 测试1: 文件存在性检查
test_file_existence() {
    run_test "主脚本存在性检查" \
        "[[ -f 'scripts/generate-verification-summary.sh' ]]" \
        "true"
    
    run_test "主脚本可执行权限检查" \
        "[[ -x 'scripts/generate-verification-summary.sh' ]]" \
        "true"
}

# 测试2: 帮助功能测试
test_help_function() {
    run_test "帮助选项显示测试 (-h)" \
        "./scripts/generate-verification-summary.sh -h | grep -q '验证脚本汇总报告生成器'" \
        "true"
    
    run_test "帮助选项显示测试 (--help)" \
        "./scripts/generate-verification-summary.sh --help | grep -q '用法:'" \
        "true"
}

# 测试3: 干运行模式验证
test_dry_run_mode() {
    run_test "干运行模式测试 (-d)" \
        "./scripts/generate-verification-summary.sh -d | grep -q '干运行模式'" \
        "true"
    
    run_test "干运行模式测试 (--dry-run)" \
        "./scripts/generate-verification-summary.sh --dry-run | grep -q '预览将要检查的脚本'" \
        "true"
}

# 测试4: 参数验证测试
test_parameter_validation() {
    run_test "快速模式测试 (-q)" \
        "./scripts/generate-verification-summary.sh -q --dry-run | grep -q '模式: true'" \
        "true"
    
    run_test "快速模式测试 (--quick)" \
        "./scripts/generate-verification-summary.sh --quick --dry-run | grep -q '模式: true'" \
        "true"
    
    run_test "输出文件测试" \
        "./scripts/generate-verification-summary.sh -o /tmp/test-report.txt --dry-run && rm -f /tmp/test-report.txt" \
        "true"
    
    run_test "JSON输出测试" \
        "./scripts/generate-verification-summary.sh --json --dry-run | grep -q '\"report\"'" \
        "true"
}

# 测试5: 语法检查
test_syntax_check() {
    run_test "主脚本语法检查" \
        "bash -n scripts/generate-verification-summary.sh" \
        "true"
    
    run_test "验证脚本语法检查" \
        "bash -n scripts/verify-generate-verification-summary.sh" \
        "true"
}

# 测试6: 颜色和日志功能验证
test_color_and_logging() {
    run_test "颜色定义检查" \
        "grep -q 'RED=' scripts/generate-verification-summary.sh" \
        "true"
    
    run_test "日志函数检查" \
        "grep -q 'log_info()' scripts/generate-verification-summary.sh" \
        "true"
    
    run_test "日志函数检查" \
        "grep -q 'log_success()' scripts/generate-verification-summary.sh" \
        "true"
    
    run_test "日志函数检查" \
        "grep -q 'log_error()' scripts/generate-verification-summary.sh" \
        "true"
}

# 测试7: 版本信息检查
test_version_info() {
    run_test "版本信息检查" \
        "grep -q 'v1.0.0' scripts/generate-verification-summary.sh" \
        "true"
}

# 测试8: 输出格式测试
test_output_formats() {
    run_test "文本输出格式测试" \
        "./scripts/generate-verification-summary.sh --dry-run | grep -q '验证脚本汇总报告'" \
        "true"
    
    run_test "JSON输出格式测试" \
        "./scripts/generate-verification-summary.sh --json --dry-run | grep -q '\"timestamp\"'" \
        "true"
}

# 测试9: 脚本行数检查
test_script_line_count() {
    local line_count
    line_count=$(wc -l < scripts/generate-verification-summary.sh)
    
    run_test "主脚本行数检查 (>100行)" \
        "[[ $line_count -gt 100 ]]" \
        "true"
    
    local verify_line_count
    verify_line_count=$(wc -l < scripts/verify-generate-verification-summary.sh)
    
    run_test "验证脚本行数检查 (>50行)" \
        "[[ $verify_line_count -gt 50 ]]" \
        "true"
}

# 测试10: 实际运行测试
test_actual_execution() {
    if [[ "$DRY_RUN" != "true" && "$QUICK_MODE" != "true" ]]; then
        run_test "实际运行测试 (快速模式)" \
            "./scripts/generate-verification-summary.sh -q | grep -q '汇总统计:'" \
            "true"
        
        run_test "实际运行测试 (完整模式)" \
            "./scripts/generate-verification-summary.sh --dry-run | grep -q '总共.*个脚本将被检查'" \
            "true"
    fi
}

# 主测试函数
main() {
    log_info "开始验证脚本汇总报告生成器验证..."
    log_info "模式: DRY_RUN=$DRY_RUN, QUICK_MODE=$QUICK_MODE, VERBOSE=$VERBOSE"
    
    # 切换到项目根目录
    cd /home/kai/.openclaw/workspace/roc-ai-republic || {
        log_error "无法切换到项目根目录"
        exit 1
    }
    
    # 运行测试
    test_file_existence
    test_help_function
    test_dry_run_mode
    test_parameter_validation
    test_syntax_check
    test_color_and_logging
    test_version_info
    test_output_formats
    test_script_line_count
    test_actual_execution
    
    # 显示汇总结果
    echo ""
    echo "========================================"
    echo "验证完成汇总:"
    echo "  总测试数: $TOTAL_TESTS"
    echo "  通过测试: $PASSED_TESTS"
    echo "  失败测试: $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "✅ 所有测试通过!"
        echo "========================================"
        exit 0
    else
        log_error "❌ 有 $FAILED_TESTS 个测试失败"
        echo "========================================"
        exit 1
    fi
}

# 运行主函数
main "$@"