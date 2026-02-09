#!/usr/bin/env bash
set -euo pipefail

# 修复 forum.clawdrepublic.cn 502 错误
# 问题：Flarum 运行在 127.0.0.1:8081，但外网反向代理未正确配置
# 此脚本提供 Caddy/Nginx 配置修复方案

usage() {
  cat <<EOF
修复 forum.clawdrepublic.cn 502 错误

用法:
  $0 --caddy     # 生成 Caddyfile 配置
  $0 --nginx     # 生成 nginx.conf 配置
  $0 --deploy    # 部署修复配置到服务器（需要 SSH 访问）
  $0 --verify    # 验证论坛是否可访问

环境变量:
  SERVER_IP      服务器 IP（默认从 /tmp/server.txt 读取）
  FORUM_PORT     Flarum 端口（默认 8081）
EOF
  exit 1
}

# 读取服务器 IP
read_server_ip() {
  if [[ -f "/tmp/server.txt" ]]; then
    local content
    content=$(cat /tmp/server.txt | head -1)
    if [[ "$content" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$content"
    elif [[ "$content" =~ ^ip=([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
    else
      echo "8.210.185.194"  # 默认值
    fi
  else
    echo "8.210.185.194"  # 默认值
  fi
}

generate_caddy() {
  cat <<'EOF'
# Caddyfile for forum.clawdrepublic.cn
forum.clawdrepublic.cn {
    # 反向代理到 Flarum
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 日志
    log {
        output file /var/log/caddy/forum.log
        format json
    }
}

# 如果同时需要 HTTPS（自动证书）
# forum.clawdrepublic.cn {
#     tls {
#         dns cloudflare {env.CLOUDFLARE_API_TOKEN}
#     }
#     reverse_proxy 127.0.0.1:8081
# }
EOF
}

generate_nginx() {
  cat <<'EOF'
# nginx.conf for forum.clawdrepublic.cn
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
    
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
}

# HTTPS 配置（需要证书）
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name forum.clawdrepublic.cn;
#     
#     ssl_certificate /etc/ssl/certs/forum.clawdrepublic.cn.crt;
#     ssl_certificate_key /etc/ssl/private/forum.clawdrepublic.cn.key;
#     
#     location / {
#         proxy_pass http://127.0.0.1:8081;
#         proxy_set_header Host $host;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#     }
# }
EOF
}

deploy_fix() {
  local server_ip
  server_ip=$(read_server_ip)
  
  echo "部署论坛 502 修复到服务器 $server_ip..."
  
  # 生成 Caddy 配置
  local caddy_config
  caddy_config=$(generate_caddy)
  
  # 上传并应用配置
  ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" <<EOF
set -e
echo "检查 Flarum 服务状态..."
if ! docker ps | grep -q flarum; then
  echo "警告: Flarum 容器未运行"
  echo "检查 /opt/roc/forum 目录..."
  ls -la /opt/roc/forum/ 2>/dev/null || echo "论坛目录不存在"
fi

echo "检查端口 8081..."
netstat -tlnp | grep :8081 || echo "端口 8081 未监听"

echo "生成 Caddy 配置..."
cat > /tmp/forum-caddy.conf <<'CADDY_EOF'
$caddy_config
CADDY_EOF

echo "配置内容:"
cat /tmp/forum-caddy.conf

echo "注意: 需要将上述配置添加到 Caddy 主配置并重启 Caddy"
echo "或者运行: caddy reload --config /etc/caddy/Caddyfile"
EOF
  
  echo "部署完成。请手动将配置添加到 Caddy 并重启服务。"
}

verify_forum() {
  echo "验证论坛可访问性..."
  
  # 检查外网访问
  echo "1. 检查 forum.clawdrepublic.cn (外网):"
  if curl -fsS -m 10 "http://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "   ✅ 论坛可访问"
    return 0
  else
    echo "   ❌ 论坛返回 502 或其他错误"
    
    # 检查服务器本地访问
    local server_ip
    server_ip=$(read_server_ip)
    echo "2. 检查服务器 $server_ip 本地访问:"
    if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
       "curl -fsS -m 5 'http://127.0.0.1:8081/'" >/dev/null 2>&1; then
      echo "   ✅ 服务器本地 Flarum 运行正常"
      echo "   🔧 问题: 反向代理配置缺失"
      return 1
    else
      echo "   ❌ 服务器本地 Flarum 未运行"
      echo "   🔧 问题: Flarum 服务未启动"
      return 2
    fi
  fi
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
  fi
  
  case "$1" in
    --caddy)
      generate_caddy
      ;;
    --nginx)
      generate_nginx
      ;;
    --deploy)
      deploy_fix
      ;;
    --verify)
      verify_forum
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "未知选项: $1"
      usage
      ;;
  esac
}

main "$@"