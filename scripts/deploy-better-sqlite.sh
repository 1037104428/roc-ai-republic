#!/bin/bash
# deploy-better-sqlite.sh - 部署 better-sqlite3 版本的 quota-proxy
# 中等落地：使用 better-sqlite3 替代 sqlite3，解决依赖问题

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
echo "=== 当前状态 ==="
docker compose ps
echo ""
echo "=== 健康检查 ==="
curl -fsS http://127.0.0.1:8787/healthz && echo "健康检查通过" || echo "健康检查失败"
EOF

# 2. 准备 better-sqlite3 版本文件
log_info "2. 准备 better-sqlite3 版本文件..."

# 创建 Dockerfile
cat > /tmp/Dockerfile-better-sqlite << 'EOF'
FROM node:20-alpine
WORKDIR /app

# 复制 package.json 文件
COPY package*.json ./

# 安装依赖（better-sqlite3 需要编译）
RUN apk add --no-cache python3 make g++ \
    && npm ci --only=production \
    && apk del python3 make g++

# 复制应用代码
COPY server-better-sqlite.js ./server.js

EXPOSE 8787
CMD ["node", "server.js"]
EOF

# 创建 compose 文件
cat > /tmp/compose-better-sqlite.yaml << 'EOF'
version: '3.8'
services:
  quota-proxy:
    build:
      context: .
      dockerfile: Dockerfile-better-sqlite
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

# 3. 上传文件到服务器
log_info "3. 上传 better-sqlite3 版本文件到服务器..."
scp -i ~/.ssh/id_ed25519_roc_server /tmp/Dockerfile-better-sqlite root@$SERVER_IP:/opt/roc/quota-proxy/Dockerfile-better-sqlite
scp -i ~/.ssh/id_ed25519_roc_server /tmp/compose-better-sqlite.yaml root@$SERVER_IP:/opt/roc/quota-proxy/compose-better-sqlite.yaml
scp -i ~/.ssh/id_ed25519_roc_server $REPO_ROOT/quota-proxy/server-better-sqlite.js root@$SERVER_IP:/opt/roc/quota-proxy/server-better-sqlite.js

# 4. 停止当前服务
log_info "4. 停止当前服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose down || true
EOF

# 5. 切换到 better-sqlite3 版本
log_info "5. 切换到 better-sqlite3 版本..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
# 备份原文件
cp compose.yaml compose.yaml.backup.$(date +%Y%m%d-%H%M%S)
cp Dockerfile Dockerfile.backup.$(date +%Y%m%d-%H%M%S)
cp server.js server.js.backup.$(date +%Y%m%d-%H%M%S)

# 使用 better-sqlite3 版本
cp compose-better-sqlite.yaml compose.yaml
cp Dockerfile-better-sqlite Dockerfile
cp server-better-sqlite.js server.js

# 确保数据目录存在
mkdir -p data

# 如果 quota.db 不存在，创建空文件
if [ ! -f data/quota.db ]; then
    echo "创建空的 SQLite 数据库文件..."
    touch data/quota.db
fi
EOF

# 6. 启动 better-sqlite3 版本
log_info "6. 启动 better-sqlite3 版本服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
docker compose up -d --build
sleep 15  # 给构建和启动更多时间
docker compose ps
EOF

# 7. 验证部署
log_info "7. 验证 better-sqlite3 版本部署..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 健康检查 ==="
for i in {1..10}; do
    if curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null; then
        echo "健康检查通过！"
        break
    fi
    echo "尝试 $i/10: 健康检查失败，等待 3 秒..."
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
log_info "8. 测试 better-sqlite3 版本管理接口..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
cd /opt/roc/quota-proxy
echo "=== 测试 /admin/keys (创建测试密钥) ==="
ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2)
if [ -n "$ADMIN_TOKEN" ]; then
    curl -s -X POST http://127.0.0.1:8787/admin/keys \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"label":"test-better-sqlite-deployment-$(date +%s)"}' | jq . 2>/dev/null || echo "响应: $(curl -s -X POST http://127.0.0.1:8787/admin/keys -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"label":"test-better-sqlite"}')"
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

# 9. 提交到仓库
log_info "9. 提交 better-sqlite3 版本到仓库..."
cd $REPO_ROOT
git add quota-proxy/server-better-sqlite.js
git add scripts/deploy-better-sqlite.sh
git commit -m "feat(quota-proxy): add better-sqlite3 version with simplified deployment

- Add server-better-sqlite.js using better-sqlite3 (easier dependency management)
- Add deploy-better-sqlite.sh for reliable SQLite deployment
- Fixes sqlite3 dependency issues in Alpine Docker
- Maintains full admin API compatibility"
git push origin main
git push gitee main

log_success "better-sqlite3 版本部署完成！"
log_info "服务器: $SERVER_IP"
log_info "端口: 127.0.0.1:8787"
log_info "健康检查: curl -fsS http://127.0.0.1:8787/healthz"
log_info "Git提交: $(cd $REPO_ROOT && git log --oneline -1)"
log_info "GitHub: https://github.com/1037104428/roc-ai-republic/commit/$(cd $REPO_ROOT && git rev-parse HEAD)"
log_info "Gitee: https://gitee.com/junkaiWang324/roc-ai-republic/commit/$(cd $REPO_ROOT && git rev-parse HEAD)"