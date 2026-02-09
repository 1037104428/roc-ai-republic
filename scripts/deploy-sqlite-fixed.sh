#!/bin/bash
# deploy-sqlite-fixed.sh - 修复并部署 SQLite 版本的 quota-proxy
# 中等落地：修复 SQLite 依赖问题并部署

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

# 1. 检查当前状态
log_info "1. 检查当前服务状态..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 当前容器状态 ==="
docker compose ps
echo ""
echo "=== 健康检查 ==="
curl -fsS http://127.0.0.1:8787/healthz && echo "健康检查通过" || echo "健康检查失败"
EOF

# 2. 准备修复的 SQLite 版本文件
log_info "2. 准备修复的 SQLite 版本文件..."

# 创建正确的 Dockerfile
cat > /tmp/Dockerfile-sqlite-fixed << 'EOF'
FROM node:20-alpine
WORKDIR /app

# 复制 package.json 文件
COPY package*.json ./

# 安装依赖（包括 sqlite3 需要的编译工具）
RUN apk add --no-cache python3 make g++ \
    && npm ci --only=production \
    && apk del python3 make g++

# 复制应用代码
COPY server-sqlite.js ./server.js

EXPOSE 8787
CMD ["node", "server.js"]
EOF

# 创建 compose 文件
cat > /tmp/compose-sqlite-fixed.yaml << 'EOF'
version: '3.8'
services:
  quota-proxy:
    build:
      context: .
      dockerfile: Dockerfile-sqlite-fixed
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

# 3. 上传修复文件到服务器
log_info "3. 上传修复文件到服务器..."
scp -i ~/.ssh/id_ed25519_roc_server /tmp/Dockerfile-sqlite-fixed root@$SERVER_IP:/opt/roc/quota-proxy/Dockerfile-sqlite-fixed
scp -i ~/.ssh/id_ed25519_roc_server /tmp/compose-sqlite-fixed.yaml root@$SERVER_IP:/opt/roc/quota-proxy/compose-sqlite-fixed.yaml
scp -i ~/.ssh/id_ed25519_roc_server $REPO_ROOT/quota-proxy/server-sqlite.js root@$SERVER_IP:/opt/roc/quota-proxy/server-sqlite-fixed.js

# 4. 停止当前服务
log_info "4. 停止当前服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose down || true
EOF

# 5. 切换到修复的 SQLite 版本
log_info "5. 切换到修复的 SQLite 版本..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
# 备份原文件
cp compose.yaml compose.yaml.backup.$(date +%Y%m%d-%H%M%S)
cp Dockerfile Dockerfile.backup.$(date +%Y%m%d-%H%M%S)
cp server.js server.js.backup.$(date +%Y%m%d-%H%M%S)

# 使用修复的 SQLite 版本
cp compose-sqlite-fixed.yaml compose.yaml
cp Dockerfile-sqlite-fixed Dockerfile
cp server-sqlite-fixed.js server.js

# 确保数据目录存在
mkdir -p data

# 如果 quota.db 不存在，创建空文件
if [ ! -f data/quota.db ]; then
    echo "创建空的 SQLite 数据库文件..."
    touch data/quota.db
fi
EOF

# 6. 启动修复的 SQLite 版本
log_info "6. 启动修复的 SQLite 版本服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose up -d --build
sleep 10  # 给构建和启动更多时间
docker compose ps
EOF

# 7. 验证部署
log_info "7. 验证修复的 SQLite 版本部署..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 健康检查 ==="
for i in {1..5}; do
    if curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null; then
        echo "健康检查通过！"
        break
    fi
    echo "尝试 $i/5: 健康检查失败，等待 3 秒..."
    sleep 3
done
echo ""
echo "=== 容器日志（最后20行）==="
docker compose logs --tail=20
echo ""
echo "=== 数据文件状态 ==="
ls -la data/
EOF

# 8. 测试管理接口
log_info "8. 测试 SQLite 版本管理接口..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 测试 /admin/keys (创建测试密钥) ==="
ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2)
if [ -n "$ADMIN_TOKEN" ]; then
    curl -s -X POST http://127.0.0.1:8787/admin/keys \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"label":"test-sqlite-deployment"}' | jq . 2>/dev/null || echo "响应: $(curl -s -X POST http://127.0.0.1:8787/admin/keys -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"label":"test-sqlite-deployment"}')"
else
    echo "未找到 ADMIN_TOKEN"
fi
echo ""
echo "=== 测试 /admin/usage (查看使用情况) ==="
if [ -n "$ADMIN_TOKEN" ]; then
    curl -s http://127.0.0.1:8787/admin/usage \
        -H "Authorization: Bearer $ADMIN_TOKEN" | jq . 2>/dev/null || echo "响应: $(curl -s http://127.0.0.1:8787/admin/usage -H "Authorization: Bearer $ADMIN_TOKEN")"
fi
EOF

# 9. 创建验证脚本
log_info "9. 创建验证脚本..."
cat > /tmp/verify-sqlite-deployment.sh << 'EOF'
#!/bin/bash
# verify-sqlite-deployment.sh - 验证 SQLite 版本部署

SERVER_IP="$1"
if [ -z "$SERVER_IP" ]; then
    echo "用法: $0 <服务器IP>"
    exit 1
fi

echo "验证 SQLite 版本部署到 $SERVER_IP..."
echo "1. 健康检查:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'curl -fsS http://127.0.0.1:8787/healthz && echo "✓ 健康检查通过" || echo "✗ 健康检查失败"'

echo ""
echo "2. 容器状态:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'cd /opt/roc/quota-proxy && docker compose ps'

echo ""
echo "3. 数据文件:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'cd /opt/roc/quota-proxy && ls -la data/'

echo ""
echo "4. 版本验证:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'cd /opt/roc/quota-proxy && grep -n "sqlite3" server.js | head -2 && echo "✓ 使用 SQLite 版本"'
EOF

chmod +x /tmp/verify-sqlite-deployment.sh
scp -i ~/.ssh/id_ed25519_roc_server /tmp/verify-sqlite-deployment.sh root@$SERVER_IP:/opt/roc/quota-proxy/verify-sqlite-deployment.sh

log_success "修复的 SQLite 版本部署完成！"
log_info "服务器: $SERVER_IP"
log_info "端口: 127.0.0.1:8787"
log_info "健康检查: curl -fsS http://127.0.0.1:8787/healthz"
log_info "验证脚本: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./verify-sqlite-deployment.sh localhost'"
log_info "Git提交: 请将部署脚本和验证脚本提交到仓库"