#!/bin/bash
# quick-test-basic.sh - 快速测试quota-proxy基本功能
# 版本: 2026.02.11.1726
# 目的: 提供最简单的quota-proxy功能验证，无需复杂配置

set -e

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

# 显示帮助
show_help() {
    cat << EOF
快速测试quota-proxy基本功能

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示命令不执行
  --port PORT         指定quota-proxy端口（默认: 8787）
  --host HOST         指定quota-proxy主机（默认: 127.0.0.1）

示例:
  $0                    # 测试默认配置
  $0 --port 8888        # 测试指定端口
  $0 --dry-run          # 干运行模式

功能测试:
  1. 健康检查 (/healthz)
  2. 状态查询 (/status)
  3. 模型列表 (/v1/models)
  4. 简单聊天请求（需要TRIAL_KEY）

注意: 此脚本假设quota-proxy已在运行
EOF
}

# 解析参数
PORT=8787
HOST="127.0.0.1"
DRY_RUN=false

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
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

BASE_URL="http://${HOST}:${PORT}"

log_info "开始快速测试quota-proxy基本功能"
log_info "目标地址: ${BASE_URL}"
log_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 测试函数
test_endpoint() {
    local name="$1"
    local endpoint="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    
    log_info "测试: ${name} (${method} ${endpoint})"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  curl -X ${method} '${BASE_URL}${endpoint}' ${data:+ -d '$data'}"
        return 0
    fi
    
    local curl_cmd="curl -s -X ${method} '${BASE_URL}${endpoint}'"
    if [ -n "$data" ]; then
        curl_cmd="${curl_cmd} -d '${data}'"
    fi
    
    local response
    response=$(eval "$curl_cmd 2>/dev/null || echo '{\"error\":\"curl failed\"}'")
    
    if echo "$response" | grep -q "error"; then
        log_error "请求失败: $response"
        return 1
    else
        log_success "请求成功"
        echo "  响应: $response" | head -c 200
        echo ""
        return 0
    fi
}

# 测试1: 健康检查
log_info "=== 测试1: 健康检查 ==="
test_endpoint "健康检查" "/healthz"

# 测试2: 状态查询
log_info "=== 测试2: 状态查询 ==="
test_endpoint "状态查询" "/status"

# 测试3: 模型列表
log_info "=== 测试3: 模型列表 ==="
test_endpoint "模型列表" "/v1/models"

# 测试4: 检查是否需要TRIAL_KEY
log_info "=== 测试4: 检查TRIAL_KEY要求 ==="
test_endpoint "聊天请求（无密钥）" "/v1/chat/completions" "POST" '{"model":"deepseek-chat","messages":[{"role":"user","content":"Hello"}]}'

# 总结
log_info "=== 测试总结 ==="
if [ "$DRY_RUN" = true ]; then
    log_warning "干运行模式完成，未执行实际请求"
    log_info "要实际运行测试，请去掉 --dry-run 参数"
else
    log_success "快速测试完成"
    log_info "基本功能测试完成，如需完整测试请运行其他验证脚本:"
    echo "  ./verify-trial-key-api.sh     # 试用密钥API测试"
    echo "  ./verify-admin-keys-usage.sh  # 管理密钥和使用统计测试"
    echo "  ./verify-status-endpoint.sh   # 状态端点详细测试"
fi

log_info "脚本版本: 2026.02.11.1726"
log_info "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"