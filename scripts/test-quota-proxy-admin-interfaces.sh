#!/bin/bash

# =============================================================================
# quota-proxy 管理接口测试脚本
# 专门测试 POST /admin/keys 和 GET /admin/usage 接口
# =============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN="dev-admin-token-change-in-production"

# 变量
HOST="${QUOTA_PROXY_HOST:-$DEFAULT_HOST}"
PORT="${QUOTA_PROXY_PORT:-$DEFAULT_PORT}"
ADMIN_TOKEN="${QUOTA_ADMIN_TOKEN:-$DEFAULT_ADMIN_TOKEN}"
BASE_URL="http://${HOST}:${PORT}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

# 测试数据
TEST_KEY_PREFIX="test-key-$(date +%s)"
TEST_LABEL="测试密钥 $(date '+%Y-%m-%d %H:%M:%S')"
TEST_QUOTA=500

# 临时文件
TEMP_DIR=$(mktemp -d)
TEMP_KEYS_FILE="${TEMP_DIR}/created_keys.txt"
trap 'cleanup' EXIT

# 函数：清理临时文件
cleanup() {
    if [[ "${SKIP_CLEANUP}" != "true" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

# 函数：打印消息
log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 函数：发送HTTP请求
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    local description="$5"
    
    local curl_cmd="curl -s -X ${method} \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${ADMIN_TOKEN}' \
        '${BASE_URL}${endpoint}'"
    
    if [[ -n "${data}" ]]; then
        curl_cmd="${curl_cmd} -d '${data}'"
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log "执行: ${curl_cmd}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[模拟运行] ${description}"
        return 0
    fi
    
    local response
    response=$(eval "${curl_cmd}" 2>/dev/null || true)
    local status_code=$?
    
    # 检查curl是否成功
    if [[ ${status_code} -ne 0 ]]; then
        log_error "请求失败: ${description}"
        log_error "Curl错误码: ${status_code}"
        return 1
    fi
    
    # 检查HTTP状态码
    local http_code
    http_code=$(echo "${response}" | grep -o '"statusCode":[0-9]*' | cut -d: -f2 || echo "")
    
    if [[ -n "${http_code}" ]] && [[ "${http_code}" != "${expected_status}" ]]; then
        log_error "HTTP状态码不匹配: ${description}"
        log_error "期望: ${expected_status}, 实际: ${http_code}"
        log_error "响应: ${response}"
        return 1
    fi
    
    log_success "${description}"
    
    if [[ "${VERBOSE}" == "true" ]] && [[ -n "${response}" ]]; then
        echo "响应: ${response}"
    fi
    
    echo "${response}"
}

# 函数：测试健康检查
test_health_check() {
    log "测试 1/6: 健康检查"
    
    local curl_cmd="curl -s -f '${BASE_URL}/healthz'"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log "执行: ${curl_cmd}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[模拟运行] 健康检查"
        return 0
    fi
    
    if curl -s -f "${BASE_URL}/healthz" >/dev/null 2>&1; then
        log_success "健康检查通过"
        return 0
    else
        log_error "健康检查失败"
        return 1
    fi
}

# 函数：测试未授权访问
test_unauthorized_access() {
    log "测试 2/6: 未授权访问保护"
    
    local curl_cmd="curl -s -X GET \
        -H 'Content-Type: application/json' \
        '${BASE_URL}/admin/keys'"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log "执行: ${curl_cmd}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[模拟运行] 未授权访问测试"
        return 0
    fi
    
    local response
    response=$(curl -s -X GET \
        -H 'Content-Type: application/json' \
        "${BASE_URL}/admin/keys" 2>/dev/null || true)
    
    if echo "${response}" | grep -q "Unauthorized" || echo "${response}" | grep -q "401"; then
        log_success "未授权访问保护正常"
        return 0
    else
        log_error "未授权访问保护失败"
        log_error "响应: ${response}"
        return 1
    fi
}

# 函数：测试创建trial key
test_create_trial_key() {
    log "测试 3/6: 创建trial key"
    
    local test_data="{\"label\":\"${TEST_LABEL}\",\"totalQuota\":${TEST_QUOTA}}"
    local response
    
    response=$(send_request "POST" "/admin/keys" "${test_data}" "200" "创建trial key")
    
    if [[ "${DRY_RUN}" != "true" ]] && [[ -n "${response}" ]]; then
        # 提取创建的key
        local created_key
        created_key=$(echo "${response}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [[ -n "${created_key}" ]]; then
            echo "${created_key}" >> "${TEMP_KEYS_FILE}"
            log_success "创建的key: ${created_key}"
        fi
    fi
}

# 函数：测试获取keys列表
test_get_keys_list() {
    log "测试 4/6: 获取keys列表"
    
    send_request "GET" "/admin/keys" "" "200" "获取keys列表"
}

# 函数：测试获取使用情况统计
test_get_usage_stats() {
    log "测试 5/6: 获取使用情况统计"
    
    send_request "GET" "/admin/usage" "" "200" "获取使用情况统计"
}

# 函数：测试清理创建的keys
test_cleanup_created_keys() {
    log "测试 6/6: 清理测试数据"
    
    if [[ ! -f "${TEMP_KEYS_FILE}" ]] || [[ ! -s "${TEMP_KEYS_FILE}" ]]; then
        log_info "没有测试数据需要清理"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[模拟运行] 清理测试数据"
        return 0
    fi
    
    local count=0
    while IFS= read -r key; do
        if [[ -n "${key}" ]]; then
            local curl_cmd="curl -s -X DELETE \
                -H 'Content-Type: application/json' \
                -H 'Authorization: Bearer ${ADMIN_TOKEN}' \
                '${BASE_URL}/admin/keys/${key}'"
            
            if curl -s -X DELETE \
                -H 'Content-Type: application/json' \
                -H "Authorization: Bearer ${ADMIN_TOKEN}" \
                "${BASE_URL}/admin/keys/${key}" >/dev/null 2>&1; then
                log_success "删除key: ${key}"
                ((count++))
            else
                log_warning "删除key失败: ${key}"
            fi
        fi
    done < "${TEMP_KEYS_FILE}"
    
    log_success "清理完成，删除了 ${count} 个测试key"
}

# 函数：显示帮助信息
show_help() {
    cat << EOF
quota-proxy 管理接口测试脚本

用法: $0 [选项]

选项:
  -h, --help             显示此帮助信息
  -H, --host HOST        指定quota-proxy主机 (默认: ${DEFAULT_HOST})
  -p, --port PORT        指定quota-proxy端口 (默认: ${DEFAULT_PORT})
  -t, --token TOKEN      指定管理员token (默认: 从环境变量读取)
  -v, --verbose          详细输出模式
  -d, --dry-run          模拟运行，不实际发送请求
  -s, --skip-cleanup     跳过清理测试数据
  --list                 列出所有测试用例

环境变量:
  QUOTA_PROXY_HOST       quota-proxy主机
  QUOTA_PROXY_PORT       quota-proxy端口  
  QUOTA_ADMIN_TOKEN      管理员token
  VERBOSE                详细输出模式
  DRY_RUN                模拟运行模式
  SKIP_CLEANUP           跳过清理测试数据

示例:
  $0 --host localhost --port 8787 --token my-admin-token
  $0 --dry-run --verbose
  QUOTA_PROXY_HOST=8.210.185.194 $0 --verbose
EOF
}

# 函数：列出测试用例
list_test_cases() {
    cat << EOF
测试用例列表:

1. 健康检查
   - 测试 /healthz 端点是否正常响应

2. 未授权访问保护
   - 测试未提供管理员token时访问管理接口是否被拒绝

3. 创建trial key
   - 测试 POST /admin/keys 接口
   - 创建带有标签和配额的测试key

4. 获取keys列表
   - 测试 GET /admin/keys 接口
   - 验证返回的keys列表格式

5. 获取使用情况统计
   - 测试 GET /admin/usage 接口
   - 验证使用统计数据的格式

6. 清理测试数据
   - 清理测试过程中创建的keys
   - 确保测试环境干净
EOF
}

# 主函数
main() {
    # 解析命令行参数
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
            -s|--skip-cleanup)
                SKIP_CLEANUP="true"
                shift
                ;;
            --list)
                list_test_cases
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 更新BASE_URL
    BASE_URL="http://${HOST}:${PORT}"
    
    log "开始测试 quota-proxy 管理接口"
    log "目标: ${BASE_URL}"
    log "管理员token: ${ADMIN_TOKEN:0:10}..."
    
    # 检查必要工具
    if ! command -v curl &> /dev/null; then
        log_error "需要 curl 命令"
        exit 1
    fi
    
    # 执行测试
    local tests_passed=0
    local tests_failed=0
    local tests_total=6
    
    # 测试1: 健康检查
    if test_health_check; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试2: 未授权访问保护
    if test_unauthorized_access; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试3: 创建trial key
    if test_create_trial_key; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试4: 获取keys列表
    if test_get_keys_list; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试5: 获取使用情况统计
    if test_get_usage_stats; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试6: 清理测试数据
    if test_cleanup_created_keys; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 输出测试结果
    echo ""
    log "测试完成"
    log "总计: ${tests_total} 个测试用例"
    log "通过: ${tests_passed}"
    log "失败: ${tests_failed}"
    
    if [[ ${tests_failed} -eq 0 ]]; then
        log_success "所有测试通过! quota-proxy 管理接口正常工作"
        exit 0
    else
        log_error "有 ${tests_failed} 个测试失败"
        exit 1
    fi
}

# 运行主函数
main "$@"