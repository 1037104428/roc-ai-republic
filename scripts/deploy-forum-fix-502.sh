#!/usr/bin/env bash
set -euo pipefail

# 论坛 502 修复部署脚本
# 修复 forum.clawdrepublic.cn 外网 502 错误（反向代理/HTTPS 配置）
#
# 使用：
#   ./scripts/deploy-forum-fix-502.sh --dry-run
#   ./scripts/deploy-forum-forum-fix-502.sh --caddy
#   ./scripts/deploy-forum-fix-502.sh --nginx

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/roc/forum}"

usage() {
  cat <<'TXT'
论坛 502 修复部署脚本

修复 forum.clawdrepublic.cn 外网 502 错误（反向代理/HTTPS 配置）

选项：
  --caddy             使用 Caddy 配置（自动 HTTPS）
  --nginx             使用 Nginx 配置（需手动证书）
  --dry-run           仅打印命令，不执行
  --help              显示帮助

环境变量：
  SERVER_FILE         服务器信息文件（默认：/tmp/server.txt）
  REMOTE_USER         远程用户（默认：root）
  REMOTE_DIR          远程论坛目录（默认：/opt/roc/forum）
TXT
}

DRY_RUN=0
PROXY_TYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --caddy) PROXY_TYPE="caddy"; shift ;;
    --nginx) PROXY_TYPE="nginx"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知选项: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$PROXY_TYPE" ]]; then
  echo "错误：必须指定 --caddy 或 --nginx"
  usage
  exit 1
fi

# 读取服务器信息
if [[ ! -f "$SERVER_FILE" ]]; then
  echo "错误：服务器信息文件不存在: $SERVER_FILE"
  echo "请创建文件并写入服务器IP，例如："
  echo "  8.210.185.194"
  exit 1
fi

SERVER_IP=$(head -n1 "$SERVER_FILE" | sed 's/^ip://;s/^[[:space:]]*//;s/[[:space:]]*$//')
if [[ -z "$SERVER_IP" ]]; then
  echo "错误：无法从 $SERVER_FILE 解析服务器IP"
  exit 1
fi

echo "目标服务器: $SERVER_IP"
echo "代理类型: $PROXY_TYPE"
echo "远程目录: $REMOTE_DIR"
echo ""

run_remote() {
  local cmd="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] ssh $REMOTE_USER@$SERVER_IP \"$cmd\""
  else
    ssh "$REMOTE_USER@$SERVER_IP" "$cmd"
  fi
}

# 检查论坛服务状态
echo "1. 检查论坛服务状态..."
run_remote "systemctl status flarum || docker compose -f $REMOTE_DIR/docker-compose.yml ps 2>/dev/null || echo '论坛服务未找到'"

# 检查 Flarum 是否在 127.0.0.1:8081 运行
echo ""
echo "2. 检查 Flarum 内部端口..."
run_remote "curl -fsS -m 5 http://127.0.0.1:8081/ 2>/dev/null && echo 'Flarum 内部运行正常' || echo 'Flarum 内部不可达'"

# 部署反向代理配置
echo ""
echo "3. 部署 $PROXY_TYPE 反向代理配置..."

if [[ "$PROXY_TYPE" == "caddy" ]]; then
  CADDY_CONFIG=$(cat <<'CADDY'
# forum.clawdrepublic.cn - Caddy 反向代理配置
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    encode gzip
    header {
        -Server
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
CADDY
)
  
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] 将创建 Caddy 配置:"
    echo "$CADDY_CONFIG"
    echo "[dry-run] 配置路径: /etc/caddy/Caddyfile (需要追加)"
  else
    # 备份原配置
    run_remote "cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
    # 追加配置
    echo "$CADDY_CONFIG" | run_remote "cat >> /etc/caddy/Caddyfile"
    # 重载 Caddy
    run_remote "systemctl reload caddy || caddy reload --config /etc/caddy/Caddyfile"
  fi

elif [[ "$PROXY_TYPE" == "nginx" ]]; then
  NGINX_CONFIG=$(cat <<'NGINX'
# forum.clawdrepublic.cn - Nginx 反向代理配置
server {
    listen 80;
    listen [::]:80;
    server_name forum.clawdrepublic.cn;
    
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:8081;
    }
}
NGINX
)
  
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] 将创建 Nginx 配置:"
    echo "$NGINX_CONFIG"
    echo "[dry-run] 配置路径: /etc/nginx/sites-available/forum.clawdrepublic.cn"
  else
    # 创建 Nginx 配置
    echo "$NGINX_CONFIG" | run_remote "cat > /etc/nginx/sites-available/forum.clawdrepublic.cn"
    # 启用站点
    run_remote "ln -sf /etc/nginx/sites-available/forum.clawdrepublic.cn /etc/nginx/sites-enabled/ 2>/dev/null || true"
    # 测试配置
    run_remote "nginx -t"
    # 重载 Nginx
    run_remote "systemctl reload nginx || nginx -s reload"
  fi
fi

# 验证修复
echo ""
echo "4. 验证修复..."
if [[ $DRY_RUN -eq 1 ]]; then
  echo "[dry-run] 等待 3 秒后验证..."
  echo "[dry-run] curl -fsS -m 5 http://forum.clawdrepublic.cn/"
else
  sleep 3
  echo "测试论坛访问..."
  if curl -fsS -m 5 "http://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "✅ 论坛 502 修复成功！"
    echo "论坛地址: http://forum.clawdrepublic.cn/"
  else
    echo "❌ 论坛仍然不可访问"
    echo "请检查："
    echo "1. 域名解析是否正确"
    echo "2. 防火墙是否开放 80 端口"
    echo "3. 反向代理服务是否运行"
    exit 1
  fi
fi

echo ""
echo "✅ 论坛 502 修复部署脚本完成"
echo "下一步："
echo "1. 访问 http://forum.clawdrepublic.cn/ 确认论坛可访问"
echo "2. 配置 HTTPS（Caddy 自动，Nginx 需手动证书）"
echo "3. 更新官网链接到论坛"