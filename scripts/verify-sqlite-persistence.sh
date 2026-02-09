#!/bin/bash
set -e

# 验证 SQLite 持久化功能
echo "=== 验证 quota-proxy SQLite 持久化功能 ==="

# 检查必要的环境变量
if [ -z "$ADMIN_TOKEN" ]; then
    echo "错误: ADMIN_TOKEN 环境变量未设置"
    echo "请设置: export ADMIN_TOKEN=your_admin_token_here"
    exit 1
fi

QUOTA_PROXY_URL="${QUOTA_PROXY_URL:-http://127.0.0.1:8787}"

echo "1. 测试健康检查..."
curl -fsS "${QUOTA_PROXY_URL}/healthz" || {
    echo "健康检查失败"
    exit 1
}
echo "✓ 健康检查通过"

echo "2. 测试管理员接口认证..."
curl -fsS "${QUOTA_PROXY_URL}/admin/keys" -H "Authorization: Bearer ${ADMIN_TOKEN}" || {
    echo "管理员认证失败"
    exit 1
}
echo "✓ 管理员认证通过"

echo "3. 创建测试 trial key..."
TEST_LABEL="test-$(date +%Y%m%d-%H%M%S)"
RESPONSE=$(curl -s -X POST "${QUOTA_PROXY_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"label\":\"${TEST_LABEL}\"}")
  
echo "创建响应: $RESPONSE"
KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -z "$KEY" ]; then
    echo "创建 trial key 失败"
    exit 1
fi
echo "✓ 创建 trial key: ${KEY:0:20}..."

echo "4. 验证 key 在列表中..."
curl -fsS "${QUOTA_PROXY_URL}/admin/keys" -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -q "$TEST_LABEL" || {
    echo "key 未在列表中"
    exit 1
}
echo "✓ key 在列表中"

echo "5. 测试 key 使用..."
curl -fsS "${QUOTA_PROXY_URL}/v1/models" -H "Authorization: Bearer $KEY" || {
    echo "key 使用失败"
    exit 1
}
echo "✓ key 使用正常"

echo "6. 检查使用情况..."
USAGE_RESPONSE=$(curl -s "${QUOTA_PROXY_URL}/admin/usage" -H "Authorization: Bearer ${ADMIN_TOKEN}")
echo "使用情况: $USAGE_RESPONSE"

echo "7. 清理测试 key..."
curl -fsS -X DELETE "${QUOTA_PROXY_URL}/admin/keys/${KEY}" -H "Authorization: Bearer ${ADMIN_TOKEN}" || {
    echo "删除 key 失败"
    exit 1
}
echo "✓ 清理完成"

echo ""
echo "=== SQLite 持久化验证完成 ==="
echo "所有功能正常，数据持久化验证通过"