#!/bin/bash
# deploy-static-site.sh - 部署静态站点到服务器
# 优先级C（站点）的部署脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SERVER_IP=""
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
SITE_DIR="/opt/roc/web"
LOCAL_SOURCE_DIR=""
WEB_SERVER="nginx"  # nginx 或 caddy
DOMAIN=""
HTTPS_ENABLED=false
DRY_RUN=false
VERBOSE=false

# 帮助信息
show_help() {
    cat << EOF
部署静态站点到服务器

用法: $0 [选项]

选项:
  -s, --server-ip IP      服务器IP地址（默认从/tmp/server.txt读取）
  -k, --ssh-key PATH      SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）
  -d, --site-dir DIR      服务器上的站点目录（默认: /opt/roc/web）
  -l, --local-source DIR  本地静态文件目录
  -w, --web-server TYPE   Web服务器类型: nginx 或 caddy（默认: nginx）
  --domain DOMAIN         域名（用于HTTPS配置）
  --https                 启用HTTPS（需要域名）
  --dry-run               干运行模式，只显示将要执行的命令
  -v, --verbose           详细输出模式
  -h, --help              显示此帮助信息

示例:
  $0 --local-source ./site --domain example.com --https
  $0 --server-ip 8.210.185.194 --local-source ./public --web-server caddy

说明:
  1. 检查服务器连接
  2. 创建站点目录
  3. 上传静态文件
  4. 配置Web服务器（Nginx或Caddy）
  5. 重启Web服务
  6. 验证部署
EOF
}

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server-ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -k|--ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            -d|--site-dir)
                SITE_DIR="$2"
                shift 2
                ;;
            -l|--local-source)
                LOCAL_SOURCE_DIR="$2"
                shift 2
                ;;
            -w|--web-server)
                WEB_SERVER="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --https)
                HTTPS_ENABLED=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
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
}

# 检查必需参数
check_requirements() {
    # 如果未指定服务器IP，从/tmp/server.txt读取
    if [[ -z "$SERVER_IP" ]]; then
        if [[ -f "/tmp/server.txt" ]]; then
            SERVER_IP=$(grep -E '^ip:' /tmp/server.txt | cut -d':' -f2 | tr -d '[:space:]')
            if [[ -z "$SERVER_IP" ]]; then
                log_error "无法从/tmp/server.txt解析服务器IP"
                exit 1
            fi
            log_info "从/tmp/server.txt读取服务器IP: $SERVER_IP"
        else
            log_error "请指定服务器IP或确保/tmp/server.txt存在"
            exit 1
        fi
    fi

    # 检查本地源目录
    if [[ -z "$LOCAL_SOURCE_DIR" ]]; then
        log_error "请指定本地静态文件目录（--local-source）"
        exit 1
    fi

    if [[ ! -d "$LOCAL_SOURCE_DIR" ]]; then
        log_error "本地目录不存在: $LOCAL_SOURCE_DIR"
        exit 1
    fi

    # 检查Web服务器类型
    if [[ "$WEB_SERVER" != "nginx" && "$WEB_SERVER" != "caddy" ]]; then
        log_error "不支持的Web服务器类型: $WEB_SERVER，请使用nginx或caddy"
        exit 1
    fi

    # 检查HTTPS配置
    if [[ "$HTTPS_ENABLED" == true && -z "$DOMAIN" ]]; then
        log_error "启用HTTPS需要指定域名（--domain）"
        exit 1
    fi

    # 检查SSH密钥
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH密钥不存在: $SSH_KEY"
        exit 1
    fi
}

# 执行SSH命令
run_ssh() {
    local cmd="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \"$cmd\""
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "$cmd"
    fi
}

# 执行SCP命令
run_scp() {
    local src="$1"
    local dst="$2"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] scp -i \"$SSH_KEY\" -r \"$src\" root@$SERVER_IP:\"$dst\""
    else
        scp -i "$SSH_KEY" -r "$src" root@"$SERVER_IP":"$dst"
    fi
}

# 检查服务器连接
check_server_connection() {
    log_info "检查服务器连接..."
    if ! run_ssh "echo '连接成功'" > /dev/null 2>&1; then
        log_error "无法连接到服务器 $SERVER_IP"
        exit 1
    fi
    log_success "服务器连接正常"
}

# 准备服务器目录
prepare_server_directory() {
    log_info "准备服务器目录: $SITE_DIR"
    
    # 创建目录
    run_ssh "mkdir -p \"$SITE_DIR\""
    
    # 设置权限
    run_ssh "chmod 755 \"$SITE_DIR\""
    
    # 检查磁盘空间
    local disk_info
    disk_info=$(run_ssh "df -h \"$SITE_DIR\" | tail -1")
    log_info "磁盘空间信息: $disk_info"
    
    log_success "服务器目录准备完成"
}

# 上传静态文件
upload_static_files() {
    log_info "上传静态文件从 $LOCAL_SOURCE_DIR 到 $SITE_DIR"
    
    # 清空目标目录（保留目录结构）
    run_ssh "rm -rf \"$SITE_DIR\"/* 2>/dev/null || true"
    
    # 上传文件
    run_scp "$LOCAL_SOURCE_DIR/" "$SITE_DIR"
    
    # 设置文件权限
    run_ssh "find \"$SITE_DIR\" -type f -exec chmod 644 {} \;"
    run_ssh "find \"$SITE_DIR\" -type d -exec chmod 755 {} \;"
    
    # 检查文件数量
    local file_count
    file_count=$(run_ssh "find \"$SITE_DIR\" -type f | wc -l")
    log_info "上传了 $file_count 个文件"
    
    log_success "静态文件上传完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    local nginx_conf="/etc/nginx/sites-available/roc-site"
    local nginx_enabled="/etc/nginx/sites-enabled/roc-site"
    
    # 创建Nginx配置
    local config_content
    if [[ "$HTTPS_ENABLED" == true ]]; then
        config_content=$(cat << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/ssl/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/ssl/private/$DOMAIN.key;
    
    root $SITE_DIR;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
        )
        log_warning "HTTPS配置需要手动设置SSL证书: /etc/ssl/certs/$DOMAIN.crt 和 /etc/ssl/private/$DOMAIN.key"
    else
        config_content=$(cat << EOF
server {
    listen 80;
    server_name _;
    
    root $SITE_DIR;
    index index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
        )
    fi
    
    # 上传配置
    echo "$config_content" | run_ssh "cat > /tmp/nginx-roc-site.conf"
    run_ssh "sudo cp /tmp/nginx-roc-site.conf \"$nginx_conf\""
    
    # 启用站点
    run_ssh "sudo ln -sf \"$nginx_conf\" \"$nginx_enabled\" 2>/dev/null || true"
    
    # 测试配置
    if ! run_ssh "sudo nginx -t" 2>/dev/null; then
        log_error "Nginx配置测试失败"
        run_ssh "cat /tmp/nginx-roc-site.conf"
        exit 1
    fi
    
    log_success "Nginx配置完成"
}

# 配置Caddy
configure_caddy() {
    log_info "配置Caddy..."
    
    local caddyfile="/etc/caddy/Caddyfile"
    
    # 创建Caddy配置
    local config_content
    if [[ "$HTTPS_ENABLED" == true ]]; then
        config_content="$DOMAIN {
    root * $SITE_DIR
    file_server
    
    # 静态文件缓存
    header Cache-Control \"public, max-age=31536000\" {
        /assets/*
        /static/*
        /images/*
        /css/*
        /js/*
    }
}"
    else
        config_content=":80 {
    root * $SITE_DIR
    file_server
    
    # 静态文件缓存
    header Cache-Control \"public, max-age=31536000\" {
        /assets/*
        /static/*
        /images/*
        /css/*
        /js/*
    }
}"
    fi
    
    # 上传配置
    echo "$config_content" | run_ssh "cat > /tmp/Caddyfile-roc-site"
    run_ssh "sudo cp /tmp/Caddyfile-roc-site \"$caddyfile\""
    
    log_success "Caddy配置完成"
}

# 重启Web服务
restart_web_service() {
    log_info "重启Web服务: $WEB_SERVER"
    
    case "$WEB_SERVER" in
        nginx)
            run_ssh "sudo systemctl restart nginx"
            run_ssh "sudo systemctl status nginx --no-pager"
            ;;
        caddy)
            run_ssh "sudo systemctl restart caddy"
            run_ssh "sudo systemctl status caddy --no-pager"
            ;;
    esac
    
    log_success "Web服务重启完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    # 检查服务状态
    case "$WEB_SERVER" in
        nginx)
            if ! run_ssh "systemctl is-active --quiet nginx"; then
                log_error "Nginx服务未运行"
                return 1
            fi
            ;;
        caddy)
            if ! run_ssh "systemctl is-active --quiet caddy"; then
                log_error "Caddy服务未运行"
                return 1
            fi
            ;;
    esac
    
    # 检查端口监听
    local port
    if [[ "$HTTPS_ENABLED" == true ]]; then
        port=443
    else
        port=80
    fi
    
    if ! run_ssh "netstat -tln | grep -q \":$port \""; then
        log_warning "端口 $port 未监听，但服务可能使用其他配置"
    fi
    
    # 检查站点文件
    if ! run_ssh "[[ -f \"$SITE_DIR/index.html\" ]] || [[ -f \"$SITE_DIR/index.htm\" ]]"; then
        log_warning "站点目录中没有找到index.html或index.htm文件"
    fi
    
    # 尝试访问站点（如果可能）
    if [[ -n "$DOMAIN" && "$HTTPS_ENABLED" == true ]]; then
        log_info "尝试访问站点: https://$DOMAIN"
        if curl -s -f -I "https://$DOMAIN" > /dev/null 2>&1; then
            log_success "站点可访问: https://$DOMAIN"
        else
            log_warning "无法访问 https://$DOMAIN，可能是DNS或证书问题"
        fi
    elif [[ -n "$SERVER_IP" ]]; then
        log_info "尝试访问站点: http://$SERVER_IP"
        if curl -s -f -I "http://$SERVER_IP" > /dev/null 2>&1; then
            log_success "站点可访问: http://$SERVER_IP"
        else
            log_warning "无法访问 http://$SERVER_IP，可能是防火墙或配置问题"
        fi
    fi
    
    log_success "部署验证完成"
}

# 生成部署报告
generate_report() {
    local report_file="/tmp/deploy-static-site-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
静态站点部署报告
================
部署时间: $(date)
服务器: $SERVER_IP
站点目录: $SITE_DIR
Web服务器: $WEB_SERVER
HTTPS启用: $HTTPS_ENABLED
域名: ${DOMAIN:-未指定}
本地源目录: $LOCAL_SOURCE_DIR

部署步骤:
1. 服务器连接检查: ✓
2. 目录准备: ✓
3. 文件上传: ✓
4. Web服务器配置: ✓
5. 服务重启: ✓
6. 部署验证: ✓

验证命令:
  ssh -i "$SSH_KEY" root@$SERVER_IP "ls -la $SITE_DIR"
  curl -I http://$SERVER_IP

注意事项:
EOF

    if [[ "$HTTPS_ENABLED" == true ]]; then
        cat >> "$report_file" << EOF
  - HTTPS已启用，需要配置SSL证书
  - 证书路径: /etc/ssl/certs/$DOMAIN.crt
  - 私钥路径: /etc/ssl/private/$DOMAIN.key
EOF
    fi
    
    cat >> "$report_file" << EOF
  - 确保防火墙允许端口80/443
  - 建议配置域名DNS解析

后续操作:
  1. 配置域名DNS指向 $SERVER_IP
  2. 设置SSL证书（如启用HTTPS）
  3. 配置监控和备份
  4. 定期更新静态内容

EOF
    
    log_info "部署报告已生成: $report_file"
    cat "$report_file"
}

# 主函数
main() {
    parse_args "$@"
    check_requirements
    
    log_info "开始部署静态站点"
    log_info "服务器: $SERVER_IP"
    log_info "站点目录: $SITE_DIR"
    log_info "Web服务器: $WEB_SERVER"
    log_info "HTTPS: $HTTPS_ENABLED"
    [[ -n "$DOMAIN" ]] && log_info "域名: $DOMAIN"
    
    check_server_connection
    prepare_server_directory
    upload_static_files
    
    case "$WEB_SERVER" in
        nginx)
            configure_nginx
            ;;
        caddy)
            configure_caddy
            ;;
    esac
    
    restart_web_service
    verify_deployment
    generate_report
    
    log_success "静态站点部署完成！"
}

# 运行主函数
main "$@"