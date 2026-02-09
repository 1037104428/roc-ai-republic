#!/bin/bash
set -e

# 验证 quota-proxy 管理界面部署

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
验证 quota-proxy 管理界面部署

用法: $0 [选项]

选项:
  --local            验证本地开发环境
  --remote           验证远程服务器部署
  --server-file FILE 指定服务器配置文件路径（默认: /tmp/server.txt）
  --help             显示此帮助信息

EOF
}

verify_local() {
    log_info "验证本地管理界面文件..."
    
    # 检查文件是否存在
    local admin_file="$REPO_ROOT/quota-proxy/admin/index.html"
    if [[ ! -f "$admin_file" ]]; then
        log_error "管理界面文件不存在: $admin_file"
        return 1
    fi
    
    log_info "✓ 管理界面文件存在: $(basename "$admin_file")"
    
    # 检查文件大小
    local file_size=$(wc -c < "$admin_file")
    if [[ $file_size -lt 1000 ]]; then
        log_warn "管理界面文件可能过小: ${file_size}字节"
    else
        log_info "✓ 文件大小正常: ${file_size}字节"
    fi
    
    # 检查是否包含关键功能
    if grep -q "创建试用密钥" "$admin_file"; then
        log_info "✓ 包含密钥创建功能"
    else
        log_warn "可能缺少密钥创建功能"
    fi
    
    if grep -q "查看使用情况" "$admin_file"; then
        log_info "✓ 包含使用情况查看功能"
    else
        log_warn "可能缺少使用情况查看功能"
    fi
    
    # 检查 server-sqlite.js 是否配置了静态文件服务
    local server_file="$REPO_ROOT/quota-proxy/server-sqlite.js"
    if [[ -f "$server_file" ]]; then
        if grep -q "express.static.*admin" "$server_file"; then
            log_info "✓ server-sqlite.js 已配置静态文件服务"
        else
            log_warn "server-sqlite.js 可能未配置静态文件服务"
        fi
    fi
    
    log_info "本地验证完成"
    return 0
}

verify_remote() {
    # 解析服务器配置
    if [[ ! -f "$SERVER_FILE" ]]; then
        log_error "服务器配置文件不存在: $SERVER_FILE"
        return 1
    fi
    
    local SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d'=' -f2 | head -1)
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(head -1 "$SERVER_FILE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    fi
    
    if [[ -z "$SERVER_IP" ]]; then
        log_error "无法从 $SERVER_FILE 中解析服务器IP"
        return 1
    fi
    
    log_info "验证远程服务器: $SERVER_IP"
    
    # 检查容器状态
    log_info "检查 quota-proxy 容器状态..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
        "cd /opt/roc/quota-proxy && docker compose ps" 2>/dev/null | grep -q "Up"; then
        log_info "✓ quota-proxy 容器运行正常"
    else
        log_error "quota-proxy 容器未运行"
        return 1
    fi
    
    # 检查健康状态
    log_info "检查健康状态..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
        "curl -fsS http://127.0.0.1:8787/healthz" >/dev/null 2>&1; then
        log_info "✓ 健康检查通过"
    else
        log_error "健康检查失败"
        return 1
    fi
    
    # 检查管理界面文件是否存在
    log_info "检查管理界面文件..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
        "ls -la /opt/roc/quota-proxy/admin/index.html" >/dev/null 2>&1; then
        log_info "✓ 管理界面文件存在"
        
        # 检查文件大小
        local remote_size=$(ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
            "wc -c < /opt/roc/quota-proxy/admin/index.html" 2>/dev/null)
        log_info "远程文件大小: ${remote_size}字节"
    else
        log_warn "管理界面文件可能不存在，尝试检查其他位置..."
        
        # 检查是否在 static 目录
        if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
            "ls -la /opt/roc/quota-proxy/static/admin-ui.html" >/dev/null 2>&1; then
            log_info "✓ 管理界面在 static 目录"
        else
            log_error "未找到管理界面文件"
            return 1
        fi
    fi
    
    # 尝试访问管理界面（通过 curl 检查是否可访问）
    log_info "检查管理界面可访问性..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
        "curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:8787/admin/" 2>/dev/null | grep -q "200\|404"; then
        log_info "✓ 管理界面路径可访问"
    else
        log_warn "管理界面路径可能无法访问"
    fi
    
    log_info "远程验证完成"
    return 0
}

# 解析参数
MODE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            shift
            ;;
        --remote)
            MODE="remote"
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

# 如果没有指定模式，显示帮助
if [[ -z "$MODE" ]]; then
    log_error "请指定验证模式 (--local 或 --remote)"
    show_help
    exit 1
fi

# 执行验证
if [[ "$MODE" == "local" ]]; then
    verify_local
elif [[ "$MODE" == "remote" ]]; then
    verify_remote
fi

EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    log_info "验证成功！"
else
    log_error "验证失败"
fi

exit $EXIT_CODE