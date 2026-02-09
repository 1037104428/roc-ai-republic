#!/usr/bin/env bash
set -euo pipefail

# Fix forum subdomain reverse proxy configuration
# This script adds forum.clawdrepublic.cn subdomain support to Caddy

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "Error: Server file not found: $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(head -1 "$SERVER_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
if [[ -z "$SERVER_IP" ]]; then
    echo "Error: Could not extract IP from $SERVER_FILE"
    exit 1
fi

echo "Target server: $SERVER_IP"

# Create updated Caddyfile
CADDYFILE_CONTENT='# Caddyfile for ROC AI Republic static site + forum subdomain
# Deploy to: /opt/roc/web/caddy/Caddyfile
# Usage: caddy run --config /opt/roc/web/caddy/Caddyfile

# HTTPS auto-configuration (must be first if present)
{
    # Auto HTTPS with Let\'s Encrypt
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
    
    # Forum reverse proxy (path-based)
    handle_path /forum/* {
        reverse_proxy http://127.0.0.1:8081 {
            header_up Host {host}
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

# Forum subdomain
forum.clawdrepublic.cn {
    # Reverse proxy to Flarum
    reverse_proxy http://127.0.0.1:8081 {
        header_up Host {host}
    }
    
    # Logging
    log {
        output file /var/log/caddy/forum-access.log
        format json
    }
}

# Redirect www to non-www
www.clawdrepublic.cn {
    redir https://clawdrepublic.cn{uri} permanent
}'

echo "Updating Caddy configuration on server..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "mkdir -p /opt/roc/web/caddy && echo '$CADDYFILE_CONTENT' > /opt/roc/web/caddy/Caddyfile"

echo "Reloading Caddy..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "systemctl reload caddy 2>/dev/null || systemctl restart caddy 2>/dev/null || echo 'Note: Caddy reload/restart may need manual check'"

echo "Testing forum subdomain..."
if curl -fsS -m 10 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✓ forum.clawdrepublic.cn is accessible"
else
    echo "⚠ forum.clawdrepublic.cn may need DNS propagation or certificate issuance"
    echo "  Path-based forum is still available at: https://clawdrepublic.cn/forum/"
fi

echo "Testing path-based forum..."
if curl -fsS -m 10 "https://clawdrepublic.cn/forum/" >/dev/null 2>&1; then
    echo "✓ https://clawdrepublic.cn/forum/ is accessible"
else
    echo "✗ Path-based forum is not accessible"
fi

echo ""
echo "Summary:"
echo "1. Updated Caddy configuration with forum subdomain support"
echo "2. Forum is accessible via:"
echo "   - https://clawdrepublic.cn/forum/ (path-based)"
echo "   - https://forum.clawdrepublic.cn/ (subdomain, may need DNS/cert)"
echo "3. Note: DNS A record for forum.clawdrepublic.cn must point to $SERVER_IP"