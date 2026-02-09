#!/bin/bash
# show-quota-usage.sh - 显示quota-proxy API使用统计信息
# 用法: ./scripts/show-quota-usage.sh [--server SERVER_IP] [--admin-token TOKEN]

set -e

# 默认配置
SERVER_IP="8.210.185.194"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
QUOTA_PROXY_PORT="8787"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_IP="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --server SERVER_IP    指定服务器IP (默认: 8.210.185.194)"
            echo "  --admin-token TOKEN   管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 读取)"
            echo "  --help                显示此帮助信息"
            exit 0
            ;;
        *)
            echo "错误: 未知选项 $1"
            echo "使用 --help 查看用法"
            exit 1
            ;;
    esac
done

# 检查管理员令牌
if [[ -z "$ADMIN_TOKEN" ]]; then
    echo "错误: 需要管理员令牌"
    echo "请设置环境变量 ADMIN_TOKEN 或使用 --admin-token 参数"
    echo "示例: ADMIN_TOKEN=your_token ./scripts/show-quota-usage.sh"
    exit 1
fi

echo "正在查询 quota-proxy 使用统计..."
echo "服务器: $SERVER_IP"
echo "端口: $QUOTA_PROXY_PORT"
echo ""

# 查询使用统计
echo "=== API 使用统计 ==="
if curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "http://$SERVER_IP:$QUOTA_PROXY_PORT/admin/usage" | jq -r '.usage // empty'; then
    echo "查询成功"
else
    echo "查询失败或暂无数据"
fi

echo ""
echo "=== 活跃密钥统计 ==="
if curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "http://$SERVER_IP:$QUOTA_PROXY_PORT/admin/keys" | jq -r '.[] | "\(.key): \(.remaining)"' 2>/dev/null || true; then
    echo "查询完成"
else
    echo "查询失败或暂无数据"
fi

echo ""
echo "=== 健康状态 ==="
if curl -fsS "http://$SERVER_IP:$QUOTA_PROXY_PORT/healthz" | jq -r '.ok // empty'; then
    echo "服务健康"
else
    echo "服务异常"
fi