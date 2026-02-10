#!/bin/bash

# =============================================================================
# quota-proxy 管理接口远程测试脚本
# 通过SSH在服务器上测试 POST /admin/keys 和 GET /admin/usage 接口
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
DEFAULT_SERVER="8.210.185.194"
DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
DEFAULT_QUOTA_PROXY_DIR="/opt/roc/quota-proxy"

# 变量
SERVER="${QUOTA_PROXY_SERVER:-$DEFAULT_SERVER}"
SSH_KEY="${SSH_KEY_PATH:-$DEFAULT_SSH_KEY}"
QUOTA_PROXY_DIR="${QUOTA_PROXY_DIR:-$DEFAULT_QUOTA_PROXY_DIR}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# 测试数据
TEST_LABEL="远程测试-$(date '+%Y%m%d-%H%M%S')"
TEST_QUOTA=250

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

# 函数：执行SSH命令
ssh_cmd() {
    local cmd="$1"
    local description="$2"
    
    local ssh_command="ssh -i \"${SSH_KEY}\" -o BatchMode=yes -o ConnectTimeout=8 root@${SERVER} \"${cmd}\""
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log "执行SSH: ${ssh_command}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[模拟运行] ${description}"
        echo "模拟响应"
        return 0
    fi
    
    local response
    response=$(eval "${ssh_command}" 2>/dev/null || true)
    local status_code=$?
    
    if [[ ${status_code} -ne 0 ]]; then
        log_error "SSH命令失败: ${description}"
        log_error "退出码: ${status_code}"
        return 1
    fi
    
    if [[ "${VERBOSE}" == "true" ]] && [[ -n "${response}" ]]; then
        echo "响应: ${response}"
    fi
    
    echo "${response}"
}

# 函数：获取管理员token
get_admin_token() {
    log "获取管理员token"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && grep ADMIN_TOKEN .env | cut -d= -f2"
    local response
    
    response=$(ssh_cmd "${cmd}" "获取管理员token")
    
    if [[ -z "${response}" ]]; then
        log_error "无法获取管理员token"
        return 1
    fi
    
    echo "${response}"
}

# 函数：测试健康检查
test_health_check() {
    log "测试 1/6: 健康检查"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -f http://127.0.0.1:8787/healthz"
    local response
    
    response=$(ssh_cmd "${cmd}" "健康检查")
    
    if echo "${response}" | grep -q '"ok":true'; then
        log_success "健康检查通过"
        return 0
    else
        log_error "健康检查失败"
        log_error "响应: ${response}"
        return 1
    fi
}

# 函数：测试未授权访问
test_unauthorized_access() {
    log "测试 2/6: 未授权访问保护"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -X GET -H 'Content-Type: application/json' http://127.0.0.1:8787/admin/keys"
    local response
    
    response=$(ssh_cmd "${cmd}" "未授权访问测试")
    
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
    
    local admin_token="$1"
    local json_data="{\\\"label\\\":\\\"${TEST_LABEL}\\\",\\\"totalQuota\\\":${TEST_QUOTA}}"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -X POST \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${admin_token}' \
        -d '${json_data}' \
        http://127.0.0.1:8787/admin/keys"
    
    local response
    response=$(ssh_cmd "${cmd}" "创建trial key")
    
    if echo "${response}" | grep -q '"key":"sk-'; then
        local created_key
        created_key=$(echo "${response}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_success "创建trial key成功"
        log_success "创建的key: ${created_key}"
        echo "${created_key}"
        return 0
    else
        log_error "创建trial key失败"
        log_error "响应: ${response}"
        return 1
    fi
}

# 函数：测试获取keys列表
test_get_keys_list() {
    log "测试 4/6: 获取keys列表"
    
    local admin_token="$1"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -X GET \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${admin_token}' \
        http://127.0.0.1:8787/admin/keys"
    
    local response
    response=$(ssh_cmd "${cmd}" "获取keys列表")
    
    if echo "${response}" | grep -q '"keys":'; then
        log_success "获取keys列表成功"
        
        # 统计key数量
        local key_count
        key_count=$(echo "${response}" | grep -o '"key":"sk-' | wc -l)
        log_success "找到 ${key_count} 个keys"
        
        return 0
    else
        log_error "获取keys列表失败"
        log_error "响应: ${response}"
        return 1
    fi
}

# 函数：测试获取使用情况统计
test_get_usage_stats() {
    log "测试 5/6: 获取使用情况统计"
    
    local admin_token="$1"
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -X GET \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${admin_token}' \
        http://127.0.0.1:8787/admin/usage"
    
    local response
    response=$(ssh_cmd "${cmd}" "获取使用情况统计")
    
    if echo "${response}" | grep -q '"items":'; then
        log_success "获取使用情况统计成功"
        
        # 解析统计数据
        local total
        total=$(echo "${response}" | grep -o '"total":[0-9]*' | cut -d: -f2)
        if [[ -n "${total}" ]]; then
            log_success "总使用记录: ${total}"
        fi
        
        return 0
    else
        log_error "获取使用情况统计失败"
        log_error "响应: ${response}"
        return 1
    fi
}

# 函数：测试清理创建的key
test_cleanup_created_key() {
    log "测试 6/6: 清理测试数据"
    
    local admin_token="$1"
    local created_key="$2"
    
    if [[ -z "${created_key}" ]]; then
        log_info "没有测试key需要清理"
        return 0
    fi
    
    local cmd="cd \"${QUOTA_PROXY_DIR}\" && curl -s -X DELETE \
        -H 'Content-Type: application/json' \
        -H 'Authorization: Bearer ${admin_token}' \
        http://127.0.0.1:8787/admin/keys/${created_key}"
    
    local response
    response=$(ssh_cmd "${cmd}" "清理测试key")
    
    if [[ -z "${response}" ]] || echo "${response}" | grep -q '"deleted":true'; then
        log_success "清理测试key成功: ${created_key}"
        return 0
    else
        log_warning "清理测试key可能失败: ${created_key}"
        log_warning "响应: ${response}"
        return 0  # 不因清理失败而标记测试失败
    fi
}

# 函数：显示帮助信息
show_help() {
    cat << EOF
quota-proxy 管理接口远程测试脚本

用法: $0 [选项]

选项:
  -h, --help             显示此帮助信息
  -s, --server SERVER    指定服务器地址 (默认: ${DEFAULT_SERVER})
  -k, --key KEY          指定SSH私钥路径 (默认: ${DEFAULT_SSH_KEY})
  -d, --dir DIR          指定quota-proxy目录 (默认: ${DEFAULT_QUOTA_PROXY_DIR})
  -v, --verbose          详细输出模式
  -n, --dry-run          模拟运行，不实际发送请求
  --list                 列出所有测试用例

环境变量:
  QUOTA_PROXY_SERVER     服务器地址
  SSH_KEY_PATH           SSH私钥路径
  QUOTA_PROXY_DIR        quota-proxy目录
  VERBOSE                详细输出模式
  DRY_RUN                模拟运行模式

示例:
  $0 --server 8.210.185.194 --key ~/.ssh/id_ed25519
  $0 --dry-run --verbose
  QUOTA_PROXY_SERVER=8.210.185.194 $0 --verbose
EOF
}

# 函数：列出测试用例
list_test_cases() {
    cat << EOF
测试用例列表:

1. 健康检查
   - 测试 /healthz 端点是否正常响应
   - 在服务器本地执行curl命令

2. 未授权访问保护
   - 测试未提供管理员token时访问管理接口是否被拒绝
   - 验证安全保护机制

3. 创建trial key
   - 测试 POST /admin/keys 接口
   - 创建带有唯一标签和配额的测试key

4. 获取keys列表
   - 测试 GET /admin/keys 接口
   - 验证返回的keys列表格式和数量

5. 获取使用情况统计
   - 测试 GET /admin/usage 接口
   - 验证使用统计数据的格式

6. 清理测试数据
   - 清理测试过程中创建的key
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
            -s|--server)
                SERVER="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -d|--dir)
                QUOTA_PROXY_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN="true"
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
    
    log "开始远程测试 quota-proxy 管理接口"
    log "服务器: ${SERVER}"
    log "SSH密钥: ${SSH_KEY}"
    log "quota-proxy目录: ${QUOTA_PROXY_DIR}"
    
    # 检查SSH密钥是否存在
    if [[ ! -f "${SSH_KEY}" ]] && [[ "${DRY_RUN}" != "true" ]]; then
        log_error "SSH密钥不存在: ${SSH_KEY}"
        exit 1
    fi
    
    # 获取管理员token
    local admin_token
    admin_token=$(get_admin_token)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    log "管理员token: ${admin_token:0:10}..."
    
    # 执行测试
    local tests_passed=0
    local tests_failed=0
    local tests_total=6
    local created_key=""
    
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
    local key_result
    key_result=$(test_create_trial_key "${admin_token}")
    if [[ $? -eq 0 ]]; then
        ((tests_passed++))
        created_key="${key_result}"
    else
        ((tests_failed++))
    fi
    
    # 测试4: 获取keys列表
    if test_get_keys_list "${admin_token}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试5: 获取使用情况统计
    if test_get_usage_stats "${admin_token}"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试6: 清理测试数据
    if test_cleanup_created_key "${admin_token}" "${created_key}"; then
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