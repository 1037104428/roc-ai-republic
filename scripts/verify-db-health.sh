#!/bin/bash
set -e

# 验证 quota-proxy 数据库健康检查端点
# 用法：./scripts/verify-db-health.sh [--host HOST] [--admin-token TOKEN]

HOST="http://127.0.0.1:8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)
      HOST="$2"
      shift 2
      ;;
    --admin-token)
      ADMIN_TOKEN="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: $0 [--host HOST] [--admin-token TOKEN]"
      exit 1
      ;;
  esac
done

echo "🔍 验证数据库健康检查端点: $HOST/healthz/db"

# 检查健康端点
response=$(curl -fsS -m 10 "$HOST/healthz/db" 2>/dev/null || true)

if [[ -z "$response" ]]; then
  echo "❌ 无法连接到 $HOST/healthz/db"
  exit 1
fi

echo "✅ 数据库健康检查响应:"
echo "$response" | jq . 2>/dev/null || echo "$response"

# 如果有管理员令牌，检查更详细的统计
if [[ -n "$ADMIN_TOKEN" ]]; then
  echo ""
  echo "🔍 使用管理员令牌检查数据库统计..."
  
  # 检查 /admin/usage 端点（包含数据库统计）
  admin_response=$(curl -fsS -m 10 -H "Authorization: Bearer $ADMIN_TOKEN" "$HOST/admin/usage" 2>/dev/null || true)
  
  if [[ -n "$admin_response" ]]; then
    echo "✅ 管理员统计响应:"
    echo "$admin_response" | jq . 2>/dev/null || echo "$admin_response"
  else
    echo "⚠️  无法获取管理员统计（可能需要有效令牌）"
  fi
fi

echo ""
echo "📊 数据库健康检查完成"