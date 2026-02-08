#!/usr/bin/env bash
set -euo pipefail

# 快速生成 trial key 脚本
# 用法: ./quick-gen-trial-key.sh [BASE_URL] [ADMIN_TOKEN]

show_help() {
    cat << EOF
快速生成 quota-proxy trial key 脚本

用法: $0 [BASE_URL] [ADMIN_TOKEN]
       $0 --help

参数:
  BASE_URL    quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  ADMIN_TOKEN 管理员令牌 (必需)

环境变量:
  DAYS        trial key 有效期天数 (默认: 7)

示例:
  $0 http://127.0.0.1:8787 your_admin_token_here
  DAYS=30 $0 http://127.0.0.1:8787 token123

输出:
  - 成功: 输出完整的 trial key
  - 失败: 显示错误信息并退出

EOF
    exit 0
}

if [[ "$#" -gt 0 ]]; then
    case "$1" in
        -h|--help|help)
            show_help
            ;;
    esac
fi

BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${2:-}"
DAYS="${DAYS:-7}"

if [[ -z "$ADMIN_TOKEN" ]]; then
    echo "错误: 必须提供 ADMIN_TOKEN 参数"
    echo ""
    echo "用法: $0 [BASE_URL] [ADMIN_TOKEN]"
    echo "示例: $0 http://127.0.0.1:8787 your_token_here"
    echo ""
    echo "提示:"
    echo "  - 从服务器获取 ADMIN_TOKEN: cat /opt/roc/quota-proxy/.env | grep ADMIN_TOKEN"
    echo "  - 或查看文档: docs/quota-proxy-v1-admin-spec.md"
    exit 1
fi

echo "正在生成 trial key..."
echo "目标: ${BASE_URL}"
echo "有效期: ${DAYS} 天"
echo ""

# 检查健康状态
if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    echo "❌ 服务不可用: ${BASE_URL}/healthz"
    exit 1
fi

# 生成 trial key
response=$(curl -sS -X POST "${BASE_URL}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"trial\",\"days\":${DAYS}}" 2>&1)

# 检查响应
if echo "$response" | grep -q '"key"'; then
    # 提取完整的 key
    key=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "✅ 成功生成 trial key:"
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
    echo "  - 查看使用情况: curl -sS \"${BASE_URL}/admin/usage\" -H \"Authorization: Bearer ${ADMIN_TOKEN}\" | jq ."
else
    echo "❌ 生成失败"
    echo "响应: ${response}"
    exit 1
fi