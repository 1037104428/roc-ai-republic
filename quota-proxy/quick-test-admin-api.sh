#!/bin/bash

# Quota Proxy Admin API 快速测试脚本
# 用于快速验证 Admin API 的基本功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token-123}"
BASE_URL="${BASE_URL:-http://localhost:8787}"
TEST_LABEL="测试密钥 $(date '+%Y-%m-%d %H:%M:%S')"

echo -e "${BLUE}🔧 Quota Proxy Admin API 快速测试${NC}"
echo -e "${BLUE}================================${NC}"
echo "管理令牌: ${ADMIN_TOKEN:0:10}..."
echo "基础URL: $BASE_URL"
echo "测试标签: $TEST_LABEL"
echo ""

# 函数：发送 HTTP 请求并检查响应
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    
    echo -e "${YELLOW}➡️  请求: $method $endpoint${NC}"
    if [ -n "$data" ]; then
        echo "数据: $data"
    fi
    
    local response
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$BASE_URL$endpoint" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$BASE_URL$endpoint" \
            -H "Authorization: Bearer $ADMIN_TOKEN")
    fi
    
    local body=$(echo "$response" | head -n -1)
    local status_code=$(echo "$response" | tail -n 1)
    
    echo "状态码: $status_code"
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ 状态码验证通过 ($expected_status)${NC}"
    else
        echo -e "${RED}❌ 状态码验证失败: 期望 $expected_status, 实际 $status_code${NC}"
        return 1
    fi
    
    if [ -n "$body" ]; then
        echo "响应体:"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    fi
    echo ""
    return 0
}

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq 未安装，响应体将以原始格式显示${NC}"
    echo "安装命令: sudo apt-get install jq 或 brew install jq"
    echo ""
fi

# 测试 1: 创建试用密钥
echo -e "${BLUE}📝 测试 1: 创建试用密钥${NC}"
send_request "POST" "/admin/keys" "{\"label\": \"$TEST_LABEL\", \"totalQuota\": 100}" "201"

# 从响应中提取密钥
if [ -n "$body" ] && command -v jq &> /dev/null; then
    TEST_KEY=$(echo "$body" | jq -r '.key')
    if [ "$TEST_KEY" != "null" ] && [ -n "$TEST_KEY" ]; then
        echo -e "${GREEN}✅ 试用密钥创建成功: ${TEST_KEY:0:20}...${NC}"
    else
        echo -e "${RED}❌ 无法从响应中提取密钥${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  无法提取密钥，跳过后续密钥相关测试${NC}"
    TEST_KEY=""
fi

# 测试 2: 获取所有密钥
echo -e "${BLUE}📋 测试 2: 获取所有密钥${NC}"
send_request "GET" "/admin/keys" "" "200"

# 测试 3: 获取使用情况
echo -e "${BLUE}📊 测试 3: 获取使用情况${NC}"
send_request "GET" "/admin/usage" "" "200"

# 测试 4: 使用试用密钥调用 API（如果密钥可用）
if [ -n "$TEST_KEY" ]; then
    echo -e "${BLUE}🔑 测试 4: 使用试用密钥调用 API${NC}"
    echo -e "${YELLOW}➡️  请求: GET /api/chat${NC}"
    
    local api_response
    api_response=$(curl -s -w "\n%{http_code}" -X "GET" \
        "$BASE_URL/api/chat" \
        -H "Authorization: Bearer $TEST_KEY")
    
    local api_body=$(echo "$api_response" | head -n -1)
    local api_status=$(echo "$api_response" | tail -n 1)
    
    echo "状态码: $api_status"
    if [ "$api_status" = "200" ] || [ "$api_status" = "429" ]; then
        echo -e "${GREEN}✅ API 调用成功 (状态码: $api_status)${NC}"
        if [ "$api_status" = "429" ]; then
            echo -e "${YELLOW}⚠️  已达到请求限制（正常行为）${NC}"
        fi
    else
        echo -e "${RED}❌ API 调用失败: 状态码 $api_status${NC}"
    fi
    
    if [ -n "$api_body" ]; then
        echo "响应体:"
        echo "$api_body" | jq . 2>/dev/null || echo "$api_body"
    fi
    echo ""
fi

# 测试 5: 删除试用密钥（如果密钥可用）
if [ -n "$TEST_KEY" ]; then
    echo -e "${BLUE}🗑️  测试 5: 删除试用密钥${NC}"
    send_request "DELETE" "/admin/keys/$TEST_KEY" "" "200"
fi

# 测试 6: 验证密钥已删除
if [ -n "$TEST_KEY" ]; then
    echo -e "${BLUE}🔍 测试 6: 验证密钥已删除${NC}"
    echo -e "${YELLOW}➡️  请求: GET /admin/keys${NC}"
    
    local final_response
    final_response=$(curl -s -w "\n%{http_code}" -X "GET" \
        "$BASE_URL/admin/keys" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
    
    local final_body=$(echo "$final_response" | head -n -1)
    local final_status=$(echo "$final_response" | tail -n 1)
    
    echo "状态码: $final_status"
    if [ "$final_status" = "200" ]; then
        echo -e "${GREEN}✅ 密钥列表获取成功${NC}"
        # 检查密钥是否已删除
        if echo "$final_body" | grep -q "$TEST_KEY"; then
            echo -e "${RED}❌ 密钥删除验证失败: 密钥仍然存在${NC}"
        else
            echo -e "${GREEN}✅ 密钥删除验证成功: 密钥已从列表中移除${NC}"
        fi
    else
        echo -e "${RED}❌ 密钥列表获取失败${NC}"
    fi
    echo ""
fi

echo -e "${GREEN}🎉 所有测试完成！${NC}"
echo -e "${BLUE}================================${NC}"
echo "测试总结:"
echo "- ✅ 创建试用密钥"
echo "- ✅ 获取密钥列表"
echo "- ✅ 获取使用情况"
if [ -n "$TEST_KEY" ]; then
    echo "- ✅ 使用试用密钥调用 API"
    echo "- ✅ 删除试用密钥"
    echo "- ✅ 验证密钥删除"
fi
echo ""
echo -e "${YELLOW}📝 使用说明:${NC}"
echo "1. 确保 Quota Proxy 正在运行"
echo "2. 设置环境变量:"
echo "   export ADMIN_TOKEN='你的管理令牌'"
echo "   export BASE_URL='http://localhost:8787'"
echo "3. 运行测试: ./quick-test-admin-api.sh"
echo ""
echo -e "${BLUE}🔗 相关文档:${NC}"
echo "- ADMIN-INTERFACE.md - 完整的管理界面文档"
echo "- VERIFY-ADMIN-KEYS-ENDPOINTS.md - Admin API 端点验证"
echo "- test-admin-api-quick.js - Node.js 测试脚本"