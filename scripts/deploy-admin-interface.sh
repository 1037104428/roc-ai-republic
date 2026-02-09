#!/bin/bash
# deploy-admin-interface.sh - 部署 quota-proxy 管理界面到服务器
# 这是一个轻量级部署，只更新管理界面相关文件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
部署 quota-proxy 管理界面到服务器

用法: $0 [选项]

选项:
  --dry-run    只显示将要执行的操作，不实际执行
  --help       显示此帮助信息

环境变量:
  SERVER_IP    服务器IP地址（默认从/tmp/server.txt读取）
EOF
}

get_server_ip() {
    if [ -z "${SERVER_IP:-}" ]; then
        if [ -f "/tmp/server.txt" ]; then
            SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
            if [ -z "$SERVER_IP" ]; then
                SERVER_IP=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /tmp/server.txt | head -1)
            fi
        fi
    fi
    
    if [ -z "$SERVER_IP" ]; then
        log_error "无法获取服务器IP地址"
        log_error "请设置 SERVER_IP 环境变量或确保 /tmp/server.txt 包含IP地址"
        return 1
    fi
    
    echo "$SERVER_IP"
}

deploy_admin_interface() {
    local server_ip="$1"
    local dry_run="${2:-0}"
    
    log_info "部署管理界面到服务器: $server_ip"
    
    # 检查必需文件
    local required_files=(
        "$REPO_ROOT/quota-proxy/admin.html"
        "$REPO_ROOT/quota-proxy/server-sqlite.js"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "必需文件不存在: $file"
            return 1
        fi
    done
    
    log_success "所有必需文件存在"
    
    if [ $dry_run -eq 1 ]; then
        log_info "[DRY-RUN] 将执行以下操作:"
        log_info "1. 复制 admin.html 到服务器"
        log_info "2. 复制 server-sqlite.js 到服务器"
        log_info "3. 重启 quota-proxy 服务"
        return 0
    fi
    
    # 1. 复制文件到服务器
    log_info "复制文件到服务器..."
    scp "$REPO_ROOT/quota-proxy/admin.html" "root@$server_ip:/opt/roc/quota-proxy/" || {
        log_error "复制 admin.html 失败"
        return 1
    }
    
    scp "$REPO_ROOT/quota-proxy/server-sqlite.js" "root@$server_ip:/opt/roc/quota-proxy/" || {
        log_error "复制 server-sqlite.js 失败"
        return 1
    }
    
    log_success "文件复制完成"
    
    # 2. 重启服务
    log_info "重启 quota-proxy 服务..."
    ssh "root@$server_ip" "cd /opt/roc/quota-proxy && docker compose restart quota-proxy" || {
        log_error "重启服务失败"
        return 1
    }
    
    log_success "服务重启完成"
    
    # 3. 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 4. 验证部署
    log_info "验证部署..."
    if ssh "root@$server_ip" "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null"; then
        log_success "服务健康检查通过"
    else
        log_error "服务健康检查失败"
        return 1
    fi
    
    # 检查管理界面端点
    log_info "检查管理界面端点..."
    if ssh "root@$server_ip" "curl -fsS http://127.0.0.1:8787/admin/health 2>/dev/null"; then
        log_success "管理界面健康端点正常"
    else
        log_warn "管理界面健康端点不可用（可能 ADMIN_TOKEN 未设置）"
    fi
    
    # 检查容器内文件
    log_info "检查容器内文件..."
    if ssh "root@$server_ip" "docker exec quota-proxy-quota-proxy-1 ls -la /app/admin.html 2>/dev/null"; then
        log_success "容器内 admin.html 文件存在"
    else
        log_error "容器内 admin.html 文件不存在"
        return 1
    fi
    
    log_success "管理界面部署完成！"
    log_info "访问地址: http://$server_ip:8787/admin"
    log_info "健康检查: http://$server_ip:8787/admin/health"
    
    return 0
}

main() {
    local dry_run=0
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run=1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 获取服务器IP
    local server_ip
    server_ip=$(get_server_ip) || exit 1
    
    # 部署
    if ! deploy_admin_interface "$server_ip" "$dry_run"; then
        log_error "部署失败"
        exit 1
    fi
    
    exit 0
}

main "$@"