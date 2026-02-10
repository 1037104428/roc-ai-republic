#!/usr/bin/env bash
set -euo pipefail

# 快速验证 quota-proxy 管理接口健康状态
# 用法: ./scripts/verify-admin-health-quick.sh [--host HOST] [--token TOKEN]

show_help() {
  cat << EOF
快速验证 quota-proxy 管理接口健康状态

用法: $0 [选项]

选项:
  --host HOST     quota-proxy 主机地址 (默认: 127.0.0.1:8787)
  --token TOKEN   管理员令牌 (也可通过 ADMIN_TOKEN 环境变量设置)
  -h, --help      显示此帮助信息

示例:
  $0 --host 127.0.0.1:8787 --token "your-admin-token"
  ADMIN_TOKEN="your-admin-token" $0 --host api.clawdrepublic.cn

环境变量:
  ADMIN_TOKEN     管理员令牌
  HOST            quota-proxy 主机地址
EOF
}

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
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "错误: 未知参数: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "错误: 需要 ADMIN_TOKEN 环境变量或 --token 参数"
  echo "提示: export ADMIN_TOKEN='your-admin-token'"
  exit 1
fi

echo "=== 验证 quota-proxy 管理接口健康状态 ==="
echo "主机: $HOST"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 1. 验证 /healthz 基础健康
echo "1. 验证基础健康检查 (/healthz):"
if curl -fsS "http://$HOST/healthz" > /dev/null; then
  echo "   ✅ 通过"
else
  echo "   ❌ 失败"
  exit 1
fi

# 2. 验证 /admin/keys 接口
echo "2. 验证管理密钥接口 (/admin/keys):"
if curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/keys" > /dev/null; then
  echo "   ✅ 通过"
else
  echo "   ❌ 失败 (可能 token 无效或无权限)"
  exit 1
fi

# 3. 验证 /admin/usage 接口
echo "3. 验证使用情况接口 (/admin/usage):"
if curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/usage" > /dev/null; then
  echo "   ✅ 通过"
else
  echo "   ❌ 失败"
  exit 1
fi

echo
echo "=== 所有管理接口健康检查通过 ==="
echo "✅ 可以正常使用 quota-proxy 管理功能"
echo
echo "快速命令参考:"
echo "  # 创建试用密钥"
echo "  curl -X POST http://$HOST/admin/keys \\"
echo "    -H 'Authorization: Bearer $TOKEN' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"label\":\"test-$(date +%s)\", \"limit\":100}'"
echo
echo "  # 查看使用情况"
echo "  curl -fsS http://$HOST/admin/usage \\"
echo "    -H 'Authorization: Bearer $TOKEN' | jq ."