#!/bin/bash
set -e

# 部署 quota-proxy SQLite 版本 + ADMIN_TOKEN 保护
# 用法: ./scripts/deploy-quota-proxy-sqlite-with-auth.sh [--dry-run] [--host <ip>]

DRY_RUN=false
HOST=""
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1"
      echo "用法: $0 [--dry-run] [--host <ip>]"
      exit 1
      ;;
  esac
done

if [ -z "$HOST" ]; then
  if [ -f "/tmp/server.txt" ]; then
    HOST=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [ -z "$HOST" ]; then
      HOST=$(grep -E '^ip:' /tmp/server.txt | cut -d: -f2 | tr -d ' ')
    fi
  fi
  if [ -z "$HOST" ]; then
    echo "错误: 未指定主机且 /tmp/server.txt 中未找到 IP"
    exit 1
  fi
fi

echo "目标主机: $HOST"
echo "部署 SQLite 版本 + ADMIN_TOKEN 保护"

# 检查本地文件
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -f "$LOCAL_DIR/quota-proxy/server-sqlite.js" ]; then
  echo "错误: 未找到 server-sqlite.js"
  exit 1
fi

# 生成随机 ADMIN_TOKEN
ADMIN_TOKEN=$(openssl rand -hex 32 2>/dev/null || echo "admin-token-$(date +%s)")

cat > /tmp/quota-proxy-sqlite-deploy.sh <<EOF
#!/bin/bash
set -e

cd /opt/roc/quota-proxy

echo "备份当前配置..."
cp -f docker-compose.yml docker-compose.yml.backup.\$(date +%s) 2>/dev/null || true
cp -f .env .env.backup.\$(date +%s) 2>/dev/null || true

echo "停止当前服务..."
docker compose down 2>/dev/null || true

echo "更新文件..."
# 复制 SQLite 版本
cat > server-sqlite.js <<'SERVER_EOF'
$(cat "$LOCAL_DIR/quota-proxy/server-sqlite.js")
SERVER_EOF

# 创建 Dockerfile
cat > Dockerfile <<'DOCKER_EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8787
CMD ["node", "server-sqlite.js"]
DOCKER_EOF

# 创建 docker-compose.yml
cat > docker-compose.yml <<'COMPOSE_EOF'
version: '3.8'
services:
  quota-proxy:
    build: .
    container_name: quota-proxy-sqlite
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - NODE_ENV=production
      - PORT=8787
      - ADMIN_TOKEN=${ADMIN_TOKEN:-admin-token-change-me}
      - DB_PATH=/data/quota.db
      - LOG_LEVEL=info
    volumes:
      - ./data:/data
COMPOSE_EOF

# 创建 .env 文件
cat > .env <<ENV_EOF
ADMIN_TOKEN=$ADMIN_TOKEN
ENV_EOF

echo "创建数据目录..."
mkdir -p data

echo "构建并启动服务..."
docker compose build
docker compose up -d

echo "等待服务启动..."
sleep 5

echo "检查服务状态..."
docker compose ps

echo "测试健康检查..."
curl -fsS http://127.0.0.1:8787/healthz || (echo "健康检查失败"; exit 1)

echo "测试管理员接口（需要 ADMIN_TOKEN）..."
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/keys || echo "管理员接口测试跳过（可能需要首次运行）"

echo "部署完成!"
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
echo "请妥善保存此 token"
EOF

if [ "$DRY_RUN" = true ]; then
  echo "=== 干跑模式 ==="
  echo "将执行以下操作:"
  cat /tmp/quota-proxy-sqlite-deploy.sh
  echo "ADMIN_TOKEN: $ADMIN_TOKEN"
else
  echo "开始部署..."
  scp -i "$SSH_KEY" /tmp/quota-proxy-sqlite-deploy.sh "root@$HOST:/tmp/deploy.sh"
  ssh -i "$SSH_KEY" "root@$HOST" "bash /tmp/deploy.sh"
  
  echo "验证部署..."
  ssh -i "$SSH_KEY" "root@$HOST" "cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz"
  
  echo "部署完成！"
  echo "ADMIN_TOKEN 已保存到服务器 /opt/roc/quota-proxy/.env"
fi

rm -f /tmp/quota-proxy-sqlite-deploy.sh