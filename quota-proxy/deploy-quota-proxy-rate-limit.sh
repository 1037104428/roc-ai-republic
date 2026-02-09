#!/bin/bash
# 部署带速率限制的 quota-proxy

set -e

SERVER_IP="${1:-8.210.185.194}"
SSH_KEY="${2:-$HOME/.ssh/id_ed25519_roc_server}"

echo "=== 部署带速率限制的 quota-proxy ==="
echo "目标服务器: $SERVER_IP"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查必要文件
if [ ! -f "middleware/rate-limit.js" ]; then
    echo "错误: middleware/rate-limit.js 不存在"
    exit 1
fi

if [ ! -f "server-sqlite.js" ]; then
    echo "错误: server-sqlite.js 不存在"
    exit 1
fi

# 上传文件到服务器
echo "上传文件到服务器..."
scp -i "$SSH_KEY" \
    middleware/rate-limit.js \
    server-sqlite.js \
    root@$SERVER_IP:/opt/roc/quota-proxy/

# 重启服务
echo "重启 quota-proxy 服务..."
ssh -i "$SSH_KEY" root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose restart quota-proxy'

# 验证部署
echo "验证部署..."
sleep 3
ssh -i "$SSH_KEY" root@$SERVER_IP 'curl -fsS http://127.0.0.1:8787/healthz'

echo ""
echo "✅ 部署完成!"
echo "速率限制已应用到 Admin API:"
echo "  - 时间窗口: 15 分钟"
echo "  - 最大请求数: 30 次"
echo "  - 保护端点: /admin/*"
echo ""
echo "📋 验证命令:"
echo "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
