#!/bin/bash
# verify-install-compatibility.sh - 验证安装后的版本兼容性
# 用于检查OpenClaw安装后的版本兼容性和功能完整性

set -euo pipefail

# 颜色输出
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

# 显示帮助信息
show_help() {
    cat << EOF
验证安装后的版本兼容性脚本

用法: $0 [选项]

选项:
  --dry-run      干运行模式，只显示将要执行的命令
  --help         显示此帮助信息
  --verbose      详细输出模式

功能:
  1. 检查OpenClaw版本
  2. 验证核心命令可用性
  3. 检查配置文件完整性
  4. 验证工具链兼容性
  5. 生成兼容性报告

示例:
  $0                    # 执行完整验证
  $0 --dry-run          # 干运行模式
  $0 --verbose          # 详细输出

EOF
}

# 解析命令行参数
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 执行命令函数
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    log_info "检查: $desc"
    
    if [ "$VERBOSE" = true ]; then
        echo "命令: $cmd"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "[干运行] 将执行: $cmd"
        return 0
    fi
    
    if eval "$cmd" > /dev/null 2>&1; then
        log_success "$desc ✓"
        return 0
    else
        log_error "$desc ✗"
        return 1
    fi
}

# 主验证函数
main() {
    log_info "开始验证OpenClaw安装兼容性"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    # 1. 检查OpenClaw版本
    run_cmd "openclaw --version" "OpenClaw版本命令"
    
    # 2. 验证核心命令可用性
    run_cmd "openclaw status" "OpenClaw状态检查"
    run_cmd "openclaw gateway status" "网关状态检查"
    
    # 3. 检查配置文件
    local config_dir="$HOME/.openclaw"
    if [ -d "$config_dir" ]; then
        log_success "配置文件目录存在: $config_dir ✓"
        
        # 检查关键配置文件
        for config_file in "config.yaml" "agents.yaml" "skills.yaml"; do
            if [ -f "$config_dir/$config_file" ]; then
                log_success "配置文件存在: $config_file ✓"
            else
                log_warning "配置文件不存在: $config_file"
            fi
        done
    else
        log_error "配置文件目录不存在: $config_dir"
    fi
    
    # 4. 验证工具链
    run_cmd "node --version" "Node.js版本"
    run_cmd "npm --version" "npm版本"
    run_cmd "git --version" "Git版本"
    
    # 5. 检查工作空间
    local workspace="$HOME/.openclaw/workspace"
    if [ -d "$workspace" ]; then
        log_success "工作空间目录存在: $workspace ✓"
        
        # 检查关键工作空间文件
        for ws_file in "AGENTS.md" "SOUL.md" "USER.md"; do
            if [ -f "$workspace/$ws_file" ]; then
                log_success "工作空间文件存在: $ws_file ✓"
            else
                log_warning "工作空间文件不存在: $ws_file"
            fi
        done
    else
        log_warning "工作空间目录不存在: $workspace"
    fi
    
    # 6. 验证技能系统
    run_cmd "openclaw skills list" "技能列表"
    
    echo
    log_info "兼容性验证完成"
    
    # 生成摘要报告
    echo
    echo "=== 兼容性验证摘要 ==="
    echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "系统: $(uname -s) $(uname -m)"
    echo "Node.js: $(node --version 2>/dev/null || echo '未安装')"
    echo "OpenClaw: $(openclaw --version 2>/dev/null | head -1 || echo '未安装')"
    echo "配置文件: $(if [ -d "$config_dir" ]; then echo '存在'; else echo '缺失'; fi)"
    echo "工作空间: $(if [ -d "$workspace" ]; then echo '存在'; else echo '缺失'; fi)"
    echo "======================"
}

# 执行主函数
main "$@"