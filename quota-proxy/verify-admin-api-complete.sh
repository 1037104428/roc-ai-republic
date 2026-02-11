#!/bin/bash
# 验证quota-proxy管理API完整性脚本
# 检查所有管理API端点是否正常工作

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PORT=${PORT:-8787}
HOST=${HOST:-127.0.0.1}
ADMIN_TOKEN=${ADMIN_TOKEN:-"test-admin-token"}
BASE_URL="http://${HOST}:${PORT}"
DRY_RUN=${DRY_RUN:-false}

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

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 不存在，请安装后重试"
        return 1
    fi
}

# 检查服务器是否运行
check_server_running() {
    if curl -s -f "${BASE_URL}/healthz" > /dev/null 2>&1; then
        log_info "服务器正在运行: ${BASE_URL}"
        return 0
    else
        log_warning "服务器未运行或健康检查失败: ${BASE_URL}"
        return 1
    fi
}

# 测试API端点
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local expected_status="$3"
    local data="$4"
    local description="$5"
    
    local curl_cmd="curl -s -o /dev/null -w '%{http_code}' -X ${method}"
    
    # 添加认证头
    if [[ "$endpoint" == /admin/* ]]; then
        curl_cmd="${curl_cmd} -H 'Authorization: Bearer ${ADMIN_TOKEN}'"
    fi
    
    # 添加数据
    if [[ -n "$data" ]]; then
        curl_cmd="${curl_cmd} -H 'Content-Type: application/json' -d '${data}'"
    fi
    
    curl_cmd="${curl_cmd} ${BASE_URL}${endpoint}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "干运行: ${description}"
        log_info "  命令: ${curl_cmd}"
        log_info "  预期状态码: ${expected_status}"
        return 0
    fi
    
    log_info "测试: ${description}"
    
    local status_code
    status_code=$(eval "$curl_cmd")
    
    if [[ "$status_code" == "$expected_status" ]]; then
        log_success "  ✓ 端点 ${endpoint} 返回 ${status_code}"
        return 0
    else
        log_error "  ✗ 端点 ${endpoint} 返回 ${status_code} (预期: ${expected_status})"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始验证quota-proxy管理API完整性"
    log_info "服务器地址: ${BASE_URL}"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:8}..."
    log_info "干运行模式: ${DRY_RUN}"
    
    # 检查必需命令
    check_command curl || exit 1
    
    # 检查服务器
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! check_server_running; then
            log_error "请先启动quota-proxy服务器"
            log_info "启动命令: cd quota-proxy && npm start"
            exit 1
        fi
    fi
    
    local tests_passed=0
    local tests_failed=0
    
    # 测试健康检查端点
    if test_endpoint "GET" "/healthz" "200" "" "健康检查端点"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试状态端点
    if test_endpoint "GET" "/status" "200" "" "状态端点"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试管理API端点
    if test_endpoint "GET" "/admin/keys" "200" "" "获取所有API密钥"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试创建试用密钥
    local trial_key_data='{"daily_limit": 100, "monthly_limit": 3000, "notes": "测试密钥"}'
    if test_endpoint "POST" "/admin/keys/trial" "201" "$trial_key_data" "创建试用密钥"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试使用统计端点
    if test_endpoint "GET" "/admin/usage" "200" "" "获取使用统计"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试重置使用统计
    if test_endpoint "POST" "/admin/reset-usage" "200" '{"key": "all"}' "重置使用统计"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试系统信息端点
    if test_endpoint "GET" "/admin/system" "200" "" "获取系统信息"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 测试模型端点
    if test_endpoint "GET" "/v1/models" "200" "" "获取模型列表"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # 总结
    log_info "测试完成: ${tests_passed} 通过, ${tests_failed} 失败"
    
    if [[ $tests_failed -eq 0 ]]; then
        log_success "所有管理API端点验证通过！"
        return 0
    else
        log_error "部分API端点验证失败"
        return 1
    fi
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --dry-run         干运行模式，只显示命令不执行"
            echo "  --port PORT       服务器端口 (默认: 8787)"
            echo "  --host HOST       服务器主机 (默认: 127.0.0.1)"
            echo "  --admin-token TOKEN 管理员令牌"
            echo "  --help            显示帮助信息"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 运行主函数
main "$@"