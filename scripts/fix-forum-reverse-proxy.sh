#!/usr/bin/env bash
set -euo pipefail

# Fix forum reverse proxy 502 issue
# This script updates Caddy configuration to properly proxy forum requests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 修复论坛反向代理 502 问题 ==="

# Check if we have server info
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "❌ 服务器配置文件不存在: $SERVER_FILE"
    echo "请先创建包含服务器IP的文件: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
fi

SERVER_IP="$(head -n1 "$SERVER_FILE" | sed 's/^ip=//' | tr -d '[:space:]')"
echo "📡 目标服务器: $SERVER_IP"

# Create updated Caddy configuration
cat > /tmp/caddy-forum-fix.caddy << 'CADDY'
# Caddyfile for ROC AI Republic static site
# Deploy to: /opt/roc/web/caddy/Caddyfile
# Usage: caddy run --config /opt/roc/web/caddy/Caddyfile

# HTTPS auto-configuration (must be first if present)
{
    # Auto HTTPS with Let's Encrypt
    email admin@clawdrepublic.cn
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

# Main domain - landing page
clawdrepublic.cn {
    # Static site files
    root * /opt/roc/web/site
    file_server {
        index index.html
    }
    
    # API gateway reverse proxy
    handle_path /api/* {
        reverse_proxy http://127.0.0.1:8787 {
            header_up Host {host}
        }
    }
    
    # Forum reverse proxy - FIXED VERSION
    # Using handle instead of handle_path for proper path handling
    handle /forum/* {
        reverse_proxy http://127.0.0.1:8081 {
            header_up Host {host}
            header_up X-Forwarded-Proto {scheme}
            header_up X-Real-IP {remote}
        }
    }
    
    # Health check endpoint
    handle /healthz {
        respond "OK" 200
    }
    
    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# Redirect www to non-www
www.clawdrepublic.cn {
    redir https://clawdrepublic.cn{uri} permanent
}
CADDY

echo "✅ 生成修复后的 Caddy 配置"

# Deploy to server
echo "🚀 部署到服务器..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" '
    echo "备份当前配置..."
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)
    
    echo "应用修复配置..."
    cat > /etc/caddy/Caddyfile << "EOF"
'"$(cat /tmp/caddy-forum-fix.caddy)"'
EOF
    
    echo "验证配置..."
    caddy validate --config /etc/caddy/Caddyfile
    
    echo "重新加载 Caddy..."
    caddy reload --config /etc/caddy/Caddyfile --force
    
    echo "等待 3 秒让配置生效..."
    sleep 3
    
    echo "测试论坛访问..."
    curl -fsS -m 5 -H "Host: clawdrepublic.cn" http://127.0.0.1/forum/ >/dev/null 2>&1 && echo "✅ 本地测试通过" || echo "⚠️  本地测试失败"
'

echo ""
echo "=== 验证步骤 ==="
echo "1. 等待证书更新（如果需要）"
echo "2. 测试论坛访问:"
echo "   curl -fsS -m 5 https://clawdrepublic.cn/forum/"
echo "3. 如果仍有问题，检查 Caddy 日志:"
echo "   journalctl -u caddy --since '1 minute ago' | grep -i forum"
echo ""
echo "修复完成！论坛应该现在可以正常访问了。"

# Clean up
rm -f /tmp/caddy-forum-fix.caddy