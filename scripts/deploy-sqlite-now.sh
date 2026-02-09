#!/bin/bash
# deploy-sqlite-now.sh - 立即部署 SQLite 版本的 quota-proxy
# 中等落地：将服务器上的 quota-proxy 从 JSON 版本迁移到 SQLite 版本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="/tmp/server.txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 读取服务器信息
if [ ! -f "$SERVER_FILE" ]; then
    log_error "服务器文件不存在: $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$SERVER_FILE" | head -1)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2 | head -1)
fi

if [ -z "$SERVER_IP" ]; then
    log_error "无法从 $SERVER_FILE 中提取服务器IP"
    exit 1
fi

log_info "目标服务器: $SERVER_IP"

# 1. 备份当前服务状态
log_info "1. 备份当前服务状态..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 当前状态 ==="
docker compose ps
echo ""
echo "=== 环境变量 ==="
cat .env 2>/dev/null | grep -v "DEEPSEEK_API_KEY" | grep -v "ADMIN_TOKEN"
echo ""
echo "=== 数据文件 ==="
ls -la data/
echo ""
echo "=== 备份当前配置 ==="
cp -f compose.yaml compose.yaml.backup.$(date +%Y%m%d-%H%M%S)
cp -f server.js server.js.backup.$(date +%Y%m%d-%H%M%S)
EOF

# 2. 准备 SQLite 版本文件
log_info "2. 准备 SQLite 版本文件..."
cat > /tmp/compose-sqlite.yaml << 'EOF'
version: '3.8'
services:
  quota-proxy:
    build:
      context: .
      dockerfile: Dockerfile-sqlite
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - DAILY_REQ_LIMIT=${DAILY_REQ_LIMIT:-200}
      - SQLITE_PATH=/data/quota.db
    volumes:
      - ./data:/data
    restart: unless-stopped
EOF

cat > /tmp/Dockerfile-sqlite << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY server-sqlite.js ./server.js
EXPOSE 8787
CMD ["node", "server.js"]
EOF

# 3. 上传文件到服务器
log_info "3. 上传 SQLite 版本文件到服务器..."
scp -i ~/.ssh/id_ed25519_roc_server /tmp/compose-sqlite.yaml root@$SERVER_IP:/opt/roc/quota-proxy/compose-sqlite.yaml
scp -i ~/.ssh/id_ed25519_roc_server /tmp/Dockerfile-sqlite root@$SERVER_IP:/opt/roc/quota-proxy/Dockerfile-sqlite
scp -i ~/.ssh/id_ed25519_roc_server $REPO_ROOT/quota-proxy/server-sqlite.js root@$SERVER_IP:/opt/roc/quota-proxy/server-sqlite.js

# 4. 停止当前服务
log_info "4. 停止当前服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose down || true
EOF

# 5. 切换到 SQLite 版本
log_info "5. 切换到 SQLite 版本..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
# 备份原文件
cp compose.yaml compose.yaml.original
cp Dockerfile Dockerfile.original
cp server.js server.js.original

# 使用 SQLite 版本
cp compose-sqlite.yaml compose.yaml
cp Dockerfile-sqlite Dockerfile
cp server-sqlite.js server.js

# 确保数据目录存在
mkdir -p data

# 如果 quota.db 不存在，创建空数据库
if [ ! -f data/quota.db ]; then
    echo "创建空的 SQLite 数据库..."
    touch data/quota.db
fi
EOF

# 6. 启动 SQLite 版本
log_info "6. 启动 SQLite 版本服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose up -d --build
sleep 5
docker compose ps
EOF

# 7. 验证部署
log_info "7. 验证 SQLite 版本部署..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 健康检查 ==="
curl -fsS http://127.0.0.1:8787/healthz || echo "健康检查失败"
echo ""
echo "=== 容器日志（最后10行）==="
docker compose logs --tail=10
echo ""
echo "=== 数据文件状态 ==="
ls -la data/
EOF

# 8. 创建回滚脚本
log_info "8. 创建回滚脚本..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
cat > rollback-to-json.sh << 'ROLLBACK_EOF'
#!/bin/bash
echo "回滚到 JSON 版本..."
cp compose.yaml.original compose.yaml
cp Dockerfile.original Dockerfile
cp server.js.original server.js
docker compose down
docker compose up -d --build
sleep 3
curl -fsS http://127.0.0.1:8787/healthz && echo "回滚成功" || echo "回滚失败"
ROLLBACK_EOF
chmod +x rollback-to-json.sh
echo "回滚脚本已创建: /opt/roc/quota-proxy/rollback-to-json.sh"
EOF

log_success "SQLite 版本部署完成！"
log_info "服务器: $SERVER_IP"
log_info "端口: 127.0.0.1:8787"
log_info "健康检查: curl -fsS http://127.0.0.1:8787/healthz"
log_info "回滚脚本: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./rollback-to-json.sh'"