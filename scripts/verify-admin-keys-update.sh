#!/bin/bash
# 验证 PUT /admin/keys/:key 端点（更新密钥标签）
# 用法: ./scripts/verify-admin-keys-update.sh [--help] [--quiet] [--base-url URL] [--admin-token TOKEN]

set -e

# 默认配置
BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
QUIET=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
验证 PUT /admin/keys/:key 端点（更新密钥标签）

用法: $0 [选项]

选项:
  --help          显示此帮助信息
  --quiet         安静模式，只输出最终结果
  --base-url URL  设置 API 基础 URL (默认: http://127.0.0.1:8787)
  --admin-token TOKEN 设置管理员令牌 (默认: test-admin-token)

环境变量:
  BASE_URL        API 基础 URL
  ADMIN_TOKEN     管理员令牌

示例:
  $0
  $0 --base-url http://localhost:8787 --admin-token my-secret-token
  BASE_URL=http://api.example.com ADMIN_TOKEN=secret $0 --quiet
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 日志函数
log() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[INFO]${NC} $1"
    fi
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查依赖
check_deps() {
    if ! command -v curl &> /dev/null; then
        error "curl 未安装，请先安装 curl"
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq 未安装，请先安装 jq"
    fi
}

# 健康检查
health_check() {
    log "检查服务健康状态..."
    if curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
        log "服务健康状态正常"
    else
        error "服务不可用，请检查 ${BASE_URL}/healthz"
    fi
}

# 创建测试密钥
create_test_key() {
    log "创建测试密钥..."
    local response=$(curl -s -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": "测试密钥-更新前", "totalQuota": 1000}')
    
    if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
        TEST_KEY=$(echo "$response" | jq -r '.key')
        TEST_ID=$(echo "$response" | jq -r '.id')
        log "创建测试密钥成功: ${TEST_KEY} (ID: ${TEST_ID})"
    else
        error "创建测试密钥失败: $response"
    fi
}

# 验证 PUT /admin/keys/:key 端点
test_update_key() {
    log "测试 PUT /admin/keys/:key 端点..."
    
    # 测试1: 正常更新
    log "测试1: 正常更新密钥标签..."
    local response=$(curl -s -X PUT "${BASE_URL}/admin/keys/${TEST_KEY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": "测试密钥-更新后"}')
    
    if echo "$response" | jq -e '.success == true and .label == "测试密钥-更新后"' > /dev/null 2>&1; then
        log "✓ 正常更新成功"
    else
        error "正常更新失败: $response"
    fi
    
    # 测试2: 验证更新已生效
    log "测试2: 验证更新已生效..."
    local list_response=$(curl -s "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    if echo "$list_response" | jq -e ".keys[] | select(.key == \"${TEST_KEY}\" and .label == \"测试密钥-更新后\")" > /dev/null 2>&1; then
        log "✓ 更新验证成功"
    else
        error "更新验证失败: $list_response"
    fi
    
    # 测试3: 空标签应该失败
    log "测试3: 测试空标签应该失败..."
    local empty_response=$(curl -s -X PUT "${BASE_URL}/admin/keys/${TEST_KEY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": ""}')
    
    if echo "$empty_response" | jq -e '.error' > /dev/null 2>&1; then
        log "✓ 空标签正确返回错误"
    else
        error "空标签未返回错误: $empty_response"
    fi
    
    # 测试4: 不存在的密钥应该返回404
    log "测试4: 测试不存在的密钥..."
    local fake_response=$(curl -s -X PUT "${BASE_URL}/admin/keys/sk-nonexistent-key" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": "新标签"}')
    
    if echo "$fake_response" | jq -e '.error and (.error | contains("not found") or contains("Key not found"))' > /dev/null 2>&1; then
        log "✓ 不存在的密钥正确返回404"
    else
        error "不存在的密钥未正确返回错误: $fake_response"
    fi
    
    # 测试5: 缺少标签参数应该失败
    log "测试5: 测试缺少标签参数..."
    local missing_response=$(curl -s -X PUT "${BASE_URL}/admin/keys/${TEST_KEY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{}')
    
    if echo "$missing_response" | jq -e '.error' > /dev/null 2>&1; then
        log "✓ 缺少标签参数正确返回错误"
    else
        error "缺少标签参数未返回错误: $missing_response"
    fi
}

# 清理测试密钥
cleanup() {
    log "清理测试密钥..."
    if [ -n "$TEST_KEY" ]; then
        curl -s -X DELETE "${BASE_URL}/admin/keys/${TEST_KEY}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" > /dev/null 2>&1
        log "已删除测试密钥: ${TEST_KEY}"
    fi
}

# 主函数
main() {
    log "开始验证 PUT /admin/keys/:key 端点"
    log "基础 URL: ${BASE_URL}"
    log "管理员令牌: ${ADMIN_TOKEN:0:4}****"
    
    # 检查依赖
    check_deps
    
    # 健康检查
    health_check
    
    # 创建测试密钥
    create_test_key
    
    # 测试更新端点
    test_update_key
    
    # 清理
    cleanup
    
    success "所有测试通过！PUT /admin/keys/:key 端点功能正常"
    log "端点功能:"
    log "  - 支持更新密钥标签"
    log "  - 验证标签非空"
    log "  - 正确处理不存在的密钥"
    log "  - 返回适当的错误信息"
}

# 捕获退出信号进行清理
trap cleanup EXIT

# 运行主函数
main