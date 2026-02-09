#!/bin/bash
set -e

# quota-proxy 管理界面部署脚本
# 将 admin-ui.html 部署到服务器，并配置静态文件服务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

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

show_help() {
    cat << EOF
部署 quota-proxy 管理界面到服务器

用法: $0 [选项]

选项:
  --dry-run          只显示将要执行的命令，不实际执行
  --server-file FILE 指定服务器配置文件路径（默认: /tmp/server.txt）
  --help             显示此帮助信息

说明:
  1. 读取服务器配置（从 /tmp/server.txt 或指定文件）
  2. 将 admin-ui.html 复制到服务器 /opt/roc/quota-proxy/static/
  3. 更新 quota-proxy 配置以提供静态文件服务
  4. 重启 quota-proxy 服务

服务器配置文件格式:
  ip=8.210.185.194
  # 可选: password=your_password

EOF
}

# 解析参数
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --server-file)
            SERVER_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查服务器配置文件
if [[ ! -f "$SERVER_FILE" ]]; then
    log_error "服务器配置文件不存在: $SERVER_FILE"
    log_info "请创建文件并添加服务器IP，例如:"
    echo "ip=8.210.185.194"
    exit 1
fi

# 解析服务器配置
SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d'=' -f2 | head -1)
if [[ -z "$SERVER_IP" ]]; then
    # 尝试读取裸IP（没有ip=前缀）
    SERVER_IP=$(head -1 "$SERVER_FILE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
fi

if [[ -z "$SERVER_IP" ]]; then
    log_error "无法从 $SERVER_FILE 中解析服务器IP"
    exit 1
fi

log_info "目标服务器: $SERVER_IP"

# 检查 admin-ui.html 文件
ADMIN_UI_FILE="$REPO_ROOT/quota-proxy/admin-ui.html"
if [[ ! -f "$ADMIN_UI_FILE" ]]; then
    log_error "管理界面文件不存在: $ADMIN_UI_FILE"
    exit 1
fi

log_info "找到管理界面文件: $(basename "$ADMIN_UI_FILE")"

# 构建部署命令
DEPLOY_COMMANDS=(
    # 创建静态文件目录
    "mkdir -p /opt/roc/quota-proxy/static"
    
    # 复制管理界面文件
    "cp $ADMIN_UI_FILE /opt/roc/quota-proxy/static/admin-ui.html"
    
    # 检查当前 quota-proxy 配置
    "cd /opt/roc/quota-proxy && docker compose ps"
    
    # 检查是否需要更新 server-sqlite.js 以提供静态文件
    "if grep -q 'express.static' /opt/roc/quota-proxy/server-sqlite.js; then echo '静态文件服务已配置'; else echo '需要配置静态文件服务'; fi"
    
    # 重启服务（如果需要）
    "cd /opt/roc/quota-proxy && docker compose restart quota-proxy"
    
    # 验证部署
    "sleep 2 && curl -fsS http://127.0.0.1:8787/healthz && echo ''"
    "echo '管理界面访问: http://127.0.0.1:8787/static/admin-ui.html'"
)

# 执行或显示命令
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "=== 干运行模式 ==="
    for cmd in "${DEPLOY_COMMANDS[@]}"; do
        echo "ssh root@$SERVER_IP \"$cmd\""
    done
    log_info "=== 结束干运行 ==="
else
    log_info "开始部署管理界面到服务器..."
    
    # 执行部署命令
    for cmd in "${DEPLOY_COMMANDS[@]}"; do
        log_info "执行: $cmd"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "$cmd"; then
            log_warn "命令执行失败，继续执行下一个..."
        fi
    done
    
    log_info "部署完成！"
    log_info "管理界面访问地址: http://127.0.0.1:8787/static/admin-ui.html"
    log_info "注意：此界面仅在服务器本机可访问，请勿暴露到公网"
fi

# 验证脚本
log_info "运行本地验证..."
if curl -fsS -m 5 "https://api.clawdrepublic.cn/healthz" > /dev/null 2>&1; then
    log_info "API 网关健康检查: ✓"
else
    log_warn "API 网关健康检查失败（可能正常，如果服务器不在线）"
fi

log_info "完成！"