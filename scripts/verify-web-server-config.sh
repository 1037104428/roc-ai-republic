#!/bin/bash
# 站点Web服务器配置验证脚本
# 用于检查Nginx/Caddy配置文件语法，确保站点部署配置正确

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SERVER_HOST="8.210.185.194"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
SITE_DIR="/opt/roc/web"
WEB_SERVER="nginx"  # nginx 或 caddy
CONFIG_FILE="/etc/nginx/nginx.conf"
CONFIG_DIR="/etc/nginx/conf.d"
TEST_PORT=80
CONNECT_TIMEOUT=8

# 帮助信息
show_help() {
    cat << EOF
站点Web服务器配置验证脚本
用于检查Nginx/Caddy配置文件语法，确保站点部署配置正确

用法: $0 [选项]

选项:
  --server-host <host>     服务器地址 (默认: $SERVER_HOST)
  --server-user <user>     服务器用户名 (默认: $SERVER_USER)
  --ssh-key <path>         SSH私钥路径 (默认: $SSH_KEY)
  --site-dir <dir>         站点目录 (默认: $SITE_DIR)
  --web-server <server>    Web服务器类型: nginx 或 caddy (默认: $WEB_SERVER)
  --config-file <path>     主配置文件路径 (默认: $CONFIG_FILE)
  --config-dir <dir>       配置目录路径 (默认: $CONFIG_DIR)
  --test-port <port>       测试端口 (默认: $TEST_PORT)
  --check-only             只检查配置，不测试连接
  --verbose                详细输出模式
  --quiet                  安静模式，只输出关键信息
  --help                   显示此帮助信息

示例:
  $0 --web-server nginx --verbose
  $0 --web-server caddy --check-only
  $0 --server-host 192.168.1.100 --server-user admin

功能:
  1. 检查Web服务器配置文件语法
  2. 验证站点目录存在性
  3. 测试端口监听状态
  4. 生成配置验证报告
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-host)
            SERVER_HOST="$2"
            shift 2
            ;;
        --server-user)
            SERVER_USER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --site-dir)
            SITE_DIR="$2"
            shift 2
            ;;
        --web-server)
            WEB_SERVER="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        --test-port)
            TEST_PORT="$2"
            shift 2
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 日志函数
log_info() {
    if [[ -z "$QUIET" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ -z "$QUIET" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [[ -z "$QUIET" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ -n "$VERBOSE" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# 检查SSH连接
check_ssh_connection() {
    log_info "检查SSH连接到服务器 $SERVER_USER@$SERVER_HOST..."
    
    if ! ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "echo 'SSH连接成功'" > /dev/null 2>&1; then
        log_error "SSH连接失败，请检查网络、密钥和服务器状态"
        return 1
    fi
    
    log_success "SSH连接成功"
    return 0
}

# 检查Web服务器配置文件语法
check_config_syntax() {
    log_info "检查 $WEB_SERVER 配置文件语法..."
    
    case "$WEB_SERVER" in
        nginx)
            # 检查nginx配置语法
            if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "nginx -t" > /dev/null 2>&1; then
                log_success "Nginx配置语法检查通过"
                return 0
            else
                log_error "Nginx配置语法检查失败"
                # 获取详细错误信息
                ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "nginx -t 2>&1" || true
                return 1
            fi
            ;;
        caddy)
            # 检查Caddy配置语法
            if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "caddy validate --config $CONFIG_FILE" > /dev/null 2>&1; then
                log_success "Caddy配置语法检查通过"
                return 0
            else
                log_error "Caddy配置语法检查失败"
                # 获取详细错误信息
                ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "caddy validate --config $CONFIG_FILE 2>&1" || true
                return 1
            fi
            ;;
        *)
            log_error "不支持的Web服务器类型: $WEB_SERVER"
            return 1
            ;;
    esac
}

# 检查站点目录
check_site_directory() {
    log_info "检查站点目录: $SITE_DIR"
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "[ -d \"$SITE_DIR\" ]"; then
        log_success "站点目录存在"
        
        # 检查目录内容
        local file_count=$(ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "find \"$SITE_DIR\" -type f -name '*.html' -o -name '*.css' -o -name '*.js' | wc -l")
        if [[ "$file_count" -gt 0 ]]; then
            log_success "站点目录包含 $file_count 个网页文件"
        else
            log_warning "站点目录中没有找到网页文件"
        fi
        
        return 0
    else
        log_error "站点目录不存在: $SITE_DIR"
        return 1
    fi
}

# 检查Web服务器服务状态
check_service_status() {
    log_info "检查 $WEB_SERVER 服务状态..."
    
    case "$WEB_SERVER" in
        nginx)
            if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "systemctl is-active nginx" > /dev/null 2>&1; then
                log_success "Nginx服务正在运行"
                return 0
            else
                log_error "Nginx服务未运行"
                return 1
            fi
            ;;
        caddy)
            if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "systemctl is-active caddy" > /dev/null 2>&1; then
                log_success "Caddy服务正在运行"
                return 0
            else
                log_error "Caddy服务未运行"
                return 1
            fi
            ;;
    esac
}

# 检查端口监听
check_port_listening() {
    log_info "检查端口 $TEST_PORT 监听状态..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "netstat -tln | grep -q \":$TEST_PORT \""; then
        log_success "端口 $TEST_PORT 正在监听"
        return 0
    else
        log_error "端口 $TEST_PORT 未监听"
        return 1
    fi
}

# 测试HTTP连接
test_http_connection() {
    log_info "测试HTTP连接到端口 $TEST_PORT..."
    
    if ssh -i "$SSH_KEY" -o ConnectTimeout="$CONNECT_TIMEOUT" "$SERVER_USER@$SERVER_HOST" "curl -fsS http://127.0.0.1:$TEST_PORT > /dev/null 2>&1"; then
        log_success "HTTP连接测试成功"
        return 0
    else
        log_error "HTTP连接测试失败"
        return 1
    fi
}

# 生成验证报告
generate_report() {
    local report_file="/tmp/web-server-config-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Web服务器配置验证报告
=====================
验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
服务器: $SERVER_USER@$SERVER_HOST
Web服务器: $WEB_SERVER
站点目录: $SITE_DIR
配置文件: $CONFIG_FILE

验证结果:
EOF
    
    # 收集各个检查的结果
    local checks=(
        "SSH连接"
        "$WEB_SERVER配置语法"
        "站点目录存在性"
        "$WEB_SERVER服务状态"
        "端口$TEST_PORT监听"
        "HTTP连接测试"
    )
    
    local results=()
    
    # SSH连接
    if check_ssh_connection > /dev/null 2>&1; then
        results+=("✓ SSH连接: 成功")
    else
        results+=("✗ SSH连接: 失败")
    fi
    
    # 配置语法
    if check_config_syntax > /dev/null 2>&1; then
        results+=("✓ $WEB_SERVER配置语法: 成功")
    else
        results+=("✗ $WEB_SERVER配置语法: 失败")
    fi
    
    # 站点目录
    if check_site_directory > /dev/null 2>&1; then
        results+=("✓ 站点目录存在性: 成功")
    else
        results+=("✗ 站点目录存在性: 失败")
    fi
    
    # 服务状态
    if check_service_status > /dev/null 2>&1; then
        results+=("✓ $WEB_SERVER服务状态: 成功")
    else
        results+=("✗ $WEB_SERVER服务状态: 失败")
    fi
    
    # 端口监听
    if check_port_listening > /dev/null 2>&1; then
        results+=("✓ 端口$TEST_PORT监听: 成功")
    else
        results+=("✗ 端口$TEST_PORT监听: 失败")
    fi
    
    # HTTP连接
    if [[ -z "$CHECK_ONLY" ]]; then
        if test_http_connection > /dev/null 2>&1; then
            results+=("✓ HTTP连接测试: 成功")
        else
            results+=("✗ HTTP连接测试: 失败")
        fi
    else
        results+=("○ HTTP连接测试: 跳过（检查模式）")
    fi
    
    # 写入结果
    for result in "${results[@]}"; do
        echo "  $result" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "建议操作:" >> "$report_file"
    
    # 根据失败情况给出建议
    local has_failures=false
    for result in "${results[@]}"; do
        if [[ "$result" == ✗* ]]; then
            has_failures=true
            break
        fi
    done
    
    if [[ "$has_failures" == false ]]; then
        echo "  - 所有检查通过，站点配置正常" >> "$report_file"
        echo "  - 建议定期运行此脚本进行监控" >> "$report_file"
    else
        echo "  - 请根据失败项进行修复:" >> "$report_file"
        for result in "${results[@]}"; do
            if [[ "$result" == ✗* ]]; then
                local check_name=$(echo "$result" | sed 's/✗ //' | cut -d: -f1)
                echo "  - 修复: $check_name" >> "$report_file"
            fi
        done
        echo "  - 修复后重新运行此脚本验证" >> "$report_file"
    fi
    
    log_success "验证报告已生成: $report_file"
    cat "$report_file"
}

# 主函数
main() {
    log_info "开始验证 $WEB_SERVER 配置..."
    log_info "服务器: $SERVER_USER@$SERVER_HOST"
    log_info "站点目录: $SITE_DIR"
    log_info "配置文件: $CONFIG_FILE"
    
    # 检查SSH连接
    if ! check_ssh_connection; then
        log_error "无法连接到服务器，验证中止"
        exit 1
    fi
    
    # 检查配置语法
    if ! check_config_syntax; then
        log_error "配置语法检查失败，请修复配置文件"
        # 继续其他检查
    fi
    
    # 检查站点目录
    if ! check_site_directory; then
        log_warning "站点目录不存在或为空"
    fi
    
    # 检查服务状态
    if ! check_service_status; then
        log_error "Web服务器服务未运行"
    fi
    
    # 检查端口监听
    if ! check_port_listening; then
        log_error "端口未监听"
    fi
    
    # 测试HTTP连接（除非指定只检查）
    if [[ -z "$CHECK_ONLY" ]]; then
        if ! test_http_connection; then
            log_error "HTTP连接测试失败"
        fi
    fi
    
    # 生成报告
    generate_report
    
    # 总结
    log_info "验证完成"
    log_info "请查看上方报告了解详细结果和建议"
}

# 执行主函数
main "$@"