#!/bin/bash
# 应用Docker Compose配置文件清理到服务器
# 解决"Found multiple config files"和"version attribute is obsolete"警告

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务器信息
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
QUOTA_PROXY_DIR="/opt/roc/quota-proxy"

# 函数：打印带颜色的消息
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

# 函数：检查服务器连接
check_server_connection() {
    log_info "检查服务器连接..."
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "echo '连接成功'" >/dev/null 2>&1; then
        log_success "服务器连接正常"
        return 0
    else
        log_error "无法连接到服务器"
        return 1
    fi
}

# 函数：检查当前Docker Compose配置文件状态
check_current_status() {
    log_info "检查当前Docker Compose配置文件状态..."
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        echo '当前目录内容:'
        ls -la *.yml *.yaml 2>/dev/null || echo '未找到配置文件'
        echo ''
        echo 'Docker Compose状态:'
        docker compose ps 2>&1 | head -20
    "
}

# 函数：执行清理操作
perform_cleanup() {
    log_info "执行Docker Compose配置文件清理..."
    
    # 1. 备份现有配置文件
    log_info "备份现有配置文件..."
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        mkdir -p backup
        timestamp=\$(date +%Y%m%d_%H%M%S)
        cp -f *.yml *.yaml backup/ 2>/dev/null || true
        echo '配置文件已备份到: backup/目录'
        ls -la backup/*.yml backup/*.yaml 2>/dev/null || echo '无配置文件需要备份'
    "
    
    # 2. 清理过时的配置文件
    log_info "清理过时的配置文件..."
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        
        # 优先保留compose.yaml（新格式）
        if [ -f 'compose.yaml' ]; then
            echo '保留compose.yaml（新格式）'
            # 移除过时的version属性
            sed -i '/^version:/d' compose.yaml 2>/dev/null || true
            # 移除其他旧格式文件
            rm -f docker-compose.yml docker-compose.yaml 2>/dev/null || true
        # 如果有docker-compose.yml，转换为compose.yaml
        elif [ -f 'docker-compose.yml' ]; then
            echo '将docker-compose.yml转换为compose.yaml'
            cp docker-compose.yml compose.yaml
            # 移除过时的version属性
            sed -i '/^version:/d' compose.yaml 2>/dev/null || true
            rm -f docker-compose.yml docker-compose.yaml 2>/dev/null || true
        fi
        
        echo '清理后目录内容:'
        ls -la *.yml *.yaml 2>/dev/null || echo '无配置文件'
    "
    
    # 3. 验证清理结果
    log_info "验证清理结果..."
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        echo '验证Docker Compose配置:'
        docker compose config 2>&1 | head -5
    "
    
    # 4. 重启服务（可选）
    log_info "重启quota-proxy服务..."
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        docker compose down
        sleep 2
        docker compose up -d
        sleep 3
        echo '服务状态:'
        docker compose ps
    "
    
    # 5. 验证健康检查
    log_info "验证健康检查..."
    health_result=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null || echo '健康检查失败'
    ")
    
    if echo "$health_result" | grep -q '{"ok":true}'; then
        log_success "健康检查通过: $health_result"
    else
        log_warning "健康检查结果: $health_result"
    fi
}

# 函数：显示使用帮助
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --check     只检查状态，不执行清理"
    echo "  --cleanup   执行清理操作"
    echo "  --help      显示此帮助信息"
    echo ""
    echo "默认行为: 检查状态并执行清理"
}

# 主函数
main() {
    local mode="cleanup"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                mode="check"
                shift
                ;;
            --cleanup)
                mode="cleanup"
                shift
                ;;
            --help|-h)
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
    
    log_info "开始应用Docker Compose配置文件清理"
    log_info "服务器: $SERVER_IP"
    log_info "目录: $QUOTA_PROXY_DIR"
    log_info "模式: $mode"
    echo ""
    
    # 检查服务器连接
    if ! check_server_connection; then
        exit 1
    fi
    
    # 检查当前状态
    check_current_status
    
    if [ "$mode" = "check" ]; then
        log_info "检查模式完成，未执行清理操作"
        exit 0
    fi
    
    # 执行清理
    echo ""
    log_info "开始执行清理操作..."
    perform_cleanup
    
    # 最终验证
    echo ""
    log_info "最终验证..."
    final_output=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "
        cd '$QUOTA_PROXY_DIR'
        echo '最终目录内容:'
        ls -la *.yml *.yaml 2>/dev/null || echo '无配置文件'
        echo ''
        echo '最终Docker Compose状态（应无警告）:'
        docker compose ps 2>&1
        echo ''
        echo '健康检查:'
        curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null || echo '健康检查失败'
    ")
    
    echo "$final_output"
    
    # 检查是否还有警告
    if echo "$final_output" | grep -q "Found multiple config files"; then
        log_error "清理失败：仍然存在多个配置文件警告"
        exit 1
    elif echo "$final_output" | grep -q "version.*obsolete"; then
        log_warning "清理警告：仍然存在version属性警告"
    else
        log_success "清理完成！所有警告已解决"
    fi
}

# 执行主函数
main "$@"