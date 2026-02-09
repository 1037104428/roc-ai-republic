#!/bin/bash
# 验证 DELETE /admin/keys/:key 端点功能
# 用法: ./verify-admin-keys-delete.sh [--help] [--base-url URL] [--admin-token TOKEN]

set -e

# 默认配置
BASE_URL="${BASE_URL:-http://localhost:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-dev-admin-token-change-in-production}"
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
验证 DELETE /admin/keys/:key 端点功能

用法: $0 [选项]

选项:
  --help          显示此帮助信息
  --base-url URL  设置 API 基础 URL (默认: http://localhost:8787)
  --admin-token TOKEN  设置管理员令牌 (默认: dev-admin-token-change-in-production)
  --verbose       显示详细输出
  --create-test-key 创建测试密钥用于删除测试

环境变量:
  BASE_URL        同 --base-url
  ADMIN_TOKEN     同 --admin-token

示例:
  $0 --base-url http://127.0.0.1:8787
  $0 --create-test-key
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --create-test-key)
            CREATE_TEST_KEY=true
            shift
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
    if [ "$VERBOSE" = true ] || [ "$1" = "ERROR" ]; then
        echo -e "$2"
    fi
}

log_info() {
    log "INFO" "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    log "WARN" "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "ERROR" "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_deps() {
    if ! command -v curl &> /dev/null; then
        log_error "需要 curl 命令"
        exit 1
    fi
}

# 检查服务是否运行
check_service() {
    log_info "检查服务健康状态..."
    if ! curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
        log_error "服务未运行在 ${BASE_URL}"
        log_error "请确保 quota-proxy 服务正在运行"
        exit 1
    fi
    log_info "服务运行正常"
}

# 创建测试密钥
create_test_key() {
    log_info "创建测试密钥..."
    local response=$(curl -s -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": "test-key-for-delete", "totalQuota": 500}')
    
    if echo "$response" | grep -q '"success":true'; then
        local key=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_info "测试密钥创建成功: $key"
        echo "$key"
    else
        log_error "创建测试密钥失败: $response"
        exit 1
    fi
}

# 验证 DELETE 端点
verify_delete_endpoint() {
    local test_key="$1"
    
    log_info "测试 DELETE /admin/keys/:key 端点..."
    
    # 1. 删除存在的密钥
    log_info "1. 删除存在的密钥: $test_key"
    local delete_response=$(curl -s -X DELETE "${BASE_URL}/admin/keys/${test_key}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "$delete_response" | tail -n1)
    local response_body=$(echo "$delete_response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        if echo "$response_body" | grep -q '"success":true'; then
            log_info "✓ 成功删除密钥"
            log_info "响应: $response_body"
        else
            log_error "响应格式错误: $response_body"
            return 1
        fi
    else
        log_error "删除失败，HTTP 状态码: $http_code"
        log_error "响应: $response_body"
        return 1
    fi
    
    # 2. 验证密钥已被删除（尝试再次删除）
    log_info "2. 验证密钥已被删除（尝试再次删除）"
    local verify_response=$(curl -s -X DELETE "${BASE_URL}/admin/keys/${test_key}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "\n%{http_code}")
    
    local verify_code=$(echo "$verify_response" | tail -n1)
    local verify_body=$(echo "$verify_response" | head -n -1)
    
    if [ "$verify_code" = "404" ]; then
        log_info "✓ 密钥不存在（符合预期）"
    else
        log_warn "预期 404 但收到 $verify_code"
        log_warn "响应: $verify_body"
    fi
    
    # 3. 验证密钥不在列表中
    log_info "3. 验证密钥不在列表中"
    local list_response=$(curl -s "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    
    if echo "$list_response" | grep -q "$test_key"; then
        log_error "密钥仍在列表中: $list_response"
        return 1
    else
        log_info "✓ 密钥已从列表中移除"
    fi
    
    # 4. 测试无效密钥格式
    log_info "4. 测试无效密钥格式"
    local invalid_response=$(curl -s -X DELETE "${BASE_URL}/admin/keys/" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "\n%{http_code}")
    
    local invalid_code=$(echo "$invalid_response" | tail -n1)
    if [ "$invalid_code" = "404" ] || [ "$invalid_code" = "400" ]; then
        log_info "✓ 无效路径处理正常"
    else
        log_warn "无效路径返回 $invalid_code（预期 404 或 400）"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}=== 验证 DELETE /admin/keys/:key 端点 ===${NC}"
    
    check_deps
    check_service
    
    # 创建或使用现有测试密钥
    if [ "$CREATE_TEST_KEY" = true ]; then
        TEST_KEY=$(create_test_key)
    else
        # 尝试获取现有密钥用于测试
        log_info "获取现有密钥用于测试..."
        local list_response=$(curl -s "${BASE_URL}/admin/keys" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}")
        
        if echo "$list_response" | grep -q '"keys":\[\]' || echo "$list_response" | grep -q '"total":0'; then
            log_warn "没有现有密钥，创建测试密钥..."
            TEST_KEY=$(create_test_key)
        else
            # 提取第一个密钥
            TEST_KEY=$(echo "$list_response" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4)
            log_info "使用现有密钥进行测试: $TEST_KEY"
            log_warn "注意：此密钥将被永久删除！"
            
            # 确认
            read -p "确认删除密钥 $TEST_KEY？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "取消测试"
                exit 0
            fi
        fi
    fi
    
    verify_delete_endpoint "$TEST_KEY"
    
    echo -e "${GREEN}=== 所有测试通过 ===${NC}"
    echo -e "${GREEN}DELETE /admin/keys/:key 端点功能正常${NC}"
}

# 运行主函数
main "$@"