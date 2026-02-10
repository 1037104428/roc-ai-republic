#!/bin/bash
set -e

# Fix Caddy permissions and restart service
# Usage: ./scripts/fix-caddy-permissions.sh [--dry-run]

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] Would fix Caddy permissions"
fi

echo "=== Fixing Caddy permissions ==="

# 1. Check current Caddy status
echo "1. Checking Caddy service status..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'systemctl status caddy 2>/dev/null | head -20' || true
fi

# 2. Fix log directory permissions
echo "2. Fixing /var/log/caddy permissions..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
        mkdir -p /var/log/caddy
        chown -R caddy:caddy /var/log/caddy
        chmod 755 /var/log/caddy
        ls -la /var/log/caddy/
    '
fi

# 3. Create forum.log with proper permissions
echo "3. Creating forum.log with proper permissions..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
        touch /var/log/caddy/forum.log
        chown caddy:caddy /var/log/caddy/forum.log
        chmod 644 /var/log/caddy/forum.log
    '
fi

# 4. Check Caddyfile for forum.log reference
echo "4. Checking Caddyfile configuration..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
        echo "Current Caddyfile forum.log references:"
        grep -n "forum.log" /etc/caddy/Caddyfile || echo "No forum.log references found"
    '
fi

# 5. Remove problematic forum.log reference if exists
echo "5. Removing problematic forum.log reference from Caddyfile..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
        # Backup current Caddyfile
        cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)
        
        # Remove forum.log specific logging config if it exists
        # Check if there's a forum.log reference in a log block
        if grep -q "forum.log" /etc/caddy/Caddyfile; then
            echo "Found forum.log reference, creating simplified Caddyfile..."
            # Create a simplified Caddyfile without forum.log
            cat > /tmp/Caddyfile.simple << EOF
# Caddyfile for ROC AI Republic static site
# Simplified version without forum.log

# HTTPS auto-configuration
{
    email admin@clawdrepublic.cn
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

# Main domain - landing page
clawdrepublic.cn {
    root * /opt/roc/web
    file_server {
        index index.html
    }
    
    # API gateway reverse proxy
    handle /v1/* {
        reverse_proxy http://127.0.0.1:8787
    }
    
    # Health check endpoint
    handle /healthz {
        reverse_proxy http://127.0.0.1:8787
    }
    
    # Apply interface
    handle /apply/* {
        reverse_proxy http://127.0.0.1:8787
    }
    
    # Admin interface (protected)
    handle /admin/* {
        reverse_proxy http://127.0.0.1:8787
    }
    
    # Forum reverse proxy (path-based)
    handle /forum/* {
        reverse_proxy http://127.0.0.1:8081
    }
    
    # Install script
    handle /install-cn.sh {
        root * /opt/roc/web
        file_server
    }
}

# API subdomain
api.clawdrepublic.cn {
    reverse_proxy http://127.0.0.1:8787
}

# Forum subdomain (enabled)
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081
    encode gzip
    header {
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
    }
}

# Redirect www to non-www
www.clawdrepublic.cn {
    redir https://clawdrepublic.cn{uri} permanent
}
EOF
            
            # Replace Caddyfile
            cp /tmp/Caddyfile.simple /etc/caddy/Caddyfile
            echo "Simplified Caddyfile installed"
        else
            echo "No forum.log reference found, keeping current Caddyfile"
        fi
    '
fi

# 6. Restart Caddy service
echo "6. Restarting Caddy service..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 '
        systemctl stop caddy
        sleep 2
        systemctl start caddy
        sleep 3
        systemctl status caddy --no-pager -l
    '
fi

# 7. Verify forum accessibility
echo "7. Verifying forum accessibility..."
if [[ "$DRY_RUN" == false ]]; then
    echo "Testing forum.clawdrepublic.cn..."
    curl -fsS -m 10 https://forum.clawdrepublic.cn/ >/dev/null && echo "✅ Forum accessible via HTTPS" || echo "❌ Forum still not accessible"
    
    echo "Testing forum via main domain..."
    curl -fsS -m 10 https://clawdrepublic.cn/forum/ >/dev/null && echo "✅ Forum accessible via /forum path" || echo "❌ Forum via /forum path not accessible"
fi

echo "=== Fix complete ==="
echo "If forum is still not accessible, check:"
echo "1. Forum service running: ssh root@8.210.185.194 'systemctl status flarum'"
echo "2. Caddy config: ssh root@8.210.185.194 'cat /etc/caddy/Caddyfile'"
echo "3. Network connectivity: ssh root@8.210.185.194 'netstat -tlnp | grep :8081'"