#!/bin/bash
# test-post-admin-keys.sh - 测试POST /admin/keys接口的简单脚本
# 用于验证quota-proxy的trial key创建功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
HOST="${QUOTA_PROXY_HOST:-127.0.0.1}"
PORT="${QUOTA_PROXY_PORT:-8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
API_BASE="http://${HOST}:${PORT}"

# 帮助信息
show_help() {
    cat << EOF
测试POST /admin/keys接口的简单脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -H, --host HOST     quota-proxy主机地址 (默认: 127.0.0.1)
  -p, --port PORT     quota-proxy端口 (默认: 8787)
  -t, --token TOKEN   管理员令牌 (默认: test-admin-token)
  -v, --verbose       详细输出模式
  -d, --dry-run       模拟运行，不实际发送请求

示例:
  $0 -H 8.210.185.194 -p 8787 -t "your-admin-token"
  $0 --dry-run
  ADMIN_TOKEN="prod-token" $0

环境变量:
  QUOTA_PROXY_HOST    quota-proxy主机地址
  QUOTA_PROXY_PORT    quota-proxy端口
  ADMIN_TOKEN         管理员令牌

退出码:
  0 - 测试成功
  1 - 测试失败
  2 - 参数错误
EOF
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 解析参数
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -H|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 2
            ;;
    esac
done

# 更新API基础URL
API_BASE="http://${HOST}:${PORT}"

# 显示配置
if [ "$VERBOSE" = true ]; then
    log_info "配置信息:"
    log_info "  Host: $HOST"
    log_info "  Port: $PORT"
    log_info "  API Base: $API_BASE"
    log_info "  Admin Token: ${ADMIN_TOKEN:0:4}**** (隐藏)"
    log_info "  Dry Run: $DRY_RUN"
fi

# 检查curl是否可用
if ! command -v curl &> /dev/null; then
    log_error "curl命令未找到，请先安装curl"
    exit 1
fi

# 测试健康端点
test_health() {
    log_info "测试健康端点..."
    local url="${API_BASE}/healthz"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN: 将请求: GET $url"
        return 0
    fi
    
    local response
    response=$(curl -s -f "${url}" 2>/dev/null || true)
    
    if [ -n "$response" ] && echo "$response" | grep -q '"ok":true'; then
        log_success "健康端点正常: $response"
        return 0
    else
        log_error "健康端点检查失败"
        return 1
    fi
}

# 测试POST /admin/keys接口
test_post_admin_keys() {
    log_info "测试POST /admin/keys接口..."
    local url="${API_BASE}/admin/keys"
    
    # 准备请求数据
    local request_data='{
        "name": "测试用户",
        "email": "test@example.com",
        "company": "测试公司",
        "notes": "这是测试创建的trial key"
    }'
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN: 将请求: POST $url"
        log_info "DRY RUN: 请求头: Authorization: Bearer ${ADMIN_TOKEN:0:4}****"
        log_info "DRY RUN: 请求体: $request_data"
        return 0
    fi
    
    local response
    response=$(curl -s -X POST "${url}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -d "${request_data}" \
        -w "\n%{http_code}" 2>/dev/null || true)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$VERBOSE" = true ]; then
        log_info "HTTP状态码: $http_code"
        log_info "响应体: $response_body"
    fi
    
    if [ "$http_code" = "201" ]; then
        log_success "成功创建trial key"
        
        # 提取key_id用于后续测试
        local key_id
        key_id=$(echo "$response_body" | grep -o '"key_id":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [ -n "$key_id" ]; then
            log_info "创建的key_id: $key_id"
            echo "$key_id" > /tmp/test_key_id.txt 2>/dev/null || true
        fi
        
        return 0
    elif [ "$http_code" = "401" ]; then
        log_error "未授权访问 (401)"
        return 1
    elif [ "$http_code" = "400" ]; then
        log_error "请求参数错误 (400)"
        return 1
    else
        log_error "创建trial key失败，HTTP状态码: $http_code"
        return 1
    fi
}

# 测试GET /admin/keys接口
test_get_admin_keys() {
    log_info "测试GET /admin/keys接口..."
    local url="${API_BASE}/admin/keys"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN: 将请求: GET $url"
        log_info "DRY RUN: 请求头: Authorization: Bearer ${ADMIN_TOKEN:0:4}****"
        return 0
    fi
    
    local response
    response=$(curl -s -X GET "${url}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "\n%{http_code}" 2>/dev/null || true)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$VERBOSE" = true ]; then
        log_info "HTTP状态码: $http_code"
        log_info "响应体长度: ${#response_body} 字符"
    fi
    
    if [ "$http_code" = "200" ]; then
        log_success "成功获取keys列表"
        
        # 检查响应是否为有效的JSON
        if echo "$response_body" | python3 -m json.tool >/dev/null 2>&1; then
            local key_count
            key_count=$(echo "$response_body" | grep -o '"key_id"' | wc -l || echo "0")
            log_info "找到 $key_count 个keys"
        fi
        
        return 0
    elif [ "$http_code" = "401" ]; then
        log_error "未授权访问 (401)"
        return 1
    else
        log_error "获取keys列表失败，HTTP状态码: $http_code"
        return 1
    fi
}

# 主测试流程
main() {
    log_info "开始测试POST /admin/keys接口..."
    log_info "目标服务: $API_BASE"
    
    # 测试健康端点
    if ! test_health; then
        log_error "健康端点测试失败，服务可能未运行"
        exit 1
    fi
    
    # 测试POST /admin/keys
    if ! test_post_admin_keys; then
        log_error "POST /admin/keys测试失败"
        exit 1
    fi
    
    # 测试GET /admin/keys
    if ! test_get_admin_keys; then
        log_error "GET /admin/keys测试失败"
        exit 1
    fi
    
    log_success "所有测试通过！"
    log_info "POST /admin/keys接口功能正常"
    
    # 清理临时文件
    rm -f /tmp/test_key_id.txt 2>/dev/null || true
    
    return 0
}

# 运行主函数
main "$@"