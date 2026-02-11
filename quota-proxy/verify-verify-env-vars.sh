#!/bin/bash
# verify-verify-env-vars.sh - 验证环境变量验证脚本
# 用于验证verify-env-vars.sh脚本的功能完整性
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

# 测试计数器
total_tests=0
passed_tests=0
failed_tests=0

# 运行测试并检查结果
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    local expected_output_pattern="${4:-}"
    
    ((total_tests++))
    
    log_info "运行测试: $test_name"
    
    # 执行命令
    local output
    local exit_code
    output=$(eval "$command" 2>&1) || true
    exit_code=$?
    
    # 检查退出码
    if [[ "$exit_code" -ne "$expected_exit_code" ]]; then
        log_error "测试失败: 退出码 $exit_code (期望 $expected_exit_code)"
        log_error "命令输出: $output"
        ((failed_tests++))
        return 1
    fi
    
    # 检查输出模式（如果提供）
    if [[ -n "$expected_output_pattern" ]]; then
        if ! echo "$output" | grep -q "$expected_output_pattern"; then
            log_error "测试失败: 输出不匹配模式 '$expected_output_pattern'"
            log_error "实际输出: $output"
            ((failed_tests++))
            return 1
        fi
    fi
    
    log_success "测试通过: $test_name"
    ((passed_tests++))
    return 0
}

# 清理函数
cleanup() {
    # 清理测试环境变量
    unset DATABASE_URL ADMIN_TOKEN PORT LOG_LEVEL CORS_ORIGIN RATE_LIMIT_PER_MINUTE MAX_REQUEST_SIZE_MB 2>/dev/null || true
}

# 主函数
main() {
    log_info "开始验证 verify-env-vars.sh 脚本"
    log_info "当前目录: $(pwd)"
    log_info "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    # 测试1: 检查脚本文件存在性
    run_test "脚本文件存在性检查" \
        "test -f ./verify-env-vars.sh" \
        0
    
    # 测试2: 检查脚本可执行权限
    run_test "脚本可执行权限检查" \
        "test -x ./verify-env-vars.sh" \
        0
    
    # 测试3: 检查脚本语法
    run_test "脚本语法检查" \
        "bash -n ./verify-env-vars.sh" \
        0
    
    # 测试4: 检查帮助功能
    run_test "帮助功能检查" \
        "./verify-env-vars.sh --help" \
        0 \
        "环境变量验证脚本"
    
    # 测试5: 检查干运行模式
    run_test "干运行模式检查" \
        "./verify-env-vars.sh --dry-run" \
        0 \
        "干运行模式"
    
    # 测试6: 检查必需环境变量缺失情况
    cleanup
    run_test "必需环境变量缺失检查" \
        "./verify-env-vars.sh --quick 2>&1" \
        1 \
        "必需环境变量检查失败"
    
    # 测试7: 检查必需环境变量完整情况
    cleanup
    export DATABASE_URL="sqlite:///test.db"
    export ADMIN_TOKEN="test_admin_token_1234567890"
    export PORT="8787"
    run_test "必需环境变量完整检查" \
        "./verify-env-vars.sh --quick 2>&1" \
        0 \
        "所有必需环境变量检查通过"
    
    # 测试8: 检查端口配置验证
    cleanup
    export DATABASE_URL="sqlite:///test.db"
    export ADMIN_TOKEN="test_admin_token_1234567890"
    export PORT="invalid"
    run_test "端口配置验证检查" \
        "./verify-env-vars.sh --quick 2>&1" \
        1 \
        "PORT必须是数字"
    
    # 测试9: 检查数据库URL格式验证
    cleanup
    export DATABASE_URL="invalid://format"
    export ADMIN_TOKEN="test_admin_token_1234567890"
    export PORT="8787"
    run_test "数据库URL格式验证检查" \
        "./verify-env-vars.sh --quick 2>&1" \
        0 \
        "未知的数据库URL格式"
    
    # 测试10: 检查管理员令牌长度验证
    cleanup
    export DATABASE_URL="sqlite:///test.db"
    export ADMIN_TOKEN="short"
    export PORT="8787"
    run_test "管理员令牌长度验证检查" \
        "./verify-env-vars.sh --quick 2>&1" \
        0 \
        "管理员令牌较短"
    
    # 测试11: 检查完整模式
    cleanup
    export DATABASE_URL="sqlite:///test.db"
    export ADMIN_TOKEN="test_admin_token_1234567890"
    export PORT="8787"
    export LOG_LEVEL="info"
    export CORS_ORIGIN="*"
    export RATE_LIMIT_PER_MINUTE="60"
    export MAX_REQUEST_SIZE_MB="10"
    run_test "完整模式检查" \
        "./verify-env-vars.sh 2>&1" \
        0 \
        "环境变量验证完成"
    
    # 测试12: 检查详细输出模式
    run_test "详细输出模式检查" \
        "./verify-env-vars.sh --verbose 2>&1" \
        0 \
        "环境变量已设置: DATABASE_URL"
    
    # 测试13: 检查脚本行数（基本完整性）
    run_test "脚本行数检查" \
        "wc -l < ./verify-env-vars.sh | awk '{print \$1 > 100}'" \
        0
    
    # 测试14: 检查颜色定义存在
    run_test "颜色定义检查" \
        "grep -q 'RED=' ./verify-env-vars.sh && grep -q 'GREEN=' ./verify-env-vars.sh && grep -q 'YELLOW=' ./verify-env-vars.sh && grep -q 'BLUE=' ./verify-env-vars.sh" \
        0
    
    # 测试15: 检查日志函数存在
    run_test "日志函数检查" \
        "grep -q 'log_info()' ./verify-env-vars.sh && grep -q 'log_success()' ./verify-env-vars.sh && grep -q 'log_warning()' ./verify-env-vars.sh && grep -q 'log_error()' ./verify-env-vars.sh" \
        0
    
    # 测试16: 检查必需变量列表
    run_test "必需变量列表检查" \
        "grep -q 'REQUIRED_VARS=' ./verify-env-vars.sh && grep -q 'DATABASE_URL' ./verify-env-vars.sh && grep -q 'ADMIN_TOKEN' ./verify-env-vars.sh && grep -q 'PORT' ./verify-env-vars.sh" \
        0
    
    # 测试17: 检查推荐变量列表
    run_test "推荐变量列表检查" \
        "grep -q 'RECOMMENDED_VARS=' ./verify-env-vars.sh && grep -q 'LOG_LEVEL' ./verify-env-vars.sh && grep -q 'CORS_ORIGIN' ./verify-env-vars.sh" \
        0
    
    # 测试18: 检查特殊检查函数
    run_test "特殊检查函数检查" \
        "grep -q 'check_port_config()' ./verify-env-vars.sh && grep -q 'check_database_url()' ./verify-env-vars.sh && grep -q 'check_admin_token()' ./verify-env-vars.sh" \
        0
    
    # 测试19: 检查参数解析
    run_test "参数解析检查" \
        "grep -q '--help' ./verify-env-vars.sh && grep -q '--dry-run' ./verify-env-vars.sh && grep -q '--quick' ./verify-env-vars.sh && grep -q '--verbose' ./verify-env-vars.sh" \
        0
    
    # 测试20: 检查版本信息
    run_test "版本信息检查" \
        "grep -q '版本:' ./verify-env-vars.sh" \
        0
    
    echo ""
    log_info "=== 验证结果汇总 ==="
    log_info "总测试数: $total_tests"
    
    if [[ "$failed_tests" -eq 0 ]]; then
        log_success "通过测试: $passed_tests"
        log_success "所有测试通过 - verify-env-vars.sh 脚本功能完整"
    else
        log_error "通过测试: $passed_tests"
        log_error "失败测试: $failed_tests"
        log_error "部分测试失败 - 请检查 verify-env-vars.sh 脚本"
        return 1
    fi
    
    # 清理
    cleanup
    rm -f test.db 2>/dev/null || true
    
    return 0
}

# 运行主函数
main "$@"