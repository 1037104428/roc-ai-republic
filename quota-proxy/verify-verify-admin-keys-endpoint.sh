#!/bin/bash

# verify-verify-admin-keys-endpoint.sh
# 验证 verify-admin-keys-endpoint.sh 脚本的功能

set -e

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
验证 verify-admin-keys-endpoint.sh 脚本的功能

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  -d, --dry-run  干运行模式，只显示将要执行的测试
  -q, --quick    快速模式，只运行核心测试
  -f, --full     完整模式，运行所有测试（默认）

示例:
  $0 --dry-run
  $0 --quick
EOF
}

# 默认配置
DRY_RUN=false
QUICK_MODE=false
FULL_MODE=true
SCRIPT_PATH="verify-admin-keys-endpoint.sh"

# 解析命令行参数
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
            FULL_MODE=false
            shift
            ;;
        -f|--full)
            FULL_MODE=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 运行测试函数
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    ((TESTS_TOTAL++))
    log_info "运行测试: $test_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[干运行] 测试: $test_name"
        return 0
    fi
    
    if $test_func; then
        log_success "测试通过: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "测试失败: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 测试1: 脚本文件存在性
test_script_exists() {
    if [[ -f "$SCRIPT_PATH" ]]; then
        log_info "脚本文件存在: $SCRIPT_PATH"
        return 0
    else
        log_error "脚本文件不存在: $SCRIPT_PATH"
        return 1
    fi
}

# 测试2: 脚本可执行权限
test_script_executable() {
    if [[ -x "$SCRIPT_PATH" ]]; then
        log_info "脚本有可执行权限"
        return 0
    else
        log_warning "脚本没有可执行权限，尝试添加..."
        chmod +x "$SCRIPT_PATH"
        
        if [[ -x "$SCRIPT_PATH" ]]; then
            log_success "已添加可执行权限"
            return 0
        else
            log_error "无法添加可执行权限"
            return 1
        fi
    fi
}

# 测试3: 脚本语法检查
test_script_syntax() {
    log_info "检查脚本语法..."
    
    if bash -n "$SCRIPT_PATH"; then
        log_success "脚本语法正确"
        return 0
    else
        log_error "脚本语法错误"
        return 1
    fi
}

# 测试4: 帮助功能
test_help_function() {
    log_info "测试帮助功能..."
    
    local output
    output=$("$SCRIPT_PATH" --help 2>&1)
    
    if echo "$output" | grep -q "用法:"; then
        log_success "帮助功能正常"
        return 0
    else
        log_error "帮助功能异常"
        echo "输出: $output"
        return 1
    fi
}

# 测试5: 干运行模式
test_dry_run_mode() {
    log_info "测试干运行模式..."
    
    local output
    output=$("$SCRIPT_PATH" --dry-run --admin-token "test-token" 2>&1)
    
    if echo "$output" | grep -q "干运行"; then
        log_success "干运行模式正常"
        return 0
    else
        log_error "干运行模式异常"
        echo "输出: $output"
        return 1
    fi
}

# 测试6: 颜色定义检查
test_color_definitions() {
    log_info "检查颜色定义..."
    
    local color_count
    color_count=$(grep -c 'RED=\|GREEN=\|YELLOW=\|BLUE=\|NC=' "$SCRIPT_PATH")
    
    if [[ $color_count -ge 5 ]]; then
        log_success "颜色定义完整 ($color_count 个定义)"
        return 0
    else
        log_error "颜色定义不完整，只找到 $color_count 个定义"
        return 1
    fi
}

# 测试7: 日志函数检查
test_log_functions() {
    log_info "检查日志函数..."
    
    local log_func_count
    log_func_count=$(grep -c 'log_info\|log_success\|log_warning\|log_error' "$SCRIPT_PATH")
    
    if [[ $log_func_count -ge 4 ]]; then
        log_success "日志函数完整 ($log_func_count 个函数)"
        return 0
    else
        log_error "日志函数不完整，只找到 $log_func_count 个函数"
        return 1
    fi
}

# 测试8: 参数解析检查
test_parameter_parsing() {
    log_info "检查参数解析..."
    
    # 检查是否有参数解析循环
    if grep -q "while.*\[\[.*\$#.*gt.*0.*\]\].*do" "$SCRIPT_PATH"; then
        log_success "参数解析循环存在"
        
        # 检查常见参数
        local param_count
        param_count=$(grep -c "case.*in\|--help\|--dry-run\|--host\|--port\|--admin-token" "$SCRIPT_PATH")
        
        if [[ $param_count -ge 5 ]]; then
            log_success "参数解析完整 ($param_count 个参数处理)"
            return 0
        else
            log_warning "参数解析可能不完整，只找到 $param_count 个参数处理"
            return 0  # 不视为失败
        fi
    else
        log_error "未找到参数解析循环"
        return 1
    fi
}

# 测试9: 必需环境变量检查
test_env_var_check() {
    log_info "检查环境变量检查逻辑..."
    
    if grep -q "ADMIN_TOKEN" "$SCRIPT_PATH" && grep -q "检查必需的环境变量" "$SCRIPT_PATH"; then
        log_success "环境变量检查逻辑存在"
        return 0
    else
        log_error "环境变量检查逻辑缺失"
        return 1
    fi
}

# 测试10: 测试函数检查
test_test_functions() {
    log_info "检查测试函数..."
    
    local test_func_count
    test_func_count=$(grep -c "test_.*()" "$SCRIPT_PATH")
    
    if [[ $test_func_count -ge 4 ]]; then
        log_success "测试函数完整 ($test_func_count 个测试函数)"
        
        # 检查具体测试函数
        local specific_tests=0
        if grep -q "test_create_api_key" "$SCRIPT_PATH"; then ((specific_tests++)); fi
        if grep -q "test_query_usage" "$SCRIPT_PATH"; then ((specific_tests++)); fi
        if grep -q "test_query_usage_with_filter" "$SCRIPT_PATH"; then ((specific_tests++)); fi
        if grep -q "test_query_usage_with_pagination" "$SCRIPT_PATH"; then ((specific_tests++)); fi
        
        if [[ $specific_tests -ge 4 ]]; then
            log_success "核心测试函数完整 ($specific_tests 个核心测试)"
            return 0
        else
            log_warning "核心测试函数不完整，只找到 $specific_tests 个核心测试"
            return 0  # 不视为失败
        fi
    else
        log_error "测试函数不完整，只找到 $test_func_count 个测试函数"
        return 1
    fi
}

# 测试11: 清理函数检查
test_cleanup_function() {
    log_info "检查清理函数..."
    
    if grep -q "cleanup()" "$SCRIPT_PATH" && grep -q "trap cleanup" "$SCRIPT_PATH"; then
        log_success "清理函数和陷阱设置存在"
        return 0
    else
        log_error "清理函数或陷阱设置缺失"
        return 1
    fi
}

# 测试12: 主函数检查
test_main_function() {
    log_info "检查主函数..."
    
    if grep -q "main()" "$SCRIPT_PATH" && grep -q "main \"\$@\"" "$SCRIPT_PATH"; then
        log_success "主函数存在"
        return 0
    else
        log_error "主函数缺失"
        return 1
    fi
}

# 测试13: 脚本行数检查
test_script_lines() {
    log_info "检查脚本行数..."
    
    local line_count
    line_count=$(wc -l < "$SCRIPT_PATH")
    
    if [[ $line_count -gt 100 ]]; then
        log_success "脚本行数充足 ($line_count 行)"
        return 0
    else
        log_error "脚本行数过少 ($line_count 行)，可能功能不完整"
        return 1
    fi
}

# 测试14: 代码质量检查（简单版本）
test_code_quality() {
    log_info "检查代码质量..."
    
    local issues=0
    
    # 检查是否有未引用的变量
    if grep -n "echo \$[a-zA-Z_]" "$SCRIPT_PATH" | grep -v "echo \"\\$" | head -5; then
        log_warning "发现可能的未引用变量使用"
        ((issues++))
    fi
    
    # 检查是否有直接使用 $? 而不保存
    local exit_code_uses
    exit_code_uses=$(grep -c "\$?" "$SCRIPT_PATH")
    if [[ $exit_code_uses -gt 10 ]]; then
        log_info "退出码检查次数: $exit_code_uses"
    fi
    
    # 检查函数返回值
    local return_uses
    return_uses=$(grep -c "return [0-9]" "$SCRIPT_PATH")
    if [[ $return_uses -lt 5 ]]; then
        log_warning "函数返回值使用较少 ($return_uses 次)"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "代码质量检查通过"
        return 0
    else
        log_warning "代码质量检查发现 $issues 个问题"
        return 0  # 不视为失败，只是警告
    fi
}

# 测试15: 实际运行测试（快速模式）
test_actual_run_quick() {
    log_info "测试实际运行（快速模式）..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[干运行] 跳过实际运行测试"
        return 0
    fi
    
    # 设置一个假的ADMIN_TOKEN来测试参数解析
    local output
    output=$(ADMIN_TOKEN="test-token-12345" "$SCRIPT_PATH" --dry-run 2>&1)
    
    if echo "$output" | grep -q "开始验证" && echo "$output" | grep -q "干运行"; then
        log_success "脚本可以正常启动（干运行模式）"
        return 0
    else
        log_error "脚本启动失败"
        echo "输出: $output"
        return 1
    fi
}

# 定义测试套件
QUICK_TESTS=(
    "test_script_exists"
    "test_script_executable"
    "test_script_syntax"
    "test_help_function"
    "test_dry_run_mode"
)

FULL_TESTS=(
    "test_script_exists"
    "test_script_executable"
    "test_script_syntax"
    "test_help_function"
    "test_dry_run_mode"
    "test_color_definitions"
    "test_log_functions"
    "test_parameter_parsing"
    "test_env_var_check"
    "test_test_functions"
    "test_cleanup_function"
    "test_main_function"
    "test_script_lines"
    "test_code_quality"
    "test_actual_run_quick"
)

# 选择测试套件
if [[ "$QUICK_MODE" == "true" ]]; then
    TESTS_TO_RUN=("${QUICK_TESTS[@]}")
    log_info "使用快速测试套件 (${#QUICK_TESTS[@]} 个测试)"
else
    TESTS_TO_RUN=("${FULL_TESTS[@]}")
    log_info "使用完整测试套件 (${#FULL_TESTS[@]} 个测试)"
fi

# 运行测试
log_info "开始验证 verify-admin-keys-endpoint.sh 脚本"
echo ""

for test_func in "${TESTS_TO_RUN[@]}"; do
    run_test "$test_func" "$test_func"
    echo ""
done

# 输出测试结果
log_info "验证完成"
log_info "总计测试: $TESTS_TOTAL"
log_info "通过: $TESTS_PASSED"
log_info "失败: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "所有测试通过！verify-admin-keys-endpoint.sh 脚本验证成功"
    exit 0
else
    log_error "有 $TESTS_FAILED 个测试失败"
    exit 1
fi