#!/bin/bash
# 状态监控页面部署验证脚本
# 验证状态页面部署到服务器的完整流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 显示帮助
show_help() {
    cat << EOF
状态监控页面部署验证脚本

用法: $0 [选项]

选项:
  --dry-run         模拟运行，不实际执行操作
  --help            显示此帮助信息
  --server-only     仅验证服务器端状态
  --local-only      仅验证本地生成状态
  --full            执行完整验证流程（默认）

示例:
  $0 --dry-run      模拟验证部署流程
  $0 --full         执行完整验证
  $0 --server-only  仅验证服务器状态
EOF
}

# 解析参数
DRY_RUN=false
SERVER_ONLY=false
LOCAL_ONLY=false

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
        --server-only)
            SERVER_ONLY=true
            shift
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --full)
            # 默认就是full，不需要特殊处理
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查是否在项目目录
check_project_dir() {
    if [[ ! -f "scripts/verify-status-page-deployment.sh" ]]; then
        log_error "请在项目根目录运行此脚本"
        exit 1
    fi
}

# 验证本地状态页面生成
verify_local_generation() {
    log_info "验证本地状态页面生成..."
    
    if [[ ! -f "scripts/create-quota-proxy-status-page.sh" ]]; then
        log_error "状态页面生成脚本不存在: scripts/create-quota-proxy-status-page.sh"
        return 1
    fi
    
    if $DRY_RUN; then
        log_success "模拟: 状态页面生成脚本存在"
        log_info "模拟: 运行: ./scripts/create-quota-proxy-status-page.sh"
        return 0
    fi
    
    # 实际生成状态页面
    ./scripts/create-quota-proxy-status-page.sh
    
    if [[ -f "/tmp/quota-proxy-status.html" ]]; then
        local file_size=$(stat -c%s "/tmp/quota-proxy-status.html")
        log_success "状态页面生成成功: /tmp/quota-proxy-status.html (${file_size}字节)"
        
        # 检查页面内容
        if grep -q "quota-proxy 状态监控" "/tmp/quota-proxy-status.html"; then
            log_success "页面标题正确"
        else
            log_warning "页面标题可能不正确"
        fi
        
        if grep -q "健康状态" "/tmp/quota-proxy-status.html"; then
            log_success "健康状态部分存在"
        fi
        
        if grep -q "API 接入信息" "/tmp/quota-proxy-status.html"; then
            log_success "API接入信息部分存在"
        fi
        
        return 0
    else
        log_error "状态页面生成失败"
        return 1
    fi
}

# 验证部署脚本
verify_deployment_script() {
    log_info "验证部署脚本..."
    
    if [[ ! -f "scripts/deploy-status-page.sh" ]]; then
        log_error "部署脚本不存在: scripts/deploy-status-page.sh"
        return 1
    fi
    
    # 检查脚本权限
    if [[ ! -x "scripts/deploy-status-page.sh" ]]; then
        log_warning "部署脚本不可执行，正在添加执行权限..."
        chmod +x "scripts/deploy-status-page.sh"
    fi
    
    # 检查脚本语法
    if bash -n "scripts/deploy-status-page.sh"; then
        log_success "部署脚本语法正确"
    else
        log_error "部署脚本语法错误"
        return 1
    fi
    
    # 检查文档
    if [[ -f "docs/status-page-deployment.md" ]]; then
        log_success "部署文档存在: docs/status-page-deployment.md"
    else
        log_warning "部署文档不存在"
    fi
    
    return 0
}

# 验证服务器状态（模拟）
verify_server_status() {
    log_info "验证服务器状态..."
    
    # 读取服务器配置
    local server_config="/tmp/server.txt"
    if [[ ! -f "$server_config" ]]; then
        log_warning "服务器配置文件不存在: $server_config"
        log_info "使用默认服务器配置进行模拟验证"
        
        if $DRY_RUN; then
            log_success "模拟: 服务器配置检查通过"
            log_info "模拟: 服务器Web目录: /opt/roc/web"
            log_info "模拟: 状态页面文件: /opt/roc/web/quota-proxy-status.html"
            return 0
        else
            log_error "需要服务器配置文件才能进行实际验证"
            return 1
        fi
    fi
    
    # 提取服务器IP
    local server_ip=$(grep "^ip:" "$server_config" | cut -d: -f2 | tr -d '[:space:]')
    if [[ -z "$server_ip" ]]; then
        log_error "无法从配置文件中提取服务器IP"
        return 1
    fi
    
    log_info "服务器IP: $server_ip"
    
    if $DRY_RUN; then
        log_success "模拟: 连接到服务器 $server_ip"
        log_info "模拟: 检查Web目录: /opt/roc/web"
        log_info "模拟: 检查状态页面: /opt/roc/web/quota-proxy-status.html"
        log_info "模拟: 检查目录权限"
        log_success "模拟: 服务器验证完成"
        return 0
    fi
    
    # 实际验证服务器状态
    log_info "实际验证服务器状态..."
    
    # 检查SSH连接
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$server_ip" "echo 'SSH连接成功'"; then
        log_success "SSH连接成功"
    else
        log_error "SSH连接失败"
        return 1
    fi
    
    # 检查Web目录
    if ssh "root@$server_ip" "test -d /opt/roc/web"; then
        log_success "Web目录存在: /opt/roc/web"
        
        # 检查目录权限
        local dir_perm=$(ssh "root@$server_ip" "stat -c '%a' /opt/roc/web")
        if [[ "$dir_perm" == "755" ]] || [[ "$dir_perm" == "775" ]]; then
            log_success "目录权限正确: $dir_perm"
        else
            log_warning "目录权限可能需要调整: $dir_perm (建议: 755)"
        fi
        
        # 检查是否已有状态页面
        if ssh "root@$server_ip" "test -f /opt/roc/web/quota-proxy-status.html"; then
            log_success "状态页面已存在: /opt/roc/web/quota-proxy-status.html"
            
            # 获取文件大小
            local file_size=$(ssh "root@$server_ip" "stat -c%s /opt/roc/web/quota-proxy-status.html")
            log_info "状态页面大小: ${file_size}字节"
        else
            log_info "状态页面不存在，可以部署"
        fi
    else
        log_info "Web目录不存在，可以创建"
    fi
    
    return 0
}

# 生成验证报告
generate_verification_report() {
    log_info "生成验证报告..."
    
    local report_file="/tmp/status-page-verification-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
状态监控页面部署验证报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
验证模式: $($DRY_RUN && echo "模拟运行" || echo "实际验证")

验证结果:
1. 本地状态页面生成: $([ $? -eq 0 ] && echo "通过" || echo "失败")
2. 部署脚本验证: $([ $? -eq 0 ] && echo "通过" || echo "失败")
3. 服务器状态验证: $([ $? -eq 0 ] && echo "通过" || echo "失败")

部署准备状态:
- 状态页面生成脚本: $(test -f "scripts/create-quota-proxy-status-page.sh" && echo "就绪" || echo "缺失")
- 部署脚本: $(test -f "scripts/deploy-status-page.sh" && echo "就绪" || echo "缺失")
- 部署文档: $(test -f "docs/status-page-deployment.md" && echo "就绪" || echo "缺失")
- 服务器配置: $(test -f "/tmp/server.txt" && echo "就绪" || echo "缺失")

下一步建议:
1. 运行部署脚本: ./scripts/deploy-status-page.sh
2. 验证部署结果: 访问 http://服务器IP/quota-proxy-status.html
3. 配置Web服务器（Caddy/Nginx）提供HTTPS访问

EOF
    
    log_success "验证报告已生成: $report_file"
    cat "$report_file"
}

# 主函数
main() {
    log_info "开始状态监控页面部署验证..."
    log_info "运行模式: $($DRY_RUN && echo "模拟运行" || echo "实际验证")"
    
    check_project_dir
    
    local local_ok=true
    local deploy_ok=true
    local server_ok=true
    
    # 根据参数选择验证范围
    if [[ "$LOCAL_ONLY" == false ]] && [[ "$SERVER_ONLY" == false ]]; then
        # 完整验证
        verify_local_generation || local_ok=false
        verify_deployment_script || deploy_ok=false
        verify_server_status || server_ok=false
    elif [[ "$LOCAL_ONLY" == true ]]; then
        # 仅本地验证
        verify_local_generation || local_ok=false
        verify_deployment_script || deploy_ok=false
    elif [[ "$SERVER_ONLY" == true ]]; then
        # 仅服务器验证
        verify_server_status || server_ok=false
    fi
    
    # 生成报告
    generate_verification_report
    
    # 总结
    log_info "验证完成总结:"
    if [[ "$LOCAL_ONLY" == false ]] && [[ "$SERVER_ONLY" == false ]]; then
        echo "本地生成: $($local_ok && echo "✅" || echo "❌")"
        echo "部署脚本: $($deploy_ok && echo "✅" || echo "❌")"
        echo "服务器状态: $($server_ok && echo "✅" || echo "❌")"
        
        if $local_ok && $deploy_ok && $server_ok; then
            log_success "所有验证通过！可以开始部署状态监控页面。"
            echo ""
            echo "部署命令:"
            echo "  ./scripts/deploy-status-page.sh"
            echo ""
            echo "验证部署结果:"
            echo "  ./scripts/verify-status-page-deployment.sh --server-only"
            return 0
        else
            log_warning "部分验证失败，请检查问题后再尝试部署。"
            return 1
        fi
    elif [[ "$LOCAL_ONLY" == true ]]; then
        echo "本地生成: $($local_ok && echo "✅" || echo "❌")"
        echo "部署脚本: $($deploy_ok && echo "✅" || echo "❌")"
        
        if $local_ok && $deploy_ok; then
            log_success "本地验证通过！"
            return 0
        else
            log_warning "本地验证失败"
            return 1
        fi
    elif [[ "$SERVER_ONLY" == true ]]; then
        echo "服务器状态: $($server_ok && echo "✅" || echo "❌")"
        
        if $server_ok; then
            log_success "服务器验证通过！"
            return 0
        else
            log_warning "服务器验证失败"
            return 1
        fi
    fi
}

# 执行主函数
main "$@"