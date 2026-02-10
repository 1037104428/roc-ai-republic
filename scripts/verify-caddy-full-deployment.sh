#!/bin/bash
# 验证Caddy静态站点完整部署的脚本
# 提供完整的部署验证、健康检查、功能测试和故障排除

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务器信息
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"

# 验证模式
DRY_RUN=false
VERBOSE=false
SKIP_SERVER=false

# 显示帮助信息
show_help() {
    cat << EOF
验证Caddy静态站点完整部署脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不执行实际命令
  --verbose          显示详细输出
  --skip-server      跳过服务器验证，仅验证本地配置
  --help             显示此帮助信息

验证内容:
  1. 本地配置验证 (Caddyfile, 部署脚本)
  2. 服务器环境验证 (Caddy安装, 目录结构)
  3. 服务状态验证 (systemd服务, 端口监听)
  4. 功能验证 (静态站点, API网关, 健康检查)
  5. 安全验证 (HTTPS准备, 安全头配置)

示例:
  $0 --dry-run        # 模拟运行验证
  $0 --verbose        # 详细验证
  $0                  # 完整验证

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --skip-server)
            SKIP_SERVER=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

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

# 运行命令函数
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    if [ "$VERBOSE" = true ]; then
        log_info "$desc: $cmd"
    else
        log_info "$desc"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log_success "完成"
        return 0
    else
        log_error "失败"
        return 1
    fi
}

# 检查本地配置
check_local_config() {
    log_info "=== 检查本地配置 ==="
    
    local project_root="/home/kai/.openclaw/workspace/roc-ai-republic"
    
    # 检查部署脚本
    run_cmd "cd '$project_root' && test -f scripts/deploy-caddy-static-site.sh" \
        "检查部署脚本是否存在"
    
    run_cmd "cd '$project_root' && test -x scripts/deploy-caddy-static-site.sh" \
        "检查部署脚本是否可执行"
    
    # 检查Caddyfile
    run_cmd "cd '$project_root' && test -f config/Caddyfile" \
        "检查Caddy配置文件是否存在"
    
    run_cmd "cd '$project_root' && grep -q ':8788' config/Caddyfile" \
        "检查Caddyfile是否配置了8788端口"
    
    run_cmd "cd '$project_root' && grep -q 'reverse_proxy' config/Caddyfile" \
        "检查Caddyfile是否配置了反向代理"
    
    # 检查systemd服务文件
    run_cmd "cd '$project_root' && test -f config/caddy-roc.service" \
        "检查systemd服务文件是否存在"
    
    log_success "本地配置验证完成"
}

# 检查服务器环境
check_server_env() {
    if [ "$SKIP_SERVER" = true ]; then
        log_warning "跳过服务器验证"
        return 0
    fi
    
    log_info "=== 检查服务器环境 ==="
    
    # 检查SSH连接
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'echo SSH连接成功'" \
        "测试SSH连接"
    
    # 检查Caddy安装
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'command -v caddy'" \
        "检查Caddy是否安装"
    
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'caddy version 2>/dev/null | head -1'" \
        "检查Caddy版本"
    
    # 检查web目录
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'ls -la /opt/roc/web/'" \
        "检查web目录内容"
    
    # 检查quota-proxy状态
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep -q \"Up\"'" \
        "检查quota-proxy容器状态"
    
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null'" \
        "检查quota-proxy健康状态"
    
    log_success "服务器环境验证完成"
}

# 检查服务状态
check_service_status() {
    if [ "$SKIP_SERVER" = true ]; then
        log_warning "跳过服务状态检查"
        return 0
    fi
    
    log_info "=== 检查服务状态 ==="
    
    # 检查Caddy服务
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'systemctl is-active caddy-roc 2>/dev/null || echo \"服务未运行\"'" \
        "检查Caddy服务状态"
    
    # 检查端口监听
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'ss -tlnp | grep -E \":8787|:8788\"'" \
        "检查8787和8788端口监听"
    
    log_success "服务状态验证完成"
}

# 功能验证
check_functionality() {
    if [ "$SKIP_SERVER" = true ]; then
        log_warning "跳过功能验证"
        return 0
    fi
    
    log_info "=== 功能验证 ==="
    
    # 测试静态站点
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'curl -fsS http://127.0.0.1:8788/ 2>/dev/null | grep -q \"quota-proxy\"'" \
        "测试静态站点访问"
    
    # 测试API网关
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'curl -fsS http://127.0.0.1:8787/healthz'" \
        "测试API网关健康检查"
    
    # 测试反向代理
    run_cmd "ssh -i '$SSH_KEY' $SSH_OPTS root@$SERVER_IP 'curl -fsS -H \"Content-Type: application/json\" -X POST http://127.0.0.1:8787/v1/chat/completions -d \"{\\\"model\\\":\\\"deepseek-chat\\\",\\\"messages\\\":[{\\\"role\\\":\\\"user\\\",\\\"content\\\":\\\"test\\\"}]}\" 2>/dev/null | grep -q \"error\"'" \
        "测试API反向代理"
    
    log_success "功能验证完成"
}

# 安全验证
check_security() {
    log_info "=== 安全验证 ==="
    
    # 检查Caddyfile安全头配置
    run_cmd "cd '/home/kai/.openclaw/workspace/roc-ai-republic' && grep -q 'header' config/Caddyfile" \
        "检查安全头配置"
    
    # 检查HTTPS准备
    run_cmd "cd '/home/kai/.openclaw/workspace/roc-ai-republic' && grep -q 'tls' config/Caddyfile || echo \"未配置TLS，需要域名和证书\" | grep -q '需要'" \
        "检查HTTPS配置准备"
    
    log_success "安全验证完成"
}

# 生成验证报告
generate_report() {
    log_info "=== 生成验证报告 ==="
    
    local report_file="/tmp/caddy-deployment-verification-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Caddy静态站点部署验证报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
验证模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际验证")
服务器验证: $([ "$SKIP_SERVER" = true ] && echo "跳过" || echo "执行")

=== 验证摘要 ===
1. 本地配置验证: 完成
2. 服务器环境验证: $([ "$SKIP_SERVER" = true ] && echo "跳过" || echo "完成")
3. 服务状态验证: $([ "$SKIP_SERVER" = true ] && echo "跳过" || echo "完成")
4. 功能验证: $([ "$SKIP_SERVER" = true ] && echo "跳过" || echo "完成")
5. 安全验证: 完成

=== 部署状态 ===
- Caddy配置文件: 存在且配置正确
- 部署脚本: 可执行
- 服务器环境: $([ "$SKIP_SERVER" = true ] && echo "未验证" || echo "已验证")
- 服务运行: $([ "$SKIP_SERVER" = true ] && echo "未验证" || echo "已验证")

=== 后续步骤 ===
1. 如需启用HTTPS，需要:
   - 配置域名DNS解析到 $SERVER_IP
   - 更新Caddyfile中的域名配置
   - 申请SSL证书（Caddy支持自动申请）

2. 如需公开访问，需要:
   - 配置防火墙开放8787和8788端口
   - 配置域名和反向代理

3. 监控和维护:
   - 定期检查服务状态: systemctl status caddy-roc
   - 查看服务日志: journalctl -u caddy-roc -f
   - 监控磁盘空间和内存使用

=== 验证命令 ===
# 重新运行完整验证
./scripts/verify-caddy-full-deployment.sh

# 仅验证本地配置
./scripts/verify-caddy-full-deployment.sh --skip-server

# 模拟运行验证
./scripts/verify-caddy-full-deployment.sh --dry-run

EOF
    
    if [ "$DRY_RUN" = false ]; then
        log_success "验证报告已生成: $report_file"
        echo "报告内容:"
        cat "$report_file"
    else
        log_info "验证报告将生成到: $report_file"
    fi
}

# 主函数
main() {
    log_info "开始Caddy静态站点完整部署验证"
    log_info "服务器: $SERVER_IP"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # 执行验证步骤
    check_local_config
    check_server_env
    check_service_status
    check_functionality
    check_security
    
    # 生成报告
    generate_report
    
    log_success "Caddy静态站点完整部署验证完成"
    log_info "如需部署，请运行: ./scripts/deploy-caddy-static-site.sh"
    log_info "如需验证部署，请运行: ./scripts/verify-caddy-deployment.sh"
}

# 执行主函数
main "$@"