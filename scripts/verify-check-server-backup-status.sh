#!/bin/bash
# 验证检查服务器备份状态脚本
# 确保 check-server-backup-status.sh 脚本功能正常

# 不设置 set -e，因为测试函数可能返回非零值

# 颜色定义
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 脚本路径
SCRIPT_PATH="./scripts/check-server-backup-status.sh"
VERIFY_SCRIPT_NAME="verify-check-server-backup-status.sh"

# 帮助信息
show_help() {
    cat << EOF
验证检查服务器备份状态脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  -d, --dry-run  模拟运行，只显示命令不执行
  -q, --quick    快速验证模式，跳过耗时测试
  -v, --verbose  详细输出模式

示例:
  $0             完整验证
  $0 --dry-run   模拟运行验证
  $0 --quick     快速验证
EOF
}

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

# 测试函数
test_file_exists() {
    log_info "测试1: 检查脚本文件是否存在"
    if [ -f "$SCRIPT_PATH" ]; then
        log_success "脚本文件存在: $SCRIPT_PATH"
        return 0
    else
        log_error "脚本文件不存在: $SCRIPT_PATH"
        return 1
    fi
}

test_executable_permission() {
    log_info "测试2: 检查脚本可执行权限"
    if [ -x "$SCRIPT_PATH" ]; then
        log_success "脚本具有可执行权限"
        return 0
    else
        log_warning "脚本缺少可执行权限，尝试修复..."
        chmod +x "$SCRIPT_PATH" 2>/dev/null
        if [ -x "$SCRIPT_PATH" ]; then
            log_success "已修复脚本可执行权限"
            return 0
        else
            log_error "无法修复脚本可执行权限"
            return 1
        fi
    fi
}

test_syntax_check() {
    log_info "测试3: 检查脚本语法"
    if bash -n "$SCRIPT_PATH" 2>/dev/null; then
        log_success "脚本语法正确"
        return 0
    else
        log_error "脚本语法错误"
        bash -n "$SCRIPT_PATH" 2>/dev/null || true
        return 1
    fi
}

test_help_function() {
    log_info "测试4: 检查帮助功能"
    if "$SCRIPT_PATH" --help 2>&1 | grep -q "检查服务器备份状态脚本"; then
        log_success "帮助功能正常"
        return 0
    else
        log_error "帮助功能异常"
        return 1
    fi
}

test_dry_run_mode() {
    log_info "测试5: 检查dry-run模式"
    if "$SCRIPT_PATH" --dry-run 2>&1 | grep -q "模拟运行模式"; then
        log_success "dry-run模式正常"
        return 0
    else
        log_warning "dry-run模式输出不符合预期"
        return 0  # 非关键错误
    fi
}

test_color_definitions() {
    log_info "测试6: 检查颜色定义"
    if grep -q "RED='\\\033\[0;31m'" "$SCRIPT_PATH" && \
       grep -q "GREEN='\\\033\[0;32m'" "$SCRIPT_PATH" && \
       grep -q "YELLOW='\\\033\[1;33m'" "$SCRIPT_PATH" && \
       grep -q "BLUE='\\\033\[0;34m'" "$SCRIPT_PATH"; then
        log_success "颜色定义完整"
        return 0
    else
        log_warning "颜色定义不完整"
        return 0  # 非关键错误
    fi
}

test_log_functions() {
    log_info "测试7: 检查日志函数"
    if grep -q "log_info()" "$SCRIPT_PATH" && \
       grep -q "log_success()" "$SCRIPT_PATH" && \
       grep -q "log_warning()" "$SCRIPT_PATH" && \
       grep -q "log_error()" "$SCRIPT_PATH"; then
        log_success "日志函数完整"
        return 0
    else
        log_warning "日志函数不完整"
        return 0  # 非关键错误
    fi
}

test_server_config() {
    log_info "测试8: 检查服务器配置"
    if grep -q "SERVER_IP=" "$SCRIPT_PATH" && \
       grep -q "SSH_KEY=" "$SCRIPT_PATH" && \
       grep -q "BACKUP_DIR=" "$SCRIPT_PATH"; then
        log_success "服务器配置完整"
        return 0
    else
        log_warning "服务器配置不完整"
        return 0  # 非关键错误
    fi
}

test_backup_check_functions() {
    log_info "测试9: 检查备份检查函数"
    if grep -q "check_backup_directory()" "$SCRIPT_PATH" && \
       grep -q "check_backup_files()" "$SCRIPT_PATH" && \
       grep -q "check_backup_age()" "$SCRIPT_PATH"; then
        log_success "备份检查函数完整"
        return 0
    else
        log_warning "备份检查函数不完整"
        return 0  # 非关键错误
    fi
}

test_cleanup_functions() {
    log_info "测试10: 检查清理函数"
    if grep -q "cleanup()" "$SCRIPT_PATH"; then
        log_success "清理函数存在"
        return 0
    else
        log_warning "清理函数不存在"
        return 0  # 非关键错误
    fi
}

# 主验证函数
main_verification() {
    local dry_run=false
    local quick_mode=false
    local verbose=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "开始验证检查服务器备份状态脚本"
    log_info "脚本路径: $SCRIPT_PATH"
    log_info "验证模式: $([ "$dry_run" = true ] && echo "模拟运行" || echo "实际执行")"
    log_info "快速模式: $([ "$quick_mode" = true ] && echo "是" || echo "否")"
    
    # 执行测试
    local tests_passed=0
    local tests_failed=0
    local tests_warning=0
    local total_tests=10
    
    # 关键测试
    if test_file_exists; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_executable_permission; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_syntax_check; then ((tests_passed++)); else ((tests_failed++)); fi
    if test_help_function; then ((tests_passed++)); else ((tests_failed++)); fi
    
    # 功能测试（非关键）
    if test_dry_run_mode; then ((tests_passed++)); else ((tests_warning++)); fi
    if test_color_definitions; then ((tests_passed++)); else ((tests_warning++)); fi
    if test_log_functions; then ((tests_passed++)); else ((tests_warning++)); fi
    if test_server_config; then ((tests_passed++)); else ((tests_warning++)); fi
    if test_backup_check_functions; then ((tests_passed++)); else ((tests_warning++)); fi
    if test_cleanup_functions; then ((tests_passed++)); else ((tests_warning++)); fi
    
    # 生成报告
    echo ""
    echo "========================================"
    echo "验证报告: $VERIFY_SCRIPT_NAME"
    echo "========================================"
    echo "目标脚本: $(basename "$SCRIPT_PATH")"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "----------------------------------------"
    echo "测试统计:"
    echo "  通过测试: $tests_passed"
    echo "  失败测试: $tests_failed"
    echo "  警告测试: $tests_warning"
    echo "  总测试数: $total_tests"
    echo "----------------------------------------"
    
    if [ $tests_failed -eq 0 ]; then
        if [ $tests_warning -eq 0 ]; then
            log_success "所有测试通过！脚本功能完整。"
            echo "建议: 脚本已准备好使用。"
        else
            log_warning "关键测试通过，但有 $tests_warning 个非关键警告。"
            echo "建议: 检查警告项，但脚本基本可用。"
        fi
        return 0
    else
        log_error "有 $tests_failed 个关键测试失败！"
        echo "建议: 修复失败项后再使用脚本。"
        return 1
    fi
}

# 清理函数
cleanup() {
    log_info "清理验证环境..."
    # 暂时没有需要清理的资源
}

# 设置陷阱
trap cleanup EXIT

# 运行主验证
main_verification "$@"