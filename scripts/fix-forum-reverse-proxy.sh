#!/bin/bash
set -e

# 修复论坛反向代理配置脚本
# 解决 forum.clawdrepublic.cn 502 错误问题

echo "=== 修复论坛反向代理配置 ==="

# 检查参数
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "用法: $0 [--dry-run] [--caddy|--nginx]"
    echo "选项:"
    echo "  --dry-run     只显示将要执行的命令，不实际执行"
    echo "  --caddy       使用 Caddy 配置（默认）"
    echo "  --nginx       使用 Nginx 配置"
    echo "  --help        显示此帮助信息"
    exit 0
fi

# 参数解析
DRY_RUN=false
PROXY_TYPE="caddy"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --caddy)
            PROXY_TYPE="caddy"
            shift
            ;;
        --nginx)
            PROXY_TYPE="nginx"
            shift
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 服务器信息
SERVER_FILE="/tmp/server.txt"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "错误: 服务器配置文件 $SERVER_FILE 不存在"
    echo "请先创建该文件，内容格式: ip:8.210.185.194"
    exit 1
fi

SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$SERVER_FILE" | head -1)
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$SERVER_FILE" | head -1)
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 无法从 $SERVER_FILE 中提取服务器IP"
    exit 1
fi

echo "服务器IP: $SERVER_IP"
echo "代理类型: $PROXY_TYPE"
echo ""

# 检查论坛容器状态
echo "1. 检查论坛容器状态..."
CHECK_CMD="docker ps | grep -i flarum"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "执行: ssh root@$SERVER_IP '$CHECK_CMD'"
else
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" "$CHECK_CMD"
fi

# 检查论坛本地访问
echo ""
echo "2. 检查论坛本地访问 (127.0.0.1:8081)..."
LOCAL_CHECK_CMD="curl -fsS -m 5 http://127.0.0.1:8081/ 2>/dev/null | grep -o 'Flarum\|论坛' || echo '本地访问失败'"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "执行: ssh root@$SERVER_IP '$LOCAL_CHECK_CMD'"
else
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" "$LOCAL_CHECK_CMD"
fi

# 生成配置
echo ""
echo "3. 生成反向代理配置..."

if [[ "$PROXY_TYPE" == "caddy" ]]; then
    # Caddy 配置
    CADDY_CONFIG=$(cat <<'EOF'
# Forum reverse proxy configuration
forum.clawdrepublic.cn {
    # Reverse proxy to Flarum container
    reverse_proxy 127.0.0.1:8081 {
        # Flarum-specific headers
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Port {port}
    }
    
    # Logging
    log {
        output file /var/log/caddy/forum.log {
            roll_size 10MiB
            roll_keep 5
        }
    }
}
EOF
)
    
    echo "Caddy 配置:"
    echo "$CADDY_CONFIG"
    echo ""
    
    # 应用配置
    APPLY_CMD=$(cat <<EOF
# 备份原配置
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.\$(date +%s) 2>/dev/null || true

# 检查是否已有论坛配置
if grep -q "forum.clawdrepublic.cn" /etc/caddy/Caddyfile; then
    echo "论坛配置已存在，将更新..."
    # 移除旧的论坛配置
    sed -i '/^# Forum reverse proxy configuration/,/^}/d' /etc/caddy/Caddyfile
fi

# 添加新配置到文件末尾
echo -e "\n\n$CADDY_CONFIG" >> /etc/caddy/Caddyfile

# 验证配置
caddy validate --config /etc/caddy/Caddyfile

# 重新加载 Caddy
caddy reload --config /etc/caddy/Caddyfile

echo "Caddy 配置已更新并重新加载"
EOF
)
    
else
    # Nginx 配置
    NGINX_CONFIG=$(cat <<'EOF'
# Forum reverse proxy configuration
server {
    listen 80;
    listen [::]:80;
    server_name forum.clawdrepublic.cn;
    
    # Redirect to HTTPS (if using SSL)
    # return 301 https://$server_name$request_uri;
    
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support for Flarum
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Logging
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
}
EOF
)
    
    echo "Nginx 配置:"
    echo "$NGINX_CONFIG"
    echo ""
    
    # 应用配置
    APPLY_CMD=$(cat <<EOF
# 创建 Nginx 配置
CONFIG_FILE="/etc/nginx/sites-available/forum.clawdrepublic.cn"
echo "$NGINX_CONFIG" > "\$CONFIG_FILE"

# 创建符号链接（如果不存在）
if [[ ! -L "/etc/nginx/sites-enabled/forum.clawdrepublic.cn" ]]; then
    ln -s "\$CONFIG_FILE" /etc/nginx/sites-enabled/
fi

# 验证配置
nginx -t

# 重新加载 Nginx
systemctl reload nginx

echo "Nginx 配置已更新并重新加载"
EOF
)
fi

# 执行配置更新
echo "4. 应用配置..."
if [[ "$DRY_RUN" == "true" ]]; then
    echo "执行命令:"
    echo "$APPLY_CMD"
else
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" "$APPLY_CMD"
fi

# 验证修复
echo ""
echo "5. 验证修复..."
if [[ "$DRY_RUN" == "true" ]]; then
    echo "执行: curl -fsS -m 5 http://forum.clawdrepublic.cn/ 2>/dev/null | grep -o 'Flarum\|论坛' || echo '验证失败'"
else
    echo "等待5秒让配置生效..."
    sleep 5
    curl -fsS -m 5 http://forum.clawdrepublic.cn/ 2>/dev/null | grep -o 'Flarum\|论坛' || echo "验证失败，可能需要检查日志"
fi

echo ""
echo "=== 修复完成 ==="
echo "论坛地址: http://forum.clawdrepublic.cn/"
echo "本地地址: http://127.0.0.1:8081/"
echo "如需HTTPS，请确保域名解析正确并配置SSL证书"