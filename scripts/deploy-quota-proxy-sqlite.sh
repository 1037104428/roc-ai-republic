#!/bin/bash
# deploy-quota-proxy-sqlite.sh - 部署 SQLite 版本的 quota-proxy 服务
# 用法: ./scripts/deploy-quota-proxy-sqlite.sh [--test] [--help]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_INFO="$REPO_ROOT/scripts/server-info.txt"

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

show_help() {
    cat << EOF
部署 SQLite 版本的 quota-proxy 服务

用法: $0 [选项]

选项:
  --test     测试模式（不实际部署，只检查）
  --help     显示此帮助信息

说明:
  1. 读取服务器信息 (scripts/server-info.txt)
  2. 构建 SQLite 版本的 Docker 镜像
  3. 部署到服务器并启动服务
  4. 验证部署结果

环境变量:
  DEEPSEEK_API_KEY    - DeepSeek API 密钥（必需）
  ADMIN_TOKEN         - 管理令牌（可选，建议设置）
  DAILY_REQ_LIMIT     - 每日请求限制（默认: 200）
  SQLITE_PATH         - SQLite 数据库路径（默认: /data/quota.db）

示例:
  $0 --test
  DEEPSEEK_API_KEY=sk-xxx ADMIN_TOKEN=secret $0
EOF
}

# 解析参数
TEST_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --test) TEST_MODE=true; shift ;;
        --help) show_help; exit 0 ;;
        *) log_error "未知参数: $1"; show_help; exit 1 ;;
    esac
done

# 检查必需文件
if [[ ! -f "$SERVER_INFO" ]]; then
    log_error "服务器信息文件不存在: $SERVER_INFO"
    log_info "请先创建服务器信息文件:"
    log_info "  echo 'ip:8.210.185.194' > scripts/server-info.txt"
    exit 1
fi

# 读取服务器信息
SERVER_IP=$(grep -E '^ip:' "$SERVER_INFO" | cut -d: -f2 | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    log_error "无法从 $SERVER_INFO 读取服务器 IP"
    exit 1
fi

log_info "目标服务器: $SERVER_IP"
log_info "测试模式: $TEST_MODE"

# 检查必需环境变量
if [[ -z "$DEEPSEEK_API_KEY" ]]; then
    log_error "必需环境变量 DEEPSEEK_API_KEY 未设置"
    log_info "请设置: export DEEPSEEK_API_KEY=sk-xxx"
    exit 1
fi

# 设置默认值
ADMIN_TOKEN=${ADMIN_TOKEN:-"$(openssl rand -hex 24)"}
DAILY_REQ_LIMIT=${DAILY_REQ_LIMIT:-200}
SQLITE_PATH=${SQLITE_PATH:-"/data/quota.db"}

log_info "配置:"
log_info "  DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY:0:10}..."
log_info "  ADMIN_TOKEN: ${ADMIN_TOKEN:0:10}..."
log_info "  DAILY_REQ_LIMIT: $DAILY_REQ_LIMIT"
log_info "  SQLITE_PATH: $SQLITE_PATH"

# 构建 Docker 镜像
log_info "构建 Docker 镜像..."
if [[ "$TEST_MODE" == "false" ]]; then
    cd "$REPO_ROOT/quota-proxy"
    
    # 创建 Dockerfile-sqlite
    cat > Dockerfile-sqlite << EOF
FROM node:20-alpine

WORKDIR /app

# 安装依赖
COPY package*.json ./
RUN npm ci --only=production

# 复制源代码
COPY server-sqlite.js ./
COPY server.js ./  # 保留原版本用于参考
COPY admin.html ./  # 管理界面

# 创建数据目录
RUN mkdir -p /data && chown node:node /data

USER node

# 环境变量
ENV DEEPSEEK_API_KEY=\${DEEPSEEK_API_KEY}
ENV ADMIN_TOKEN=\${ADMIN_TOKEN}
ENV DAILY_REQ_LIMIT=\${DAILY_REQ_LIMIT}
ENV SQLITE_PATH=\${SQLITE_PATH}
ENV PORT=8787

EXPOSE 8787

CMD ["node", "server-sqlite.js"]
EOF

    docker build -f Dockerfile-sqlite -t quota-proxy-sqlite:latest .
    log_success "Docker 镜像构建完成"
else
    log_info "[测试] 跳过 Docker 构建"
fi

# 准备部署脚本
DEPLOY_SCRIPT=$(cat << EOF
#!/bin/bash
set -e

echo "=== 部署 SQLite 版本 quota-proxy ==="

# 创建目录
sudo mkdir -p /opt/roc/quota-proxy-sqlite
cd /opt/roc/quota-proxy-sqlite

# 创建 docker-compose.yml
cat > docker-compose.yml << DOCKER_COMPOSE
version: '3.8'

services:
  quota-proxy:
    image: quota-proxy-sqlite:latest
    container_name: quota-proxy-sqlite
    restart: unless-stopped
    ports:
      - "127.0.0.1:8788:8787"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - DAILY_REQ_LIMIT=${DAILY_REQ_LIMIT}
      - SQLITE_PATH=${SQLITE_PATH}
    volumes:
      - quota-data:/data

volumes:
  quota-data:
    driver: local

DOCKER_COMPOSE

# 停止并移除旧容器（如果存在）
docker compose down 2>/dev/null || true

# 加载镜像（需要提前传输）
if [[ -f quota-proxy-sqlite.tar ]]; then
    docker load -i quota-proxy-sqlite.tar
fi

# 启动服务
docker compose up -d

echo "等待服务启动..."
sleep 5

# 验证服务
if curl -fsS http://127.0.0.1:8788/healthz > /dev/null 2>&1; then
    echo "✓ 服务健康检查通过"
    echo "✓ SQLite 版本 quota-proxy 已启动"
    echo "✓ 监听端口: 127.0.0.1:8788"
    echo "✓ 数据库路径: ${SQLITE_PATH}"
else
    echo "✗ 服务健康检查失败"
    docker compose logs
    exit 1
fi
EOF
)

# 执行部署
if [[ "$TEST_MODE" == "false" ]]; then
    log_info "部署到服务器 $SERVER_IP..."
    
    # 保存镜像为 tar 文件
    docker save quota-proxy-sqlite:latest -o /tmp/quota-proxy-sqlite.tar
    
    # 传输到服务器
    scp -i "$REPO_ROOT/scripts/roc-key.pem" /tmp/quota-proxy-sqlite.tar "root@$SERVER_IP:/tmp/"
    
    # 执行部署脚本
    ssh -i "$REPO_ROOT/scripts/roc-key.pem" "root@$SERVER_IP" "bash -s" <<< "$DEPLOY_SCRIPT"
    
    log_success "部署完成"
    
    # 验证部署
    log_info "验证部署..."
    if curl -fsS "http://$SERVER_IP:8788/healthz" > /dev/null 2>&1; then
        log_success "✓ 服务可访问: http://$SERVER_IP:8788/healthz"
    else
        log_warn "⚠ 服务暂时不可访问，可能需要等待几秒钟"
    fi
    
    # 清理
    rm -f /tmp/quota-proxy-sqlite.tar
else
    log_info "[测试] 部署脚本内容:"
    echo "----------------------------------------"
    echo "$DEPLOY_SCRIPT"
    echo "----------------------------------------"
    log_info "[测试] 完成"
fi

log_success "SQLite 版本 quota-proxy 部署准备完成"
log_info "下一步:"
log_info "  1. 设置环境变量: export DEEPSEEK_API_KEY=sk-xxx"
log_info "  2. 运行部署: $0"
log_info "  3. 验证: curl http://$SERVER_IP:8788/healthz"
log_info "  4. 获取试用密钥: curl -H 'Authorization: Bearer \$ADMIN_TOKEN' -X POST http://$SERVER_IP:8788/admin/keys"