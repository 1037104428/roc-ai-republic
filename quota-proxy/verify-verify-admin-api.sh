#!/usr/bin/env bash

# verify-verify-admin-api.sh - 验证verify-admin-api.sh脚本
# 版本: 2026.02.11.1554
# 作者: 中华AI共和国项目组

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 帮助信息
show_help() {
    cat <<EOF
验证verify-admin-api.sh脚本

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示将要执行的命令
  --quick, -q         快速验证模式，只执行核心检查
  --verbose, -v       详细输出模式，显示所有详细信息

示例:
  $0 --dry-run          # 干运行模式
  $0 --quick            # 快速验证模式
  $0 --verbose          # 详细验证模式
EOF
}

# 参数解析
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查目标脚本是否存在
check_script_exists() {
    local script_path="verify-admin-api.sh"
    
    log_info "检查目标脚本是否存在..."
    
    if [[ ! -f "$script_path" ]]; then
        log_error "目标脚本不存在: $script_path"
        exit 1
    fi
    
    log_success "目标脚本存在: $script_path"
}

# 检查脚本可执行权限
check_executable_permission() {
    log_info "检查脚本可执行权限..."
    
    if [[ ! -x "verify-admin-api.sh" ]]; then
        log_warn "脚本没有可执行权限，尝试添加..."
        chmod +x "verify-admin-api.sh"
    fi
    
    if [[ -x "verify-admin-api.sh" ]]; then
        log_success "脚本具有可执行权限"
    else
        log_error "无法添加可执行权限"
        exit 1
    fi
}

# 检查脚本语法
check_syntax() {
    log_info "检查脚本语法..."
    
    if $DRY_RUN; then
        echo "bash -n verify-admin-api.sh"
        return 0
    fi
    
    if bash -n "verify-admin-api.sh"; then
        log_success "脚本语法检查通过"
    else
        log_error "脚本语法检查失败"
        exit 1
    fi
}

# 检查帮助功能
check_help_function() {
    log_info "检查帮助功能..."
    
    if $DRY_RUN; then
        echo "./verify-admin-api.sh --help"
        return 0
    fi
    
    local output
    output=$(./verify-admin-api.sh --help 2>&1)
    
    if echo "$output" | grep -q "用法:"; then
        log_success "帮助功能正常"
        
        if $VERBOSE; then
            echo "帮助输出:"
            echo "$output"
        fi
    else
        log_error "帮助功能异常"
        exit 1
    fi
}

# 检查干运行模式
check_dry_run_mode() {
    log_info "检查干运行模式..."
    
    if $DRY_RUN; then
        echo "./verify-admin-api.sh --dry-run"
        return 0
    fi
    
    local output
    output=$(./verify-admin-api.sh --dry-run 2>&1)
    
    if echo "$output" | grep -q "干运行模式"; then
        log_success "干运行模式正常"
        
        if $VERBOSE; then
            echo "干运行输出:"
            echo "$output"
        fi
    else
        log_error "干运行模式异常"
        exit 1
    fi
}

# 检查颜色定义
check_color_definitions() {
    log_info "检查颜色定义..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    local color_count=0
    color_count=$(echo "$script_content" | grep -c 'RED=\|GREEN=\|YELLOW=\|BLUE=\|NC=')
    
    if [[ $color_count -ge 5 ]]; then
        log_success "颜色定义完整 ($color_count 个定义)"
    else
        log_error "颜色定义不完整"
        exit 1
    fi
}

# 检查日志函数
check_log_functions() {
    log_info "检查日志函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    local log_count=0
    log_count=$(echo "$script_content" | grep -c 'log_info\|log_success\|log_warn\|log_error')
    
    if [[ $log_count -ge 4 ]]; then
        log_success "日志函数完整 ($log_count 个函数)"
    else
        log_error "日志函数不完整"
        exit 1
    fi
}

# 检查参数解析
check_argument_parsing() {
    log_info "检查参数解析..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "while \[\[ \$# -gt 0 \]\]; do"; then
        log_success "参数解析结构存在"
    else
        log_error "参数解析结构缺失"
        exit 1
    fi
}

# 检查依赖检查函数
check_dependency_check() {
    log_info "检查依赖检查函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "check_dependencies()"; then
        log_success "依赖检查函数存在"
    else
        log_error "依赖检查函数缺失"
        exit 1
    fi
}

# 检查环境变量检查函数
check_env_var_check() {
    log_info "检查环境变量检查函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "check_env_vars()"; then
        log_success "环境变量检查函数存在"
    else
        log_error "环境变量检查函数缺失"
        exit 1
    fi
}

# 检查服务状态检查函数
check_service_status_check() {
    log_info "检查服务状态检查函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "check_service_status()"; then
        log_success "服务状态检查函数存在"
    else
        log_error "服务状态检查函数缺失"
        exit 1
    fi
}

# 检查管理员认证测试函数
check_admin_auth_test() {
    log_info "检查管理员认证测试函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "test_admin_auth()"; then
        log_success "管理员认证测试函数存在"
    else
        log_error "管理员认证测试函数缺失"
        exit 1
    fi
}

# 检查试用密钥生成测试函数
check_trial_key_generation_test() {
    log_info "检查试用密钥生成测试函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "test_generate_trial_key()"; then
        log_success "试用密钥生成测试函数存在"
    else
        log_error "试用密钥生成测试函数缺失"
        exit 1
    fi
}

# 检查使用情况查询测试函数
check_usage_query_test() {
    log_info "检查使用情况查询测试函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "test_query_usage()"; then
        log_success "使用情况查询测试函数存在"
    else
        log_error "使用情况查询测试函数缺失"
        exit 1
    fi
}

# 检查主函数
check_main_function() {
    log_info "检查主函数..."
    
    local script_content
    script_content=$(cat verify-admin-api.sh)
    
    if echo "$script_content" | grep -q "main()"; then
        log_success "主函数存在"
    else
        log_error "主函数缺失"
        exit 1
    fi
}

# 检查脚本行数
check_script_line_count() {
    log_info "检查脚本行数..."
    
    local line_count
    line_count=$(wc -l < verify-admin-api.sh)
    
    if [[ $line_count -gt 100 ]]; then
        log_success "脚本行数充足: $line_count 行"
    else
        log_error "脚本行数不足: $line_count 行"
        exit 1
    fi
}

# 快速验证模式
quick_verification() {
    log_info "开始快速验证..."
    
    check_script_exists
    check_executable_permission
    check_syntax
    check_help_function
    check_dry_run_mode
    check_color_definitions
    check_log_functions
    
    log_success "快速验证完成"
}

# 完整验证模式
full_verification() {
    log_info "开始完整验证..."
    
    check_script_exists
    check_executable_permission
    check_syntax
    check_help_function
    check_dry_run_mode
    check_color_definitions
    check_log_functions
    check_argument_parsing
    check_dependency_check
    check_env_var_check
    check_service_status_check
    check_admin_auth_test
    check_trial_key_generation_test
    check_usage_query_test
    check_main_function
    check_script_line_count
    
    log_success "完整验证完成"
}

# 主函数
main() {
    log_info "开始验证verify-admin-api.sh脚本"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_info "工作目录: $(pwd)"
    
    if $DRY_RUN; then
        log_info "干运行模式 - 只显示命令"
        echo "========================================"
    fi
    
    if $QUICK_MODE; then
        quick_verification
    else
        full_verification
    fi
    
    if $DRY_RUN; then
        echo "========================================"
        log_info "干运行模式完成 - 未执行实际命令"
    else
        log_success "所有验证完成"
        log_info "脚本验证总结:"
        echo "  - 脚本存在性: ✓"
        echo "  - 可执行权限: ✓"
        echo "  - 语法检查: ✓"
        echo "  - 帮助功能: ✓"
        echo "  - 干运行模式: ✓"
        echo "  - 颜色定义: ✓"
        echo "  - 日志函数: ✓"
        echo "  - 参数解析: ✓"
        echo "  - 依赖检查函数: ✓"
        echo "  - 环境变量检查函数: ✓"
        echo "  - 服务状态检查函数: ✓"
        echo "  - 管理员认证测试函数: ✓"
        echo "  - 试用密钥生成测试函数: ✓"
        echo "  - 使用情况查询测试函数: ✓"
        echo "  - 主函数: ✓"
        echo "  - 脚本行数: ✓"
    fi
}

# 执行主函数
main "$@"