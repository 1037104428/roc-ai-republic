#!/usr/bin/env bash
set -euo pipefail

# 修复 forum.clawdrepublic.cn 子域名 502 错误的脚本
# 问题：Caddyfile 中 forum.clawdrepublic.cn 配置被注释掉了
# 解决方案：取消注释并启用子域名反向代理

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SERVER_IP=""
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -1 "$SERVER_FILE" | tr -d '[:space:]')
    # 如果文件格式是 ip=xxx，提取 IP
    if [[ "$SERVER_IP" =~ ^ip= ]]; then
        SERVER_IP="${SERVER_IP#ip=}"
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "错误：无法从 $SERVER_FILE 读取服务器 IP"
    echo "请确保文件存在且包含 IP 地址（格式：8.210.185.194 或 ip=8.210.185.194）"
    exit 1
fi

echo "目标服务器: $SERVER_IP"
echo "修复 forum.clawdrepublic.cn 子域名配置..."

# 备份当前 Caddyfile
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
    "cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)"

# 创建修复后的 Caddyfile
cat > /tmp/fixed-caddyfile.caddy << 'CADDYFILE'
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
    
    # API gateway reverse proxy - FIXED VERSION
    handle /api/* {
        reverse_proxy http://127.0.0.1:8787 {
            header_up Host {host}
        }
    }
    
    # Forum reverse proxy (path-based)
    handle /forum/* {
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

# API subdomain (alternative approach)
api.clawdrepublic.cn {
    reverse_proxy http://127.0.0.1:8787 {
        header_up Host {host}
    }
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
CADDYFILE

# 上传修复后的配置
scp /tmp/fixed-caddyfile.caddy root@"$SERVER_IP":/tmp/fixed-caddyfile.caddy

# 应用配置
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" << 'EOF'
set -e
echo "备份原配置..."
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.before-fix
echo "应用新配置..."
cp /tmp/fixed-caddyfile.caddy /etc/caddy/Caddyfile
echo "重新加载 Caddy..."
systemctl reload caddy || systemctl restart caddy || {
    echo "尝试直接重启 Caddy 进程..."
    pkill -HUP caddy || true
}
echo "等待 3 秒让配置生效..."
sleep 3
EOF

# 验证修复
echo "验证 forum.clawdrepublic.cn 是否可用..."
if curl -fsS -m 10 "http://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✅ forum.clawdrepublic.cn HTTP 访问成功"
elif curl -fsS -m 10 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✅ forum.clawdrepublic.cn HTTPS 访问成功"
else
    echo "⚠️  forum.clawdrepublic.cn 访问失败，检查配置..."
    echo "备用验证：clawdrepublic.cn/forum/ 路径应该仍然可用"
    if curl -fsS -m 5 "https://clawdrepublic.cn/forum/" >/dev/null 2>&1; then
        echo "✅ clawdrepublic.cn/forum/ 路径访问成功"
    fi
fi

echo ""
echo "修复完成！"
echo "论坛现在可以通过以下方式访问："
echo "1. https://clawdrepublic.cn/forum/ (路径方式)"
echo "2. https://forum.clawdrepublic.cn/ (子域名方式)"
echo ""
echo "如果需要回滚："
echo "ssh root@$SERVER_IP 'cp /etc/caddy/Caddyfile.backup.before-fix /etc/caddy/Caddyfile && systemctl reload caddy'"