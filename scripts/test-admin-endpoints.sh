#!/bin/bash
# quota-proxy管理员接口测试脚本
# 用于验证POST /admin/keys和GET /admin/usage接口功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
QUOTA_PROXY_URL="${QUOTA_PROXY_URL:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
DRY_RUN=false
VERBOSE=false
QUIET=false

# 帮助信息
show_help() {
    cat << EOF
quota-proxy管理员接口测试脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -u, --url URL       quota-proxy URL (默认: $QUOTA_PROXY_URL)
  -t, --token TOKEN   管理员令牌 (默认: $ADMIN_TOKEN)
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -v, --verbose       详细输出模式
  -q, --quiet         安静模式，只输出关键信息
  --create-key        创建测试API密钥
  --check-usage       检查API使用情况

环境变量:
  QUOTA_PROXY_URL     quota-proxy服务URL
  ADMIN_TOKEN         管理员令牌

示例:
  $0 --url http://localhost:8787 --token my-secret-token
  $0 --create-key --check-usage
  ADMIN_TOKEN="my-token" $0 --verbose

EOF
}

# 日志函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warn() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请安装缺少的工具:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# 健康检查
check_health() {
    log_info "检查quota-proxy健康状态..."
    
    local health_url="$QUOTA_PROXY_URL/healthz"
    log_debug "健康检查URL: $health_url"
    
    if [ "$DRY_RUN" = true ]; then
        echo "curl -fsS \"$health_url\""
        return 0
    fi
    
    local response
    if response=$(curl -fsS "$health_url" 2>/dev/null); then
        log_success "健康检查通过: $response"
        return 0
    else
        log_error "健康检查失败"
        return 1
    fi
}

# 创建API密钥
create_api_key() {
    log_info "创建API密钥..."
    
    local create_url="$QUOTA_PROXY_URL/admin/keys"
    local payload='{"prefix":"test","quota":1000}'
    
    log_debug "创建密钥URL: $create_url"
    log_debug "请求负载: $payload"
    
    if [ "$DRY_RUN" = true ]; then
        echo "curl -X POST \"$create_url\" \\"
        echo "  -H \"Authorization: Bearer $ADMIN_TOKEN\" \\"
        echo "  -H \"Content-Type: application/json\" \\"
        echo "  -d '$payload'"
        return 0
    fi
    
    local response
    if response=$(curl -X POST "$create_url" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -s \
        -w "\n%{http_code}" 2>/dev/null); then
        
        local http_code=$(echo "$response" | tail -n1)
        local response_body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            log_success "API密钥创建成功"
            log_debug "响应: $response_body"
            
            # 提取密钥
            local api_key=$(echo "$response_body" | jq -r '.key // .apiKey // empty')
            if [ -n "$api_key" ]; then
                log_info "生成的API密钥: $api_key"
                echo "$api_key" > /tmp/test-api-key.txt
                log_info "API密钥已保存到 /tmp/test-api-key.txt"
            fi
            
            return 0
        else
            log_error "API密钥创建失败 (HTTP $http_code)"
            log_debug "响应: $response_body"
            return 1
        fi
    else
        log_error "创建API密钥请求失败"
        return 1
    fi
}

# 检查API使用情况
check_api_usage() {
    log_info "检查API使用情况..."
    
    local usage_url="$QUOTA_PROXY_URL/admin/usage"
    
    log_debug "使用情况URL: $usage_url"
    
    if [ "$DRY_RUN" = true ]; then
        echo "curl -X GET \"$usage_url\" \\"
        echo "  -H \"Authorization: Bearer $ADMIN_TOKEN\""
        return 0
    fi
    
    local response
    if response=$(curl -X GET "$usage_url" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -s \
        -w "\n%{http_code}" 2>/dev/null); then
        
        local http_code=$(echo "$response" | tail -n1)
        local response_body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" = "200" ]; then
            log_success "API使用情况查询成功"
            
            # 格式化输出
            if command -v jq &> /dev/null; then
                echo "$response_body" | jq .
            else
                echo "$response_body"
            fi
            
            return 0
        else
            log_error "API使用情况查询失败 (HTTP $http_code)"
            log_debug "响应: $response_body"
            return 1
        fi
    else
        log_error "API使用情况查询请求失败"
        return 1
    fi
}

# 测试API密钥
test_api_key() {
    local api_key="$1"
    
    if [ -z "$api_key" ]; then
        log_warn "没有API密钥可测试"
        return 0
    fi
    
    log_info "测试API密钥: ${api_key:0:8}..."
    
    local test_url="$QUOTA_PROXY_URL/test"
    
    if [ "$DRY_RUN" = true ]; then
        echo "curl -X GET \"$test_url\" \\"
        echo "  -H \"Authorization: Bearer $api_key\""
        return 0
    fi
    
    local response
    if response=$(curl -X GET "$test_url" \
        -H "Authorization: Bearer $api_key" \
        -s \
        -w "\n%{http_code}" 2>/dev/null); then
        
        local http_code=$(echo "$response" | tail -n1)
        local response_body=$(echo "$response" | head -n-1)
        
        if [ "$http_code" = "200" ]; then
            log_success "API密钥测试成功"
            log_debug "响应: $response_body"
            return 0
        else
            log_warn "API密钥测试失败 (HTTP $http_code)"
            log_debug "响应: $response_body"
            return 1
        fi
    else
        log_warn "API密钥测试请求失败"
        return 1
    fi
}

# 主函数
main() {
    # 解析参数
    local create_key=false
    local check_usage=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--url)
                QUOTA_PROXY_URL="$2"
                shift 2
                ;;
            -t|--token)
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
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --create-key)
                create_key=true
                shift
                ;;
            --check-usage)
                check_usage=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查依赖
    check_dependencies
    
    # 显示配置
    log_info "配置信息:"
    log_info "  quota-proxy URL: $QUOTA_PROXY_URL"
    log_info "  管理员令牌: ${ADMIN_TOKEN:0:8}..."
    
    # 健康检查
    if ! check_health; then
        log_error "quota-proxy服务不可用，请检查服务状态"
        exit 1
    fi
    
    # 执行测试
    local test_key=""
    
    # 创建API密钥
    if [ "$create_key" = true ]; then
        if create_api_key; then
            if [ -f /tmp/test-api-key.txt ]; then
                test_key=$(cat /tmp/test-api-key.txt)
            fi
        else
            log_warn "API密钥创建失败，跳过后续测试"
        fi
    fi
    
    # 检查API使用情况
    if [ "$check_usage" = true ]; then
        check_api_usage
    fi
    
    # 测试API密钥
    if [ -n "$test_key" ]; then
        test_api_key "$test_key"
    fi
    
    # 如果没有指定具体操作，执行完整测试流程
    if [ "$create_key" = false ] && [ "$check_usage" = false ]; then
        log_info "执行完整测试流程..."
        
        # 1. 创建API密钥
        if create_api_key; then
            if [ -f /tmp/test-api-key.txt ]; then
                test_key=$(cat /tmp/test-api-key.txt)
            fi
        fi
        
        # 2. 检查API使用情况
        check_api_usage
        
        # 3. 测试API密钥
        if [ -n "$test_key" ]; then
            test_api_key "$test_key"
        fi
    fi
    
    log_success "测试完成"
}

# 运行主函数
main "$@"