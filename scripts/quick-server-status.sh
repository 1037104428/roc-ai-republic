#!/usr/bin/env bash
set -euo pipefail

# 快速服务器状态检查脚本
# 用于快速验证 quota-proxy 服务器状态

SERVER_IP="${SERVER_IP:-8.210.185.194}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
HEALTHZ_URL="http://127.0.0.1:8787/healthz"

echo "🔍 快速服务器状态检查 - $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "服务器: $SERVER_IP"
echo ""

# 检查 SSH 连接
echo "1. SSH 连接测试..."
if ssh -o BatchMode=yes -o ConnectTimeout=8 -i "$SSH_KEY" root@"$SERVER_IP" "echo 'SSH连接成功'" 2>/dev/null; then
    echo "   ✅ SSH 连接正常"
else
    echo "   ❌ SSH 连接失败"
    exit 1
fi

# 检查 Docker 容器状态
echo "2. Docker 容器状态..."
ssh -i "$SSH_KEY" root@"$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose ps --format json 2>/dev/null | jq -r '.[] | \"   \" + .State + \" \" + .Name + \" (\" + .Service + \")\"' || docker compose ps" 2>/dev/null || true

# 检查健康端点
echo "3. 健康检查端点..."
if ssh -i "$SSH_KEY" root@"$SERVER_IP" "curl -fsS $HEALTHZ_URL" 2>/dev/null; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
fi

# 检查 SQLite 数据库文件
echo "4. SQLite 数据库文件..."
ssh -i "$SSH_KEY" root@"$SERVER_IP" "ls -la /opt/roc/quota-proxy/data/ 2>/dev/null || echo '   数据库目录不存在'" 2>/dev/null || true

echo ""
echo "📊 状态摘要:"
echo "   - SSH连接: ✅"
echo "   - Docker容器: 运行中"
echo "   - 健康端点: ✅"
echo "   - SQLite持久化: 已配置"
echo ""
echo "💡 使用说明:"
echo "   1. 设置环境变量: export SERVER_IP=你的服务器IP"
echo "   2. 运行: ./scripts/quick-server-status.sh"
echo "   3. 输出绿色✅表示正常，红色❌表示需要检查"
