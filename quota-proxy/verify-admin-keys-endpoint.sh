#!/bin/bash

# verify-admin-keys-endpoint.sh
# 验证 POST /admin/keys 和 GET /admin/usage 端点功能
# 需要 ADMIN_TOKEN 环境变量

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

# 帮助信息
show_help() {
    cat << EOF
验证 POST /admin/keys 和 GET /admin/usage 端点功能

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -q, --quiet         安静模式，只显示错误和最终结果
  -v, --verbose       详细模式，显示所有输出
  --host HOST         服务器主机地址 (默认: 127.0.0.1)
  --port PORT         服务器端口 (默认: 8787)
  --admin-token TOKEN 管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 读取)
  --no-cleanup        测试后不清理创建的密钥

示例:
  $0 --host 127.0.0.1 --port 8787
  ADMIN_TOKEN=my-secret-token $0 --dry-run
EOF
}

# 默认配置
DRY_RUN=false
QUIET=false
VERBOSE=false
HOST="127.0.0.1"
PORT="8787"
ADMIN_TOKEN="${ADMIN_TOKEN}"
CLEANUP=true

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必需的环境变量
if [[ -z "$ADMIN_TOKEN" ]]; then
    log_error "ADMIN_TOKEN 环境变量未设置"
    log_info "请设置 ADMIN_TOKEN 环境变量或使用 --admin-token 参数"
    exit 1
fi

# 基础URL
BASE_URL="http://${HOST}:${PORT}"

# 运行命令函数
run_command() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[干运行] $description"
        echo "  $cmd"
        return 0
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "执行: $description"
        echo "命令: $cmd"
    fi
    
    eval "$cmd"
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "命令执行失败 (退出码: $exit_code): $description"
        return $exit_code
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_success "命令执行成功: $description"
    fi
    
    return 0
}

# 检查服务器是否运行
check_server() {
    log_info "检查服务器是否运行..."
    local health_url="${BASE_URL}/healthz"
    
    run_command "curl -fsS \"${health_url}\"" "检查服务器健康状态"
    
    if [[ $? -eq 0 ]]; then
        log_success "服务器运行正常"
        return 0
    else
        log_error "服务器未运行或健康检查失败"
        return 1
    fi
}

# 测试1: 创建API密钥
test_create_api_key() {
    log_info "测试1: 创建API密钥"
    
    local create_url="${BASE_URL}/admin/keys"
    local label="test-key-$(date +%s)"
    local total_quota=500
    
    local response_file=$(mktemp)
    
    run_command "curl -X POST \"${create_url}\" \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        -H \"Content-Type: application/json\" \
        -d '{\"label\": \"${label}\", \"totalQuota\": ${total_quota}}' \
        -w \"HTTP_STATUS:%{http_code}\" \
        -o \"${response_file}\"" "创建API密钥"
    
    if [[ $? -ne 0 ]]; then
        log_error "创建API密钥失败"
        rm -f "$response_file"
        return 1
    fi
    
    # 提取HTTP状态码和响应体
    local http_status=$(grep -o 'HTTP_STATUS:[0-9]*' "$response_file" | cut -d: -f2)
    local response_body=$(grep -v 'HTTP_STATUS:' "$response_file")
    
    if [[ "$http_status" != "200" ]]; then
        log_error "创建API密钥失败，HTTP状态码: $http_status"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    # 解析响应
    local key=$(echo "$response_body" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    local response_label=$(echo "$response_body" | grep -o '"label":"[^"]*"' | cut -d'"' -f4)
    local response_quota=$(echo "$response_body" | grep -o '"totalQuota":[0-9]*' | cut -d: -f2)
    
    if [[ -z "$key" ]]; then
        log_error "无法从响应中提取API密钥"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    log_success "API密钥创建成功"
    log_info "密钥: $key"
    log_info "标签: $response_label"
    log_info "配额: $response_quota"
    
    # 保存密钥用于后续测试
    CREATED_KEY="$key"
    CREATED_KEY_FILE="$response_file"
    
    return 0
}

# 测试2: 查询使用情况
test_query_usage() {
    log_info "测试2: 查询使用情况"
    
    local usage_url="${BASE_URL}/admin/usage"
    
    local response_file=$(mktemp)
    
    run_command "curl -X GET \"${usage_url}\" \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        -w \"HTTP_STATUS:%{http_code}\" \
        -o \"${response_file}\"" "查询使用情况"
    
    if [[ $? -ne 0 ]]; then
        log_error "查询使用情况失败"
        rm -f "$response_file"
        return 1
    fi
    
    # 提取HTTP状态码和响应体
    local http_status=$(grep -o 'HTTP_STATUS:[0-9]*' "$response_file" | cut -d: -f2)
    local response_body=$(grep -v 'HTTP_STATUS:' "$response_file")
    
    if [[ "$http_status" != "200" ]]; then
        log_error "查询使用情况失败，HTTP状态码: $http_status"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    # 检查响应结构
    if echo "$response_body" | grep -q '"success":true'; then
        log_success "使用情况查询成功"
        
        # 提取分页信息
        local page=$(echo "$response_body" | grep -o '"page":[0-9]*' | cut -d: -f2)
        local total=$(echo "$response_body" | grep -o '"total":[0-9]*' | cut -d: -f2)
        
        if [[ -n "$page" ]] && [[ -n "$total" ]]; then
            log_info "分页信息: 第 ${page} 页，共 ${total} 条记录"
        fi
        
        # 检查是否包含创建的密钥
        if echo "$response_body" | grep -q "\"key\":\"${CREATED_KEY}\""; then
            log_success "创建的密钥在使用情况列表中"
        else
            log_warning "创建的密钥未在使用情况列表中（可能是分页原因）"
        fi
    else
        log_error "使用情况查询响应格式不正确"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    rm -f "$response_file"
    return 0
}

# 测试3: 带过滤条件查询使用情况
test_query_usage_with_filter() {
    log_info "测试3: 带密钥过滤查询使用情况"
    
    local usage_url="${BASE_URL}/admin/usage?key=${CREATED_KEY}"
    
    local response_file=$(mktemp)
    
    run_command "curl -X GET \"${usage_url}\" \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        -w \"HTTP_STATUS:%{http_code}\" \
        -o \"${response_file}\"" "按密钥过滤查询使用情况"
    
    if [[ $? -ne 0 ]]; then
        log_error "按密钥过滤查询使用情况失败"
        rm -f "$response_file"
        return 1
    fi
    
    # 提取HTTP状态码和响应体
    local http_status=$(grep -o 'HTTP_STATUS:[0-9]*' "$response_file" | cut -d: -f2)
    local response_body=$(grep -v 'HTTP_STATUS:' "$response_file")
    
    if [[ "$http_status" != "200" ]]; then
        log_error "按密钥过滤查询使用情况失败，HTTP状态码: $http_status"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    # 检查响应是否包含指定密钥
    if echo "$response_body" | grep -q "\"key\":\"${CREATED_KEY}\""; then
        log_success "按密钥过滤查询成功，找到指定密钥"
    else
        log_error "按密钥过滤查询失败，未找到指定密钥"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    rm -f "$response_file"
    return 0
}

# 测试4: 带分页查询使用情况
test_query_usage_with_pagination() {
    log_info "测试4: 带分页查询使用情况"
    
    local usage_url="${BASE_URL}/admin/usage?page=1&limit=10"
    
    local response_file=$(mktemp)
    
    run_command "curl -X GET \"${usage_url}\" \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        -w \"HTTP_STATUS:%{http_code}\" \
        -o \"${response_file}\"" "分页查询使用情况"
    
    if [[ $? -ne 0 ]]; then
        log_error "分页查询使用情况失败"
        rm -f "$response_file"
        return 1
    fi
    
    # 提取HTTP状态码和响应体
    local http_status=$(grep -o 'HTTP_STATUS:[0-9]*' "$response_file" | cut -d: -f2)
    local response_body=$(grep -v 'HTTP_STATUS:' "$response_file")
    
    if [[ "$http_status" != "200" ]]; then
        log_error "分页查询使用情况失败，HTTP状态码: $http_status"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    # 检查分页信息
    if echo "$response_body" | grep -q '"pagination"'; then
        local page=$(echo "$response_body" | grep -o '"page":[0-9]*' | cut -d: -f2)
        local limit=$(echo "$response_body" | grep -o '"limit":[0-9]*' | cut -d: -f2)
        
        log_success "分页查询成功"
        log_info "分页信息: 第 ${page} 页，每页 ${limit} 条"
    else
        log_error "分页查询响应缺少分页信息"
        echo "响应: $response_body"
        rm -f "$response_file"
        return 1
    fi
    
    rm -f "$response_file"
    return 0
}

# 清理函数：删除测试创建的密钥
cleanup() {
    if [[ "$CLEANUP" == "true" ]] && [[ -n "$CREATED_KEY" ]]; then
        log_info "清理测试创建的密钥: $CREATED_KEY"
        
        local delete_url="${BASE_URL}/admin/keys/${CREATED_KEY}"
        
        run_command "curl -X DELETE \"${delete_url}\" \
            -H \"Authorization: Bearer ${ADMIN_TOKEN}\"" "删除测试密钥"
        
        if [[ $? -eq 0 ]]; then
            log_success "测试密钥清理成功"
        else
            log_warning "测试密钥清理失败"
        fi
    fi
    
    # 清理临时文件
    if [[ -f "$CREATED_KEY_FILE" ]]; then
        rm -f "$CREATED_KEY_FILE"
    fi
}

# 主函数
main() {
    log_info "开始验证 POST /admin/keys 和 GET /admin/usage 端点"
    log_info "服务器: ${BASE_URL}"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:4}****${ADMIN_TOKEN: -4}"
    
    # 设置陷阱，确保清理
    trap cleanup EXIT
    
    # 检查服务器
    if ! check_server; then
        exit 1
    fi
    
    # 运行测试
    local tests_passed=0
    local tests_failed=0
    local tests=(
        "test_create_api_key"
        "test_query_usage"
        "test_query_usage_with_filter"
        "test_query_usage_with_pagination"
    )
    
    for test_func in "${tests[@]}"; do
        log_info "运行测试: $test_func"
        
        if $test_func; then
            log_success "测试通过: $test_func"
            ((tests_passed++))
        else
            log_error "测试失败: $test_func"
            ((tests_failed++))
            
            # 如果测试失败，可以选择继续或停止
            if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
                log_error "测试失败，停止执行"
                break
            fi
        fi
        
        echo ""
    done
    
    # 输出测试结果
    log_info "测试完成"
    log_info "通过: $tests_passed"
    log_info "失败: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log_success "所有测试通过！"
        return 0
    else
        log_error "有 $tests_failed 个测试失败"
        return 1
    fi
}

# 运行主函数
main "$@"