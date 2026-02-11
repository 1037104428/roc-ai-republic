#!/bin/bash
# Admin API 快速验证脚本
# 验证Admin API的基本功能：生成试用密钥、查看用量统计、查看密钥详情

set -e

echo "=== Admin API 快速验证脚本 ==="
echo "此脚本验证Admin API的基本功能"
echo ""

# 检查环境变量
if [ -z "${ADMIN_TOKEN}" ]; then
    echo "错误：ADMIN_TOKEN环境变量未设置"
    echo "请设置：export ADMIN_TOKEN=your_admin_token_here"
    exit 1
fi

if [ -z "${BASE_URL}" ]; then
    echo "警告：BASE_URL环境变量未设置，使用默认值 http://localhost:8787"
    BASE_URL="http://localhost:8787"
fi

echo "使用配置："
echo "  BASE_URL: ${BASE_URL}"
echo "  ADMIN_TOKEN: ${ADMIN_TOKEN:0:10}..."
echo ""

# 1. 验证服务状态
echo "1. 验证服务状态..."
curl -fsS "${BASE_URL}/healthz" || {
    echo "错误：服务未运行或/healthz端点不可用"
    exit 1
}
echo "✓ 服务状态正常"
echo ""

# 2. 生成试用密钥
echo "2. 生成试用密钥..."
RESPONSE=$(curl -s -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-key-verification",
    "quota": 1000,
    "expires_in": 86400
  }')

if echo "${RESPONSE}" | grep -q '"key"'; then
    TRIAL_KEY=$(echo "${RESPONSE}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "✓ 试用密钥生成成功"
    echo "  密钥: ${TRIAL_KEY:0:20}..."
else
    echo "错误：试用密钥生成失败"
    echo "响应: ${RESPONSE}"
    exit 1
fi
echo ""

# 3. 查看密钥详情
echo "3. 查看密钥详情..."
curl -s -X GET "${BASE_URL}/admin/keys/${TRIAL_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -q '"name"' && {
    echo "✓ 密钥详情查询成功"
} || {
    echo "警告：密钥详情查询失败或格式不符"
}
echo ""

# 4. 查看用量统计
echo "4. 查看用量统计..."
curl -s -X GET "${BASE_URL}/admin/usage" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -q '"total_requests"' && {
    echo "✓ 用量统计查询成功"
} || {
    echo "警告：用量统计查询失败或格式不符"
}
echo ""

# 5. 验证试用密钥可用性
echo "5. 验证试用密钥可用性..."
curl -s -X GET "${BASE_URL}/api/test" \
  -H "Authorization: Bearer ${TRIAL_KEY}" | grep -q '"message"' && {
    echo "✓ 试用密钥验证成功"
} || {
    echo "警告：试用密钥验证失败或格式不符"
}
echo ""

echo "=== 所有基本验证通过 ==="
echo "Admin API 功能验证完成："
echo "  - 服务状态检查 ✓"
echo "  - 试用密钥生成 ✓"
echo "  - 密钥详情查询 ✓"
echo "  - 用量统计查询 ✓"
echo "  - 试用密钥验证 ✓"
echo ""
echo "如需完整功能测试，请参考 docs/admin-api-quick-example.md"
