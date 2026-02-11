#!/bin/bash

# 验证 Admin Keys API 端点脚本
# 用于验证 /admin/keys 和 /admin/keys/trial 端点是否正常工作

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

log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
验证 Admin Keys API 端点脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -d, --dry-run        干运行模式，只显示将要执行的步骤，不实际执行
  -v, --verbose        详细输出模式
  --host HOST          服务器主机地址 (默认: 127.0.0.1)
  --port PORT          服务器端口 (默认: 8787)
  --token TOKEN        管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 读取)
  --timeout TIMEOUT    请求超时时间(秒) (默认: 10)
  --skip-health        跳过健康检查
  --skip-trial        跳过试用密钥测试
  --skip-admin        跳过管理员密钥测试

环境变量:
  ADMIN_TOKEN          管理员令牌 (如果未通过 --token 指定)

示例:
  $0 --dry-run
  $0 --host 192.168.1.100 --port 8080 --token my-secret-token
  ADMIN_TOKEN=my-secret-token $0 --verbose

EOF
}

# 默认配置
DRY_RUN=false
VERBOSE=false
HOST="127.0.0.1"
PORT="8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-dev-admin-token-change-in-production}"
TIMEOUT=10
SKIP_HEALTH=false
SKIP_TRIAL=false
SKIP_ADMIN=false
DEBUG=false

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
        -v|--verbose)
            VERBOSE=true
            DEBUG=true
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
        --token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --skip-health)
            SKIP_HEALTH=true
            shift
            ;;
        --skip-trial)
            SKIP_TRIAL=true
            shift
            ;;
        --skip-admin)
            SKIP_ADMIN=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 基础URL
BASE_URL="http://${HOST}:${PORT}"

# 检查curl是否可用
check_curl() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 命令未找到，请先安装 curl"
        exit 1
    fi
    log_debug "curl 命令可用"
}

# 检查服务器是否运行
check_server() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：跳过服务器检查"
        return 0
    fi
    
    log_info "检查服务器是否运行在 ${BASE_URL}"
    
    if curl -s --max-time "${TIMEOUT}" "${BASE_URL}/healthz" > /dev/null 2>&1; then
        log_success "服务器正在运行"
        return 0
    else
        log_error "服务器未运行或无法访问"
        return 1
    fi
}

# 健康检查
health_check() {
    if [[ "${SKIP_HEALTH}" == "true" ]]; then
        log_info "跳过健康检查"
        return 0
    fi
    
    log_info "执行健康检查"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl -s --max-time ${TIMEOUT} ${BASE_URL}/healthz"
        log_info "期望响应：包含 'ok': true 的 JSON"
        return 0
    fi
    
    local response
    response=$(curl -s --max-time "${TIMEOUT}" "${BASE_URL}/healthz")
    
    if [[ $? -ne 0 ]]; then
        log_error "健康检查请求失败"
        return 1
    fi
    
    if echo "${response}" | grep -q '"ok":true'; then
        log_success "健康检查通过"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
        fi
        return 0
    else
        log_error "健康检查失败"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}"
        fi
        return 1
    fi
}

# 测试试用密钥生成端点
test_trial_key_endpoint() {
    if [[ "${SKIP_TRIAL}" == "true" ]]; then
        log_info "跳过试用密钥端点测试"
        return 0
    fi
    
    log_info "测试试用密钥生成端点: POST ${BASE_URL}/admin/keys/trial"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl -X POST -H 'Content-Type: application/json' --max-time ${TIMEOUT} ${BASE_URL}/admin/keys/trial"
        log_info "期望响应：包含 'success': true 和 'key' 字段的 JSON"
        return 0
    fi
    
    local response
    response=$(curl -X POST \
        -H "Content-Type: application/json" \
        --max-time "${TIMEOUT}" \
        "${BASE_URL}/admin/keys/trial" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "试用密钥生成请求失败"
        return 1
    fi
    
    if echo "${response}" | grep -q '"success":true'; then
        log_success "试用密钥生成端点测试通过"
        
        # 提取生成的密钥
        local trial_key
        trial_key=$(echo "${response}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -n "${trial_key}" ]]; then
            log_info "生成的试用密钥: ${trial_key}"
            
            # 验证密钥格式
            if [[ "${trial_key}" =~ ^roc_trial_[0-9]+-[a-z0-9]{9}$ ]]; then
                log_success "试用密钥格式正确"
            else
                log_warning "试用密钥格式可能不正确: ${trial_key}"
            fi
        fi
        
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
        fi
        return 0
    else
        log_error "试用密钥生成端点测试失败"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}"
        fi
        return 1
    fi
}

# 测试管理员密钥生成端点
test_admin_key_endpoint() {
    if [[ "${SKIP_ADMIN}" == "true" ]]; then
        log_info "跳过管理员密钥端点测试"
        return 0
    fi
    
    log_info "测试管理员密钥生成端点: POST ${BASE_URL}/admin/keys"
    
    # 准备测试数据
    local test_data='{
        "label": "测试密钥 - 验证脚本生成",
        "totalQuota": 500,
        "expiresAt": "2026-12-31T23:59:59Z"
    }'
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer ${ADMIN_TOKEN}' --max-time ${TIMEOUT} ${BASE_URL}/admin/keys -d '${test_data}'"
        log_info "期望响应：包含 'success': true 和 'key' 字段的 JSON"
        return 0
    fi
    
    local response
    response=$(curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        --max-time "${TIMEOUT}" \
        -d "${test_data}" \
        "${BASE_URL}/admin/keys" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "管理员密钥生成请求失败"
        return 1
    fi
    
    if echo "${response}" | grep -q '"success":true'; then
        log_success "管理员密钥生成端点测试通过"
        
        # 提取生成的密钥
        local admin_key
        admin_key=$(echo "${response}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -n "${admin_key}" ]]; then
            log_info "生成的管理员密钥: ${admin_key}"
            
            # 验证密钥格式
            if [[ "${admin_key}" =~ ^roc_[0-9]+-[a-z0-9]{9}$ ]]; then
                log_success "管理员密钥格式正确"
            else
                log_warning "管理员密钥格式可能不正确: ${admin_key}"
            fi
        fi
        
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
        fi
        return 0
    else
        log_error "管理员密钥生成端点测试失败"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}"
        fi
        
        # 检查是否是认证失败
        if echo "${response}" | grep -q 'Invalid admin token'; then
            log_error "管理员令牌无效，请检查 ADMIN_TOKEN 配置"
            log_info "当前使用的令牌: ${ADMIN_TOKEN}"
        fi
        return 1
    fi
}

# 测试管理员密钥列表端点
test_admin_keys_list_endpoint() {
    log_info "测试管理员密钥列表端点: GET ${BASE_URL}/admin/keys"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl -H 'Authorization: Bearer ${ADMIN_TOKEN}' --max-time ${TIMEOUT} ${BASE_URL}/admin/keys"
        log_info "期望响应：包含 'success': true 和 'keys' 数组的 JSON"
        return 0
    fi
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        --max-time "${TIMEOUT}" \
        "${BASE_URL}/admin/keys" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "管理员密钥列表请求失败"
        return 1
    fi
    
    if echo "${response}" | grep -q '"success":true'; then
        log_success "管理员密钥列表端点测试通过"
        
        # 提取密钥数量
        local key_count
        key_count=$(echo "${response}" | grep -o '"keys":\[.*\]' | grep -o '{"' | wc -l || echo "0")
        
        if [[ "${key_count}" -gt 0 ]]; then
            log_info "找到 ${key_count} 个密钥"
        else
            log_warning "密钥列表为空"
        fi
        
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
        fi
        return 0
    else
        log_error "管理员密钥列表端点测试失败"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}"
        fi
        return 1
    fi
}

# 测试管理员使用情况端点
test_admin_usage_endpoint() {
    log_info "测试管理员使用情况端点: GET ${BASE_URL}/admin/usage"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl -H 'Authorization: Bearer ${ADMIN_TOKEN}' --max-time ${TIMEOUT} ${BASE_URL}/admin/usage"
        log_info "期望响应：包含 'success': true 和 'data' 数组的 JSON"
        return 0
    fi
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        --max-time "${TIMEOUT}" \
        "${BASE_URL}/admin/usage" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "管理员使用情况请求失败"
        return 1
    fi
    
    if echo "${response}" | grep -q '"success":true'; then
        log_success "管理员使用情况端点测试通过"
        
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}" | python3 -m json.tool 2>/dev/null || echo "${response}"
        fi
        return 0
    else
        log_error "管理员使用情况端点测试失败"
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${response}"
        fi
        return 1
    fi
}

# 主验证函数
main_verification() {
    log_info "开始验证 Admin Keys API 端点"
    log_info "服务器: ${BASE_URL}"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:10}..."
    log_info "超时设置: ${TIMEOUT}秒"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "=== 干运行模式 ==="
    fi
    
    # 检查依赖
    check_curl
    
    # 检查服务器
    if ! check_server; then
        log_error "服务器检查失败，终止验证"
        return 1
    fi
    
    # 执行各项测试
    local tests_passed=0
    local tests_failed=0
    local tests_skipped=0
    
    # 健康检查
    if health_check; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 试用密钥端点测试
    if test_trial_key_endpoint; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 管理员密钥端点测试
    if test_admin_key_endpoint; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 管理员密钥列表端点测试
    if test_admin_keys_list_endpoint; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 管理员使用情况端点测试
    if test_admin_usage_endpoint; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 输出总结
    log_info "=== 验证总结 ==="
    log_info "测试通过: ${tests_passed}"
    log_info "测试失败: ${tests_failed}"
    log_info "测试跳过: ${tests_skipped}"
    
    if [[ ${tests_failed} -eq 0 ]]; then
        log_success "所有测试通过！Admin Keys API 端点验证成功"
        return 0
    else
        log_error "部分测试失败，请检查服务器配置和日志"
        return 1
    fi
}

# 执行主函数
main_verification

# 保存退出状态
exit_status=$?

# 根据退出状态输出最终结果
if [[ ${exit_status} -eq 0 ]]; then
    log_success "✅ Admin Keys API 端点验证完成，所有端点正常工作"
else
    log_error "❌ Admin Keys API 端点验证失败，请检查问题"
fi

exit ${exit_status}