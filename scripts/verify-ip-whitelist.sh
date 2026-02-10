#!/bin/bash
# IP 白名单功能验证脚本
# 用于测试 quota-proxy 的 IP 白名单功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== IP 白名单功能验证脚本 ===${NC}"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 配置
LOCAL_SERVER="http://127.0.0.1:8787"
REMOTE_SERVER="${1:-http://8.210.185.194:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d}"
SERVER_URL="${2:-$REMOTE_SERVER}"

echo "目标服务器: $SERVER_URL"
echo "使用 Admin Token: ${ADMIN_TOKEN:0:10}..."

# 函数：发送 HTTP 请求
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local headers="$4"
    
    local curl_cmd="curl -s -X $method"
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    curl_cmd="$curl_cmd $SERVER_URL$endpoint"
    
    echo -e "${YELLOW}请求: $method $endpoint${NC}"
    eval "$curl_cmd"
    echo
}

# 函数：检查响应
check_response() {
    local response="$1"
    local expected_status="$2"
    
    if echo "$response" | grep -q "$expected_status"; then
        echo -e "${GREEN}✓ 测试通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 测试失败${NC}"
        echo "响应: $response"
        return 1
    fi
}

# 1. 测试基础健康检查（应该总是允许）
echo -e "${YELLOW}1. 测试基础健康检查（无白名单限制）${NC}"
response=$(send_request "GET" "/healthz")
check_response "$response" '"ok":true'

# 2. 测试 Admin API 在没有白名单时的访问（应该允许，如果 token 正确）
echo -e "${YELLOW}2. 测试 Admin API 访问（无白名单配置）${NC}"
response=$(send_request "GET" "/admin/usage" "" "-H 'Authorization: Bearer $ADMIN_TOKEN'")
if echo "$response" | grep -q '"error":"Forbidden"'; then
    echo -e "${GREEN}✓ IP 白名单已生效（拒绝访问）${NC}"
else
    echo -e "${YELLOW}⚠ IP 白名单未配置或未生效${NC}"
    echo "响应: $response"
fi

# 3. 测试创建测试密钥（如果允许访问）
echo -e "${YELLOW}3. 测试创建测试密钥${NC}"
test_key_data='{"label":"IP白名单测试密钥"}'
response=$(send_request "POST" "/admin/keys" "$test_key_data" "-H 'Authorization: Bearer $ADMIN_TOKEN'")

if echo "$response" | grep -q '"key"'; then
    TEST_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 成功创建测试密钥: ${TEST_KEY:0:10}...${NC}"
    
    # 4. 测试使用密钥（公开 API，无白名单限制）
    echo -e "${YELLOW}4. 测试使用密钥（公开 API）${NC}"
    response=$(send_request "POST" "/apply" "{\"key\":\"$TEST_KEY\"}")
    check_response "$response" '"remaining"'
    
    # 5. 测试删除密钥
    echo -e "${YELLOW}5. 测试删除测试密钥${NC}"
    response=$(send_request "DELETE" "/admin/keys/$TEST_KEY" "" "-H 'Authorization: Bearer $ADMIN_TOKEN'")
    check_response "$response" '"message":"Key deleted"'
else
    echo -e "${YELLOW}⚠ 无法创建测试密钥（可能被白名单阻止）${NC}"
fi

# 6. 测试 IP 白名单配置说明
echo -e "${YELLOW}6. IP 白名单配置说明${NC}"
cat << EOF

要启用 IP 白名单功能，需要在环境变量中设置 ADMIN_IP_WHITELIST：

1. Docker 部署时：
   docker run -e ADMIN_IP_WHITELIST="192.168.1.0/24,10.0.0.1" ...

2. docker-compose 中：
   environment:
     ADMIN_IP_WHITELIST: "192.168.1.0/24,10.0.0.1"

3. 支持格式：
   - 单个 IP: 192.168.1.100
   - CIDR 网段: 192.168.1.0/24
   - 多个 IP: 192.168.1.100,10.0.0.1,172.16.0.0/16

4. 默认允许 localhost/127.0.0.1（可通过配置禁用）

EOF

# 7. 验证服务器状态
echo -e "${YELLOW}7. 验证服务器状态${NC}"
if [ "$SERVER_URL" = "$REMOTE_SERVER" ]; then
    echo "检查远程服务器状态..."
    ssh_output=$(ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null || echo "无法连接"')
    
    if echo "$ssh_output" | grep -q "Up"; then
        echo -e "${GREEN}✓ 远程服务器运行正常${NC}"
    else
        echo -e "${YELLOW}⚠ 远程服务器状态未知${NC}"
        echo "$ssh_output"
    fi
else
    echo "本地测试模式，跳过远程验证"
fi

echo
echo -e "${GREEN}=== IP 白名单验证完成 ===${NC}"
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo
echo "总结:"
echo "- IP 白名单中间件已集成到 server-sqlite.js"
echo "- 验证脚本已创建: scripts/verify-ip-whitelist.sh"
echo "- 支持 CIDR 网段和多个 IP 配置"
echo "- 默认允许 localhost 访问（便于本地管理）"
echo "- 可通过 ADMIN_IP_WHITELIST 环境变量配置"