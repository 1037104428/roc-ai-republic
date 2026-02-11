#!/bin/bash
# 验证 quota-proxy 持久化部署状态
# 检查数据持久化、容器状态和功能完整性

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

# 检查 Docker 是否运行
check_docker() {
    if ! docker info &> /dev/null; then
        log_error "Docker 守护进程未运行"
        exit 1
    fi
    log_success "Docker 守护进程正在运行"
}

# 检查容器状态
check_container_status() {
    log_info "检查 quota-proxy 容器状态..."
    
    if ! docker-compose -f docker-compose-persistent.yml ps -q &> /dev/null; then
        log_error "持久化容器未运行"
        return 1
    fi
    
    local status=$(docker-compose -f docker-compose-persistent.yml ps --services --filter "status=running")
    if [ -z "$status" ]; then
        log_error "没有运行中的容器"
        return 1
    fi
    
    log_info "运行中的容器: $status"
    
    # 检查每个容器的详细状态
    docker-compose -f docker-compose-persistent.yml ps
    
    log_success "容器状态检查通过"
}

# 检查健康端点
check_health_endpoint() {
    log_info "检查健康端点..."
    
    local max_retries=5
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -f http://localhost:8787/healthz 2>/dev/null; then
            log_success "健康端点响应正常"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        log_warning "健康检查失败，重试 $retry_count/$max_retries..."
        sleep 3
    done
    
    log_error "健康端点检查失败"
    return 1
}

# 检查数据持久化
check_data_persistence() {
    log_info "检查数据持久化..."
    
    # 检查数据卷是否存在
    local volume_name="quota-proxy_quota-data"
    if docker volume ls | grep -q "$volume_name"; then
        log_success "数据卷 '$volume_name' 存在"
        
        # 检查数据卷信息
        log_info "数据卷信息:"
        docker volume inspect "$volume_name" | jq -r '.[0] | {Name, Mountpoint, Driver}'
        
        # 检查数据卷中的文件
        log_info "检查数据卷中的文件:"
        docker run --rm -v "$volume_name:/data" alpine ls -la /data/ 2>/dev/null || log_warning "无法列出数据卷内容"
    else
        log_warning "未找到命名数据卷，检查绑定挂载..."
        
        # 检查本地数据目录
        local data_dir="./data"
        if [ -d "$data_dir" ]; then
            log_success "找到本地数据目录: $data_dir"
            ls -la "$data_dir/"
        else
            log_error "未找到数据持久化配置"
            return 1
        fi
    fi
    
    log_success "数据持久化检查通过"
}

# 测试数据库持久化
test_database_persistence() {
    log_info "测试数据库持久化功能..."
    
    # 生成测试密钥
    local admin_token="86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d"
    local test_label="持久化测试-$(date +%Y%m%d-%H%M%S)"
    
    log_info "生成测试密钥: $test_label"
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d "{\"label\":\"$test_label\"}" \
        http://localhost:8787/admin/keys)
    
    local key=$(echo "$response" | jq -r '.key // empty')
    
    if [ -n "$key" ]; then
        log_success "测试密钥生成成功: $key"
        
        # 验证密钥存在
        log_info "验证密钥存在..."
        curl -s -H "Authorization: Bearer $admin_token" \
            http://localhost:8787/admin/keys | jq -r '.keys[] | select(.key == "'"$key"'") | .label'
        
        log_success "数据库写入测试通过"
    else
        log_error "测试密钥生成失败"
        echo "响应: $response"
        return 1
    fi
}

# 测试容器重启后的数据持久性
test_restart_persistence() {
    log_info "测试容器重启后的数据持久性..."
    
    # 记录当前状态
    local admin_token="86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d"
    local before_count=$(curl -s -H "Authorization: Bearer $admin_token" \
        http://localhost:8787/admin/keys | jq '.keys | length')
    
    log_info "重启前密钥数量: $before_count"
    
    # 重启容器
    log_info "重启容器..."
    docker-compose -f docker-compose-persistent.yml restart
    
    # 等待服务恢复
    log_info "等待服务恢复..."
    sleep 10
    
    # 检查健康状态
    check_health_endpoint
    
    # 检查重启后的状态
    local after_count=$(curl -s -H "Authorization: Bearer $admin_token" \
        http://localhost:8787/admin/keys | jq '.keys | length')
    
    log_info "重启后密钥数量: $after_count"
    
    if [ "$before_count" -eq "$after_count" ]; then
        log_success "数据持久性测试通过：重启后数据未丢失"
    else
        log_error "数据持久性测试失败：重启前后数据不一致"
        return 1
    fi
}

# 检查备份和恢复能力
check_backup_capability() {
    log_info "检查备份能力..."
    
    local backup_dir="./backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$backup_dir/quota-data-$timestamp.tar.gz"
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 备份数据卷
    log_info "创建数据备份..."
    docker run --rm \
        -v "quota-proxy_quota-data:/source" \
        -v "$(pwd)/$backup_dir:/backup" \
        alpine tar czf "/backup/quota-data-$timestamp.tar.gz" -C /source . 2>/dev/null
    
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log_success "备份创建成功: $backup_file ($size)"
        
        # 检查备份文件内容
        log_info "备份文件内容:"
        tar -tzf "$backup_file" | head -5
    else
        log_warning "备份创建失败，跳过备份检查"
    fi
    
    log_success "备份能力检查完成"
}

# 生成验证报告
generate_verification_report() {
    log_info "生成验证报告..."
    
    local report_file="./verification-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=== quota-proxy 持久化部署验证报告 ==="
        echo "生成时间: $(date)"
        echo ""
        
        echo "1. 系统信息:"
        echo "   Docker 版本: $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
        echo "   Docker Compose 版本: $(docker-compose --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
        echo "   主机名: $(hostname)"
        echo ""
        
        echo "2. 容器状态:"
        docker-compose -f docker-compose-persistent.yml ps 2>/dev/null || echo "   无法获取容器状态"
        echo ""
        
        echo "3. 数据持久化:"
        docker volume ls | grep quota-data || echo "   未找到数据卷"
        echo ""
        
        echo "4. 健康状态:"
        curl -s http://localhost:8787/healthz 2>/dev/null || echo "   健康检查失败"
        echo ""
        
        echo "5. 数据库状态:"
        local admin_token="86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d"
        curl -s -H "Authorization: Bearer $admin_token" http://localhost:8787/admin/keys | jq '.keys | length' 2>/dev/null || echo "   无法获取密钥数量"
        echo ""
        
        echo "6. 备份状态:"
        ls -la ./backups/ 2>/dev/null | head -5 || echo "   无备份文件"
        echo ""
        
        echo "=== 验证结果 ==="
        echo "持久化部署: $(if check_container_status &>/dev/null && check_health_endpoint &>/dev/null; then echo '✅ 通过'; else echo '❌ 失败'; fi)"
        echo "数据持久性: $(if check_data_persistence &>/dev/null; then echo '✅ 通过'; else echo '❌ 失败'; fi)"
        echo "功能完整性: $(if test_database_persistence &>/dev/null; then echo '✅ 通过'; else echo '❌ 失败'; fi)"
        
    } > "$report_file"
    
    log_success "验证报告已生成: $report_file"
    cat "$report_file"
}

# 显示使用信息
show_usage() {
    echo -e "${BLUE}quota-proxy 持久化部署验证脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help         显示此帮助信息"
    echo "  -q, --quick        快速验证（仅检查基本状态）"
    echo "  -f, --full         完整验证（包含重启测试）"
    echo "  -r, --report       生成验证报告"
    echo "  -t, --test         仅运行功能测试"
    echo ""
    echo "示例:"
    echo "  $0                 标准验证流程"
    echo "  $0 --quick         快速验证"
    echo "  $0 --full          完整验证（包含重启测试）"
    echo "  $0 --report        生成验证报告"
}

# 主函数
main() {
    local mode="standard"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -q|--quick)
                mode="quick"
                shift
                ;;
            -f|--full)
                mode="full"
                shift
                ;;
            -r|--report)
                mode="report"
                shift
                ;;
            -t|--test)
                mode="test"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "开始 quota-proxy 持久化部署验证"
    log_info "验证模式: $mode"
    
    check_docker
    
    case $mode in
        "quick")
            check_container_status
            check_health_endpoint
            check_data_persistence
            ;;
        "full")
            check_container_status
            check_health_endpoint
            check_data_persistence
            test_database_persistence
            test_restart_persistence
            check_backup_capability
            generate_verification_report
            ;;
        "report")
            generate_verification_report
            ;;
        "test")
            test_database_persistence
            ;;
        "standard")
            check_container_status
            check_health_endpoint
            check_data_persistence
            test_database_persistence
            check_backup_capability
            ;;
    esac
    
    log_success "验证完成"
    
    # 显示总结
    echo ""
    echo -e "${GREEN}验证总结:${NC}"
    echo "✓ Docker 状态: 正常"
    echo "✓ 容器状态: $(if check_container_status &>/dev/null; then echo '正常'; else echo '异常'; fi)"
    echo "✓ 健康端点: $(if check_health_endpoint &>/dev/null; then echo '正常'; else echo '异常'; fi)"
    echo "✓ 数据持久化: $(if check_data_persistence &>/dev/null; then echo '已配置'; else echo '未配置'; fi)"
    echo ""
    echo -e "${YELLOW}建议:${NC}"
    echo "1. 定期运行验证脚本确保系统健康"
    echo "2. 设置定时备份任务"
    echo "3. 监控容器日志和资源使用情况"
}

# 运行主函数
main "$@"