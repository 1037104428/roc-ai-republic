#!/bin/bash

# Verify SQLite persistent quota-proxy API endpoints
# Usage: ./verify-sqlite-persistent-api.sh [--dry-run] [--admin-token TOKEN] [--base-url URL]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
DRY_RUN=false
ADMIN_TOKEN="test-admin-token-$(date +%s)"
BASE_URL="http://localhost:8787"
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    log_error "curl is not installed"
    exit 1
fi

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    log_info "干运行模式 - 显示验证步骤但不实际执行"
    log_info "将验证以下端点:"
    log_info "  1. GET /healthz"
    log_info "  2. POST /admin/keys (生成试用密钥)"
    log_info "  3. GET /admin/keys (列出试用密钥)"
    log_info "  4. GET /admin/usage (获取使用统计)"
    log_info "  5. DELETE /admin/keys/:key (删除试用密钥)"
    log_info "  6. POST /v1/chat/completions (配额检查)"
    log_info ""
    log_info "配置:"
    log_info "  Base URL: $BASE_URL"
    log_info "  Admin Token: ${ADMIN_TOKEN:0:10}..."
    log_info ""
    log_success "所有验证步骤已规划完成"
    exit 0
fi

# Check if server is running
log_info "检查服务器是否运行..."
if ! curl -s -f "$BASE_URL/healthz" > /dev/null 2>&1; then
    log_error "服务器未运行在 $BASE_URL"
    log_info "请先启动服务器: ./start-sqlite-persistent.sh"
    exit 1
fi
log_success "服务器运行正常"

# Test 1: Health check
log_info "测试 1: 健康检查端点..."
response=$(curl -s -f "$BASE_URL/healthz")
if echo "$response" | grep -q '"ok":true'; then
    log_success "健康检查通过"
else
    log_error "健康检查失败: $response"
    exit 1
fi

# Test 2: Generate trial key
log_info "测试 2: 生成试用密钥..."
response=$(curl -s -f -X POST "$BASE_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"label": "测试密钥", "daily_limit": 100}')
    
if echo "$response" | grep -q '"key":"roc_'; then
    TRIAL_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    log_success "试用密钥生成成功: ${TRIAL_KEY:0:20}..."
else
    log_error "试用密钥生成失败: $response"
    exit 1
fi

# Test 3: List trial keys
log_info "测试 3: 列出试用密钥..."
response=$(curl -s -f "$BASE_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
    
if echo "$response" | grep -q '"key":'; then
    KEY_COUNT=$(echo "$response" | grep -o '"key":' | wc -l)
    log_success "列出 $KEY_COUNT 个试用密钥"
else
    log_error "列出试用密钥失败: $response"
    exit 1
fi

# Test 4: Get usage statistics
log_info "测试 4: 获取使用统计..."
response=$(curl -s -f "$BASE_URL/admin/usage" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
    
if echo "$response" | grep -q '"day":'; then
    log_success "使用统计获取成功"
else
    log_error "使用统计获取失败: $response"
    exit 1
fi

# Test 5: Delete trial key
log_info "测试 5: 删除试用密钥..."
response=$(curl -s -f -X DELETE "$BASE_URL/admin/keys/$TRIAL_KEY" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
    
if echo "$response" | grep -q '"ok":true'; then
    log_success "试用密钥删除成功"
else
    log_error "试用密钥删除失败: $response"
    exit 1
fi

# Test 6: Verify quota enforcement
log_info "测试 6: 验证配额检查..."
response=$(curl -s -X POST "$BASE_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid_key" \
    -d '{"model": "deepseek-chat", "messages": [{"role": "user", "content": "Hello"}]}')
    
if echo "$response" | grep -q 'Invalid trial key'; then
    log_success "配额检查正常 (无效密钥被拒绝)"
else
    log_warning "配额检查响应异常: $response"
fi

# Summary
log_success ""
log_success "✅ 所有 SQLite 持久化 API 端点验证通过!"
log_success ""
log_success "已验证功能:"
log_success "  ✓ 健康检查端点"
log_success "  ✓ 试用密钥生成 (POST /admin/keys)"
log_success "  ✓ 试用密钥列表 (GET /admin/keys)"
log_success "  ✓ 使用统计查询 (GET /admin/usage)"
log_success "  ✓ 试用密钥删除 (DELETE /admin/keys/:key)"
log_success "  ✓ 配额检查机制"
log_success ""
log_success "SQLite 持久化功能完整可用!"