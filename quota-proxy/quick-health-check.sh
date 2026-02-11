#!/bin/bash
# quota-proxy 快速健康检查脚本
# 用于快速验证 quota-proxy 服务状态和基本功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
TIMEOUT="${TIMEOUT:-5}"
DRY_RUN="${DRY_RUN:-false}"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
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

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        return 1
    fi
    return 0
}

# 健康检查端点
check_health() {
    log_info "检查健康端点: ${BASE_URL}/healthz"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "干运行模式 - 跳过实际HTTP请求"
        echo "模拟响应: {\"status\":\"healthy\",\"timestamp\":\"$(date -Iseconds)\"}"
        return 0
    fi
    
    local response
    response=$(curl -s -f --max-time "$TIMEOUT" "${BASE_URL}/healthz" 2>/dev/null || echo "")
    
    if [ -n "$response" ]; then
        log_success "健康检查通过: $response"
        return 0
    else
        log_error "健康检查失败"
        return 1
    fi
}

# 状态端点检查
check_status() {
    log_info "检查状态端点: ${BASE_URL}/status"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "干运行模式 - 跳过实际HTTP请求"
        echo "模拟响应: {\"version\":\"1.0.0\",\"uptime\":3600,\"requests\":1000}"
        return 0
    fi
    
    local response
    response=$(curl -s -f --max-time "$TIMEOUT" "${BASE_URL}/status" 2>/dev/null || echo "")
    
    if [ -n "$response" ]; then
        log_success "状态检查通过: $response"
        return 0
    else
        log_error "状态检查失败"
        return 1
    fi
}

# 基本API密钥检查（如果可用）
check_api_key() {
    log_info "检查API密钥端点（如果可用）"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "干运行模式 - 跳过实际HTTP请求"
        echo "模拟响应: {\"valid\":true,\"remaining\":100}"
        return 0
    fi
    
    # 尝试使用默认的测试密钥
    local response
    response=$(curl -s -f --max-time "$TIMEOUT" \
        -H "Authorization: Bearer test-key" \
        "${BASE_URL}/v1/chat/completions" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"model":"deepseek/deepseek-chat","messages":[{"role":"user","content":"ping"}]}' \
        2>/dev/null || echo "")
    
    if echo "$response" | grep -q "quota_exceeded\|invalid_key\|unauthorized"; then
        log_warning "API密钥检查: 密钥无效或配额已用完（正常状态）"
        return 0
    elif [ -n "$response" ]; then
        log_success "API密钥检查通过"
        return 0
    else
        log_error "API密钥检查失败"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 快速健康检查脚本

用法: $0 [选项]

选项:
  --base-url URL     设置 quota-proxy 基础URL (默认: http://127.0.0.1:8787)
  --admin-token TOKEN 设置管理员令牌 (默认: test-admin-token)
  --timeout SECONDS  设置超时时间 (默认: 5)
  --dry-run          干运行模式，不发送实际HTTP请求
  --help             显示此帮助信息

环境变量:
  BASE_URL       同 --base-url
  ADMIN_TOKEN    同 --admin-token
  TIMEOUT        同 --timeout
  DRY_RUN        同 --dry-run

示例:
  $0
  $0 --base-url http://localhost:8787 --timeout 10
  DRY_RUN=true $0
  $0 --dry-run

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --base-url)
                BASE_URL="$2"
                shift 2
                ;;
            --admin-token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
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
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "开始 quota-proxy 快速健康检查"
    log_info "配置: BASE_URL=${BASE_URL}, TIMEOUT=${TIMEOUT}s, DRY_RUN=${DRY_RUN}"
    
    # 检查必要命令
    check_command curl || exit 1
    
    local errors=0
    
    # 执行检查
    check_health || ((errors++))
    check_status || ((errors++))
    check_api_key || ((errors++))
    
    # 总结
    echo ""
    if [ $errors -eq 0 ]; then
        log_success "所有健康检查通过！quota-proxy 服务运行正常"
        exit 0
    else
        log_error "健康检查失败 ($errors 个错误)"
        log_info "建议:"
        log_info "1. 检查 quota-proxy 服务是否运行: docker compose ps"
        log_info "2. 检查服务日志: docker compose logs quota-proxy"
        log_info "3. 验证网络连接: curl -v ${BASE_URL}/healthz"
        exit 1
    fi
}

# 运行主函数
main "$@"