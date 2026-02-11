#!/bin/bash
# 部署带数据持久化的 quota-proxy SQLite 版本
# 使用 Docker 命名卷确保数据库文件在容器重启后不丢失

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_info "Docker 和 Docker Compose 已安装"
}

# 检查当前目录
check_directory() {
    if [ ! -f "docker-compose-persistent.yml" ]; then
        log_error "请在 quota-proxy 目录中运行此脚本"
        log_info "当前目录: $(pwd)"
        exit 1
    fi
    log_info "当前目录正确: $(pwd)"
}

# 设置环境变量
setup_environment() {
    if [ -f ".env" ]; then
        log_info "使用现有的 .env 文件"
    else
        log_warning ".env 文件不存在，创建默认配置"
        cat > .env << EOF
# quota-proxy 持久化部署环境变量
ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d
NODE_ENV=production
PORT=8787
STORE_PATH=/data/quota.db
LOG_LEVEL=info
ENABLE_RATE_LIMIT=true
MAX_REQUESTS_PER_MINUTE=60
ENABLE_IP_WHITELIST=false
ENABLE_OPERATION_LOG=true
KEY_EXPIRY_DAYS=30
EOF
        log_success "已创建 .env 文件"
    fi
}

# 创建数据目录（如果使用绑定挂载）
create_data_directory() {
    local data_dir="./data"
    if [ ! -d "$data_dir" ]; then
        log_info "创建数据目录: $data_dir"
        mkdir -p "$data_dir"
        chmod 755 "$data_dir"
        log_success "数据目录已创建"
    fi
}

# 停止并删除现有容器
cleanup_existing() {
    log_info "检查并清理现有容器..."
    
    # 停止并删除使用持久化配置的容器
    if docker-compose -f docker-compose-persistent.yml ps -q &> /dev/null; then
        log_info "停止现有持久化容器..."
        docker-compose -f docker-compose-persistent.yml down
        log_success "持久化容器已停止"
    fi
    
    # 停止并删除使用默认配置的容器（如果存在）
    if [ -f "compose.yaml" ] && docker-compose -f compose.yaml ps -q &> /dev/null; then
        log_info "停止现有默认容器..."
        docker-compose -f compose.yaml down
        log_success "默认容器已停止"
    fi
}

# 部署持久化版本
deploy_persistent() {
    log_info "开始部署带数据持久化的 quota-proxy..."
    
    # 构建镜像
    log_info "构建 Docker 镜像..."
    docker-compose -f docker-compose-persistent.yml build
    
    # 启动服务
    log_info "启动服务..."
    docker-compose -f docker-compose-persistent.yml up -d
    
    # 等待服务启动
    log_info "等待服务启动（10秒）..."
    sleep 10
    
    log_success "持久化版本部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查容器状态
    log_info "检查容器状态:"
    docker-compose -f docker-compose-persistent.yml ps
    
    # 检查健康状态
    log_info "检查健康状态:"
    if docker-compose -f docker-compose-persistent.yml exec -T quota-proxy curl -f http://localhost:8787/healthz 2>/dev/null; then
        log_success "健康检查通过"
    else
        log_error "健康检查失败"
        return 1
    fi
    
    # 检查数据卷
    log_info "检查数据卷:"
    docker volume ls | grep quota-data || log_warning "未找到 quota-data 卷（可能使用绑定挂载）"
    
    # 检查数据库文件
    log_info "检查数据库文件:"
    if docker-compose -f docker-compose-persistent.yml exec -T quota-proxy ls -la /data/ 2>/dev/null; then
        log_success "数据目录存在"
    else
        log_warning "无法访问数据目录"
    fi
    
    log_success "部署验证完成"
}

# 显示使用信息
show_usage() {
    echo -e "${BLUE}quota-proxy 持久化部署脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -c, --clean    仅清理现有容器，不部署"
    echo "  -v, --verify   仅验证部署状态"
    echo "  -d, --deploy   仅部署（跳过清理）"
    echo ""
    echo "示例:"
    echo "  $0             完整部署流程（清理+部署+验证）"
    echo "  $0 --clean     仅清理现有容器"
    echo "  $0 --verify    仅验证当前部署状态"
    echo "  $0 --deploy    仅部署（假设已清理）"
}

# 主函数
main() {
    local action="full"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--clean)
                action="clean"
                shift
                ;;
            -v|--verify)
                action="verify"
                shift
                ;;
            -d|--deploy)
                action="deploy"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "开始 quota-proxy 持久化部署流程"
    log_info "操作模式: $action"
    
    check_docker
    check_directory
    
    case $action in
        "clean")
            cleanup_existing
            log_success "清理完成"
            ;;
        "verify")
            verify_deployment
            ;;
        "deploy")
            setup_environment
            create_data_directory
            deploy_persistent
            verify_deployment
            ;;
        "full")
            setup_environment
            create_data_directory
            cleanup_existing
            deploy_persistent
            verify_deployment
            ;;
    esac
    
    log_success "操作完成"
    
    # 显示后续步骤
    if [ "$action" != "clean" ]; then
        echo ""
        echo -e "${GREEN}后续步骤:${NC}"
        echo "1. 检查服务状态: docker-compose -f docker-compose-persistent.yml ps"
        echo "2. 查看日志: docker-compose -f docker-compose-persistent.yml logs -f"
        echo "3. 测试 API: curl http://localhost:8787/healthz"
        echo "4. 备份数据卷: docker run --rm -v quota-proxy_quota-data:/source -v \$(pwd)/backups:/backup alpine tar czf /backup/quota-data-\$(date +%Y%m%d).tar.gz -C /source ."
        echo ""
        echo -e "${YELLOW}重要提示:${NC}"
        echo "- 数据库文件存储在 Docker 命名卷 'quota-proxy_quota-data' 中"
        echo "- 容器重启或重新部署不会丢失数据"
        echo "- 定期备份数据卷以防止数据丢失"
    fi
}

# 运行主函数
main "$@"