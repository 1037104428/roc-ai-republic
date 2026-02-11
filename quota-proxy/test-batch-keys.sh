#!/bin/bash
# 批量生成试用密钥测试脚本
# 用法: ./test-batch-keys.sh [count]

set -e

# 配置
BASE_URL="${BASE_URL:-http://localhost:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
COUNT="${1:-3}"

echo "=== 批量生成试用密钥测试 ==="
echo "目标: 生成 $COUNT 个试用密钥"
echo "API端点: $BASE_URL/admin/keys"
echo ""

# 测试单个密钥生成
echo "1. 测试单个密钥生成:"
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "单个测试密钥"}' | jq . || echo "响应: $(curl -s -X POST "$BASE_URL/admin/keys" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"label": "单个测试密钥"}')"

echo ""
echo "2. 测试批量密钥生成 ($COUNT 个):"
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"count\": $COUNT, \"label\": \"批量测试\", \"prefix\": \"batch_test_\"}" | jq . || echo "响应: $(curl -s -X POST "$BASE_URL/admin/keys" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d "{\"count\": $COUNT, \"label\": \"批量测试\", \"prefix\": \"batch_test_\"}")"

echo ""
echo "3. 验证密钥列表:"
curl -s "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.keys | length' | xargs echo "当前密钥总数:"

echo ""
echo "=== 测试完成 ==="
echo "批量生成功能测试完毕。如果看到密钥数量和预期一致，说明功能正常。"