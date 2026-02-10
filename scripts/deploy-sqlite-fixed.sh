#!/bin/bash
set -e

# 修复版 SQLite 部署脚本 - 使用预构建的镜像
# 用法: ./scripts/deploy-sqlite-fixed.sh [--dry-run] [--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat <<EOF
修复版 SQLite 部署脚本 - 使用预构建的镜像避免构建错误

用法: $0 [选项]

选项:
  --dry-run     只显示将要执行的命令，不实际执行
  --help        显示此帮助信息
  --server-ip   IP 地址 (默认从 $SERVER_FILE 读取)

环境变量:
  SERVER_FILE   服务器信息文件路径 (默认: /tmp/server.txt)
  SSH_KEY       SSH 私钥路径 (默认: ~/.ssh/id_ed25519_roc_server)

示例:
  $0                     # 从 /tmp/server.txt 读取 IP 并部署
  $0 --server-ip 1.2.3.4 # 指定服务器 IP
  $0 --dry-run          # 预览部署命令
EOF
}

# 解析参数
DRY_RUN=false
SERVER_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取服务器 IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "$SERVER_FILE" ]]; then
        # 支持格式: ip:8.210.185.194 或裸 IP
        SERVER_IP=$(head -1 "$SERVER_FILE" | sed 's/^ip://')
        if [[ -z "$SERVER_IP" ]]; then
            echo "错误: 无法从 $SERVER_FILE 解析 IP 地址"
            exit 1
        fi
    else
        echo "错误: 未指定 --server-ip 且 $SERVER_FILE 不存在"
        exit 1
    fi
fi

# SSH 配置
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_ssh() {
    local cmd="$1"
    if $DRY_RUN; then
        echo "[DRY-RUN] ssh $SSH_OPTS root@$SERVER_IP \"$cmd\""
    else
        ssh $SSH_OPTS "root@$SERVER_IP" "$cmd"
    fi
}

run_local() {
    local cmd="$1"
    if $DRY_RUN; then
        echo "[DRY-RUN] $cmd"
    else
        eval "$cmd"
    fi
}

# 检查服务器连接
log_info "检查服务器连接: $SERVER_IP"
if ! run_ssh "echo '连接成功'" >/dev/null 2>&1; then
    log_error "无法连接到服务器 $SERVER_IP"
    exit 1
fi

# 检查当前 quota-proxy 状态
log_info "检查当前 quota-proxy 状态"
run_ssh "cd /opt/roc/quota-proxy 2>/dev/null && docker compose ps 2>/dev/null || echo '未找到 quota-proxy 目录'"

# 创建 SQLite 部署目录
log_info "准备 SQLite 部署文件"
SQLITE_DEPLOY_DIR="/tmp/quota-proxy-sqlite-fixed-$(date +%s)"
run_ssh "mkdir -p $SQLITE_DEPLOY_DIR"

# 创建简化的 Dockerfile（使用 node:18-alpine 基础镜像）
log_info "创建简化的 Dockerfile"
SIMPLIFIED_DOCKERFILE=$(cat <<'EOF'
FROM node:18-alpine

WORKDIR /app

# 复制应用文件
COPY package.json package-lock.json ./
COPY server-sqlite.js ./

# 安装依赖（使用 npm install 而不是 npm ci，更兼容）
RUN apk add --no-cache python3 make g++ \
    && npm install --only=production \
    && apk del python3 make g++

# 创建非root用户
RUN addgroup -g 1001 -S nodejs \
    && adduser -S nodejs -u 1001

# 切换用户
USER nodejs

# 暴露端口
EXPOSE 8787

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8787/healthz || exit 1

# 启动命令
CMD ["node", "server-sqlite.js"]
EOF
)

run_ssh "cat > $SQLITE_DEPLOY_DIR/Dockerfile <<'EOF'
$SIMPLIFIED_DOCKERFILE
EOF"

# 复制必要的文件到服务器
log_info "复制部署文件到服务器"
run_local "scp $SSH_OPTS $REPO_ROOT/quota-proxy/server-sqlite.js root@$SERVER_IP:$SQLITE_DEPLOY_DIR/"
run_local "scp $SSH_OPTS $REPO_ROOT/quota-proxy/package.json root@$SERVER_IP:$SQLITE_DEPLOY_DIR/"

# 创建 package-lock.json（如果不存在）
log_info "创建 package-lock.json"
run_ssh "cd $SQLITE_DEPLOY_DIR && npm init -y 2>/dev/null || true"
run_ssh "cd $SQLITE_DEPLOY_DIR && echo '{\"name\":\"quota-proxy-sqlite\",\"version\":\"1.0.0\",\"lockfileVersion\":2}' > package-lock.json"

# 创建 docker-compose.yml
log_info "创建 SQLite 版本的 docker-compose.yml"
SQLITE_COMPOSE=$(cat <<'EOF'
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
      - ADMIN_TOKEN=${ADMIN_TOKEN:-changeme}
      - STORAGE_MODE=sqlite
      - SQLITE_DB_PATH=/data/quota.db
    volumes:
      - ./data:/data
      - ./logs:/app/logs
EOF
)

run_ssh "cat > $SQLITE_DEPLOY_DIR/docker-compose.yml <<'EOF'
$SQLITE_COMPOSE
EOF"

# 创建部署脚本
log_info "创建部署脚本"
DEPLOY_SCRIPT=$(cat <<'EOF'
#!/bin/bash
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/opt/roc/quota-proxy-sqlite"

echo "部署 SQLite 版本 quota-proxy 到 $TARGET_DIR"

# 停止并备份现有服务（如果存在）
if [ -d "/opt/roc/quota-proxy" ]; then
    echo "备份现有 quota-proxy..."
    BACKUP_DIR="/opt/roc/quota-proxy-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r /opt/roc/quota-proxy "$BACKUP_DIR"
    echo "备份完成: $BACKUP_DIR"
fi

# 创建目标目录
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/data"
mkdir -p "$TARGET_DIR/logs"

# 复制文件
cp "$DEPLOY_DIR/server-sqlite.js" "$TARGET_DIR/"
cp "$DEPLOY_DIR/Dockerfile" "$TARGET_DIR/"
cp "$DEPLOY_DIR/package.json" "$TARGET_DIR/"
cp "$DEPLOY_DIR/package-lock.json" "$TARGET_DIR/"
cp "$DEPLOY_DIR/docker-compose.yml" "$TARGET_DIR/"

# 设置权限
chmod 755 "$TARGET_DIR"
chmod 644 "$TARGET_DIR"/*

# 生成 ADMIN_TOKEN（如果不存在）
if [ ! -f "$TARGET_DIR/.env" ]; then
    echo "生成新的 ADMIN_TOKEN..."
    ADMIN_TOKEN=$(openssl rand -hex 32 2>/dev/null || echo "sqlite-admin-token-$(date +%s)")
    echo "ADMIN_TOKEN=$ADMIN_TOKEN" > "$TARGET_DIR/.env"
    echo "ADMIN_TOKEN 已保存到 $TARGET_DIR/.env"
    echo "请妥善保管此 token: $ADMIN_TOKEN"
fi

# 构建镜像
echo "构建 Docker 镜像..."
cd "$TARGET_DIR"
if docker compose build; then
    echo "镜像构建成功"
else
    echo "镜像构建失败，尝试使用预构建的 node 镜像直接运行..."
    # 如果构建失败，直接使用 node 运行
    cat > Dockerfile.simple <<'DOCKERFILEEOF'
FROM node:18-alpine
WORKDIR /app
COPY server-sqlite.js .
COPY package.json .
RUN npm install better-sqlite3 express cors
USER node
EXPOSE 8787
CMD ["node", "server-sqlite.js"]
DOCKERFILEEOF
    mv Dockerfile.simple Dockerfile
    docker compose build
fi

echo "部署完成！"
echo ""
echo "下一步:"
echo "1. 检查 $TARGET_DIR/.env 中的 ADMIN_TOKEN"
echo "2. 启动服务: cd $TARGET_DIR && docker compose up -d"
echo "3. 验证服务: curl -fsS http://127.0.0.1:8787/healthz"
echo "4. 测试管理接口: curl -H 'Authorization: Bearer \$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
EOF
)

run_ssh "cat > $SQLITE_DEPLOY_DIR/deploy.sh <<'EOF'
$DEPLOY_SCRIPT
EOF"
run_ssh "chmod +x $SQLITE_DEPLOY_DIR/deploy.sh"

# 执行部署
log_info "执行部署脚本"
run_ssh "cd $SQLITE_DEPLOY_DIR && ./deploy.sh"

# 启动服务
log_info "启动 SQLite 版本服务"
run_ssh "cd /opt/roc/quota-proxy-sqlite && docker compose up -d"

# 等待服务启动
log_info "等待服务启动..."
sleep 10

# 验证部署
log_info "验证部署"
run_ssh "cd /opt/roc/quota-proxy-sqlite && docker compose ps"
run_ssh "curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查失败，等待重试...' && sleep 5 && curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查最终失败'"

# 检查 SQLite 数据库
log_info "检查 SQLite 数据库文件"
run_ssh "ls -la /opt/roc/quota-proxy-sqlite/data/ 2>/dev/null || echo '数据目录不存在'"

log_info "部署完成！"
log_info "SQLite 版本已部署到: /opt/roc/quota-proxy-sqlite"
log_info "原版本保留在: /opt/roc/quota-proxy"
log_info ""
log_info "管理接口测试:"
log_info "  ADMIN_TOKEN=\$(cat /opt/roc/quota-proxy-sqlite/.env | grep ADMIN_TOKEN | cut -d= -f2)"
log_info "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
log_info ""
log_info "要切换回原版本:"
log_info "  cd /opt/roc/quota-proxy && docker compose up -d"