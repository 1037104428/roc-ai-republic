#!/usr/bin/env bash
set -euo pipefail

# 应用论坛子路径修复（临时方案）
# 将论坛从 forum.clawdrepublic.cn 移到 clawdrepublic.cn/forum/

SERVER_IP="8.210.185.194"
CADDY_CONFIG="/opt/roc/web/caddy/Caddyfile"
BACKUP_DIR="/opt/roc/web/caddy/backups"

echo "=== 应用论坛子路径修复 ==="
echo "将论坛从独立子域名移到主域名子路径"
echo ""

# 创建备份
echo "1. 备份当前 Caddy 配置..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER_IP} \
  "mkdir -p ${BACKUP_DIR} && cp ${CADDY_CONFIG} ${BACKUP_DIR}/Caddyfile.backup.\$(date +%Y%m%d-%H%M%S)"

# 生成新的 Caddy 配置
echo "2. 生成新的 Caddy 配置..."
NEW_CONFIG=$(cat <<'EOF'
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
    
    # Forum reverse proxy (subpath)
    handle_path /forum/* {
        reverse_proxy http://127.0.0.1:8081 {
            header_up Host {host}
            header_up X-Forwarded-Prefix /forum
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

echo "3. 写入新配置..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER_IP} \
  "cat > ${CADDY_CONFIG}.new <<'EOF'
${NEW_CONFIG}
EOF"

echo "4. 验证配置语法..."
if ssh -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER_IP} \
  "caddy validate --config ${CADDY_CONFIG}.new 2>&1"; then
  echo "   ✓ 配置语法正确"
else
  echo "   ✗ 配置语法错误"
  exit 1
fi

echo "5. 应用新配置..."
ssh -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER_IP} \
  "mv ${CADDY_CONFIG}.new ${CADDY_CONFIG} && systemctl reload caddy"

echo "6. 等待 Caddy 重载..."
sleep 3

echo "7. 验证修复..."
echo "   检查 Caddy 状态："
ssh -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER_IP} "systemctl status caddy --no-pager | head -10"

echo ""
echo "8. 测试访问："
echo "   主站：https://clawdrepublic.cn/"
echo "   论坛：https://clawdrepublic.cn/forum/"
echo "   API：https://api.clawdrepublic.cn/healthz"

echo ""
echo "=== 修复完成 ==="
echo "论坛现在可通过 https://clawdrepublic.cn/forum/ 访问"
echo "原 forum.clawdrepublic.cn 已禁用"
echo ""
echo "如需恢复原配置，请从备份恢复："
echo "  ssh root@${SERVER_IP} 'cp ${BACKUP_DIR}/Caddyfile.backup.* ${CADDY_CONFIG} && systemctl reload caddy'"