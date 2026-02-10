#!/bin/bash
set -euo pipefail

# 检查 quota-proxy 管理接口健康状态
# 用法: ./scripts/check-admin-health.sh [--host HOST] [--token TOKEN]
# 默认: host=127.0.0.1:8787, token=$ADMIN_TOKEN 环境变量

HOST="${HOST:-127.0.0.1:8787}"
TOKEN="${ADMIN_TOKEN:-}"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --host)
      HOST="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [--host HOST] [--token TOKEN]"
      echo "检查 quota-proxy 管理接口健康状态"
      echo "环境变量: ADMIN_TOKEN (可选)"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "错误: 需要 ADMIN_TOKEN 环境变量或 --token 参数"
  echo "提示: export ADMIN_TOKEN='your-admin-token'"
  exit 1
fi

echo "检查 quota-proxy 管理接口健康状态..."
echo "主机: $HOST"
echo ""

# 1. 检查基础健康
echo "1. 基础健康检查 (/healthz):"
if curl -fsS "http://$HOST/healthz"; then
  echo "✅ 基础健康正常"
else
  echo "❌ 基础健康检查失败"
  exit 1
fi

echo ""

# 2. 检查管理接口鉴权
echo "2. 管理接口鉴权检查 (/admin/keys):"
if curl -fsS "http://$HOST/admin/keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"; then
  echo "✅ 管理接口鉴权正常"
else
  echo "❌ 管理接口鉴权失败 (可能 token 无效或权限不足)"
  exit 1
fi

echo ""

# 3. 检查使用情况接口
echo "3. 使用情况接口检查 (/admin/usage):"
if curl -fsS "http://$HOST/admin/usage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq -r '. | "✅ 使用情况接口正常 (模式: \(.mode), 条目数: \(.items | length))"'; then
  echo ""
else
  echo "❌ 使用情况接口失败"
  exit 1
fi

echo ""
echo "✅ 所有管理接口检查通过"