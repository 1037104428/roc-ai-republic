#!/bin/bash
set -e

# 简化版修复论坛反向代理配置脚本
echo "=== 修复论坛反向代理配置（简化版）==="

# 创建新的Caddy配置
NEW_CADDY_CONFIG=$(cat <<'EOF'
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

# Redirect www to non-www
www.clawdrepublic.cn {
    redir https://clawdrepublic.cn{uri} permanent
}
EOF
)

echo "1. 备份当前配置..."
ssh root@8.210.185.194 "cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"

echo "2. 写入新配置..."
echo "$NEW_CADDY_CONFIG" | ssh root@8.210.185.194 "cat > /etc/caddy/Caddyfile"

echo "3. 验证配置语法..."
ssh root@8.210.185.194 "caddy validate --config /etc/caddy/Caddyfile"

echo "4. 重新加载Caddy..."
ssh root@8.210.185.194 "systemctl reload caddy 2>/dev/null || caddy reload --config /etc/caddy/Caddyfile 2>/dev/null || echo '可能需要手动重启: systemctl restart caddy'"

echo "5. 等待服务稳定..."
sleep 5

echo "6. 验证论坛可访问性..."
if curl -fsS -m 10 https://clawdrepublic.cn/forum/ >/dev/null 2>&1; then
    echo "  ✅ 论坛可访问: https://clawdrepublic.cn/forum/"
    
    # 检查论坛内容
    echo "  论坛标题检查:"
    curl -fsS -m 5 https://clawdrepublic.cn/forum/ | grep -o 'Clawd 国度' | head -1
else
    echo "  ⚠️  论坛访问失败，检查日志:"
    ssh root@8.210.185.194 "journalctl -u caddy --since '5 minutes ago' | tail -20" 2>/dev/null || true
fi

echo
echo "=== 修复完成 ==="
echo "论坛URL: https://clawdrepublic.cn/forum/"
echo "验证命令: curl -fsS -m 5 https://clawdrepublic.cn/forum/ | grep -o 'Clawd 国度'"