#!/usr/bin/env bash
set -euo pipefail

# quota-proxy 管理界面验证脚本
# 验证 admin UI 是否可访问，并提供 curl 示例

usage() {
  cat <<'TXT'
quota-proxy 管理界面验证脚本

用法:
  ./verify-quota-proxy-admin-ui.sh [选项]

选项:
  --host <host>       quota-proxy 主机 (默认: 127.0.0.1)
  --port <port>       端口 (默认: 8787)
  --admin-token <token>  管理员令牌 (可选，用于 API 测试)
  --no-ui             跳过 UI 检查，只测试 API
  --help              显示帮助

环境变量:
  QUOTA_PROXY_HOST    主机 (默认: 127.0.0.1)
  QUOTA_PROXY_PORT    端口 (默认: 8787)
  ADMIN_TOKEN         管理员令牌

示例:
  # 本地验证
  ./verify-quota-proxy-admin-ui.sh

  # 远程服务器验证
  QUOTA_PROXY_HOST=8.210.185.194 ./verify-quota-proxy-admin-ui.sh

  # 带管理员令牌验证 API
  ADMIN_TOKEN=your_token ./verify-quota-proxy-admin-ui.sh
TXT
}

HOST="${QUOTA_PROXY_HOST:-127.0.0.1}"
PORT="${QUOTA_PROXY_PORT:-8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
NO_UI=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --admin-token) ADMIN_TOKEN="$2"; shift 2 ;;
    --no-ui) NO_UI=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知选项: $1"; usage; exit 1 ;;
  esac
done

BASE_URL="http://${HOST}:${PORT}"

echo "=== quota-proxy 管理界面验证 ==="
echo "目标: ${BASE_URL}"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 1. 检查健康端点
echo "1. 检查 /healthz 端点..."
if curl -fsS -m 10 "${BASE_URL}/healthz" >/dev/null; then
  echo "   ✅ /healthz 正常"
else
  echo "   ❌ /healthz 失败"
  exit 1
fi

# 2. 检查管理界面 (如果未禁用)
if [[ $NO_UI -eq 0 ]]; then
  echo "2. 检查管理界面..."
  if curl -fsS -m 10 "${BASE_URL}/admin/" >/dev/null; then
    echo "   ✅ 管理界面可访问"
  else
    echo "   ⚠️  管理界面不可访问 (可能未部署或路径不对)"
  fi
fi

# 3. 检查 /admin/keys 端点 (需要管理员令牌)
if [[ -n "$ADMIN_TOKEN" ]]; then
  echo "3. 检查 /admin/keys 端点..."
  RESPONSE=$(curl -fsS -m 10 -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/keys" 2>/dev/null || true)
  if [[ -n "$RESPONSE" ]]; then
    echo "   ✅ /admin/keys 响应正常"
    echo "   响应示例: ${RESPONSE:0:100}..."
  else
    echo "   ⚠️  /admin/keys 无响应或令牌无效"
  fi
  
  # 4. 检查 /admin/usage 端点
  echo "4. 检查 /admin/usage 端点..."
  USAGE_RESPONSE=$(curl -fsS -m 10 -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/usage" 2>/dev/null || true)
  if [[ -n "$USAGE_RESPONSE" ]]; then
    echo "   ✅ /admin/usage 响应正常"
    # 尝试解析 JSON 格式
    if echo "$USAGE_RESPONSE" | jq -e . >/dev/null 2>&1; then
      ITEM_COUNT=$(echo "$USAGE_RESPONSE" | jq '.items | length' 2>/dev/null || echo "0")
      echo "   包含 ${ITEM_COUNT} 条使用记录"
    fi
  else
    echo "   ⚠️  /admin/usage 无响应"
  fi
else
  echo "3. 跳过 API 端点检查 (未提供 ADMIN_TOKEN)"
  echo "4. 跳过 /admin/usage 检查 (未提供 ADMIN_TOKEN)"
fi

echo
echo "=== 验证完成 ==="
echo
echo "快速测试命令:"
echo "  # 健康检查"
echo "  curl -fsS ${BASE_URL}/healthz"
echo
echo "  # 管理界面"
echo "  curl -fsS ${BASE_URL}/admin/"
echo
if [[ -n "$ADMIN_TOKEN" ]]; then
  echo "  # 列出所有密钥"
  echo "  curl -fsS -H 'Authorization: Bearer ${ADMIN_TOKEN}' ${BASE_URL}/admin/keys"
  echo
  echo "  # 查看使用情况"
  echo "  curl -fsS -H 'Authorization: Bearer ${ADMIN_TOKEN}' ${BASE_URL}/admin/usage"
  echo
  echo "  # 创建新密钥"
  echo "  curl -fsS -X POST -H 'Authorization: Bearer ${ADMIN_TOKEN}' \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"label\":\"test-key-$(date +%s)\"}' \\"
  echo "    ${BASE_URL}/admin/keys"
fi

exit 0