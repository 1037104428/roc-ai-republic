#!/usr/bin/env bash
set -euo pipefail

# 修复 forum.clawdrepublic.cn 502 问题
# 检查并修复反向代理配置

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
  echo "❌ $SERVER_FILE not found. Create it with: echo 'ip=8.210.185.194' > $SERVER_FILE"
  exit 1
fi

SERVER_IP=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$SERVER_FILE" | head -1)
if [[ -z "$SERVER_IP" ]]; then
  echo "❌ Could not extract IP from $SERVER_FILE"
  exit 1
fi

echo "🔧 Fixing forum 502 on $SERVER_IP"

# 1. 检查论坛容器是否运行
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" '
set -e

echo "📊 Checking forum container status..."
cd /opt/roc/forum 2>/dev/null || { echo "❌ /opt/roc/forum not found"; exit 1; }

if docker compose ps --services | grep -q forum; then
  echo "✅ Forum container exists"
  docker compose ps forum
else
  echo "❌ Forum container not found in compose"
  exit 1
fi

# 2. 检查论坛是否在 127.0.0.1:8081 响应
echo "🔍 Checking forum on 127.0.0.1:8081..."
if curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1; then
  echo "✅ Forum responds on 127.0.0.1:8081"
else
  echo "❌ Forum not responding on 127.0.0.1:8081"
  echo "Trying to restart forum container..."
  docker compose restart forum
  sleep 5
  if curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1; then
    echo "✅ Forum restarted and now responds"
  else
    echo "❌ Forum still not responding after restart"
    exit 1
  fi
fi

# 3. 检查 Caddy 配置
echo "🔧 Checking Caddy configuration..."
CADDYFILE="/opt/roc/web/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
  echo "📄 Caddyfile exists at $CADDYFILE"
  if grep -q "forum.clawdrepublic.cn" "$CADDYFILE"; then
    echo "✅ Caddyfile contains forum.clawdrepublic.cn"
    # 检查反向代理配置
    if grep -A2 "forum.clawdrepublic.cn" "$CADDYFILE" | grep -q "reverse_proxy"; then
      echo "✅ Caddy has reverse_proxy config for forum"
      PROXY_TARGET=$(grep -A2 "forum.clawdrepublic.cn" "$CADDYFILE" | grep "reverse_proxy" | awk "{print \$2}")
      echo "📌 Proxy target: $PROXY_TARGET"
    else
      echo "❌ Caddy missing reverse_proxy for forum"
      echo "Adding reverse_proxy configuration..."
      cat >> "$CADDYFILE" <<EOF

# Forum reverse proxy
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
    encode gzip
    header {
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF
      echo "✅ Added forum reverse_proxy config"
    fi
  else
    echo "❌ Caddyfile missing forum.clawdrepublic.cn"
    echo "Adding forum configuration..."
    cat >> "$CADDYFILE" <<EOF

# Forum reverse proxy
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
    encode gzip
    header {
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF
    echo "✅ Added forum configuration to Caddyfile"
  fi
  
  # 4. 重新加载 Caddy
  echo "🔄 Reloading Caddy..."
  if docker compose -f /opt/roc/web/docker-compose.yaml exec caddy caddy reload --config /etc/caddy/Caddyfile 2>/dev/null || \
     docker exec caddy caddy reload --config /etc/caddy/Caddyfile 2>/dev/null; then
    echo "✅ Caddy reloaded successfully"
  else
    echo "⚠️  Could not reload Caddy via docker exec, trying restart..."
    docker compose -f /opt/roc/web/docker-compose.yaml restart caddy 2>/dev/null || \
    docker restart caddy 2>/dev/null
    sleep 3
    echo "✅ Caddy restarted"
  fi
else
  echo "❌ Caddyfile not found at $CADDYFILE"
  echo "Checking for Nginx..."
  NGINX_CONF="/opt/roc/web/nginx/nginx.conf"
  if [[ -f "$NGINX_CONF" ]]; then
    echo "📄 Nginx config exists at $NGINX_CONF"
    # 类似逻辑处理 Nginx 配置
  else
    echo "⚠️  No web server config found"
  fi
fi

# 5. 最终验证
echo "🎯 Final verification..."
sleep 2
if curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null 2>&1; then
  echo "✅ SUCCESS: forum.clawdrepublic.cn is now accessible!"
  echo "   You can visit: http://forum.clawdrepublic.cn/"
else
  echo "❌ FAILED: forum.clawdrepublic.cn still not accessible"
  echo "   Forum is running on 127.0.0.1:8081 but not publicly accessible"
  echo "   Check firewall and DNS settings"
  exit 1
fi
'

echo ""
echo "📝 Summary:"
echo "  - Forum container checked/restarted if needed"
echo "  - Caddy reverse proxy configuration verified/added"
echo "  - Caddy reloaded/restarted"
echo "  - Final accessibility test performed"
echo ""
echo "🔗 Forum URL: http://forum.clawdrepublic.cn/"
echo "📚 Documentation: docs/tickets.md (search 'forum 502')"