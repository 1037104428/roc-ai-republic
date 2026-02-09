#!/usr/bin/env bash
set -euo pipefail

# 快速生成 quota-proxy trial key 脚本
# 兼容旧用法: ./quick-gen-trial-key.sh [BASE_URL] [ADMIN_TOKEN]

show_help() {
  cat << 'EOF'
快速生成 quota-proxy trial key 脚本

用法:
  quick-gen-trial-key.sh [BASE_URL] [ADMIN_TOKEN]
  quick-gen-trial-key.sh --base-url <BASE_URL> --admin-token <ADMIN_TOKEN> [--days <N>]
  quick-gen-trial-key.sh --help

参数(位置参数，兼容旧版):
  BASE_URL      quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  ADMIN_TOKEN   管理员令牌 (必需；也可用环境变量 ADMIN_TOKEN)

选项:
  --base-url <url>         同 BASE_URL
  --admin-token <token>    同 ADMIN_TOKEN
  --days <N>               trial key 有效期天数 (默认: 7；也可用环境变量 DAYS)

环境变量:
  ADMIN_TOKEN  管理员令牌 (当未提供位置参数/--admin-token 时使用)
  DAYS         trial key 有效期天数 (当未提供 --days 时使用；默认: 7)

示例:
  # 旧用法
  ./scripts/quick-gen-trial-key.sh http://127.0.0.1:8787 your_admin_token_here
  DAYS=30 ./scripts/quick-gen-trial-key.sh http://127.0.0.1:8787 token123

  # 推荐：用选项 + 环境变量
  export ADMIN_TOKEN=token123
  ./scripts/quick-gen-trial-key.sh --base-url http://127.0.0.1:8787 --days 30

输出:
  - 成功: 输出完整的 trial key
  - 失败: 显示错误信息并退出
EOF
}

BASE_URL=""
ADMIN_TOKEN_ARG=""
DAYS_ARG=""

# 简单参数解析（避免依赖 getopt）
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help)
      show_help
      exit 0
      ;;
    --base-url)
      BASE_URL="${2:-}"
      shift 2
      ;;
    --admin-token)
      ADMIN_TOKEN_ARG="${2:-}"
      shift 2
      ;;
    --days)
      DAYS_ARG="${2:-}"
      shift 2
      ;;
    --*)
      echo "错误: 未知选项: $1" >&2
      echo "提示: 使用 --help 查看用法" >&2
      exit 2
      ;;
    *)
      # 位置参数：BASE_URL / ADMIN_TOKEN
      if [[ -z "$BASE_URL" ]]; then
        BASE_URL="$1"
      elif [[ -z "$ADMIN_TOKEN_ARG" ]]; then
        ADMIN_TOKEN_ARG="$1"
      else
        echo "错误: 多余参数: $1" >&2
        echo "提示: 使用 --help 查看用法" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN_ARG:-${ADMIN_TOKEN:-}}"
DAYS="${DAYS_ARG:-${DAYS:-7}}"

if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "错误: 必须提供 ADMIN_TOKEN（参数或环境变量）" >&2
  echo "" >&2
  echo "用法: ./scripts/quick-gen-trial-key.sh [BASE_URL] [ADMIN_TOKEN]" >&2
  echo "或:   ADMIN_TOKEN=... ./scripts/quick-gen-trial-key.sh --base-url <BASE_URL> [--days <N>]" >&2
  echo "" >&2
  echo "提示:" >&2
  echo "  - 从服务器获取 ADMIN_TOKEN: cat /opt/roc/quota-proxy/.env | grep ADMIN_TOKEN" >&2
  echo "  - 或查看文档: docs/quota-proxy-v1-admin-spec.md" >&2
  exit 1
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -le 0 ]]; then
  echo "错误: --days/DAYS 必须是正整数，当前: $DAYS" >&2
  exit 2
fi

echo "正在生成 trial key..."
echo "目标: ${BASE_URL}"
echo "有效期: ${DAYS} 天"
echo ""

# 检查健康状态
if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  echo "服务不可用: ${BASE_URL}/healthz" >&2
  exit 1
fi

# 生成 trial key
response=$(curl -sS -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"trial\",\"days\":${DAYS}}" 2>&1)

# 尝试从 JSON 中提取 key（不强依赖 jq）
key=""
if command -v jq >/dev/null 2>&1; then
  key=$(printf '%s' "$response" | jq -r '.key // empty' 2>/dev/null || true)
fi
if [[ -z "$key" ]]; then
  key=$(printf '%s' "$response" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi

if [[ -n "$key" ]]; then
  echo "成功生成 trial key:"
  echo ""
  echo "export CLAWD_TRIAL_KEY=\"${key}\""
  echo ""
  echo "使用方式:"
  echo "  export CLAWD_TRIAL_KEY=\"${key}\""
  echo "  openclaw --trial-key \"\${CLAWD_TRIAL_KEY}\""
  echo ""
  echo "或直接使用:"
  echo "  openclaw --trial-key \"${key}\""
  echo ""
  echo "提示:"
  echo "  - 此 key 有效期为 ${DAYS} 天"
  echo "  - 查看使用情况: BASE_URL=${BASE_URL} ADMIN_TOKEN=*** ./scripts/curl-admin-usage.sh --day $(date +%F) --pretty --mask | head"
else
  echo "生成失败" >&2
  echo "响应: ${response}" >&2
  exit 1
fi
