#!/bin/bash

# deploy-verification.sh - quota-proxy部署验证脚本
# 验证quota-proxy服务是否正常运行

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=8787
DEFAULT_HOST="127.0.0.1"
DEFAULT_TIMEOUT=5
DEFAULT_ADMIN_TOKEN="test-token"

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy部署验证脚本

用法: $0 [选项]

选项:
  -h, --help                显示此帮助信息
  -p, --port PORT           指定quota-proxy端口 (默认: $DEFAULT_PORT)
  -H, --host HOST           指定quota-proxy主机 (默认: $DEFAULT_HOST)
  -t, --timeout SECONDS     指定超时时间(秒) (默认: $DEFAULT_TIMEOUT)
  -a, --admin-token TOKEN   指定管理员令牌 (默认: $DEFAULT_ADMIN_TOKEN)
  -d, --dry-run             干运行模式，只显示将要执行的命令
  -v, --verbose             详细输出模式
  --no-color                禁用彩色输出

示例:
  $0                        使用默认配置验证
  $0 -p 8787 -H localhost   指定端口和主机验证
  $0 --dry-run              干运行模式
  $0 --verbose              详细输出模式

EOF
}

# 解析命令行参数
parse_args() {
    PORT="$DEFAULT_PORT"
    HOST="$DEFAULT_HOST"
    TIMEOUT="$DEFAULT_TIMEOUT"
    ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
    DRY_RUN=false
    VERBOSE=false
    NO_COLOR=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -a|--admin-token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            *)
                echo "错误: 未知选项 $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$NO_COLOR" = true ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

# 打印信息
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

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        return 1
    fi
    return 0
}

# 检查HTTP端点
check_http_endpoint() {
    local url="$1"
    local expected_status="${2:-200}"
    local description="$3"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行: 检查 $description ($url)"
        echo "curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout $TIMEOUT '$url'"
        return 0
    fi
    
    local status_code
    if status_code=$(curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout "$TIMEOUT" "$url" 2>/dev/null); then
        if [ "$status_code" = "$expected_status" ]; then
            log_success "$description: HTTP $status_code"
            return 0
        else
            log_error "$description: 期望 HTTP $expected_status，实际 HTTP $status_code"
            return 1
        fi
    else
        log_error "$description: 连接失败"
        return 1
    fi
}

# 检查健康端点
check_health() {
    local url="http://$HOST:$PORT/healthz"
    check_http_endpoint "$url" 200 "健康检查端点"
}

# 检查状态端点
check_status() {
    local url="http://$HOST:$PORT/status"
    check_http_endpoint "$url" 200 "状态端点"
}

# 检查管理员端点（需要令牌）
check_admin_endpoint() {
    local endpoint="$1"
    local description="$2"
    local url="http://$HOST:$PORT$endpoint"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行: 检查 $description ($url)"
        echo "curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout $TIMEOUT -H 'Authorization: Bearer $ADMIN_TOKEN' '$url'"
        return 0
    fi
    
    local status_code
    if status_code=$(curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout "$TIMEOUT" \
        -H "Authorization: Bearer $ADMIN_TOKEN" "$url" 2>/dev/null); then
        if [ "$status_code" = "200" ] || [ "$status_code" = "201" ]; then
            log_success "$description: HTTP $status_code"
            return 0
        else
            log_error "$description: HTTP $status_code"
            return 1
        fi
    else
        log_error "$description: 连接失败"
        return 1
    fi
}

# 主验证函数
main_verification() {
    log_info "开始quota-proxy部署验证"
    log_info "配置: 主机=$HOST, 端口=$PORT, 超时=${TIMEOUT}s"
    
    # 检查必要命令
    check_command curl || return 1
    
    local all_passed=true
    
    # 检查健康端点
    log_info "1. 检查健康端点..."
    if ! check_health; then
        all_passed=false
    fi
    
    # 检查状态端点
    log_info "2. 检查状态端点..."
    if ! check_status; then
        all_passed=false
    fi
    
    # 检查管理员端点（如果提供了令牌）
    if [ -n "$ADMIN_TOKEN" ] && [ "$ADMIN_TOKEN" != "test-token" ]; then
        log_info "3. 检查管理员端点..."
        
        # 检查管理员密钥列表
        if ! check_admin_endpoint "/admin/keys" "管理员密钥列表"; then
            all_passed=false
        fi
        
        # 检查使用统计
        if ! check_admin_endpoint "/admin/usage" "使用统计"; then
            all_passed=false
        fi
    else
        log_warning "使用默认测试令牌，跳过管理员端点验证"
        log_info "要测试管理员端点，请使用: $0 --admin-token YOUR_TOKEN"
    fi
    
    # 总结
    echo
    log_info "验证完成"
    if [ "$all_passed" = true ]; then
        log_success "所有检查通过！quota-proxy服务正常运行"
        return 0
    else
        log_error "部分检查失败，请检查quota-proxy服务状态"
        return 1
    fi
}

# 主程序
main() {
    parse_args "$@"
    
    if [ "$VERBOSE" = true ]; then
        set -x
    fi
    
    if main_verification; then
        exit 0
    else
        exit 1
    fi
}

# 运行主程序
main "$@"