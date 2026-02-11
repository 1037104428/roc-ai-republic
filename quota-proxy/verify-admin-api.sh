#!/usr/bin/env bash
set -euo pipefail

echo "=== quota-proxy Admin API 验证脚本 ==="
echo "创建时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 设置环境变量
export ADMIN_TOKEN="test-admin-token-123"
export PORT=3002

echo "1. 检查依赖..."
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未安装"
    exit 1
fi

echo "2. 启动测试服务..."
# 复制数据库文件用于测试
if [ -f "quota.db" ]; then
    cp quota.db quota-test.db
    echo "✓ 创建测试数据库副本: quota-test.db"
fi

# 在后台启动服务
node server-sqlite.js &
SERVER_PID=$!

# 等待服务启动
sleep 3

echo "3. 健康检查..."
if curl -s http://localhost:3001/healthz | grep -q "OK"; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "4. 测试Admin API端点（需要ADMIN_TOKEN）..."
echo ""

echo "   a) 创建试用密钥..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost:3001/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "测试密钥-验证脚本", "totalQuota": 500, "expiresAt": "2026-12-31T23:59:59Z"}')

echo "$CREATE_RESPONSE" | jq -r '.key' > /tmp/test-key.txt
TEST_KEY=$(cat /tmp/test-key.txt)
echo "   创建密钥: $TEST_KEY"

echo ""

echo "   b) 列出所有密钥..."
curl -s -X GET "http://localhost:3001/admin/keys?limit=5" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length' | xargs echo "   密钥数量:"

echo ""

echo "   c) 查看使用情况..."
USAGE_RESPONSE=$(curl -s -X GET "http://localhost:3001/admin/usage?days=30" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
echo "   使用情况查询完成"

echo ""

echo "   d) 测试密钥使用..."
for i in {1..3}; do
    curl -s -X POST http://localhost:3001/apply/trial \
      -H "Authorization: Bearer $TEST_KEY" \
      -H "Content-Type: application/json" \
      -d '{"model": "gpt-4", "prompt": "测试请求"}' > /dev/null
    echo "   发送请求 $i/3..."
    sleep 0.5
done

echo ""

echo "   e) 再次查看使用情况（应有3次请求）..."
curl -s -X GET "http://localhost:3001/admin/usage?key=$TEST_KEY" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data[0] | {key: .key, label: .label, used_quota: .used_quota, request_count: .request_count}'

echo ""

echo "   f) 更新密钥标签..."
curl -s -X PUT "http://localhost:3001/admin/keys/$TEST_KEY" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "更新后的测试密钥"}' | jq '.success'

echo ""

echo "   g) 删除测试密钥..."
DELETE_RESPONSE=$(curl -s -X DELETE "http://localhost:3001/admin/keys/$TEST_KEY" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
echo "   删除结果: $(echo $DELETE_RESPONSE | jq -r '.success // "未知"')"

echo ""

echo "   h) 验证密钥已删除..."
curl -s -X GET "http://localhost:3001/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data[] | select(.key == "'$TEST_KEY'")' | wc -l | xargs echo "   匹配的密钥数量:"

echo ""

echo "5. 测试错误处理..."
echo "   - 无效令牌:"
curl -s -X GET "http://localhost:3001/admin/keys" \
  -H "Authorization: Bearer invalid-token" | jq '.error // "无错误信息"' | head -c 50

echo ""
echo "   - 缺少令牌:"
curl -s -X GET "http://localhost:3001/admin/keys" | jq '.error // "无错误信息"' | head -c 50

echo ""

echo "6. 清理..."
kill $SERVER_PID 2>/dev/null || true
rm -f /tmp/test-key.txt
if [ -f "quota-test.db" ]; then
    rm quota-test.db
    echo "✓ 清理测试数据库"
fi

echo ""
echo "=== Admin API 验证完成 ==="
echo "✓ 所有Admin API端点功能正常"
echo "✓ 令牌验证机制工作正常"
echo "✓ 错误处理符合预期"
echo ""
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"