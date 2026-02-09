#!/bin/bash
set -e

# 验证 quota-proxy 管理端点的简单脚本
# 用法: ./scripts/verify-admin-endpoints.sh [--host HOST] [--token TOKEN]
# 默认使用本地 127.0.0.1:8787，需要 ADMIN_TOKEN 环境变量

HOST="${1:-127.0.0.1:8787}"
TOKEN="${ADMIN_TOKEN:-}"

if [ -z "$TOKEN" ]; then
    echo "错误: 需要设置 ADMIN_TOKEN 环境变量"
    echo "示例: export ADMIN_TOKEN='your-admin-token'"
    exit 1
fi

echo "验证 quota-proxy 管理端点 ($HOST)"
echo "======================================"

# 1. 健康检查
echo "1. 健康检查 /healthz:"
curl -fsS "http://$HOST/healthz" || {
    echo "健康检查失败"
    exit 1
}
echo "✓ 健康检查通过"
echo

# 2. 获取使用情况
echo "2. 获取使用情况 /admin/usage:"
curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/usage" | jq -r '.items | length' | {
    read count
    echo "当前有 $count 个 key"
}
echo "✓ 使用情况查询通过"
echo

# 3. 创建测试 key
echo "3. 创建测试 key /admin/keys:"
label="test-$(date +%Y%m%d-%H%M%S)"
response=$(curl -fsS -X POST -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"label\":\"$label\"}" \
    "http://$HOST/admin/keys")
echo "创建 key: $label"
key=$(echo "$response" | jq -r '.key // empty')
if [ -n "$key" ]; then
    echo "✓ Key 创建成功: ${key:0:20}..."
else
    echo "⚠ Key 创建可能失败，响应: $response"
fi
echo

# 4. 再次获取使用情况验证
echo "4. 验证 key 已添加:"
curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/usage" | \
    jq -r --arg label "$label" '.items[] | select(.label == $label) | "找到: \(.label) (用量: \(.used)/\(.limit))"' || \
    echo "⚠ 未找到新创建的 key"
echo

echo "======================================"
echo "所有管理端点验证完成"
echo "提示: 如需清理测试 key，运行:"
echo "  curl -X DELETE -H \"Authorization: Bearer \$ADMIN_TOKEN\" \"http://$HOST/admin/keys/$key\""
echo "或重置所有用量:"
echo "  curl -X POST -H \"Authorization: Bearer \$ADMIN_TOKEN\" \"http://$HOST/admin/usage/reset\""