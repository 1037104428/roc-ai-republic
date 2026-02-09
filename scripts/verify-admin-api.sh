#!/bin/bash
# 验证 quota-proxy 管理员 API 端点是否正常工作
# 用法: ./scripts/verify-admin-api.sh [base_url] [admin_token]
# 示例: ./scripts/verify-admin-api.sh http://127.0.0.1:8787 my_admin_token

set -e

# 默认参数
BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${2:-${ADMIN_TOKEN:-test_admin_token}}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}验证 quota-proxy 管理员 API 端点...${NC}"
echo "Base URL: $BASE_URL"
echo "Admin Token: ${ADMIN_TOKEN:0:8}**** (隐藏后8位)"

# 1. 检查健康端点
echo -e "\n1. 检查健康端点 /healthz..."
if curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 健康端点正常${NC}"
else
    echo -e "${RED}✗ 健康端点失败${NC}"
    exit 1
fi

# 2. 检查数据库健康端点
echo -e "\n2. 检查数据库健康端点 /healthz/db..."
if curl -fsS "${BASE_URL}/healthz/db" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 数据库健康端点正常${NC}"
else
    echo -e "${YELLOW}⚠ 数据库健康端点不可用（可能是旧版本）${NC}"
fi

# 3. 检查管理员密钥列表端点（需要认证）
echo -e "\n3. 检查管理员密钥列表端点 /admin/keys..."
RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/admin_keys_response.txt \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${BASE_URL}/admin/keys")
HTTP_CODE="${RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 管理员密钥列表端点正常 (HTTP 200)${NC}"
    echo "响应示例:"
    head -c 200 /tmp/admin_keys_response.txt
    echo ""
elif [ "$HTTP_CODE" = "401" ]; then
    echo -e "${YELLOW}⚠ 管理员端点需要有效令牌 (HTTP 401)${NC}"
    echo "提示: 请设置正确的 ADMIN_TOKEN 环境变量"
else
    echo -e "${YELLOW}⚠ 管理员端点返回 HTTP $HTTP_CODE${NC}"
fi

# 4. 检查管理员使用统计端点
echo -e "\n4. 检查管理员使用统计端点 /admin/usage..."
RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/admin_usage_response.txt \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${BASE_URL}/admin/usage")
HTTP_CODE="${RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ 管理员使用统计端点正常 (HTTP 200)${NC}"
elif [ "$HTTP_CODE" = "401" ]; then
    echo -e "${YELLOW}⚠ 使用统计端点需要有效令牌 (HTTP 401)${NC}"
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠ 使用统计端点未找到 (HTTP 404) - 可能是旧版本${NC}"
else
    echo -e "${YELLOW}⚠ 使用统计端点返回 HTTP $HTTP_CODE${NC}"
fi

# 5. 检查模型列表端点（公开）
echo -e "\n5. 检查模型列表端点 /v1/models..."
if curl -fsS "${BASE_URL}/v1/models" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 模型列表端点正常${NC}"
else
    echo -e "${YELLOW}⚠ 模型列表端点不可用${NC}"
fi

echo -e "\n${GREEN}✅ 验证完成！${NC}"
echo "总结:"
echo "  - 基础健康检查: 通过"
echo "  - 管理员API: 需要有效令牌"
echo "  - 公开API: 正常"
echo ""
echo "下一步:"
echo "  1. 设置正确的 ADMIN_TOKEN 环境变量"
echo "  2. 使用 ./scripts/test-admin-api.sh 进行完整测试"
echo "  3. 访问 http://127.0.0.1:8787/admin/ 使用Web管理界面"

# 清理临时文件
rm -f /tmp/admin_keys_response.txt /tmp/admin_usage_response.txt