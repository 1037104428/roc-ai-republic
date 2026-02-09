#!/bin/bash
# test-admin-interface.sh - 测试 quota-proxy 管理界面
# 用法: ./scripts/test-admin-interface.sh [--local] [--remote] [--help]

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
测试 quota-proxy 管理界面

用法: $0 [选项]

选项:
  --local     测试本地管理界面文件
  --remote    测试远程服务器上的管理界面
  --all       测试所有（默认）
  --help      显示此帮助信息

示例:
  $0 --local           # 只测试本地文件
  $0 --remote          # 只测试远程服务器
  $0                   # 测试所有

环境变量:
  SERVER_IP           服务器IP地址（默认从/tmp/server.txt读取）
  ADMIN_TOKEN         管理员令牌（用于远程测试）
EOF
}

test_local() {
    log_info "测试本地管理界面文件..."
    
    # 检查 admin.html 文件
    if [ ! -f "$REPO_ROOT/quota-proxy/admin.html" ]; then
        log_error "admin.html 文件不存在: $REPO_ROOT/quota-proxy/admin.html"
        return 1
    fi
    
    log_success "admin.html 文件存在"
    
    # 检查文件大小
    file_size=$(wc -c < "$REPO_ROOT/quota-proxy/admin.html")
    if [ "$file_size" -lt 1000 ]; then
        log_warn "admin.html 文件可能过小: $file_size 字节"
    else
        log_success "admin.html 文件大小正常: $file_size 字节"
    fi
    
    # 检查 server-sqlite.js 是否包含管理界面路由
    if ! grep -q "app.get.*'/admin'" "$REPO_ROOT/quota-proxy/server-sqlite.js"; then
        log_error "server-sqlite.js 中未找到管理界面路由"
        return 1
    fi
    
    log_success "server-sqlite.js 包含管理界面路由"
    
    # 检查是否导入了 path 模块
    if ! grep -q "import.*path" "$REPO_ROOT/quota-proxy/server-sqlite.js" && \
       ! grep -q "from.*'path'" "$REPO_ROOT/quota-proxy/server-sqlite.js"; then
        log_error "server-sqlite.js 中未导入 path 模块"
        return 1
    fi
    
    log_success "server-sqlite.js 导入了必要的模块"
    
    return 0
}

test_remote() {
    log_info "测试远程服务器管理界面..."
    
    # 获取服务器IP
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
    
    log_info "使用服务器IP: $SERVER_IP"
    
    # 测试健康检查端点
    log_info "测试 /healthz 端点..."
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null"; then
        log_error "无法访问服务器上的 /healthz 端点"
        return 1
    fi
    
    log_success "/healthz 端点正常"
    
    # 测试管理健康检查端点
    log_info "测试 /admin/health 端点..."
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "curl -fsS http://127.0.0.1:8787/admin/health 2>/dev/null"; then
        log_warn "无法访问 /admin/health 端点（可能 ADMIN_TOKEN 未设置）"
    else
        log_success "/admin/health 端点正常"
    fi
    
    # 检查管理界面文件是否存在
    log_info "检查服务器上的 admin.html 文件..."
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "test -f /opt/roc/quota-proxy/admin.html && echo '文件存在' || echo '文件不存在'"; then
        log_warn "无法检查服务器上的 admin.html 文件"
    fi
    
    # 检查服务状态
    log_info "检查 quota-proxy 服务状态..."
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep quota-proxy"; then
        log_error "quota-proxy 服务未运行"
        return 1
    fi
    
    log_success "quota-proxy 服务正在运行"
    
    # 检查日志中是否有管理界面启动信息
    log_info "检查服务日志..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "cd /opt/roc/quota-proxy && docker compose logs quota-proxy 2>/dev/null | tail -20 | grep -i 'admin'"; then
        log_success "服务日志中包含管理界面信息"
    else
        log_warn "服务日志中未找到管理界面信息"
    fi
    
    return 0
}

main() {
    local test_local_flag=0
    local test_remote_flag=0
    
    # 解析参数
    if [ $# -eq 0 ]; then
        test_local_flag=1
        test_remote_flag=1
    else
        while [ $# -gt 0 ]; do
            case "$1" in
                --local)
                    test_local_flag=1
                    shift
                    ;;
                --remote)
                    test_remote_flag=1
                    shift
                    ;;
                --all)
                    test_local_flag=1
                    test_remote_flag=1
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
    fi
    
    local exit_code=0
    
    if [ $test_local_flag -eq 1 ]; then
        if ! test_local; then
            exit_code=1
        fi
    fi
    
    if [ $test_remote_flag -eq 1 ]; then
        if ! test_remote; then
            exit_code=1
        fi
    fi
    
    if [ $exit_code -eq 0 ]; then
        log_success "所有测试通过！"
        log_info "管理界面可通过以下方式访问："
        log_info "1. 本地文件: $REPO_ROOT/quota-proxy/admin.html"
        log_info "2. 服务器界面: http://$SERVER_IP:8787/admin (需 ADMIN_TOKEN)"
        log_info "3. 健康检查: http://$SERVER_IP:8787/admin/health"
    else
        log_error "部分测试失败"
    fi
    
    return $exit_code
}

main "$@"