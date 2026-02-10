#!/bin/bash
# 验证 quota-proxy 的 POST /admin/reset-usage 端点
# 用法: ./scripts/verify-admin-reset-usage.sh [--local|--remote <host>] [--help]

set -e

# 默认配置
LOCAL_HOST="http://localhost:8787"
REMOTE_HOST=""
ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
BASE_URL=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_help() {
    echo "验证 quota-proxy 的 POST /admin/reset-usage 端点"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --local           验证本地服务 (默认)"
    echo "  --remote <host>   验证远程服务，例如: --remote http://api.example.com"
    echo "  --token <token>   指定 ADMIN_TOKEN (默认从环境变量读取)"
    echo "  --help            显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --local"
    echo "  $0 --remote http://api.clawdrepublic.cn --token my-secret-token"
    echo ""
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            BASE_URL="$LOCAL_HOST"
            shift
            ;;
        --remote)
            BASE_URL="$2"
            shift 2
            ;;
        --token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            print_help
            exit 1
            ;;
    esac
done

# 设置默认 BASE_URL
if [ -z "$BASE_URL" ]; then
    BASE_URL="$LOCAL_HOST"
fi

# 检查必需的工具
check_dependencies() {
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必需的工具: ${missing[*]}${NC}"
        exit 1
    fi
}

# 发送 HTTP 请求
send_request() {
    local endpoint="$1"
    local method="$2"
    local data="$3"
    
    local curl_cmd="curl -s -X $method"
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    curl_cmd="$curl_cmd -H 'Authorization: Bearer $ADMIN_TOKEN'"
    curl_cmd="$curl_cmd '$BASE_URL$endpoint'"
    
    echo -e "${YELLOW}请求: $method $BASE_URL$endpoint${NC}"
    if [ -n "$data" ]; then
        echo -e "${YELLOW}数据: $data${NC}"
    fi
    
    eval "$curl_cmd"
}

# 验证端点
verify_endpoint() {
    echo -e "${GREEN}=== 开始验证 POST /admin/reset-usage 端点 ===${NC}"
    
    # 1. 首先创建一个测试密钥
    echo -e "${YELLOW}1. 创建测试密钥...${NC}"
    local create_response=$(send_request "/admin/keys" "POST" '{"label":"测试重置使用量"}')
    local test_key=$(echo "$create_response" | jq -r '.key // empty')
    
    if [ -z "$test_key" ] || [ "$test_key" = "null" ]; then
        echo -e "${RED}创建测试密钥失败: $create_response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}测试密钥创建成功: $test_key${NC}"
    
    # 2. 模拟一些使用量
    echo -e "${YELLOW}2. 模拟使用量...${NC}"
    for i in {1..3}; do
        curl -s -X POST "$BASE_URL/chat" \
            -H "Authorization: Bearer $test_key" \
            -H "Content-Type: application/json" \
            -d '{"messages":[{"role":"user","content":"test"}]}' > /dev/null 2>&1 || true
        echo -n "."
        sleep 0.5
    done
    echo ""
    
    # 3. 检查当前使用量
    echo -e "${YELLOW}3. 检查当前使用量...${NC}"
    local usage_before=$(send_request "/admin/usage?key=$test_key" "GET")
    local used_quota_before=$(echo "$usage_before" | jq -r '.data[0].used_quota // 0')
    echo -e "${GREEN}重置前使用量: $used_quota_before${NC}"
    
    # 4. 重置特定密钥的使用量
    echo -e "${YELLOW}4. 重置特定密钥的使用量...${NC}"
    local reset_response=$(send_request "/admin/reset-usage" "POST" "{\"key\":\"$test_key\"}")
    echo "响应: $reset_response"
    
    if echo "$reset_response" | jq -e '.success == true' > /dev/null; then
        echo -e "${GREEN}✓ 重置特定密钥成功${NC}"
    else
        echo -e "${RED}✗ 重置特定密钥失败${NC}"
        return 1
    fi
    
    # 5. 验证使用量已重置
    echo -e "${YELLOW}5. 验证使用量已重置...${NC}"
    sleep 1
    local usage_after=$(send_request "/admin/usage?key=$test_key" "GET")
    local used_quota_after=$(echo "$usage_after" | jq -r '.data[0].used_quota // 0')
    
    if [ "$used_quota_after" -eq 0 ]; then
        echo -e "${GREEN}✓ 使用量已成功重置为 0${NC}"
    else
        echo -e "${RED}✗ 使用量重置失败: 当前为 $used_quota_after${NC}"
        return 1
    fi
    
    # 6. 重置所有密钥的使用量
    echo -e "${YELLOW}6. 重置所有密钥的使用量...${NC}"
    local reset_all_response=$(send_request "/admin/reset-usage" "POST" "{}")
    echo "响应: $reset_all_response"
    
    if echo "$reset_all_response" | jq -e '.success == true' > /dev/null; then
        echo -e "${GREEN}✓ 重置所有密钥成功${NC}"
    else
        echo -e "${RED}✗ 重置所有密钥失败${NC}"
        return 1
    fi
    
    # 7. 测试带 reset_logs 参数的请求
    echo -e "${YELLOW}7. 测试带 reset_logs 参数的请求...${NC}"
    local reset_with_logs_response=$(send_request "/admin/reset-usage" "POST" "{\"key\":\"$test_key\",\"reset_logs\":true}")
    echo "响应: $reset_with_logs_response"
    
    if echo "$reset_with_logs_response" | jq -e '.success == true' > /dev/null; then
        echo -e "${GREEN}✓ 带日志重置的请求成功${NC}"
    else
        echo -e "${YELLOW}⚠ 带日志重置的请求可能失败（可能是没有日志可删除）${NC}"
    fi
    
    # 8. 清理测试密钥
    echo -e "${YELLOW}8. 清理测试密钥...${NC}"
    local delete_response=$(send_request "/admin/keys/$test_key" "DELETE")
    
    if echo "$delete_response" | jq -e '.success == true' > /dev/null; then
        echo -e "${GREEN}✓ 测试密钥清理成功${NC}"
    else
        echo -e "${YELLOW}⚠ 测试密钥清理失败: $delete_response${NC}"
    fi
    
    echo -e "${GREEN}=== 所有验证通过 ===${NC}"
    return 0
}

# 主函数
main() {
    check_dependencies
    
    echo -e "${GREEN}验证配置:${NC}"
    echo "  BASE_URL:    $BASE_URL"
    echo "  ADMIN_TOKEN: ${ADMIN_TOKEN:0:10}..."
    
    # 检查服务是否可用
    echo -e "${YELLOW}检查服务健康状态...${NC}"
    if curl -fsS "$BASE_URL/healthz" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务健康检查通过${NC}"
    else
        echo -e "${RED}✗ 服务不可用或健康检查失败${NC}"
        exit 1
    fi
    
    # 运行验证
    if verify_endpoint; then
        echo -e "${GREEN}✅ POST /admin/reset-usage 端点验证成功${NC}"
        exit 0
    else
        echo -e "${RED}❌ POST /admin/reset-usage 端点验证失败${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"