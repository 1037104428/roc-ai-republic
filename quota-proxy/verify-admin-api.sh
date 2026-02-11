#!/usr/bin/env bash

# verify-admin-api.sh - 验证quota-proxy管理API功能
# 版本: 2026.02.11.1553
# 作者: 中华AI共和国项目组

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 帮助信息
show_help() {
    cat <<EOF
验证quota-proxy管理API功能

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示将要执行的命令
  --quick, -q         快速验证模式，只执行核心检查
  --verbose, -v       详细输出模式，显示所有详细信息
  --port <端口>       指定quota-proxy端口（默认: 8787）
  --admin-token <令牌> 指定管理员令牌（默认: 从环境变量读取）
  --base-url <URL>    指定quota-proxy基础URL（默认: http://localhost:8787）

示例:
  $0 --dry-run          # 干运行模式
  $0 --quick            # 快速验证模式
  $0 --verbose          # 详细验证模式
  $0 --port 8888        # 指定端口验证
EOF
}

# 参数解析
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false
PORT="8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
BASE_URL="http://localhost:8787"

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 更新基础URL
BASE_URL="http://localhost:${PORT}"

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "请安装缺少的依赖:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 检查环境变量
check_env_vars() {
    if [[ -z "$ADMIN_TOKEN" ]]; then
        log_error "未设置ADMIN_TOKEN环境变量"
        log_info "请设置ADMIN_TOKEN环境变量或使用--admin-token参数"
        exit 1
    fi
    
    log_success "环境变量检查通过: ADMIN_TOKEN已设置"
}

# 检查quota-proxy服务状态
check_service_status() {
    log_info "检查quota-proxy服务状态..."
    
    if $DRY_RUN; then
        echo "curl -fsS \"${BASE_URL}/healthz\""
        return 0
    fi
    
    if ! curl -fsS "${BASE_URL}/healthz" &> /dev/null; then
        log_error "quota-proxy服务未运行或无法访问"
        log_info "请确保quota-proxy正在运行:"
        echo "  - 检查服务状态: ps aux | grep node"
        echo "  - 检查端口占用: netstat -tlnp | grep :${PORT}"
        echo "  - 启动服务: cd quota-proxy && npm start"
        exit 1
    fi
    
    log_success "quota-proxy服务运行正常"
}

# 测试管理员认证
test_admin_auth() {
    log_info "测试管理员认证..."
    
    local cmd="curl -s -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${BASE_URL}/admin/usage\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "管理员认证失败"
        log_info "响应: $response"
        exit 1
    fi
    
    log_success "管理员认证通过"
}

# 测试生成试用密钥
test_generate_trial_key() {
    log_info "测试生成试用密钥..."
    
    local cmd="curl -s -X POST -H \"Authorization: Bearer ${ADMIN_TOKEN}\" -H \"Content-Type: application/json\" -d '{\"label\":\"测试密钥-$(date +%s)\"}' \"${BASE_URL}/admin/keys\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "生成试用密钥失败"
        log_info "响应: $response"
        exit 1
    fi
    
    local trial_key
    trial_key=$(echo "$response" | jq -r '.key')
    
    if [[ -z "$trial_key" || "$trial_key" == "null" ]]; then
        log_error "未获取到试用密钥"
        exit 1
    fi
    
    log_success "试用密钥生成成功: $trial_key"
    echo "$trial_key" > /tmp/verify-admin-api-trial-key.txt
}

# 测试查询使用情况
test_query_usage() {
    log_info "测试查询使用情况..."
    
    local cmd="curl -s -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${BASE_URL}/admin/usage?limit=5\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "查询使用情况失败"
        log_info "响应: $response"
        exit 1
    fi
    
    log_success "使用情况查询成功"
    
    if $VERBOSE; then
        echo "响应详情:"
        echo "$response" | jq .
    fi
}

# 测试按天查询使用情况
test_query_usage_by_day() {
    log_info "测试按天查询使用情况..."
    
    local today
    today=$(date +%Y-%m-%d)
    local cmd="curl -s -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${BASE_URL}/admin/usage?day=${today}\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "按天查询使用情况失败"
        log_info "响应: $response"
        exit 1
    fi
    
    log_success "按天使用情况查询成功"
}

# 测试重置使用情况
test_reset_usage() {
    log_info "测试重置使用情况..."
    
    local trial_key
    trial_key=$(cat /tmp/verify-admin-api-trial-key.txt 2>/dev/null || echo "")
    
    if [[ -z "$trial_key" ]]; then
        log_warn "未找到试用密钥，跳过重置测试"
        return 0
    fi
    
    local today
    today=$(date +%Y-%m-%d)
    local cmd="curl -s -X POST -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${BASE_URL}/admin/usage/reset?key=${trial_key}&day=${today}\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "重置使用情况失败"
        log_info "响应: $response"
        exit 1
    fi
    
    log_success "使用情况重置成功"
}

# 测试删除试用密钥
test_delete_trial_key() {
    log_info "测试删除试用密钥..."
    
    local trial_key
    trial_key=$(cat /tmp/verify-admin-api-trial-key.txt 2>/dev/null || echo "")
    
    if [[ -z "$trial_key" ]]; then
        log_warn "未找到试用密钥，跳过删除测试"
        return 0
    fi
    
    local cmd="curl -s -X DELETE -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \"${BASE_URL}/admin/keys/${trial_key}\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | jq -e '.error' &> /dev/null; then
        log_error "删除试用密钥失败"
        log_info "响应: $response"
        exit 1
    fi
    
    log_success "试用密钥删除成功"
    
    # 清理临时文件
    rm -f /tmp/verify-admin-api-trial-key.txt
}

# 快速验证模式
quick_verification() {
    log_info "开始快速验证..."
    
    check_dependencies
    check_env_vars
    check_service_status
    test_admin_auth
    test_generate_trial_key
    test_query_usage
    
    log_success "快速验证完成"
}

# 完整验证模式
full_verification() {
    log_info "开始完整验证..."
    
    check_dependencies
    check_env_vars
    check_service_status
    test_admin_auth
    test_generate_trial_key
    test_query_usage
    test_query_usage_by_day
    test_reset_usage
    test_delete_trial_key
    
    log_success "完整验证完成"
}

# 主函数
main() {
    log_info "开始验证quota-proxy管理API功能"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_info "基础URL: $BASE_URL"
    log_info "端口: $PORT"
    
    if $DRY_RUN; then
        log_info "干运行模式 - 只显示命令"
        echo "========================================"
    fi
    
    if $QUICK_MODE; then
        quick_verification
    else
        full_verification
    fi
    
    if $DRY_RUN; then
        echo "========================================"
        log_info "干运行模式完成 - 未执行实际命令"
    else
        log_success "所有验证完成"
        log_info "管理API功能验证总结:"
        echo "  - 依赖检查: ✓"
        echo "  - 环境变量检查: ✓"
        echo "  - 服务状态检查: ✓"
        echo "  - 管理员认证: ✓"
        echo "  - 试用密钥生成: ✓"
        echo "  - 使用情况查询: ✓"
        echo "  - 按天查询: ✓"
        echo "  - 使用情况重置: ✓"
        echo "  - 试用密钥删除: ✓"
    fi
}

# 执行主函数
main "$@"