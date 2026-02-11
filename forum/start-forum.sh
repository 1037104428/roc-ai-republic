#!/bin/bash
# NodeBB 论坛启动脚本

set -e

echo "=== NodeBB 论坛启动脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查 Docker 和 Docker Compose
command -v docker >/dev/null 2>&1 || { echo "需要 Docker 但未安装"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "需要 Docker Compose 但未安装"; exit 1; }

# 设置环境变量
export NODEBB_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "default_secret_key_$(date +%s)")
export ADMIN_USER="admin"
export ADMIN_EMAIL="admin@clawd.ai"
export ADMIN_PASSWORD="Clawd@2026!"

echo "环境变量已设置:"
echo "  NODEBB_SECRET: [已设置]"
echo "  ADMIN_USER: $ADMIN_USER"
echo "  ADMIN_EMAIL: $ADMIN_EMAIL"
echo "  ADMIN_PASSWORD: $ADMIN_PASSWORD"

# 创建必要的目录
mkdir -p logs/nginx ssl

# 检查配置文件
if [ ! -f "config.json" ]; then
    echo "创建默认 config.json 配置文件..."
    cat > config.json <<EOF
{
  "url": "http://localhost:4567",
  "secret": "${NODEBB_SECRET}",
  "database": "redis",
  "redis": {
    "host": "redis",
    "port": "6379",
    "password": "",
    "database": "0"
  },
  "port": 4567,
  "upload_path": "/usr/src/app/public/uploads"
}
EOF
    echo "config.json 已创建"
fi

if [ ! -f "nginx.conf" ]; then
    echo "创建默认 nginx.conf 配置文件..."
    cat > nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    upstream nodebb {
        server nodebb:4567;
    }

    server {
        listen 80;
        server_name forum.localhost;

        location / {
            proxy_pass http://nodebb;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket 支持
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # 静态文件缓存
        location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
            proxy_pass http://nodebb;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }

        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
    }
}
EOF
    echo "nginx.conf 已创建"
fi

# 启动服务
echo "启动 NodeBB 论坛服务..."
docker-compose -f docker-compose-nodebb.yml up -d

echo "等待服务启动..."
sleep 10

# 检查服务状态
echo "检查服务状态:"
docker-compose -f docker-compose-nodebb.yml ps

echo "论坛访问地址:"
echo "  - NodeBB 直接访问: http://localhost:4567"
echo "  - 通过 Nginx: http://forum.localhost"
echo ""
echo "管理员账号:"
echo "  - 用户名: $ADMIN_USER"
echo "  - 密码: $ADMIN_PASSWORD"
echo "  - 邮箱: $ADMIN_EMAIL"
echo ""
echo "停止论坛: ./stop-forum.sh"
echo "查看日志: docker-compose -f docker-compose-nodebb.yml logs -f"