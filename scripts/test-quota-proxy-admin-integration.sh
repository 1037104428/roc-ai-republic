#!/bin/bash

# quota-proxy 管理接口集成测试脚本
# 测试 POST /admin/keys 和 GET /admin/usage 接口
# 作者: 中华AI共和国项目组
# 版本: v1.0.0

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
HOST="${QUOTA_PROXY_HOST:-127.0.0.1}"
PORT="${QUOTA_PROXY_PORT:-8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
BASE_URL="http://${HOST}:${PORT}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# 帮助信息
show_help() {
    cat << EOF
quota-proxy 管理接口集成测试脚本

测试 POST /admin/keys 和 GET /admin/usage 接口的完整功能。

用法: $0 [选项]

选项:
  -h, --help                显示此帮助信息
  -H, --host HOST           quota-proxy 主机地址 (默认: 127.0.0.1)
  -p, --port PORT           quota-proxy 端口 (默认: 8787)
  -t, --token TOKEN         管理员令牌 (必需)
  -v, --verbose             详细输出模式
  -d, --dry-run             模拟运行，不实际发送请求
  --version                 显示版本信息

环境变量:
  QUOTA_PROXY_HOST          quota-proxy 主机地址
  QUOTA_PROXY_PORT          quota-proxy 端口
  ADMIN_TOKEN               管理员令牌

示例:
  $0 -t "your-admin-token"
  ADMIN_TOKEN="your-token" $0 -v
  $0 -H 8.210.185.194 -p 8787 -t "your-token" -v

退出码:
  0 - 所有测试通过
  1 - 测试失败
  2 - 参数错误
  3 - 网络连接失败
EOF
}

# 版本信息
show_version() {
    echo "quota-proxy 管理接口集成测试脚本 v1.0.0"
    echo "中华AI共和国项目组"
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

log_debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_error "请安装: sudo apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    log_debug "所有依赖已安装"
    return 0
}

# 检查服务健康状态
check_health() {
    log_info "检查 quota-proxy 服务健康状态..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 跳过健康检查"
        return 0
    fi
    
    local health_url="${BASE_URL}/healthz"
    local response
    
    if response=$(curl -s -f -w "%{http_code}" "$health_url" 2>/dev/null); then
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            log_success "服务健康状态正常"
            log_debug "响应: $body"
            return 0
        else
            log_error "服务返回非200状态码: $status_code"
            log_debug "响应: $body"
            return 1
        fi
    else
        log_error "无法连接到服务: $health_url"
        return 1
    fi
}

# 测试 POST /admin/keys 接口
test_post_admin_keys() {
    log_info "测试 POST /admin/keys 接口..."
    
    local test_label="integration-test-$(date +%s)"
    local test_quota=1000
    local endpoint="${BASE_URL}/admin/keys"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 将发送 POST 请求到 $endpoint"
        log_warning "请求体: {\"label\":\"$test_label\",\"totalQuota\":$test_quota}"
        echo "sk-test-dry-run-1234567890"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -w "%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"label\":\"$test_label\",\"totalQuota\":$test_quota}" \
        "$endpoint" 2>/dev/null); then
        
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            local key=$(echo "$body" | jq -r '.key // .id // empty')
            if [ -n "$key" ]; then
                log_success "成功创建试用密钥"
                log_debug "响应: $body"
                echo "$key"
                return 0
            else
                log_error "响应中未找到密钥"
                log_debug "响应: $body"
                return 1
            fi
        else
            log_error "POST /admin/keys 返回非200状态码: $status_code"
            log_debug "响应: $body"
            return 1
        fi
    else
        log_error "POST /admin/keys 请求失败"
        return 1
    fi
}

# 测试 GET /admin/keys 接口
test_get_admin_keys() {
    log_info "测试 GET /admin/keys 接口..."
    
    local endpoint="${BASE_URL}/admin/keys"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 将发送 GET 请求到 $endpoint"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -w "%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$endpoint" 2>/dev/null); then
        
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            log_success "成功获取密钥列表"
            local count=$(echo "$body" | jq '.items | length')
            log_debug "找到 $count 个密钥"
            log_debug "响应: $body"
            return 0
        else
            log_error "GET /admin/keys 返回非200状态码: $status_code"
            log_debug "响应: $body"
            return 1
        fi
    else
        log_error "GET /admin/keys 请求失败"
        return 1
    fi
}

# 测试 GET /admin/usage 接口
test_get_admin_usage() {
    log_info "测试 GET /admin/usage 接口..."
    
    local endpoint="${BASE_URL}/admin/usage"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 将发送 GET 请求到 $endpoint"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -w "%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$endpoint" 2>/dev/null); then
        
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            log_success "成功获取使用情况统计"
            log_debug "响应: $body"
            return 0
        else
            log_error "GET /admin/usage 返回非200状态码: $status_code"
            log_debug "响应: $body"
            return 1
        fi
    else
        log_error "GET /admin/usage 请求失败"
        return 1
    fi
}

# 测试带参数的 GET /admin/usage 接口
test_get_admin_usage_with_params() {
    log_info "测试带参数的 GET /admin/usage 接口..."
    
    local test_key="$1"
    local endpoint="${BASE_URL}/admin/usage?key=${test_key}&days=1"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 将发送 GET 请求到 $endpoint"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -w "%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$endpoint" 2>/dev/null); then
        
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            log_success "成功获取指定密钥的使用情况"
            log_debug "响应: $body"
            return 0
        else
            log_error "GET /admin/usage?key=... 返回非200状态码: $status_code"
            log_debug "响应: $body"
            return 1
        fi
    else
        log_error "GET /admin/usage?key=... 请求失败"
        return 1
    fi
}

# 清理测试数据
cleanup_test_data() {
    local test_key="$1"
    
    if [ -z "$test_key" ] || [ "$test_key" = "sk-test-dry-run-1234567890" ]; then
        return 0
    fi
    
    log_info "清理测试数据: $test_key"
    
    local endpoint="${BASE_URL}/admin/keys/${test_key}"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "模拟运行: 将发送 DELETE 请求到 $endpoint"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -w "%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -X DELETE \
        "$endpoint" 2>/dev/null); then
        
        local status_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$status_code" = "200" ]; then
            log_success "成功删除测试密钥"
            log_debug "响应: $body"
            return 0
        else
            log_warning "删除测试密钥失败: 状态码 $status_code"
            log_debug "响应: $body"
            return 0  # 不因清理失败而失败测试
        fi
    else
        log_warning "删除测试密钥请求失败"
        return 0  # 不因清理失败而失败测试
    fi
}

# 主测试函数
run_tests() {
    local test_key=""
    local failed_tests=0
    
    log_info "开始 quota-proxy 管理接口集成测试"
    log_debug "配置: HOST=$HOST, PORT=$PORT, BASE_URL=$BASE_URL"
    
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi
    
    # 检查健康状态
    if ! check_health; then
        return 1
    fi
    
    # 测试 POST /admin/keys
    if test_key=$(test_post_admin_keys); then
        log_success "✅ POST /admin/keys 测试通过"
    else
        log_error "❌ POST /admin/keys 测试失败"
        failed_tests=$((failed_tests + 1))
    fi
    
    # 测试 GET /admin/keys
    if test_get_admin_keys; then
        log_success "✅ GET /admin/keys 测试通过"
    else
        log_error "❌ GET /admin/keys 测试失败"
        failed_tests=$((failed_tests + 1))
    fi
    
    # 测试 GET /admin/usage
    if test_get_admin_usage; then
        log_success "✅ GET /admin/usage 测试通过"
    else
        log_error "❌ GET /admin/usage 测试失败"
        failed_tests=$((failed_tests + 1))
    fi
    
    # 测试带参数的 GET /admin/usage
    if [ -n "$test_key" ] && [ "$test_key" != "sk-test-dry-run-1234567890" ]; then
        if test_get_admin_usage_with_params "$test_key"; then
            log_success "✅ GET /admin/usage?key=... 测试通过"
        else
            log_error "❌ GET /admin/usage?key=... 测试失败"
            failed_tests=$((failed_tests + 1))
        fi
    fi
    
    # 清理测试数据
    cleanup_test_data "$test_key"
    
    # 输出测试结果
    if [ $failed_tests -eq 0 ]; then
        log_success "🎉 所有测试通过！"
        return 0
    else
        log_error "💥 $failed_tests 个测试失败"
        return 1
    fi
}

# 解析命令行参数
parse_args() {
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
                VERBOSE="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 2
                ;;
        esac
    done
    
    # 验证必需参数
    if [ -z "$ADMIN_TOKEN" ] && [ "$DRY_RUN" = "false" ]; then
        log_error "必需参数缺失: ADMIN_TOKEN"
        log_error "请通过 -t 参数或环境变量提供管理员令牌"
        show_help
        exit 2
    fi
    
    BASE_URL="http://${HOST}:${PORT}"
}

# 主函数
main() {
    parse_args "$@"
    
    if run_tests; then
        exit 0
    else
        exit 1
    fi
}

# 运行主函数
main "$@"