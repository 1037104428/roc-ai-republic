#!/usr/bin/env bash
set -euo pipefail

# 验证install-cn.sh在不同执行模式下的行为
# 这是一个轻量级验证，专注于执行模式而非完整功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# 检查脚本是否存在
check_script_exists() {
    log_info "检查安装脚本是否存在..."
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        log_success "安装脚本存在: $INSTALL_SCRIPT"
        return 0
    else
        log_error "安装脚本不存在: $INSTALL_SCRIPT"
        return 1
    fi
}

# 检查脚本可执行权限
check_script_permissions() {
    log_info "检查安装脚本权限..."
    if [[ -x "$INSTALL_SCRIPT" ]]; then
        log_success "安装脚本可执行"
        return 0
    else
        log_warning "安装脚本不可执行，尝试修复..."
        chmod +x "$INSTALL_SCRIPT" 2>/dev/null || true
        if [[ -x "$INSTALL_SCRIPT" ]]; then
            log_success "已修复安装脚本权限"
            return 0
        else
            log_error "无法修复安装脚本权限"
            return 1
        fi
    fi
}

# 检查脚本语法
check_script_syntax() {
    log_info "检查安装脚本语法..."
    if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
        log_success "安装脚本语法正确"
        return 0
    else
        log_error "安装脚本语法错误"
        bash -n "$INSTALL_SCRIPT" 2>&1 | head -20
        return 1
    fi
}

# 测试帮助功能
test_help_function() {
    log_info "测试帮助功能..."
    local output
    output="$("$INSTALL_SCRIPT" --help 2>&1 || true)"
    
    if echo "$output" | grep -q "Usage:"; then
        log_success "帮助功能正常"
        echo "$output" | head -10
        return 0
    else
        log_warning "帮助功能可能有问题"
        echo "$output" | head -5
        return 1
    fi
}

# 测试版本信息
test_version_info() {
    log_info "测试版本信息..."
    local output
    output="$("$INSTALL_SCRIPT" --version 2>&1 || true)"
    
    if echo "$output" | grep -q "SCRIPT_VERSION="; then
        log_success "版本信息正常"
        echo "$output" | grep -E "SCRIPT_VERSION=|版本"
        return 0
    else
        log_warning "版本信息可能有问题"
        echo "$output" | head -3
        return 1
    fi
}

# 测试快速验证模式（dry-run）
test_quick_verify_dry_run() {
    log_info "测试快速验证模式（dry-run）..."
    local output
    output="$("$INSTALL_SCRIPT" --mode quick --dry-run 2>&1 || true)"
    
    if echo "$output" | grep -q "快速验证脚本"; then
        log_success "快速验证模式正常"
        echo "$output" | grep -E "快速验证|quick-verify" | head -3
        return 0
    else
        log_warning "快速验证模式可能有问题"
        echo "$output" | head -5
        return 1
    fi
}

# 测试基本验证模式
test_basic_verify_mode() {
    log_info "测试基本验证模式..."
    local output
    output="$("$INSTALL_SCRIPT" --mode basic --dry-run 2>&1 || true)"
    
    if echo "$output" | grep -q "openclaw --version"; then
        log_success "基本验证模式正常"
        echo "$output" | grep -E "openclaw|验证" | head -3
        return 0
    else
        log_warning "基本验证模式可能有问题"
        echo "$output" | head -5
        return 1
    fi
}

# 测试完整验证模式
test_full_verify_mode() {
    log_info "测试完整验证模式..."
    local output
    output="$("$INSTALL_SCRIPT" --mode full --dry-run 2>&1 || true)"
    
    if echo "$output" | grep -q "完整验证脚本"; then
        log_success "完整验证模式正常"
        echo "$output" | grep -E "完整验证|VERIFY_SCRIPT" | head -3
        return 0
    else
        log_warning "完整验证模式可能有问题"
        echo "$output" | head -5
        return 1
    fi
}

# 测试CI模式
test_ci_mode() {
    log_info "测试CI模式..."
    local output
    CI_MODE=1 SKIP_INTERACTIVE=1 output="$("$INSTALL_SCRIPT" --dry-run 2>&1 || true)"
    
    if echo "$output" | grep -q "CI_MODE=1"; then
        log_success "CI模式正常"
        echo "$output" | grep -E "CI_MODE|SKIP_INTERACTIVE" | head -3
        return 0
    else
        log_warning "CI模式可能有问题"
        echo "$output" | head -5
        return 1
    fi
}

# 主函数
main() {
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    log_info "开始验证install-cn.sh执行模式..."
    log_info "脚本路径: $INSTALL_SCRIPT"
    log_info "当前目录: $(pwd)"
    
    # 运行测试
    run_test "检查脚本存在" check_script_exists
    run_test "检查脚本权限" check_script_permissions
    run_test "检查脚本语法" check_script_syntax
    run_test "测试帮助功能" test_help_function
    run_test "测试版本信息" test_version_info
    run_test "测试快速验证模式" test_quick_verify_dry_run
    run_test "测试基本验证模式" test_basic_verify_mode
    run_test "测试完整验证模式" test_full_verify_mode
    run_test "测试CI模式" test_ci_mode
    
    # 汇总结果
    echo ""
    echo "========================================"
    echo "验证完成"
    echo "========================================"
    echo "总测试数: $total_tests"
    echo "通过测试: $passed_tests"
    echo "失败测试: $failed_tests"
    echo "通过率: $((passed_tests * 100 / total_tests))%"
    echo ""
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "有 $failed_tests 个测试失败"
        return 1
    fi
}

# 运行测试的辅助函数
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    echo ""
    echo "测试: $test_name"
    echo "----------------------------------------"
    
    ((total_tests++))
    
    if $test_func; then
        ((passed_tests++))
        printf "${GREEN}✓ 通过${NC}\n"
    else
        ((failed_tests++))
        printf "${RED}✗ 失败${NC}\n"
    fi
}

# 处理命令行参数
if [[ "$#" -gt 0 ]]; then
    case "$1" in
        --help|-h)
            echo "用法: $0 [--help]"
            echo ""
            echo "验证install-cn.sh在不同执行模式下的行为"
            echo ""
            echo "选项:"
            echo "  --help, -h    显示此帮助信息"
            echo ""
            echo "测试内容:"
            echo "  - 脚本存在性和权限"
            echo "  - 脚本语法检查"
            echo "  - 帮助功能测试"
            echo "  - 版本信息测试"
            echo "  - 快速验证模式测试"
            echo "  - 基本验证模式测试"
            echo "  - 完整验证模式测试"
            echo "  - CI模式测试"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
fi

# 运行主函数
main "$@"