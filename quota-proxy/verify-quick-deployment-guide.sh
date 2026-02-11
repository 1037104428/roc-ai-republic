#!/bin/bash

# quota-proxy 快速部署指南验证脚本
# 版本: 2026.02.11.17
# 用途: 验证 QUICK_DEPLOYMENT_GUIDE.md 文档的完整性和正确性

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

# 检查文件是否存在
check_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log_success "文件存在: $file"
        return 0
    else
        log_error "文件不存在: $file"
        return 1
    fi
}

# 检查文件大小
check_file_size() {
    local file="$1"
    local min_size="$2"
    local size=$(wc -c < "$file" 2>/dev/null || echo 0)
    
    if [[ $size -ge $min_size ]]; then
        log_success "文件大小符合要求: $file ($size 字节，要求 ≥ $min_size 字节)"
        return 0
    else
        log_error "文件大小不足: $file ($size 字节，要求 ≥ $min_size 字节)"
        return 1
    fi
}

# 检查文件内容
check_file_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_success "找到内容: $description"
        return 0
    else
        log_error "未找到内容: $description (模式: $pattern)"
        return 1
    fi
}

# 检查章节结构
check_sections() {
    local file="$1"
    local sections=("概述" "环境要求" "一键部署脚本" "手动部署步骤" "快速验证" "常用管理命令" "故障排除" "下一步操作" "验证脚本" "版本历史" "支持与反馈")
    
    log_info "检查文档章节结构..."
    
    local missing_sections=0
    for section in "${sections[@]}"; do
        if grep -q "^#.*$section" "$file" || grep -q "^##.*$section" "$file"; then
            log_success "找到章节: $section"
        else
            log_error "未找到章节: $section"
            missing_sections=$((missing_sections + 1))
        fi
    done
    
    if [[ $missing_sections -eq 0 ]]; then
        log_success "所有章节结构完整"
        return 0
    else
        log_error "缺少 $missing_sections 个章节"
        return 1
    fi
}

# 检查代码块
check_code_blocks() {
    local file="$1"
    local code_blocks=$(grep -c '^```' "$file" 2>/dev/null || echo 0)
    
    if [[ $code_blocks -ge 10 ]]; then
        log_success "代码块数量足够: $code_blocks 个 (要求 ≥ 10)"
        return 0
    else
        log_error "代码块数量不足: $code_blocks 个 (要求 ≥ 10)"
        return 1
    fi
}

# 检查链接
check_links() {
    local file="$1"
    local links=$(grep -c '\[.*\](.*)' "$file" 2>/dev/null || echo 0)
    
    if [[ $links -ge 3 ]]; then
        log_success "链接数量足够: $links 个 (要求 ≥ 3)"
        return 0
    else
        log_error "链接数量不足: $links 个 (要求 ≥ 3)"
        return 1
    fi
}

# 检查命令示例
check_command_examples() {
    local file="$1"
    local commands=("curl" "docker compose" "chmod" "mkdir" "netstat" "systemctl" "grep")
    
    log_info "检查命令示例..."
    
    local missing_commands=0
    for cmd in "${commands[@]}"; do
        if grep -q "$cmd" "$file" 2>/dev/null; then
            log_success "找到命令示例: $cmd"
        else
            log_warning "未找到命令示例: $cmd"
            missing_commands=$((missing_commands + 1))
        fi
    done
    
    if [[ $missing_commands -le 2 ]]; then
        log_success "命令示例基本完整 (缺少 $missing_commands 个)"
        return 0
    else
        log_error "命令示例不完整 (缺少 $missing_commands 个)"
        return 1
    fi
}

# 主验证函数
main_verification() {
    local guide_file="QUICK_DEPLOYMENT_GUIDE.md"
    local script_file="verify-quick-deployment-guide.sh"
    
    log_info "开始验证快速部署指南..."
    log_info "当前目录: $(pwd)"
    log_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    echo "========================================"
    log_info "阶段 1: 检查文件存在性和基本属性"
    echo "========================================"
    
    # 检查指南文件
    check_file_exists "$guide_file" || return 1
    check_file_size "$guide_file" 3000 || return 1
    
    # 检查脚本文件自身
    check_file_exists "$script_file" || return 1
    check_file_size "$script_file" 1000 || return 1
    
    echo "========================================"
    log_info "阶段 2: 检查文档内容完整性"
    echo "========================================"
    
    # 检查关键内容
    check_file_content "$guide_file" "一键部署脚本" "一键部署章节" || return 1
    check_file_content "$guide_file" "docker-compose.yml" "Docker Compose配置" || return 1
    check_file_content "$guide_file" "健康检查" "健康检查部分" || return 1
    check_file_content "$guide_file" "故障排除" "故障排除章节" || return 1
    check_file_content "$guide_file" "验证脚本" "验证脚本部分" || return 1
    
    echo "========================================"
    log_info "阶段 3: 检查文档结构"
    echo "========================================"
    
    check_sections "$guide_file" || return 1
    check_code_blocks "$guide_file" || return 1
    check_links "$guide_file" || return 1
    check_command_examples "$guide_file" || return 1
    
    echo "========================================"
    log_info "阶段 4: 检查脚本功能"
    echo "========================================"
    
    # 检查脚本是否可执行
    if [[ -x "$script_file" ]]; then
        log_success "脚本可执行"
    else
        log_warning "脚本不可执行，尝试添加执行权限..."
        chmod +x "$script_file" 2>/dev/null && log_success "已添加执行权限" || log_error "无法添加执行权限"
    fi
    
    # 检查脚本帮助信息
    if grep -q "用途:" "$script_file"; then
        log_success "脚本包含用途说明"
    else
        log_error "脚本缺少用途说明"
        return 1
    fi
    
    if grep -q "版本:" "$script_file"; then
        log_success "脚本包含版本信息"
    else
        log_error "脚本缺少版本信息"
        return 1
    fi
    
    echo "========================================"
    log_info "验证完成"
    echo "========================================"
    
    log_success "快速部署指南验证通过！"
    log_info "文档位置: $(pwd)/$guide_file"
    log_info "文档大小: $(wc -c < "$guide_file") 字节"
    log_info "文档行数: $(wc -l < "$guide_file") 行"
    log_info "代码块数量: $(grep -c '^```' "$guide_file") 个"
    
    return 0
}

# 演示模式
demo_mode() {
    log_info "运行演示模式..."
    
    echo "========================================"
    log_info "演示: 显示文档基本信息"
    echo "========================================"
    
    if [[ -f "QUICK_DEPLOYMENT_GUIDE.md" ]]; then
        echo "文档前10行:"
        head -10 "QUICK_DEPLOYMENT_GUIDE.md"
        echo ""
        
        echo "文档章节:"
        grep -E '^#+ ' "QUICK_DEPLOYMENT_GUIDE.md" | head -10
        echo ""
        
        echo "代码块示例:"
        grep -A2 -B2 '^```' "QUICK_DEPLOYMENT_GUIDE.md" | head -10
        echo ""
    else
        log_error "文档文件不存在"
    fi
    
    echo "========================================"
    log_info "演示: 显示脚本帮助信息"
    echo "========================================"
    
    echo "脚本帮助:"
    echo "  用法: ./verify-quick-deployment-guide.sh [选项]"
    echo "  选项:"
    echo "    --help    显示此帮助信息"
    echo "    --demo    运行演示模式"
    echo "    --quick   运行快速验证"
    echo "    --full    运行完整验证（默认）"
    echo ""
    
    log_success "演示模式完成"
}

# 快速验证模式
quick_mode() {
    log_info "运行快速验证模式..."
    
    local guide_file="QUICK_DEPLOYMENT_GUIDE.md"
    
    # 基本检查
    if [[ ! -f "$guide_file" ]]; then
        log_error "文档文件不存在: $guide_file"
        return 1
    fi
    
    if [[ ! -f "verify-quick-deployment-guide.sh" ]]; then
        log_error "验证脚本不存在"
        return 1
    fi
    
    # 检查关键内容
    local checks_passed=0
    local total_checks=5
    
    grep -q "一键部署脚本" "$guide_file" && {
        log_success "✓ 找到一键部署章节"
        checks_passed=$((checks_passed + 1))
    } || log_error "✗ 未找到一键部署章节"
    
    grep -q "docker-compose.yml" "$guide_file" && {
        log_success "✓ 找到Docker Compose配置"
        checks_passed=$((checks_passed + 1))
    } || log_error "✗ 未找到Docker Compose配置"
    
    grep -q "健康检查" "$guide_file" && {
        log_success "✓ 找到健康检查部分"
        checks_passed=$((checks_passed + 1))
    } || log_error "✗ 未找到健康检查部分"
    
    grep -q "故障排除" "$guide_file" && {
        log_success "✓ 找到故障排除章节"
        checks_passed=$((checks_passed + 1))
    } || log_error "✗ 未找到故障排除章节"
    
    grep -q "验证脚本" "$guide_file" && {
        log_success "✓ 找到验证脚本部分"
        checks_passed=$((checks_passed + 1))
    } || log_error "✗ 未找到验证脚本部分"
    
    log_info "快速验证结果: $checks_passed/$total_checks 项检查通过"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        log_success "快速验证通过！"
        return 0
    else
        log_error "快速验证失败"
        return 1
    fi
}

# 帮助信息
show_help() {
    echo "quota-proxy 快速部署指南验证脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help     显示此帮助信息"
    echo "  --demo     运行演示模式（显示文档基本信息）"
    echo "  --quick    运行快速验证模式（基本检查）"
    echo "  --full     运行完整验证模式（默认）"
    echo ""
    echo "示例:"
    echo "  $0 --help         显示帮助信息"
    echo "  $0 --demo         运行演示模式"
    echo "  $0 --quick        运行快速验证"
    echo "  $0 --full         运行完整验证"
    echo ""
    echo "版本: 2026.02.11.17"
    echo "用途: 验证 QUICK_DEPLOYMENT_GUIDE.md 文档的完整性和正确性"
}

# 主函数
main() {
    local mode="full"
    
    # 解析参数
    case "${1:-}" in
        --help)
            show_help
            return 0
            ;;
        --demo)
            mode="demo"
            ;;
        --quick)
            mode="quick"
            ;;
        --full|"")
            mode="full"
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            return 1
            ;;
    esac
    
    # 切换到脚本所在目录
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$script_dir" || {
        log_error "无法切换到脚本目录: $script_dir"
        return 1
    }
    
    # 根据模式执行
    case "$mode" in
        demo)
            demo_mode
            ;;
        quick)
            quick_mode
            ;;
        full)
            main_verification
            ;;
    esac
    
    local exit_code=$?
    
    echo ""
    log_info "验证模式: $mode"
    log_info "退出代码: $exit_code"
    log_info "完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    return $exit_code
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi