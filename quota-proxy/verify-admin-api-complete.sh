#!/bin/bash

# Admin API 完整功能验证脚本
# 验证 POST /admin/keys 和 GET /admin/usage 端点的完整功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Admin API 完整功能验证脚本${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查必需的环境变量
echo -e "\n${YELLOW}[1/6] 检查环境变量配置...${NC}"

if [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}✗ 错误: ADMIN_TOKEN 环境变量未设置${NC}"
    echo -e "请设置 ADMIN_TOKEN 环境变量:"
    echo -e "  export ADMIN_TOKEN=\"your-admin-token-here\""
    exit 1
fi

if [ -z "$QUOTA_PROXY_URL" ]; then
    QUOTA_PROXY_URL="http://localhost:8787"
    echo -e "${YELLOW}⚠ 警告: QUOTA_PROXY_URL 未设置，使用默认值: $QUOTA_PROXY_URL${NC}"
fi

echo -e "${GREEN}✓ ADMIN_TOKEN 已设置${NC}"
echo -e "${GREEN}✓ QUOTA_PROXY_URL: $QUOTA_PROXY_URL${NC}"

# 检查配额代理服务是否运行
echo -e "\n${YELLOW}[2/6] 检查配额代理服务状态...${NC}"

if ! curl -s "$QUOTA_PROXY_URL/healthz" > /dev/null 2>&1; then
    echo -e "${RED}✗ 错误: 配额代理服务未运行或无法访问${NC}"
    echo -e "请确保配额代理服务正在运行:"
    echo -e "  cd /opt/roc/quota-proxy && docker compose up -d"
    exit 1
fi

echo -e "${GREEN}✓ 配额代理服务运行正常${NC}"

# 验证 Admin API 端点存在性
echo -e "\n${YELLOW}[3/6] 验证 Admin API 端点存在性...${NC}"

# 检查 POST /admin/keys 端点
if ! curl -s -X POST "$QUOTA_PROXY_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"test": "ping"}' 2>/dev/null | grep -q "Missing required parameters\|label\|daily_limit"; then
    echo -e "${RED}✗ 错误: POST /admin/keys 端点未正确响应${NC}"
else
    echo -e "${GREEN}✓ POST /admin/keys 端点存在${NC}"
fi

# 检查 GET /admin/usage 端点
if ! curl -s -X GET "$QUOTA_PROXY_URL/admin/usage" \
    -H "Authorization: Bearer $ADMIN_TOKEN" 2>/dev/null | grep -q "success\|usage\|trial_keys"; then
    echo -e "${RED}✗ 错误: GET /admin/usage 端点未正确响应${NC}"
else
    echo -e "${GREEN}✓ GET /admin/usage 端点存在${NC}"
fi

# 测试生成试用密钥
echo -e "\n${YELLOW}[4/6] 测试生成试用密钥 (POST /admin/keys)...${NC}"

TEST_LABEL="验证脚本测试密钥-$(date +%Y%m%d-%H%M%S)"
TEST_DAILY_LIMIT=50

RESPONSE=$(curl -s -X POST "$QUOTA_PROXY_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"label\": \"$TEST_LABEL\", \"daily_limit\": $TEST_DAILY_LIMIT}")

if echo "$RESPONSE" | grep -q '"success":true'; then
    TRIAL_KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 成功生成试用密钥${NC}"
    echo -e "  密钥: ${BLUE}$TRIAL_KEY${NC}"
    echo -e "  标签: ${BLUE}$TEST_LABEL${NC}"
    echo -e "  每日限制: ${BLUE}$TEST_DAILY_LIMIT${NC}"
else
    echo -e "${RED}✗ 生成试用密钥失败${NC}"
    echo -e "  响应: $RESPONSE"
    exit 1
fi

# 测试获取使用统计
echo -e "\n${YELLOW}[5/6] 测试获取使用统计 (GET /admin/usage)...${NC}"

USAGE_RESPONSE=$(curl -s -X GET "$QUOTA_PROXY_URL/admin/usage?days=1" \
    -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$USAGE_RESPONSE" | grep -q '"success":true\|usage\|trial_keys'; then
    echo -e "${GREEN}✓ 成功获取使用统计${NC}"
    
    # 检查是否包含新生成的密钥
    if echo "$USAGE_RESPONSE" | grep -q "$TRIAL_KEY"; then
        echo -e "${GREEN}✓ 新生成的密钥已在使用统计中${NC}"
    else
        echo -e "${YELLOW}⚠ 警告: 新生成的密钥未在使用统计中找到（可能需要等待数据同步）${NC}"
    fi
else
    echo -e "${RED}✗ 获取使用统计失败${NC}"
    echo -e "  响应: $USAGE_RESPONSE"
fi

# 测试带密钥过滤的使用统计
echo -e "\n${YELLOW}[6/6] 测试带密钥过滤的使用统计...${NC}"

FILTERED_RESPONSE=$(curl -s -X GET "$QUOTA_PROXY_URL/admin/usage?key=$TRIAL_KEY&days=7" \
    -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$FILTERED_RESPONSE" | grep -q "$TRIAL_KEY"; then
    echo -e "${GREEN}✓ 密钥过滤功能正常${NC}"
else
    echo -e "${YELLOW}⚠ 警告: 密钥过滤功能可能有问题${NC}"
fi

# 验证总结
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Admin API 验证总结${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${GREEN}✓ 环境变量配置检查完成${NC}"
echo -e "${GREEN}✓ 配额代理服务状态检查完成${NC}"
echo -e "${GREEN}✓ Admin API 端点存在性验证完成${NC}"
echo -e "${GREEN}✓ 试用密钥生成功能测试完成${NC}"
echo -e "${GREEN}✓ 使用统计获取功能测试完成${NC}"
echo -e "${GREEN}✓ 密钥过滤功能测试完成${NC}"

echo -e "\n${BLUE}测试生成的试用密钥信息:${NC}"
echo -e "  密钥: ${BLUE}$TRIAL_KEY${NC}"
echo -e "  标签: ${BLUE}$TEST_LABEL${NC}"
echo -e "  每日限制: ${BLUE}$TEST_DAILY_LIMIT${NC}"

echo -e "\n${YELLOW}使用说明:${NC}"
echo -e "1. 生成新试用密钥:"
echo -e "   curl -X POST '$QUOTA_PROXY_URL/admin/keys' \\"
echo -e "     -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
echo -e "     -H 'Content-Type: application/json' \\"
echo -e "     -d '{\"label\": \"用户描述\", \"daily_limit\": 100}'"
echo -e ""
echo -e "2. 获取使用统计:"
echo -e "   curl -X GET '$QUOTA_PROXY_URL/admin/usage?days=7' \\"
echo -e "     -H 'Authorization: Bearer \$ADMIN_TOKEN'"
echo -e ""
echo -e "3. 过滤特定密钥使用统计:"
echo -e "   curl -X GET '$QUOTA_PROXY_URL/admin/usage?key=KEY_HERE&days=7' \\"
echo -e "     -H 'Authorization: Bearer \$ADMIN_TOKEN'"

echo -e "\n${GREEN}✅ Admin API 完整功能验证完成！${NC}"
echo -e "${BLUE}========================================${NC}"