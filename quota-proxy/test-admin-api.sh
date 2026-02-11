#!/bin/bash

# Admin API自动化测试套件
# 支持完整的API功能测试和集成测试

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
BASE_URL="${BASE_URL:-http://localhost:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-admin-secret-token-change-in-production}"
TEST_TIMEOUT="${TEST_TIMEOUT:-10}"
VERBOSE="${VERBOSE:-false}"

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# HTTP请求函数
http_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local headers="$4"
    
    local curl_cmd="curl -s -X $method"
    
    # 添加认证头
    if [[ "$endpoint" == /admin/* ]]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $ADMIN_TOKEN'"
    fi
    
    # 添加自定义头
    if [[ -n "$headers" ]]; then
        curl_cmd="$curl_cmd $headers"
    fi
    
    # 添加数据
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    # 添加超时
    curl_cmd="$curl_cmd --max-time $TEST_TIMEOUT"
    
    # 执行请求
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "请求: $method $BASE_URL$endpoint"
        if [[ -n "$data" ]]; then
            log_info "数据: $data"
        fi
    fi
    
    eval "$curl_cmd $BASE_URL$endpoint"
}

# 验证响应
validate_response() {
    local response="$1"
    local expected_status="$2"
    local expected_field="$3"
    local expected_value="$4"
    
    # 提取状态码
    local status_code=$(echo "$response" | grep -o '"statusCode":[0-9]*' | cut -d: -f2)
    if [[ -z "$status_code" ]]; then
        status_code=$(echo "$response" | grep -o '"status":[0-9]*' | cut -d: -f2)
    fi
    
    # 验证状态码
    if [[ "$status_code" != "$expected_status" ]]; then
        log_error "状态码不匹配: 期望 $expected_status, 实际 $status_code"
        echo "响应: $response"
        return 1
    fi
    
    # 验证字段
    if [[ -n "$expected_field" && -n "$expected_value" ]]; then
        local actual_value=$(echo "$response" | grep -o "\"$expected_field\":\"[^\"]*\"" | cut -d: -f2 | tr -d '\"')
        if [[ -z "$actual_value" ]]; then
            actual_value=$(echo "$response" | grep -o "\"$expected_field\":[^,}]*" | cut -d: -f2 | tr -d ' ')
        fi
        
        if [[ "$actual_value" != "$expected_value" ]]; then
            log_error "字段 '$expected_field' 不匹配: 期望 '$expected_value', 实际 '$actual_value'"
            echo "响应: $response"
            return 1
        fi
    fi
    
    return 0
}

# 测试用例
test_health_check() {
    log_test "测试健康检查端点"
    local response=$(http_request "GET" "/healthz")
    
    if validate_response "$response" "200" "status" "ok"; then
        log_success "健康检查测试通过"
        ((TESTS_PASSED++))
    else
        log_error "健康检查测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

test_admin_auth() {
    log_test "测试Admin API认证"
    
    # 测试无效令牌
    local response=$(curl -s -X GET -H "Authorization: Bearer invalid-token" --max-time $TEST_TIMEOUT "$BASE_URL/admin/keys")
    if validate_response "$response" "401" "error" "Unauthorized"; then
        log_success "无效令牌认证测试通过"
        ((TESTS_PASSED++))
    else
        log_error "无效令牌认证测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # 测试有效令牌
    local response=$(http_request "GET" "/admin/keys")
    if validate_response "$response" "200"; then
        log_success "有效令牌认证测试通过"
        ((TESTS_PASSED++))
    else
        log_error "有效令牌认证测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

test_admin_keys() {
    log_test "测试Admin Keys管理"
    
    # 获取当前keys
    local response=$(http_request "GET" "/admin/keys")
    if validate_response "$response" "200"; then
        log_success "获取keys列表测试通过"
        ((TESTS_PASSED++))
    else
        log_error "获取keys列表测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # 创建新key
    local key_data='{"name":"test-key-'$(date +%s)'", "quota":1000, "expiresAt":"2026-12-31T23:59:59Z"}'
    local response=$(http_request "POST" "/admin/keys" "$key_data")
    if validate_response "$response" "201" "key"; then
        # 提取创建的key
        local created_key=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d: -f2 | tr -d '\"')
        log_success "创建key测试通过: $created_key"
        ((TESTS_PASSED++))
        
        # 测试获取特定key
        local response=$(http_request "GET" "/admin/keys/$created_key")
        if validate_response "$response" "200" "key" "$created_key"; then
            log_success "获取特定key测试通过"
            ((TESTS_PASSED++))
        else
            log_error "获取特定key测试失败"
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
        
        # 测试更新key
        local update_data='{"quota":2000, "enabled":false}'
        local response=$(http_request "PUT" "/admin/keys/$created_key" "$update_data")
        if validate_response "$response" "200" "quota" "2000"; then
            log_success "更新key测试通过"
            ((TESTS_PASSED++))
        else
            log_error "更新key测试失败"
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
        
        # 测试删除key
        local response=$(http_request "DELETE" "/admin/keys/$created_key")
        if validate_response "$response" "200" "message" "Key deleted"; then
            log_success "删除key测试通过"
            ((TESTS_PASSED++))
        else
            log_error "删除key测试失败"
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
    else
        log_error "创建key测试失败"
        ((TESTS_FAILED++))
        ((TESTS_TOTAL++))
    fi
}

test_admin_usage() {
    log_test "测试Admin Usage统计"
    
    local response=$(http_request "GET" "/admin/usage")
    if validate_response "$response" "200"; then
        log_success "获取usage统计测试通过"
        ((TESTS_PASSED++))
    else
        log_error "获取usage统计测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # 测试日期范围查询
    local today=$(date +%Y-%m-%d)
    local response=$(http_request "GET" "/admin/usage?startDate=2026-01-01&endDate=$today")
    if validate_response "$response" "200"; then
        log_success "日期范围查询测试通过"
        ((TESTS_PASSED++))
    else
        log_error "日期范围查询测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

test_error_handling() {
    log_test "测试错误处理"
    
    # 测试无效端点
    local response=$(http_request "GET" "/admin/invalid-endpoint")
    if validate_response "$response" "404"; then
        log_success "无效端点测试通过"
        ((TESTS_PASSED++))
    else
        log_error "无效端点测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # 测试无效JSON
    local response=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{invalid json}' --max-time $TEST_TIMEOUT "$BASE_URL/admin/keys")
    if validate_response "$response" "400"; then
        log_success "无效JSON测试通过"
        ((TESTS_PASSED++))
    else
        log_error "无效JSON测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # 测试缺失必填字段
    local response=$(http_request "POST" "/admin/keys" '{"name":"test"}')
    if validate_response "$response" "400"; then
        log_success "缺失必填字段测试通过"
        ((TESTS_PASSED++))
    else
        log_error "缺失必填字段测试失败"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
}

# 清理测试环境
cleanup() {
    log_info "清理测试环境..."
    # 这里可以添加清理逻辑，比如删除测试创建的keys
    log_success "清理完成"
}

# 主测试函数
run_tests() {
    log_info "开始Admin API自动化测试"
    log_info "基础URL: $BASE_URL"
    log_info "测试超时: ${TEST_TIMEOUT}秒"
    log_info "详细模式: $VERBOSE"
    echo ""
    
    # 运行测试用例
    test_health_check
    test_admin_auth
    test_admin_keys
    test_admin_usage
    test_error_handling
    
    # 显示测试结果
    echo ""
    log_info "测试结果汇总:"
    log_info "总测试数: $TESTS_TOTAL"
    log_success "通过: $TESTS_PASSED"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "失败: $TESTS_FAILED"
    else
        log_success "失败: $TESTS_FAILED"
    fi
    
    # 计算通过率
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        log_info "通过率: ${pass_rate}%"
    fi
    
    # 返回退出码
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "测试失败"
        return 1
    else
        log_success "所有测试通过"
        return 0
    fi
}

# 帮助信息
show_help() {
    echo "Admin API自动化测试套件"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -v, --verbose       启用详细输出"
    echo "  -u, --url URL       设置基础URL (默认: http://localhost:8787)"
    echo "  -t, --token TOKEN   设置Admin令牌 (默认: admin-secret-token-change-in-production)"
    echo "  --timeout SECONDS   设置请求超时 (默认: 10)"
    echo ""
    echo "环境变量:"
    echo "  BASE_URL            基础URL"
    echo "  ADMIN_TOKEN         Admin令牌"
    echo "  TEST_TIMEOUT        请求超时"
    echo "  VERBOSE            详细模式 (true/false)"
    echo ""
    echo "示例:"
    echo "  $0"
    echo "  $0 --url http://api.example.com --token my-secret-token"
    echo "  VERBOSE=true BASE_URL=http://localhost:8787 $0"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置陷阱，确保脚本退出时清理
trap cleanup EXIT

# 运行测试
run_tests
exit $?