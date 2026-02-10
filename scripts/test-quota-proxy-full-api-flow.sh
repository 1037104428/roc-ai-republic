#!/bin/bash
# test-quota-proxy-full-api-flow.sh
# 完整的 quota-proxy API 流程集成测试脚本
# 测试从密钥创建到使用统计的完整端到端流程

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN=""
SCRIPT_VERSION="v2026.02.10.01"

# 帮助信息
show_help() {
    cat << EOF
quota-proxy 完整 API 流程集成测试脚本 ${SCRIPT_VERSION}

测试从密钥创建、API使用到统计查询的完整端到端流程。

用法:
  $0 [选项]

选项:
  -h, --host HOST         quota-proxy 主机地址 (默认: ${DEFAULT_HOST})
  -p, --port PORT         quota-proxy 端口 (默认: ${DEFAULT_PORT})
  -t, --token TOKEN       Admin 令牌 (必须)
  -d, --dry-run           模拟运行，不实际发送请求
  -v, --verbose           详细输出模式
  -q, --quiet             安静模式，只显示结果
  --help                  显示此帮助信息
  --version               显示版本信息

环境变量:
  QUOTA_PROXY_HOST        覆盖主机地址
  QUOTA_PROXY_PORT        覆盖端口
  ADMIN_TOKEN             覆盖 Admin 令牌

示例:
  $0 -t "your-admin-token" -v
  ADMIN_TOKEN="your-token" $0 --host 8.210.185.194 --port 8787

退出码:
  0 - 所有测试通过
  1 - 参数错误或配置问题
  2 - 网络连接失败
  3 - API 测试失败
  4 - 数据验证失败

EOF
}

# 日志函数
log_info() {
    if [[ "${VERBOSE:-0}" -eq 1 || "${QUIET:-0}" -eq 0 ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [[ "${QUIET:-0}" -eq 0 ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    if [[ "${QUIET:-0}" -eq 0 ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_test() {
    if [[ "${QUIET:-0}" -eq 0 ]]; then
        echo -e "${BLUE}[TEST]${NC} $*"
    fi
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
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
            -d|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                echo "test-quota-proxy-full-api-flow.sh ${SCRIPT_VERSION}"
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

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少依赖命令: ${missing_deps[*]}"
        log_info "请安装:"
        log_info "  Ubuntu/Debian: sudo apt-get install curl jq"
        log_info "  CentOS/RHEL: sudo yum install curl jq"
        exit 1
    fi
}

# 检查配置
check_config() {
    # 使用环境变量或默认值
    HOST="${HOST:-${QUOTA_PROXY_HOST:-${DEFAULT_HOST}}}"
    PORT="${PORT:-${QUOTA_PROXY_PORT:-${DEFAULT_PORT}}}"
    ADMIN_TOKEN="${ADMIN_TOKEN:-${ADMIN_TOKEN:-}}"
    
    if [[ -z "${ADMIN_TOKEN}" ]]; then
        log_error "必须提供 Admin 令牌 (使用 -t 参数或设置 ADMIN_TOKEN 环境变量)"
        exit 1
    fi
    
    BASE_URL="http://${HOST}:${PORT}"
    API_URL="${BASE_URL}/api"
    ADMIN_URL="${BASE_URL}/admin"
    
    log_info "配置检查:"
    log_info "  Host: ${HOST}"
    log_info "  Port: ${PORT}"
    log_info "  Base URL: ${BASE_URL}"
    log_info "  Admin URL: ${ADMIN_URL}"
    log_info "  API URL: ${API_URL}"
    log_info "  Token: ${ADMIN_TOKEN:0:8}..."
}

# 健康检查
health_check() {
    log_test "1. 健康检查"
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -fsS ${BASE_URL}/healthz"
        return 0
    fi
    
    if ! curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
        log_error "健康检查失败: ${BASE_URL}/healthz"
        exit 2
    fi
    
    log_success "健康检查通过"
}

# 测试 Admin API 状态
test_admin_status() {
    log_test "2. Admin API 状态检查"
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -H 'Authorization: Bearer ...' ${ADMIN_URL}/usage"
        return 0
    fi
    
    local response
    if ! response=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "%{http_code}" \
        "${ADMIN_URL}/usage" 2>/dev/null); then
        log_error "Admin API 请求失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Admin API 状态检查失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    log_success "Admin API 状态检查通过"
}

# 创建试用密钥
create_trial_key() {
    log_test "3. 创建试用密钥"
    
    local label="集成测试-$(date +%Y%m%d-%H%M%S)"
    local payload="{\"label\":\"${label}\"}"
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -X POST -H 'Authorization: Bearer ...' -d '${payload}' ${ADMIN_URL}/keys"
        TRIAL_KEY="simulated-trial-key-12345"
        return 0
    fi
    
    local response
    if ! response=$(curl -s -X POST \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        -w "%{http_code}" \
        "${ADMIN_URL}/keys" 2>/dev/null); then
        log_error "创建试用密钥失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "201" ]]; then
        log_error "创建试用密钥失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    # 提取试用密钥
    if ! TRIAL_KEY=$(echo "$body" | jq -r '.key'); then
        log_error "解析试用密钥失败"
        log_info "响应: ${body}"
        return 1
    fi
    
    if [[ -z "$TRIAL_KEY" || "$TRIAL_KEY" == "null" ]]; then
        log_error "未获取到试用密钥"
        return 1
    fi
    
    log_success "创建试用密钥成功: ${TRIAL_KEY:0:8}..."
}

# 使用 API 网关
use_api_gateway() {
    log_test "4. 使用 API 网关"
    
    if [[ -z "${TRIAL_KEY:-}" ]]; then
        log_error "没有试用密钥，跳过 API 网关测试"
        return 1
    fi
    
    # 测试 1: 基础请求
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -H 'X-API-Key: ...' ${API_URL}/test"
        return 0
    fi
    
    local response
    if ! response=$(curl -s \
        -H "X-API-Key: ${TRIAL_KEY}" \
        -w "%{http_code}" \
        "${API_URL}/test" 2>/dev/null); then
        log_error "API 网关请求失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "API 网关测试失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    # 测试 2: 带参数的请求
    if ! response=$(curl -s \
        -H "X-API-Key: ${TRIAL_KEY}" \
        -w "%{http_code}" \
        "${API_URL}/test?param=integration" 2>/dev/null); then
        log_error "API 网关带参请求失败"
        return 1
    fi
    
    http_code="${response: -3}"
    body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "API 网关带参测试失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    log_success "API 网关使用测试通过"
}

# 检查使用统计
check_usage_stats() {
    log_test "5. 检查使用统计"
    
    if [[ -z "${TRIAL_KEY:-}" ]]; then
        log_error "没有试用密钥，跳过使用统计检查"
        return 1
    fi
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -H 'Authorization: Bearer ...' ${ADMIN_URL}/usage?key=${TRIAL_KEY}"
        return 0
    fi
    
    # 等待一下，确保统计更新
    sleep 1
    
    local response
    if ! response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "%{http_code}" \
        "${ADMIN_URL}/usage?key=${TRIAL_KEY}" 2>/dev/null); then
        log_error "获取使用统计失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "获取使用统计失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    # 验证统计数据
    if ! echo "$body" | jq -e '.usage' > /dev/null 2>&1; then
        log_error "使用统计数据格式错误"
        log_info "响应: ${body}"
        return 1
    fi
    
    local usage_count
    usage_count=$(echo "$body" | jq -r '.usage')
    
    if [[ "$usage_count" -lt 2 ]]; then
        log_warning "使用统计可能未正确更新: ${usage_count} 次"
    else
        log_success "使用统计检查通过: ${usage_count} 次调用"
    fi
}

# 列出所有密钥
list_all_keys() {
    log_test "6. 列出所有密钥"
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -H 'Authorization: Bearer ...' ${ADMIN_URL}/keys"
        return 0
    fi
    
    local response
    if ! response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "%{http_code}" \
        "${ADMIN_URL}/keys" 2>/dev/null); then
        log_error "列出密钥失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "列出密钥失败: HTTP ${http_code}"
        log_info "响应: ${body}"
        return 1
    fi
    
    # 验证我们的测试密钥在列表中
    if ! echo "$body" | jq -e --arg key "$TRIAL_KEY" \
        '.keys[] | select(.key == $key)' > /dev/null 2>&1; then
        log_warning "测试密钥未在密钥列表中找到"
    else
        log_success "密钥列表检查通过"
    fi
}

# 清理测试数据
cleanup_test_data() {
    log_test "7. 清理测试数据"
    
    if [[ -z "${TRIAL_KEY:-}" ]]; then
        log_info "没有测试密钥需要清理"
        return 0
    fi
    
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        log_info "模拟: curl -X DELETE -H 'Authorization: Bearer ...' ${ADMIN_URL}/keys/${TRIAL_KEY}"
        return 0
    fi
    
    local response
    if ! response=$(curl -s -X DELETE \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -w "%{http_code}" \
        "${ADMIN_URL}/keys/${TRIAL_KEY}" 2>/dev/null); then
        log_error "删除测试密钥失败"
        return 1
    fi
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
        log_warning "删除测试密钥返回非预期状态: HTTP ${http_code}"
    else
        log_success "测试数据清理完成"
    fi
}

# 主函数
main() {
    log_info "开始 quota-proxy 完整 API 流程集成测试"
    log_info "脚本版本: ${SCRIPT_VERSION}"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # 解析参数
    parse_args "$@"
    
    # 检查依赖
    check_dependencies
    
    # 检查配置
    check_config
    
    # 执行测试
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # 测试序列
    local test_functions=(
        health_check
        test_admin_status
        create_trial_key
        use_api_gateway
        check_usage_stats
        list_all_keys
        cleanup_test_data
    )
    
    for test_func in "${test_functions[@]}"; do
        if $test_func; then
            ((tests_passed++))
        else
            ((tests_failed++))
            log_warning "测试失败: $test_func"
            
            # 如果关键测试失败，可以提前退出
            if [[ "$test_func" == "health_check" || "$test_func" == "test_admin_status" ]]; then
                log_error "关键测试失败，停止后续测试"
                break
            fi
        fi
    done
    
    # 汇总结果
    log_info ""
    log_info "测试完成汇总:"
    log_info "  通过: ${tests_passed}"
    log_info "  失败: ${tests_failed}"
    log_info "  跳过: ${tests_skipped}"
    log_info "  总计: ${#test_functions[@]}"
    
    if [[ $tests_failed -eq 0 ]]; then
        log_success "所有测试通过！完整 API 流程验证成功。"
        log_info "结束时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        exit 0
    else
        log_error "部分测试失败。"
        log_info "结束时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        exit 3
    fi
}

# 运行主函数
main "$@"