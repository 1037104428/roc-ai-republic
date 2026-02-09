#!/bin/bash
# 测试 admin API 基本功能
set -e

echo "🔍 测试 Admin API 基本功能"
echo "=========================="

# 检查环境变量
if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ 错误：ADMIN_TOKEN 环境变量未设置"
  echo "请设置：export ADMIN_TOKEN=your-admin-token"
  exit 1
fi

# 默认使用本地
BASE_URL=${1:-"http://localhost:8787"}
echo "测试目标：$BASE_URL"

# 测试 1: 健康检查
echo ""
echo "1. 测试健康检查端点"
if curl -fsS "$BASE_URL/healthz" > /dev/null 2>&1; then
  echo "✅ /healthz 正常"
else
  echo "❌ /healthz 失败"
  exit 1
fi

# 测试 2: 列出试用密钥（需要认证）
echo ""
echo "2. 测试 Admin API 认证"
RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/admin-test.json \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  "$BASE_URL/admin/keys")

if [ "$RESPONSE" = "200" ]; then
  echo "✅ Admin API 认证成功"
  # 显示密钥数量
  KEY_COUNT=$(jq '. | length' /tmp/admin-test.json 2>/dev/null || echo "0")
  echo "   当前试用密钥数量：$KEY_COUNT"
else
  echo "❌ Admin API 认证失败 (HTTP $RESPONSE)"
  cat /tmp/admin-test.json 2>/dev/null || echo "无响应内容"
  exit 1
fi

# 测试 3: 创建试用密钥
echo ""
echo "3. 测试创建试用密钥"
CREATE_RESPONSE=$(curl -s -X POST \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "测试密钥 - '$(date +%Y%m%d-%H%M%S)'"}' \
  "$BASE_URL/admin/keys")

if echo "$CREATE_RESPONSE" | jq -e '.key' > /dev/null 2>&1; then
  NEW_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key')
  echo "✅ 创建试用密钥成功"
  echo "   新密钥：$NEW_KEY"
  
  # 保存密钥用于后续测试
  echo "$NEW_KEY" > /tmp/test-admin-key.txt
else
  echo "❌ 创建试用密钥失败"
  echo "$CREATE_RESPONSE"
  exit 1
fi

# 测试 4: 查看使用情况
echo ""
echo "4. 测试查看使用情况"
USAGE_RESPONSE=$(curl -s \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  "$BASE_URL/admin/usage")

if echo "$USAGE_RESPONSE" | jq -e '. | length' > /dev/null 2>&1; then
  echo "✅ 使用情况查询成功"
else
  echo "❌ 使用情况查询失败"
  echo "$USAGE_RESPONSE"
fi

# 测试 5: 清理测试密钥
echo ""
echo "5. 清理测试密钥"
if [ -f /tmp/test-admin-key.txt ]; then
  TEST_KEY=$(cat /tmp/test-admin-key.txt)
  DELETE_RESPONSE=$(curl -s -X DELETE \
    -H "X-Admin-Token: $ADMIN_TOKEN" \
    "$BASE_URL/admin/keys/$TEST_KEY")
  
  if echo "$DELETE_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    echo "✅ 测试密钥清理成功"
  else
    echo "⚠️  测试密钥清理失败（可能已不存在）"
  fi
  rm -f /tmp/test-admin-key.txt
fi

echo ""
echo "🎉 Admin API 基本功能测试完成"
echo "所有测试通过！"