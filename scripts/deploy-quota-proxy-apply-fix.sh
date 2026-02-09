#!/usr/bin/env bash
set -euo pipefail

# 部署 quota-proxy apply 静态文件服务修复
# 修复 /apply/* 路由无法访问的问题

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "Error: SERVER_FILE not found at $SERVER_FILE"
    echo "Create it with: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
fi

SERVER_LINE=$(head -1 "$SERVER_FILE" | tr -d '[:space:]')
# 支持格式: "ip=8.210.185.194" 或纯 "8.210.185.194"
if [[ "$SERVER_LINE" =~ ^ip= ]]; then
    SERVER_IP="${SERVER_LINE#ip=}"
else
    SERVER_IP="$SERVER_LINE"
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "Error: Could not extract server IP from '$SERVER_LINE'"
    exit 1
fi

echo "Deploying quota-proxy apply fix to $SERVER_IP..."

# 1. 复制修复后的文件到服务器
scp -o BatchMode=yes -o ConnectTimeout=8 \
    quota-proxy/server-sqlite.js \
    quota-proxy/server-better-sqlite.js \
    root@$SERVER_IP:/opt/roc/quota-proxy/

# 2. 在容器内直接修改 server.js 添加 apply 静态路由
ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    "cd /opt/roc/quota-proxy && docker compose exec quota-proxy sed -i \\\"14a app.use('/apply', express.static(join(__dirname, 'apply')));\\\" /app/server.js"

# 3. 重启 quota-proxy 容器
ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    "cd /opt/roc/quota-proxy && docker compose restart quota-proxy"

# 3. 等待服务恢复
echo "Waiting for quota-proxy to restart..."
sleep 5

# 4. 验证修复
echo "Verifying apply page is now accessible..."
if ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    "curl -fsS http://127.0.0.1:8787/apply/ >/dev/null 2>&1 && echo 'Apply page: OK' || echo 'Apply page: FAILED'"; then
    echo "✅ quota-proxy apply fix deployed successfully"
else
    echo "❌ quota-proxy apply fix deployment failed"
    exit 1
fi

# 5. 验证通过 Caddy 代理也能访问
echo "Verifying through Caddy proxy..."
if curl -fsS -m 5 https://clawdrepublic.cn/apply/ >/dev/null 2>&1; then
    echo "✅ Caddy proxy /apply/: OK"
else
    echo "⚠️  Caddy proxy /apply/: May need cache clear or DNS propagation"
fi