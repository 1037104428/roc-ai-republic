#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装脚本验证工具
# 用于验证 install-cn.sh 脚本的功能和完整性

SCRIPT_VERSION="2026.02.12.0056"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查脚本权限
check_script_permissions() {
    log_info "检查安装脚本权限..."
    if [[ -x "$INSTALL_SCRIPT" ]]; then
        log_success "安装脚本可执行"
        return 0
    else
        log_warning "安装脚本不可执行，尝试添加执行权限..."
        if chmod +x "$INSTALL_SCRIPT"; then
            log_success "已添加执行权限"
            return 0
        else
            log_error "无法添加执行权限"
            return 1
        fi
    fi
}

# 检查脚本语法
check_script_syntax() {
    log_info "检查安装脚本语法..."
    if bash -n "$INSTALL_SCRIPT"; then
        log_success "安装脚本语法正确"
        return 0
    else
        log_error "安装脚本语法错误"
        return 1
    fi
}

# 检查脚本版本
check_script_version() {
    log_info "检查安装脚本版本信息..."
    local version_line
    if version_line=$(grep -E '^SCRIPT_VERSION="[^"]+"' "$INSTALL_SCRIPT" | head -1); then
        local version=$(echo "$version_line" | cut -d'"' -f2)
        log_success "安装脚本版本: $version"
        return 0
    else
        log_warning "未找到脚本版本信息"
        return 1
    fi
}

# 检查帮助功能
check_help_function() {
    log_info "检查安装脚本帮助功能..."
    if "$INSTALL_SCRIPT" --help 2>&1 | grep -q "OpenClaw CN 快速安装脚本"; then
        log_success "帮助功能正常"
        return 0
    else
        log_error "帮助功能异常"
        return 1
    fi
}

# 检查干运行模式
check_dry_run() {
    log_info "检查干运行模式..."
    local output
    output=$("$INSTALL_SCRIPT" --dry-run 2>&1)
    if echo "$output" | grep -q "干运行模式"; then
        log_success "干运行模式正常"
        return 0
    else
        log_error "干运行模式异常"
        return 1
    fi
}

# 检查版本参数
check_version_param() {
    log_info "检查版本参数支持..."
    local output
    output=$("$INSTALL_SCRIPT" --dry-run --version 0.3.12 2>&1)
    if echo "$output" | grep -q "安装OpenClaw版本: 0.3.12"; then
        log_success "版本参数支持正常"
        return 0
    else
        log_error "版本参数支持异常"
        return 1
    fi
}

# 检查更新检查功能
check_update_check() {
    log_info "检查更新检查功能..."
    local output
    output=$("$INSTALL_SCRIPT" --check-update 2>&1)
    if echo "$output" | grep -q "检查 OpenClaw CN 安装脚本更新"; then
        log_success "更新检查功能正常"
        return 0
    else
        log_warning "更新检查功能异常或网络不可用"
        return 1
    fi
}

# 检查验证功能
check_verify_function() {
    log_info "检查验证功能..."
    local output
    output=$("$INSTALL_SCRIPT" --dry-run --verify 2>&1)
    if echo "$output" | grep -q "开始验证 OpenClaw 安装"; then
        log_success "验证功能正常"
        return 0
    else
        log_error "验证功能异常"
        return 1
    fi
}

# 检查脚本完整性
check_script_integrity() {
    log_info "检查脚本完整性..."
    
    # 检查必需函数
    local required_functions=(
        "main_install"
        "show_help"
        "color_log"
        "select_best_npm_registry"
        "install_with_fallback"
        "self_check_openclaw"
    )
    
    local missing_functions=0
    for func in "${required_functions[@]}"; do
        if grep -q "^$func()" "$INSTALL_SCRIPT"; then
            log_success "函数存在: $func"
        else
            log_error "函数缺失: $func"
            missing_functions=$((missing_functions + 1))
        fi
    done
    
    # 检查必需变量
    local required_variables=(
        "SCRIPT_VERSION"
        "SCRIPT_UPDATE_URL"
    )
    
    local missing_variables=0
    for var in "${required_variables[@]}"; do
        if grep -q "^$var=" "$INSTALL_SCRIPT"; then
            log_success "变量存在: $var"
        else
            log_error "变量缺失: $var"
            missing_variables=$((missing_variables + 1))
        fi
    done
    
    if [[ $missing_functions -eq 0 && $missing_variables -eq 0 ]]; then
        log_success "脚本完整性检查通过"
        return 0
    else
        log_error "脚本完整性检查失败: 缺失 $missing_functions 个函数, $missing_variables 个变量"
        return 1
    fi
}

# 检查文档链接
check_documentation_links() {
    log_info "检查文档链接..."
    
    # 检查文档目录
    local docs_dir="$SCRIPT_DIR/../docs"
    if [[ -d "$docs_dir" ]]; then
        log_success "文档目录存在: $docs_dir"
        
        # 检查相关文档
        local required_docs=(
            "install-cn-guide.md"
            "install-cn-troubleshooting.md"
            "install-cn-quick-verification-commands.md"
        )
        
        local missing_docs=0
        for doc in "${required_docs[@]}"; do
            if [[ -f "$docs_dir/$doc" ]]; then
                log_success "文档存在: $doc"
            else
                log_warning "文档缺失: $doc"
                missing_docs=$((missing_docs + 1))
            fi
        done
        
        if [[ $missing_docs -eq 0 ]]; then
            log_success "文档完整性检查通过"
            return 0
        else
            log_warning "文档完整性检查: 缺失 $missing_docs 个文档"
            return 1
        fi
    else
        log_error "文档目录不存在: $docs_dir"
        return 1
    fi
}

# 生成验证报告
generate_verification_report() {
    local report_file="/tmp/install-cn-verification-report-$(date +%s).txt"
    
    cat > "$report_file" << EOF
OpenClaw CN 安装脚本验证报告
============================
验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
验证脚本版本: $SCRIPT_VERSION
安装脚本路径: $INSTALL_SCRIPT

验证结果:
EOF
    
    # 运行所有检查并记录结果
    local checks=(
        "check_script_exists"
        "check_script_permissions"
        "check_script_syntax"
        "check_script_version"
        "check_help_function"
        "check_dry_run"
        "check_version_param"
        "check_update_check"
        "check_verify_function"
        "check_script_integrity"
        "check_documentation_links"
    )
    
    local total_checks=${#checks[@]}
    local passed_checks=0
    local failed_checks=0
    
    for check in "${checks[@]}"; do
        echo -n "  - $check: " >> "$report_file"
        if $check > /dev/null 2>&1; then
            echo "通过" >> "$report_file"
            passed_checks=$((passed_checks + 1))
        else
            echo "失败" >> "$report_file"
            failed_checks=$((failed_checks + 1))
        fi
    done
    
    cat >> "$report_file" << EOF

统计:
  总检查数: $total_checks
  通过数: $passed_checks
  失败数: $failed_checks
  通过率: $((passed_checks * 100 / total_checks))%

建议:
EOF
    
    if [[ $failed_checks -eq 0 ]]; then
        echo "  所有检查通过，安装脚本状态良好。" >> "$report_file"
    else
        echo "  发现 $failed_checks 个问题，建议修复。" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

下一步:
  1. 查看详细日志: 重新运行验证脚本
  2. 修复问题: 根据失败检查修复安装脚本
  3. 测试安装: 运行 ./install-cn.sh --dry-run
  4. 更新文档: 确保相关文档同步更新

验证脚本信息:
  - 版本: $SCRIPT_VERSION
  - 路径: $0
  - 生成报告: $report_file
EOF
    
    log_success "验证报告已生成: $report_file"
    log_info "查看报告: cat $report_file"
    
    # 显示摘要
    echo ""
    echo "=== 验证摘要 ==="
    echo "总检查数: $total_checks"
    echo "通过数: $passed_checks"
    echo "失败数: $failed_checks"
    echo "通过率: $((passed_checks * 100 / total_checks))%"
    echo "报告文件: $report_file"
    echo "================"
    
    if [[ $failed_checks -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 显示帮助
show_help() {
    cat << EOF
OpenClaw CN 安装脚本验证工具

用法:
  ./verify-install-cn.sh [选项]

选项:
  --quick          快速验证 (仅检查基本功能)
  --full           完整验证 (所有检查，默认)
  --report         生成验证报告
  --help           显示此帮助信息

功能:
  - 检查安装脚本是否存在和可执行
  - 验证脚本语法和版本信息
  - 测试所有命令行参数功能
  - 检查脚本完整性 (函数和变量)
  - 验证相关文档链接
  - 生成详细的验证报告

示例:
  # 完整验证并生成报告
  ./verify-install-cn.sh --full --report
  
  # 快速验证
  ./verify-install-cn.sh --quick
  
  # 仅生成报告
  ./verify-install-cn.sh --report

版本: $SCRIPT_VERSION
EOF
}

# 快速验证模式
quick_verification() {
    log_info "开始快速验证..."
    
    local quick_checks=(
        "check_script_exists"
        "check_script_permissions"
        "check_script_syntax"
        "check_help_function"
        "check_dry_run"
    )
    
    local total_checks=${#quick_checks[@]}
    local passed_checks=0
    
    for check in "${quick_checks[@]}"; do
        log_info "执行检查: $check"
        if $check; then
            passed_checks=$((passed_checks + 1))
        fi
    done
    
    echo ""
    echo "=== 快速验证结果 ==="
    echo "总检查数: $total_checks"
    echo "通过数: $passed_checks"
    echo "失败数: $((total_checks - passed_checks))"
    echo "通过率: $((passed_checks * 100 / total_checks))%"
    echo "==================="
    
    if [[ $passed_checks -eq $total_checks ]]; then
        log_success "快速验证通过"
        return 0
    else
        log_error "快速验证失败"
        return 1
    fi
}

# 主函数
main() {
    local mode="full"
    local generate_report=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick)
                mode="quick"
                shift
                ;;
            --full)
                mode="full"
                shift
                ;;
            --report)
                generate_report=true
                shift
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    log_info "开始 OpenClaw CN 安装脚本验证"
    log_info "模式: $mode"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # 根据模式执行验证
    case "$mode" in
        "quick")
            if quick_verification; then
                log_success "快速验证完成"
            else
                log_error "快速验证失败"
                return 1
            fi
            ;;
        "full")
            if generate_verification_report; then
                log_success "完整验证完成"
            else
                log_error "完整验证发现问题"
                return 1
            fi
            ;;
    esac
    
    log_info "验证完成"
    return 0
}

# 运行主函数
main "$@"