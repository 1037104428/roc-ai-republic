#!/bin/bash
set -e

# 论坛反向代理部署脚本
# 修复 forum.clawdrepublic.cn 外网 502 问题

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
论坛反向代理部署脚本

用法: $0 [选项]

选项:
  --dry-run         只显示将要执行的命令，不实际执行
  --caddy           使用 Caddy 配置（默认）
  --nginx           使用 Nginx 配置
  --help            显示此帮助信息

环境变量:
  SERVER_FILE       服务器信息文件路径（默认: /tmp/server.txt）
                    格式: ip:8.210.185.194

示例:
  $0 --dry-run
  $0 --caddy
  SERVER_FILE=/path/to/server.txt $0 --nginx
EOF
}

# 解析参数
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
        --help)
            show_help
            exit 0
            ;;
        *)
            error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 读取服务器信息
if [[ ! -f "$SERVER_FILE" ]]; then
    error "服务器信息文件不存在: $SERVER_FILE"
    error "请创建文件并写入服务器IP，例如: echo '8.210.185.194' > $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(head -n1 "$SERVER_FILE" | sed 's/^ip://' | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    error "无法从 $SERVER_FILE 读取服务器IP"
    exit 1
fi

log "目标服务器: $SERVER_IP"
log "代理类型: $PROXY_TYPE"
log "仓库根目录: $REPO_ROOT"

# 检查 SSH 密钥
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
if [[ ! -f "$SSH_KEY" ]]; then
    warn "SSH 密钥不存在: $SSH_KEY"
    warn "将使用默认 SSH 密钥"
    SSH_KEY=""
fi

SSH_CMD="ssh -o BatchMode=yes -o ConnectTimeout=8"
if [[ -n "$SSH_KEY" ]]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD root@$SERVER_IP"

# 检查论坛是否在运行
log "检查论坛服务状态..."
if $DRY_RUN; then
    echo "$SSH_CMD 'docker ps --filter \"name=flarum\" --format \"table {{.Names}}\\t{{.Status}}\"'"
else
    FORUM_STATUS=$($SSH_CMD 'docker ps --filter "name=flarum" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true')
    if echo "$FORUM_STATUS" | grep -q "flarum"; then
        log "论坛容器正在运行:"
        echo "$FORUM_STATUS"
    else
        error "论坛容器未运行"
        error "请先部署论坛: cd $REPO_ROOT && ./scripts/deploy-forum.sh"
        exit 1
    fi
fi

# 检查本地端口
log "检查论坛本地端口..."
if $DRY_RUN; then
    echo "$SSH_CMD 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo \"论坛本地端口 8081 可达\" || echo \"论坛本地端口 8081 不可达\"'"
else
    LOCAL_ACCESS=$($SSH_CMD 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1 && echo "OK" || echo "FAIL"')
    if [[ "$LOCAL_ACCESS" == "OK" ]]; then
        log "论坛本地端口 8081 可达"
    else
        error "论坛本地端口 8081 不可达"
        error "请检查论坛服务配置"
        exit 1
    fi
fi

# 部署反向代理配置
case "$PROXY_TYPE" in
    caddy)
        log "部署 Caddy 反向代理配置..."
        CADDY_CONFIG="$REPO_ROOT/web/caddy/Caddyfile.forum"
        
        if [[ ! -f "$CADDY_CONFIG" ]]; then
            log "创建 Caddy 配置..."
            cat > "$CADDY_CONFIG" << 'EOF'
# 论坛反向代理配置
forum.clawdrepublic.cn {
    # 反向代理到 Flarum
    reverse_proxy 127.0.0.1:8081
    
    # 日志
    log {
        output file /var/log/caddy/forum.log {
            roll_size 10mb
            roll_keep 5
        }
    }
    
    # 安全头
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# 重定向 http -> https
http://forum.clawdrepublic.cn {
    redir https://forum.clawdrepublic.cn{uri} permanent
}
EOF
            log "Caddy 配置已创建: $CADDY_CONFIG"
        fi
        
        if $DRY_RUN; then
            echo "scp $CADDY_CONFIG root@$SERVER_IP:/etc/caddy/Caddyfile.forum"
            echo "$SSH_CMD 'caddy validate --config /etc/caddy/Caddyfile.forum'"
            echo "$SSH_CMD 'caddy reload --config /etc/caddy/Caddyfile.forum'"
        else
            log "上传 Caddy 配置..."
            scp "$CADDY_CONFIG" "root@$SERVER_IP:/etc/caddy/Caddyfile.forum"
            
            log "验证配置..."
            $SSH_CMD 'caddy validate --config /etc/caddy/Caddyfile.forum'
            
            log "重新加载 Caddy..."
            $SSH_CMD 'caddy reload --config /etc/caddy/Caddyfile.forum'
        fi
        ;;
    
    nginx)
        log "部署 Nginx 反向代理配置..."
        NGINX_CONFIG="$REPO_ROOT/web/nginx/forum.conf"
        
        if [[ ! -f "$NGINX_CONFIG" ]]; then
            log "创建 Nginx 配置..."
            cat > "$NGINX_CONFIG" << 'EOF'
# 论坛反向代理配置
server {
    listen 80;
    listen [::]:80;
    server_name forum.clawdrepublic.cn;
    
    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name forum.clawdrepublic.cn;
    
    # SSL 证书 - Caddy 自动管理
    ssl_certificate /etc/ssl/certs/cert.pem;
    ssl_certificate_key /etc/ssl/private/key.pem;
    
    # 反向代理到 Flarum
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # 日志
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
    
    # 安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
EOF
            log "Nginx 配置已创建: $NGINX_CONFIG"
        fi
        
        if $DRY_RUN; then
            echo "scp $NGINX_CONFIG root@$SERVER_IP:/etc/nginx/sites-available/forum.conf"
            echo "$SSH_CMD 'ln -sf /etc/nginx/sites-available/forum.conf /etc/nginx/sites-enabled/'"
            echo "$SSH_CMD 'nginx -t'"
            echo "$SSH_CMD 'systemctl reload nginx'"
        else
            log "上传 Nginx 配置..."
            scp "$NGINX_CONFIG" "root@$SERVER_IP:/etc/nginx/sites-available/forum.conf"
            
            log "启用站点..."
            $SSH_CMD 'ln -sf /etc/nginx/sites-available/forum.conf /etc/nginx/sites-enabled/'
            
            log "测试配置..."
            $SSH_CMD 'nginx -t'
            
            log "重新加载 Nginx..."
            $SSH_CMD 'systemctl reload nginx'
        fi
        ;;
esac

# 验证部署
log "验证论坛外网访问..."
if $DRY_RUN; then
    echo "curl -fsS -m 10 https://forum.clawdrepublic.cn/ >/dev/null && echo '论坛外网访问正常' || echo '论坛外网访问失败'"
else
    sleep 3  # 等待配置生效
    if curl -fsS -m 10 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
        log "✅ 论坛外网访问正常"
        
        # 检查页面内容
        PAGE_CONTENT=$(curl -fsS -m 5 "https://forum.clawdrepublic.cn/" 2>/dev/null || true)
        if echo "$PAGE_CONTENT" | grep -q "Clawd 国度论坛"; then
            log "✅ 论坛页面内容正确"
        else
            warn "论坛页面内容可能不正确"
        fi
    else
        error "论坛外网访问失败"
        error "请检查:"
        error "1. DNS 解析: forum.clawdrepublic.cn -> $SERVER_IP"
        error "2. 防火墙规则: 80/443 端口开放"
        error "3. 反向代理服务状态"
        exit 1
    fi
fi

log "论坛反向代理部署完成！"
log "访问地址: https://forum.clawdrepublic.cn/"
log "本地管理: ssh root@$SERVER_IP 'docker logs flarum'"

# 生成验证命令
cat << EOF

📋 验证命令:
1. 外网访问: curl -fsS -m 5 https://forum.clawdrepublic.cn/ | grep -q "Clawd 国度论坛" && echo "✅ 论坛正常"
2. 本地端口: ssh root@$SERVER_IP 'curl -fsS http://127.0.0.1:8081/ >/dev/null && echo "✅ 论坛本地正常"'
3. 容器状态: ssh root@$SERVER_IP 'docker ps --filter "name=flarum" --format "table {{.Names}}\\t{{.Status}}"'
4. 代理日志: ssh root@$SERVER_IP 'tail -n 5 /var/log/caddy/forum.log 2>/dev/null || tail -n 5 /var/log/nginx/forum.access.log 2>/dev/null'

🔧 故障排查:
1. 检查 DNS: dig forum.clawdrepublic.cn +short
2. 检查端口: nc -zv $SERVER_IP 443
3. 检查服务: ssh root@$SERVER_IP 'systemctl status caddy || systemctl status nginx'
4. 查看日志: ssh root@$SERVER_IP 'docker logs flarum --tail 20'
EOF