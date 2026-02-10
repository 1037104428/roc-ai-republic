#!/bin/bash

# quota-proxy SQLite版本部署脚本
# 部署包含SQLite持久化、POST /admin/keys和GET /admin/usage接口的版本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_SERVER="root@8.210.185.194"
DEFAULT_DEPLOY_DIR="/opt/roc/quota-proxy-sqlite"
DEFAULT_ADMIN_TOKEN="roc-admin-token-$(date +%s | tail -c 6)"

# 显示帮助
show_help() {
    cat << EOF
quota-proxy SQLite版本部署脚本

用法: $0 [选项]

选项:
  -s, --server SERVER     服务器地址 (默认: ${DEFAULT_SERVER})
  -d, --dir DIR          部署目录 (默认: ${DEFAULT_DEPLOY_DIR})
  -t, --token TOKEN      ADMIN_TOKEN (默认: 自动生成)
  -k, --key KEY          SSH私钥路径
  -n, --dry-run          模拟运行，不实际部署
  -v, --verbose          详细输出
  -h, --help             显示此帮助信息

环境变量:
  DEEPSEEK_API_KEY       必需: DeepSeek API密钥
  ADMIN_TOKEN            可选: 管理令牌 (默认自动生成)
  DAILY_REQ_LIMIT        可选: 每日请求限制 (默认: 200)

示例:
  $0 -s root@example.com -d /opt/roc/quota-proxy
  DEEPSEEK_API_KEY=sk-xxx $0 --verbose

说明:
  1. 部署quota-proxy SQLite版本到指定服务器
  2. 包含SQLite持久化存储
  3. 实现POST /admin/keys和GET /admin/usage接口
  4. 使用ADMIN_TOKEN保护管理接口
EOF
}

# 解析参数
SERVER="$DEFAULT_SERVER"
DEPLOY_DIR="$DEFAULT_DEPLOY_DIR"
ADMIN_TOKEN=""
SSH_KEY=""
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER="$2"
            shift 2
            ;;
        -d|--dir)
            DEPLOY_DIR="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查必需环境变量
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo -e "${RED}错误: 必须设置DEEPSEEK_API_KEY环境变量${NC}"
    echo -e "${YELLOW}示例: export DEEPSEEK_API_KEY=sk-xxx${NC}"
    exit 1
fi

# 生成ADMIN_TOKEN（如果未提供）
if [ -z "$ADMIN_TOKEN" ]; then
    ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
    echo -e "${YELLOW}提示: 使用自动生成的ADMIN_TOKEN: ${ADMIN_TOKEN}${NC}"
    echo -e "${YELLOW}      在生产环境中请使用强密码并妥善保管${NC}"
fi

# 构建SSH命令
SSH_CMD="ssh"
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="$SSH_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SERVER"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 执行命令（支持dry-run）
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    if [ "$VERBOSE" = true ]; then
        log_info "$desc"
        echo -e "${BLUE}命令:${NC} $cmd"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN] 跳过执行${NC}"
        return 0
    fi
    
    eval "$cmd"
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "命令执行失败 (退出码: $exit_code)"
        return $exit_code
    fi
    
    return 0
}

# 主部署函数
deploy() {
    log_info "开始部署quota-proxy SQLite版本"
    log_info "服务器: $SERVER"
    log_info "部署目录: $DEPLOY_DIR"
    log_info "ADMIN_TOKEN: ${ADMIN_TOKEN:0:10}..."
    
    # 1. 检查服务器连接
    log_info "检查服务器连接..."
    run_cmd "$SSH_CMD 'echo \"服务器连接正常\"'" "测试SSH连接"
    
    # 2. 创建部署目录
    log_info "创建部署目录..."
    run_cmd "$SSH_CMD 'mkdir -p $DEPLOY_DIR'" "创建部署目录"
    
    # 3. 上传文件
    log_info "上传文件到服务器..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    
    # 复制必需文件
    cp -r /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy/* "$TEMP_DIR/"
    
    # 创建环境文件
    cat > "$TEMP_DIR/.env" << EOF
# quota-proxy SQLite版本配置
DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY
DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
PORT=8787
DAILY_REQ_LIMIT=${DAILY_REQ_LIMIT:-200}
ADMIN_TOKEN=$ADMIN_TOKEN
DATABASE_PATH=./quota-proxy.db
LOG_LEVEL=info
EOF
    
    # 创建启动脚本
    cat > "$TEMP_DIR/start.sh" << 'EOF'
#!/bin/bash
set -e

# 加载环境变量
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 检查必需环境变量
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "错误: 必须设置DEEPSEEK_API_KEY环境变量"
    exit 1
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "警告: ADMIN_TOKEN未设置，管理接口将不可用"
fi

# 启动服务
echo "启动quota-proxy SQLite版本..."
echo "端口: ${PORT:-8787}"
echo "数据库: ${DATABASE_PATH:-./quota-proxy.db}"
echo "每日限制: ${DAILY_REQ_LIMIT:-200}"

exec node server-sqlite-simple.js
EOF
    
    chmod +x "$TEMP_DIR/start.sh"
    
    # 创建Docker Compose文件
    cat > "$TEMP_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  quota-proxy:
    build: .
    container_name: quota-proxy-sqlite
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - DEEPSEEK_API_KEY=\${DEEPSEEK_API_KEY}
      - DEEPSEEK_BASE_URL=\${DEEPSEEK_BASE_URL:-https://api.deepseek.com/v1}
      - PORT=\${PORT:-8787}
      - DAILY_REQ_LIMIT=\${DAILY_REQ_LIMIT:-200}
      - ADMIN_TOKEN=\${ADMIN_TOKEN}
      - DATABASE_PATH=/data/quota-proxy.db
      - LOG_LEVEL=\${LOG_LEVEL:-info}
    volumes:
      - ./data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8787/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    
    # 创建Dockerfile
    cat > "$TEMP_DIR/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制应用文件
COPY . .

# 创建数据目录
RUN mkdir -p /data

# 暴露端口
EXPOSE 8787

# 启动命令
CMD ["node", "server-sqlite-simple.js"]
EOF
    
    # 创建验证脚本
    cat > "$TEMP_DIR/verify-deployment.sh" << 'EOF'
#!/bin/bash
set -e

echo "验证quota-proxy SQLite版本部署..."

# 检查服务是否运行
if curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    exit 1
fi

# 检查管理接口（需要ADMIN_TOKEN）
if [ -n "$ADMIN_TOKEN" ]; then
    if curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/keys > /dev/null 2>&1; then
        echo "✓ 管理接口可访问"
    else
        echo "✗ 管理接口访问失败"
    fi
else
    echo "⚠ ADMIN_TOKEN未设置，跳过管理接口测试"
fi

# 检查数据库文件
if [ -f ./quota-proxy.db ] || [ -f ./data/quota-proxy.db ]; then
    echo "✓ 数据库文件存在"
else
    echo "⚠ 数据库文件不存在（首次运行时会创建）"
fi

echo "验证完成"
EOF
    
    chmod +x "$TEMP_DIR/verify-deployment.sh"
    
    # 上传文件
    log_info "上传文件..."
    run_cmd "scp -r $TEMP_DIR/* $SERVER:$DEPLOY_DIR/" "上传文件到服务器"
    
    # 清理临时目录
    rm -rf "$TEMP_DIR"
    
    # 4. 在服务器上安装依赖
    log_info "在服务器上安装Node.js依赖..."
    run_cmd "$SSH_CMD 'cd $DEPLOY_DIR && npm ci --only=production'" "安装依赖"
    
    # 5. 创建systemd服务（可选）
    log_info "创建systemd服务..."
    run_cmd "$SSH_CMD 'cat > /etc/systemd/system/quota-proxy-sqlite.service << \"EOF\"
[Unit]
Description=quota-proxy SQLite Version
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DEPLOY_DIR
EnvironmentFile=$DEPLOY_DIR/.env
ExecStart=/usr/bin/node $DEPLOY_DIR/server-sqlite-simple.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'" "创建systemd服务文件"
    
    # 6. 启动服务
    log_info "启动服务..."
    run_cmd "$SSH_CMD 'systemctl daemon-reload && systemctl enable quota-proxy-sqlite.service && systemctl start quota-proxy-sqlite.service'" "启动systemd服务"
    
    # 7. 验证部署
    log_info "验证部署..."
    run_cmd "$SSH_CMD 'sleep 3 && cd $DEPLOY_DIR && ./verify-deployment.sh'" "验证部署"
    
    # 8. 显示部署信息
    log_success "quota-proxy SQLite版本部署完成！"
    echo ""
    echo -e "${GREEN}部署信息:${NC}"
    echo -e "  ${BLUE}服务地址:${NC} http://$SERVER:8787"
    echo -e "  ${BLUE}健康检查:${NC} http://$SERVER:8787/healthz"
    echo -e "  ${BLUE}管理接口:${NC} 使用ADMIN_TOKEN访问"
    echo -e "  ${BLUE}ADMIN_TOKEN:${NC} $ADMIN_TOKEN"
    echo -e "  ${BLUE}部署目录:${NC} $DEPLOY_DIR"
    echo ""
    echo -e "${YELLOW}使用示例:${NC}"
    echo -e "  创建试用密钥:"
    echo -e "    curl -X POST http://$SERVER:8787/admin/keys \\"
    echo -e "      -H \"Authorization: Bearer $ADMIN_TOKEN\" \\"
    echo -e "      -H \"Content-Type: application/json\" \\"
    echo -e "      -d '{\"label\":\"测试用户\"}'"
    echo ""
    echo -e "  查看使用情况:"
    echo -e "    curl http://$SERVER:8787/admin/usage \\"
    echo -e "      -H \"Authorization: Bearer $ADMIN_TOKEN\""
    echo ""
    echo -e "  使用试用密钥调用API:"
    echo -e "    curl -X POST http://$SERVER:8787/v1/chat/completions \\"
    echo -e "      -H \"Authorization: Bearer <TRIAL_KEY>\" \\"
    echo -e "      -H \"Content-Type: application/json\" \\"
    echo -e "      -d '{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
}

# 执行部署
deploy

exit 0