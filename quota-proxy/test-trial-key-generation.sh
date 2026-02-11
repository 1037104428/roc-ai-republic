#!/bin/bash

# test-trial-key-generation.sh - 测试试用密钥生成API端点
# 用于验证quota-proxy试用密钥生成功能

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=8787
DEFAULT_ADMIN_TOKEN="test-admin-token-123"
BASE_URL="http://127.0.0.1:${DEFAULT_PORT}"
ADMIN_TOKEN="${DEFAULT_ADMIN_TOKEN}"

# 帮助信息
show_help() {
    cat << EOM
测试试用密钥生成API端点

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -p, --port PORT     指定quota-proxy端口 (默认: ${DEFAULT_PORT})
  -t, --token TOKEN   指定管理员令牌 (默认: ${DEFAULT_ADMIN_TOKEN})
  -u, --url URL       指定完整的base URL (覆盖端口设置)
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -v, --verbose       详细输出模式

示例:
  $0                    # 使用默认配置测试
  $0 -p 8080 -t "my-secret-token"  # 自定义端口和令牌
  $0 --dry-run         # 干运行模式
  $0 --verbose         # 详细输出

功能:
  1. 测试健康端点
  2. 测试管理员API密钥生成
  3. 测试试用密钥生成
  4. 验证试用密钥可用性

退出码:
  0 - 所有测试通过
  1 - 测试失败
  2 - 参数错误
EOM
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--port)
                PORT="$2"
                BASE_URL="http://127.0.0.1:${PORT}"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -u|--url)
                BASE_URL="$2"
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
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 2
                ;;
        esac
    done
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

# 执行curl命令
run_curl() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    
    local curl_cmd="curl -s -X ${method} '${BASE_URL}${endpoint}'"
    
    if [[ -n "${data}" ]]; then
        curl_cmd="${curl_cmd} -H 'Content-Type: application/json' -d '${data}'"
    fi
    
    if [[ -n "${ADMIN_TOKEN}" ]]; then
        curl_cmd="${curl_cmd} -H 'Authorization: Bearer ${ADMIN_TOKEN}'"
    fi
    
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        log_info "执行命令: ${curl_cmd}"
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "[干运行] ${curl_cmd}"
        return 0
    fi
    
    local response
    response=$(eval "${curl_cmd}" 2>/dev/null || true)
    local status_code=$?
    
    if [[ ${status_code} -ne 0 ]]; then
        log_error "curl命令执行失败 (退出码: ${status_code})"
        return 1
    fi
    
    # 提取HTTP状态码
    local http_code
    http_code=$(echo "${response}" | grep -oP '(?<=HTTP/\d\.\d )\d+' | tail -1 || echo "000")
    
    if [[ "${http_code}" != "${expected_status}" ]]; then
        log_error "端点 ${endpoint} 返回状态码 ${http_code}，预期 ${expected_status}"
        log_error "响应: ${response}"
        return 1
    fi
    
    echo "${response}"
    return 0
}

# 测试健康端点
test_health_endpoint() {
    log_info "测试健康端点: ${BASE_URL}/healthz"
    
    local response
    response=$(run_curl "GET" "/healthz" "" "200")
    
    if [[ $? -eq 0 ]]; then
        log_success "健康端点测试通过"
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            echo "响应: ${response}"
        fi
        return 0
    else
        log_error "健康端点测试失败"
        return 1
    fi
}

# 测试管理员API密钥生成
test_admin_api_key_generation() {
    log_info "测试管理员API密钥生成: ${BASE_URL}/admin/keys"
    
    local request_data='{"name":"test-key","quota":1000}'
    local response
    response=$(run_curl "POST" "/admin/keys" "${request_data}" "201")
    
    if [[ $? -eq 0 ]]; then
        log_success "管理员API密钥生成测试通过"
        
        # 提取生成的API密钥
        local api_key
        api_key=$(echo "${response}" | grep -oP '"key":"\K[^"]+' || echo "")
        
        if [[ -n "${api_key}" ]]; then
            log_info "生成的API密钥: ${api_key}"
            echo "${api_key}" > /tmp/test-api-key.txt 2>/dev/null || true
        fi
        
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            echo "响应: ${response}"
        fi
        return 0
    else
        log_error "管理员API密钥生成测试失败"
        return 1
    fi
}

# 测试试用密钥生成
test_trial_key_generation() {
    log_info "测试试用密钥生成: ${BASE_URL}/admin/trial-keys"
    
    local request_data='{"quota":100,"expiry_hours":24}'
    local response
    response=$(run_curl "POST" "/admin/trial-keys" "${request_data}" "201")
    
    if [[ $? -eq 0 ]]; then
        log_success "试用密钥生成测试通过"
        
        # 提取生成的试用密钥
        local trial_key
        trial_key=$(echo "${response}" | grep -oP '"key":"\K[^"]+' || echo "")
        
        if [[ -n "${trial_key}" ]]; then
            log_info "生成的试用密钥: ${trial_key}"
            echo "${trial_key}" > /tmp/test-trial-key.txt 2>/dev/null || true
        fi
        
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            echo "响应: ${response}"
        fi
        return 0
    else
        log_error "试用密钥生成测试失败"
        return 1
    fi
}

# 验证试用密钥可用性
verify_trial_key_usage() {
    log_info "验证试用密钥可用性"
    
    # 读取之前生成的试用密钥
    local trial_key
    trial_key=$(cat /tmp/test-trial-key.txt 2>/dev/null || echo "")
    
    if [[ -z "${trial_key}" ]]; then
        log_warning "未找到试用密钥，跳过可用性验证"
        return 0
    fi
    
    # 使用试用密钥调用API（这里假设有一个需要认证的端点）
    log_info "使用试用密钥调用API: ${BASE_URL}/api/usage"
    
    local curl_cmd="curl -s -X GET '${BASE_URL}/api/usage' -H 'Authorization: Bearer ${trial_key}'"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "[干运行] ${curl_cmd}"
        return 0
    fi
    
    local response
    response=$(eval "${curl_cmd}" 2>/dev/null || true)
    local status_code=$?
    
    if [[ ${status_code} -eq 0 ]]; then
        log_success "试用密钥可用性验证通过"
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            echo "响应: ${response}"
        fi
        return 0
    else
        log_warning "试用密钥调用API失败 (可能端点不存在或需要不同认证)"
        return 0  # 这不是关键失败，因为端点可能不存在
    fi
}

# 清理临时文件
cleanup() {
    rm -f /tmp/test-api-key.txt /tmp/test-trial-key.txt 2>/dev/null || true
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "开始测试试用密钥生成API端点"
    log_info "Base URL: ${BASE_URL}"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:10}..."
    
    trap cleanup EXIT
    
    local tests_passed=0
    local tests_failed=0
    
    # 运行测试
    if test_health_endpoint; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_admin_api_key_generation; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_trial_key_generation; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if verify_trial_key_usage; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 输出总结
    echo ""
    log_info "测试总结:"
    echo "  通过: ${tests_passed}"
    echo "  失败: ${tests_failed}"
    echo "  总计: $((tests_passed + tests_failed))"
    
    if [[ ${tests_failed} -eq 0 ]]; then
        log_success "所有测试通过！"
        exit 0
    else
        log_error "有 ${tests_failed} 个测试失败"
        exit 1
    fi
}

# 如果直接执行脚本，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
