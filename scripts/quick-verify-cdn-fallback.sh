#!/bin/bash

# quick-verify-cdn-fallback.sh - 快速验证CDN回退策略脚本
# 快速测试install-cn.sh的国内源回退策略，确保回退机制正常工作

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

# 检查脚本存在性
check_script_exists() {
    local script_path="$1"
    local script_name="$2"
    
    if [ -f "$script_path" ]; then
        log_success "$script_name 存在: $script_path"
        return 0
    else
        log_error "$script_name 不存在: $script_path"
        return 1
    fi
}

# 检查脚本语法
check_script_syntax() {
    local script_path="$1"
    local script_name="$2"
    
    if bash -n "$script_path" 2>/dev/null; then
        log_success "$script_name 语法正确"
        return 0
    else
        log_error "$script_name 语法错误"
        return 1
    fi
}

# 检查回退策略函数
check_fallback_function() {
    local script_path="$1"
    local function_name="$2"
    
    if grep -q "function $function_name\|$function_name()" "$script_path"; then
        log_success "找到回退策略函数: $function_name"
        return 0
    else
        log_error "未找到回退策略函数: $function_name"
        return 1
    fi
}

# 检查CDN源列表
check_cdn_sources() {
    local script_path="$1"
    
    local cdn_count
    cdn_count=$(grep -c "https://registry.npmmirror.com\|https://mirrors.cloud.tencent.com\|https://registry.npm.taobao.org" "$script_path" || true)
    
    if [ "$cdn_count" -ge 2 ]; then
        log_success "找到 $cdn_count 个国内CDN源"
        return 0
    else
        log_error "国内CDN源不足 (找到 $cdn_count 个，需要至少2个)"
        return 1
    fi
}

# 检查回退逻辑
check_fallback_logic() {
    local script_path="$1"
    
    if grep -q "尝试.*失败\|fallback\|回退\|重试" "$script_path"; then
        log_success "找到回退逻辑"
        return 0
    else
        log_error "未找到明显的回退逻辑"
        return 1
    fi
}

# 检查超时设置
check_timeout_settings() {
    local script_path="$1"
    
    if grep -q "timeout\|TIMEOUT\|超时" "$script_path"; then
        log_success "找到超时设置"
        return 0
    else
        log_warning "未找到明确的超时设置"
        return 0  # 不是致命错误
    fi
}

# 检查自检功能
check_self_test() {
    local script_path="$1"
    
    if grep -q "openclaw --version\|版本检查\|自检" "$script_path"; then
        log_success "找到自检功能"
        return 0
    else
        log_error "未找到自检功能"
        return 1
    fi
}

# 主验证函数
main_verification() {
    local script_path="./scripts/install-cn.sh"
    local script_name="install-cn.sh"
    
    log_info "开始验证 $script_name 的CDN回退策略"
    echo "========================================"
    
    local all_passed=true
    
    # 1. 检查脚本存在性
    if ! check_script_exists "$script_path" "$script_name"; then
        all_passed=false
    fi
    
    # 2. 检查脚本语法
    if ! check_script_syntax "$script_path" "$script_name"; then
        all_passed=false
    fi
    
    # 3. 检查回退策略函数
    if ! check_fallback_function "$script_path" "try_download"; then
        if ! check_fallback_function "$script_path" "download_with_fallback"; then
            log_warning "未找到标准回退函数名，继续检查其他模式"
        fi
    fi
    
    # 4. 检查CDN源列表
    if ! check_cdn_sources "$script_path"; then
        all_passed=false
    fi
    
    # 5. 检查回退逻辑
    if ! check_fallback_logic "$script_path"; then
        all_passed=false
    fi
    
    # 6. 检查超时设置
    if ! check_timeout_settings "$script_path"; then
        # 这不是致命错误，只记录警告
        :
    fi
    
    # 7. 检查自检功能
    if ! check_self_test "$script_path"; then
        all_passed=false
    fi
    
    echo "========================================"
    
    # 输出验证结果
    if $all_passed; then
        log_success "✅ 所有基本验证通过"
        log_info "CDN回退策略验证完成"
        echo
        echo "建议进一步测试:"
        echo "1. 运行 ./scripts/test-cdn-sources.sh 测试CDN源可用性"
        echo "2. 运行 ./scripts/quick-verify-install-cn.sh 完整验证安装脚本"
        echo "3. 查看 docs/install-cn-quick-test-example.md 获取测试示例"
        return 0
    else
        log_error "❌ 部分验证失败"
        log_info "需要修复CDN回退策略"
        echo
        echo "修复建议:"
        echo "1. 确保至少包含2个国内CDN源"
        echo "2. 实现明确的回退逻辑（失败时尝试下一个源）"
        echo "3. 添加自检功能（openclaw --version）"
        echo "4. 参考 docs/install-cn-quick-test-example.md 中的最佳实践"
        return 1
    fi
}

# 运行主验证
if [ -f "./scripts/install-cn.sh" ]; then
    main_verification
else
    log_error "当前目录不是项目根目录或 install-cn.sh 不存在"
    log_info "请切换到项目根目录: cd /home/kai/.openclaw/workspace/roc-ai-republic"
    exit 1
fi