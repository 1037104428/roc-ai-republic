#!/bin/bash
set -e

# quota-proxy 版本切换脚本
# 用法: ./scripts/switch-quota-proxy-version.sh [sqlite|file] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat <<EOF
quota-proxy 版本切换脚本

用法: $0 [版本] [选项]

版本:
  sqlite    切换到 SQLite 持久化版本 (端口: 8787)
  file      切换到文件存储版本 (端口: 8787)

选项:
  --dry-run  只显示将要执行的命令，不实际执行
  --help     显示此帮助信息

环境变量:
  SERVER_FILE   服务器信息文件路径 (默认: /tmp/server.txt)
  SSH_KEY       SSH 私钥路径 (默认: ~/.ssh/id_ed25519_roc_server)

示例:
  $0 sqlite              # 切换到 SQLite 版本
  $0 file --dry-run      # 预览切换到文件版本
EOF
}

# 解析参数
DRY_RUN=false
VERSION=""

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
        sqlite|file)
            VERSION="$1"
            shift
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "错误: 必须指定版本 (sqlite 或 file)"
    show_help
    exit 1
fi

# 获取服务器 IP
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -1 "$SERVER_FILE" | sed 's/^ip://')
    if [[ -z "$SERVER_IP" ]]; then
        echo "错误: 无法从 $SERVER_FILE 解析 IP 地址"
        exit 1
    fi
else
    echo "错误: $SERVER_FILE 不存在"
    exit 1
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

# 检查服务器连接
log_info "检查服务器连接: $SERVER_IP"
if ! run_ssh "echo '连接成功'" >/dev/null 2>&1; then
    log_error "无法连接到服务器 $SERVER_IP"
    exit 1
fi

# 切换版本
case $VERSION in
    sqlite)
        log_info "切换到 SQLite 版本"
        
        # 1. 停止原版本
        log_info "停止文件存储版本"
        run_ssh "cd /opt/roc/quota-proxy 2>/dev/null && docker compose down 2>/dev/null || true"
        
        # 2. 确保 SQLite 版本在正确端口
        log_info "检查 SQLite 版本"
        run_ssh "docker ps | grep quota-proxy-sqlite | grep :8788 >/dev/null && echo 'SQLite版本运行在8788端口，需要切换到8787' || echo 'SQLite版本未运行或已在8787端口'"
        
        # 3. 如果 SQLite 版本在8788，停止并重新在8787启动
        log_info "重新配置 SQLite 版本到8787端口"
        run_ssh "docker stop quota-proxy-sqlite 2>/dev/null || true"
        run_ssh "docker rm quota-proxy-sqlite 2>/dev/null || true"
        
        # 4. 在8787端口启动 SQLite 版本
        log_info "在8787端口启动 SQLite 版本"
        run_ssh "cd /opt/roc/quota-proxy-sqlite && docker run -d \
          --name quota-proxy-sqlite \
          --restart unless-stopped \
          -p 127.0.0.1:8787:8787 \
          -e NODE_ENV=production \
          -e PORT=8787 \
          -e ADMIN_TOKEN=\$(cat /opt/roc/quota-proxy-sqlite/.env 2>/dev/null | grep ADMIN_TOKEN | cut -d= -f2 || echo 'sqlite-admin-token') \
          -e STORAGE_MODE=sqlite \
          -e SQLITE_DB_PATH=/data/quota.db \
          -v /opt/roc/quota-proxy-sqlite/data:/data \
          -v /opt/roc/quota-proxy-sqlite/server.js:/app/server.js \
          -v /opt/roc/quota-proxy-sqlite/package.json:/app/package.json \
          -w /app \
          node:18-alpine \
          sh -c 'npm install 2>/dev/null || true && node server.js'"
        
        # 5. 验证
        log_info "验证 SQLite 版本"
        run_ssh "sleep 3 && curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查失败，等待重试...' && sleep 2 && curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查最终失败'"
        
        log_info "切换完成！当前运行 SQLite 版本 (127.0.0.1:8787)"
        ;;
    
    file)
        log_info "切换到文件存储版本"
        
        # 1. 停止 SQLite 版本
        log_info "停止 SQLite 版本"
        run_ssh "docker stop quota-proxy-sqlite 2>/dev/null || true"
        run_ssh "docker rm quota-proxy-sqlite 2>/dev/null || true"
        
        # 2. 启动原版本
        log_info "启动文件存储版本"
        run_ssh "cd /opt/roc/quota-proxy && docker compose up -d"
        
        # 3. 验证
        log_info "验证文件存储版本"
        run_ssh "sleep 3 && curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查失败，等待重试...' && sleep 2 && curl -fsS http://127.0.0.1:8787/healthz || echo '健康检查最终失败'"
        
        log_info "切换完成！当前运行文件存储版本 (127.0.0.1:8787)"
        ;;
esac

# 显示当前状态
log_info "当前服务状态:"
run_ssh "docker ps | grep quota-proxy || echo '未找到 quota-proxy 容器'"
run_ssh "echo '端口检查:' && netstat -tlnp 2>/dev/null | grep :8787 || ss -tlnp 2>/dev/null | grep :8787 || echo '8787端口未监听'"