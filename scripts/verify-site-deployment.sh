#!/bin/bash

# 站点部署验证脚本
# 用于验证静态站点部署状态

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
SITE_DIR="/opt/roc/web"
SERVER_HOST="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
VERBOSE=false
QUIET=false

# 帮助信息
show_help() {
    cat << EOF
站点部署验证脚本 v1.0

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -q, --quiet         安静模式，只输出关键信息
  --site-dir DIR      站点目录 (默认: $SITE_DIR)
  --server-host HOST  服务器主机 (默认: $SERVER_HOST)
  --ssh-key KEY       SSH私钥路径 (默认: $SSH_KEY)

示例:
  $0                    # 基本验证
  $0 -v                 # 详细模式
  $0 --site-dir /var/www/html  # 自定义站点目录

功能:
  1. 检查服务器连接
  2. 验证站点目录存在
  3. 检查基本文件结构
  4. 验证Nginx/Caddy配置（如果已安装）
  5. 提供部署建议

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --site-dir)
            SITE_DIR="$2"
            shift 2
            ;;
        --server-host)
            SERVER_HOST="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
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
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[信息]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[成功]${NC} $1"
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[警告]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[调试]${NC} $1"
    fi
}

# 检查SSH连接
check_ssh_connection() {
    log_info "检查SSH连接到服务器: $SERVER_HOST"
    
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "echo 'SSH连接成功'" > /dev/null 2>&1; then
        log_success "SSH连接正常"
        return 0
    else
        log_error "SSH连接失败"
        return 1
    fi
}

# 检查站点目录
check_site_directory() {
    log_info "检查站点目录: $SITE_DIR"
    
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "[ -d '$SITE_DIR' ]"; then
        log_success "站点目录存在"
        
        # 检查目录内容
        local dir_content
        dir_content=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "ls -la '$SITE_DIR' | head -20")
        log_debug "目录内容:\n$dir_content"
        
        # 检查是否有index.html文件
        if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "[ -f '$SITE_DIR/index.html' ]"; then
            log_success "找到 index.html 文件"
        else
            log_warning "未找到 index.html 文件"
        fi
        
        return 0
    else
        log_error "站点目录不存在"
        return 1
    fi
}

# 检查Web服务器
check_web_server() {
    log_info "检查Web服务器状态"
    
    # 检查Nginx
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "command -v nginx > /dev/null 2>&1"; then
        log_success "检测到 Nginx"
        
        # 检查Nginx状态
        if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "systemctl is-active nginx > /dev/null 2>&1"; then
            log_success "Nginx 服务运行中"
        else
            log_warning "Nginx 服务未运行"
        fi
        
        # 检查Nginx配置
        local nginx_conf
        nginx_conf=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "nginx -t 2>&1" || true)
        if echo "$nginx_conf" | grep -q "syntax is ok"; then
            log_success "Nginx 配置语法正确"
        else
            log_warning "Nginx 配置可能有误"
            log_debug "Nginx配置检查输出:\n$nginx_conf"
        fi
        
        return 0
    fi
    
    # 检查Caddy
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "command -v caddy > /dev/null 2>&1"; then
        log_success "检测到 Caddy"
        
        # 检查Caddy状态
        if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "systemctl is-active caddy > /dev/null 2>&1"; then
            log_success "Caddy 服务运行中"
        else
            log_warning "Caddy 服务未运行"
        fi
        
        return 0
    fi
    
    log_warning "未检测到Nginx或Caddy Web服务器"
    return 1
}

# 检查端口监听
check_port_listening() {
    log_info "检查HTTP端口监听状态"
    
    # 检查80端口
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "netstat -tln | grep ':80 ' > /dev/null 2>&1"; then
        log_success "80端口正在监听"
    else
        log_warning "80端口未监听"
    fi
    
    # 检查443端口
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "netstat -tln | grep ':443 ' > /dev/null 2>&1"; then
        log_success "443端口正在监听"
    else
        log_warning "443端口未监听"
    fi
}

# 生成部署建议
generate_deployment_suggestions() {
    log_info "生成部署建议"
    
    cat << EOF

📋 站点部署状态摘要:

1. 服务器连接: $(if check_ssh_connection > /dev/null 2>&1; then echo "✅ 正常"; else echo "❌ 失败"; fi)
2. 站点目录: $(if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "[ -d '$SITE_DIR' ]" > /dev/null 2>&1; then echo "✅ 存在"; else echo "❌ 不存在"; fi)
3. Web服务器: $(if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "command -v nginx > /dev/null 2>&1"; then echo "✅ Nginx"; elif ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_HOST" "command -v caddy > /dev/null 2>&1"; then echo "✅ Caddy"; else echo "❌ 未安装"; fi)

🔧 建议操作:

1. 基础部署:
   - 创建站点目录: mkdir -p $SITE_DIR
   - 添加index.html: echo '<h1>中华AI共和国 / OpenClaw 小白中文包</h1>' > $SITE_DIR/index.html

2. Nginx配置 (推荐):
   - 安装Nginx: apt install nginx -y
   - 创建配置文件: /etc/nginx/sites-available/roc-site
   - 启用站点: ln -s /etc/nginx/sites-available/roc-site /etc/nginx/sites-enabled/
   - 重启Nginx: systemctl restart nginx

3. Caddy配置 (简单):
   - 安装Caddy: apt install caddy -y
   - 创建Caddyfile: echo ':80 { root * $SITE_DIR }' > /etc/caddy/Caddyfile
   - 重启Caddy: systemctl restart caddy

4. HTTPS配置 (生产环境):
   - 申请域名证书 (Let's Encrypt)
   - 配置SSL/TLS
   - 设置HTTP重定向

5. 内容建议:
   - 下载入口 (install-cn.sh)
   - 安装命令展示
   - API网关信息 (quota-proxy)
   - TRIAL_KEY获取方式
   - 文档链接

📝 快速部署命令示例:

# 1. 创建站点目录和基础文件
ssh root@$SERVER_HOST "mkdir -p $SITE_DIR && echo '<h1>中华AI共和国</h1><p>OpenClaw 小白中文包</p>' > $SITE_DIR/index.html"

# 2. 安装并配置Nginx
ssh root@$SERVER_HOST "apt update && apt install nginx -y && echo 'server { listen 80; server_name _; root $SITE_DIR; index index.html; }' > /etc/nginx/sites-available/roc-site && ln -sf /etc/nginx/sites-available/roc-site /etc/nginx/sites-enabled/ && nginx -t && systemctl restart nginx"

EOF
}

# 主函数
main() {
    log_info "开始站点部署验证"
    log_info "服务器: $SERVER_HOST"
    log_info "站点目录: $SITE_DIR"
    log_info "SSH密钥: $SSH_KEY"
    echo ""
    
    # 执行检查
    local checks_passed=0
    local checks_total=0
    
    if check_ssh_connection; then
        ((checks_passed++))
    fi
    ((checks_total++))
    
    if check_site_directory; then
        ((checks_passed++))
    fi
    ((checks_total++))
    
    if check_web_server; then
        ((checks_passed++))
    fi
    ((checks_total++))
    
    check_port_listening
    
    echo ""
    log_info "检查完成: $checks_passed/$checks_total 项通过"
    
    # 生成建议
    generate_deployment_suggestions
    
    if [ $checks_passed -eq $checks_total ]; then
        log_success "站点部署验证通过"
        exit 0
    else
        log_warning "站点部署需要改进"
        exit 1
    fi
}

# 运行主函数
main "$@"