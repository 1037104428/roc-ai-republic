#!/bin/bash
# rebuild-quota-proxy-with-admin.sh - 重新构建 quota-proxy Docker 镜像以包含管理界面
# 用法: 在服务器上运行此脚本

set -e

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
重新构建 quota-proxy Docker 镜像以包含管理界面

此脚本应在服务器上运行，用于更新 Docker 镜像以包含 Web 管理界面。

用法: $0 [选项]

选项:
  --dry-run    只显示将要执行的操作，不实际执行
  --help       显示此帮助信息

步骤:
  1. 备份当前 Dockerfile
  2. 更新 Dockerfile 以包含 admin.html
  3. 重新构建 Docker 镜像
  4. 重启服务
EOF
}

check_prerequisites() {
    log_info "检查前提条件..."
    
    # 检查是否在服务器上运行
    if [ ! -f "/opt/roc/quota-proxy/compose.yaml" ]; then
        log_error "未找到 /opt/roc/quota-proxy/compose.yaml"
        log_error "请确保在正确的目录中运行此脚本"
        return 1
    fi
    
    # 检查 admin.html 是否存在
    if [ ! -f "/opt/roc/quota-proxy/admin.html" ]; then
        log_error "未找到 admin.html 文件"
        log_error "请先部署管理界面文件"
        return 1
    fi
    
    # 检查 Dockerfile
    local dockerfile="/opt/roc/quota-proxy/Dockerfile-better-sqlite"
    if [ ! -f "$dockerfile" ]; then
        log_error "未找到 Dockerfile-better-sqlite"
        return 1
    fi
    
    log_success "所有前提条件满足"
    return 0
}

update_dockerfile() {
    local dockerfile="/opt/roc/quota-proxy/Dockerfile-better-sqlite"
    local backup_file="${dockerfile}.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_info "备份当前 Dockerfile: $backup_file"
    cp "$dockerfile" "$backup_file"
    
    log_info "更新 Dockerfile 以包含 admin.html..."
    
    # 检查是否已经包含 admin.html
    if grep -q "COPY admin.html" "$dockerfile"; then
        log_warn "Dockerfile 已包含 admin.html，跳过更新"
        return 0
    fi
    
    # 在 COPY server-better-sqlite.js 行后添加 COPY admin.html
    sed -i '/COPY server-better-sqlite.js \.\/server\.js/aCOPY admin.html ./' "$dockerfile"
    
    if grep -q "COPY admin.html" "$dockerfile"; then
        log_success "Dockerfile 更新成功"
        log_info "更新后的 Dockerfile 内容:"
        grep -n "COPY\|CMD" "$dockerfile"
    else
        log_error "Dockerfile 更新失败"
        return 1
    fi
    
    return 0
}

rebuild_image() {
    log_info "重新构建 Docker 镜像..."
    
    cd /opt/roc/quota-proxy || {
        log_error "无法进入 /opt/roc/quota-proxy 目录"
        return 1
    }
    
    # 构建镜像
    docker build -f Dockerfile-better-sqlite -t quota-proxy-better-sqlite:latest . || {
        log_error "Docker 构建失败"
        return 1
    }
    
    log_success "Docker 镜像构建完成"
    return 0
}

restart_service() {
    log_info "重启 quota-proxy 服务..."
    
    cd /opt/roc/quota-proxy || {
        log_error "无法进入 /opt/roc/quota-proxy 目录"
        return 1
    }
    
    docker compose down || {
        log_warn "停止服务时遇到警告，继续..."
    }
    
    docker compose up -d || {
        log_error "启动服务失败"
        return 1
    }
    
    log_success "服务重启完成"
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 验证服务
    if curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null; then
        log_success "服务健康检查通过"
    else
        log_error "服务健康检查失败"
        return 1
    fi
    
    # 检查容器内文件
    log_info "检查容器内 admin.html 文件..."
    if docker exec quota-proxy-quota-proxy-1 ls -la /app/admin.html 2>/dev/null; then
        log_success "容器内 admin.html 文件存在"
    else
        log_error "容器内 admin.html 文件不存在"
        return 1
    fi
    
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
    
    if [ $dry_run -eq 1 ]; then
        log_info "[DRY-RUN] 将执行以下操作:"
        log_info "1. 检查前提条件"
        log_info "2. 备份并更新 Dockerfile-better-sqlite"
        log_info "3. 重新构建 Docker 镜像"
        log_info "4. 重启服务"
        log_info "5. 验证部署"
        return 0
    fi
    
    # 检查前提条件
    check_prerequisites || exit 1
    
    # 更新 Dockerfile
    update_dockerfile || exit 1
    
    # 重新构建镜像
    rebuild_image || exit 1
    
    # 重启服务
    restart_service || exit 1
    
    log_success "🎉 管理界面部署完成！"
    log_info "访问地址: http://<服务器IP>:8787/admin"
    log_info "健康检查: http://<服务器IP>:8787/admin/health"
    log_info "注意: 需要设置 ADMIN_TOKEN 环境变量才能访问管理界面"
    
    return 0
}

main "$@"