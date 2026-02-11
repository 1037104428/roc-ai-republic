#!/bin/bash

# check-deployment-status.sh - 快速检查quota-proxy部署状态
# 提供轻量级的服务状态检查，适用于日常监控和快速故障排查

set -euo pipefail

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

# 显示帮助信息
show_help() {
    cat << EOF
check-deployment-status.sh - 快速检查quota-proxy部署状态

用法:
  ./check-deployment-status.sh [选项]

选项:
  -h, --help           显示此帮助信息
  -u, --url URL        服务基础URL (默认: http://127.0.0.1:8787)
  -t, --token TOKEN    管理员令牌 (可选，用于需要认证的端点)
  -d, --dry-run        干运行模式，显示检查步骤但不实际执行
  -v, --verbose        详细输出模式
  -q, --quiet          安静模式，只显示最终结果

示例:
  ./check-deployment-status.sh
  ./check-deployment-status.sh --url http://localhost:8787 --token my-admin-token
  ./check-deployment-status.sh --dry-run --verbose

功能:
  1. 检查服务健康状态
  2. 检查服务状态信息
  3. 检查API密钥端点（如果提供令牌）
  4. 检查试用密钥端点（如果提供令牌）
  5. 生成部署状态报告

退出码:
  0 - 所有检查通过
  1 - 部分检查失败
  2 - 参数错误
EOF
}

# 默认配置
BASE_URL="http://127.0.0.1:8787"
ADMIN_TOKEN=""
DRY_RUN=false
VERBOSE=false
QUIET=false

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--url)
                BASE_URL="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
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
            -q|--quiet)
                QUIET=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

# 检查URL是否有效
check_url() {
    local url="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "干运行: 检查URL: $url"
        return 0
    fi
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 发送HTTP请求
send_request() {
    local url="$1"
    local method="${2:-GET}"
    local token="${3:-}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "干运行: $method $url"
        echo '{"status": "healthy", "message": "干运行模拟响应"}'
        return 0
    fi
    
    local curl_cmd="curl -s -X $method"
    
    if [[ -n "$token" ]]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $token'"
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "执行: $curl_cmd"
    fi
    
    eval "$curl_cmd" 2>/dev/null || echo '{}'
}

# 检查健康端点
check_health() {
    if [[ "$QUIET" != "true" ]]; then
        log_info "检查健康端点..."
    fi
    
    local response
    response=$(send_request "$BASE_URL/healthz")
    
    # 移除颜色代码后检查响应
    local clean_response=$(echo "$response" | sed 's/\x1b\[[0-9;]*m//g')
    
    if echo "$clean_response" | grep -q '"status":"healthy"'; then
        if [[ "$QUIET" != "true" ]]; then
            log_success "健康检查通过"
        fi
        return 0
    else
        if [[ "$QUIET" != "true" ]]; then
            log_error "健康检查失败"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "响应: $clean_response"
            fi
        fi
        return 1
    fi
}

# 检查状态端点
check_status() {
    if [[ "$QUIET" != "true" ]]; then
        log_info "检查状态端点..."
    fi
    
    local response
    response=$(send_request "$BASE_URL/status")
    
    # 移除颜色代码后检查响应
    local clean_response=$(echo "$response" | sed 's/\x1b\[[0-9;]*m//g')
    
    if echo "$clean_response" | grep -q '"status":"ok"'; then
        if [[ "$QUIET" != "true" ]]; then
            log_success "状态检查通过"
        fi
        return 0
    else
        if [[ "$QUIET" != "true" ]]; then
            log_warning "状态检查返回非正常状态"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "响应: $clean_response"
            fi
        fi
        return 1
    fi
}

# 检查API密钥端点（需要令牌）
check_api_keys() {
    if [[ -z "$ADMIN_TOKEN" ]]; then
        if [[ "$QUIET" != "true" ]]; then
            log_info "跳过API密钥检查（未提供管理员令牌）"
        fi
        return 0
    fi
    
    if [[ "$QUIET" != "true" ]]; then
        log_info "检查API密钥端点..."
    fi
    
    local response
    response=$(send_request "$BASE_URL/admin/keys" "GET" "$ADMIN_TOKEN")
    
    # 移除颜色代码后检查响应
    local clean_response=$(echo "$response" | sed 's/\x1b\[[0-9;]*m//g')
    
    if echo "$clean_response" | grep -q '"keys":'; then
        if [[ "$QUIET" != "true" ]]; then
            log_success "API密钥检查通过"
        fi
        return 0
    else
        if [[ "$QUIET" != "true" ]]; then
            log_error "API密钥检查失败"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "响应: $clean_response"
            fi
        fi
        return 1
    fi
}

# 检查试用密钥端点（需要令牌）
check_trial_keys() {
    if [[ -z "$ADMIN_TOKEN" ]]; then
        if [[ "$QUIET" != "true" ]]; then
            log_info "跳过试用密钥检查（未提供管理员令牌）"
        fi
        return 0
    fi
    
    if [[ "$QUIET" != "true" ]]; then
        log_info "检查试用密钥端点..."
    fi
    
    local response
    response=$(send_request "$BASE_URL/admin/keys/trial" "POST" "$ADMIN_TOKEN")
    
    # 移除颜色代码后检查响应
    local clean_response=$(echo "$response" | sed 's/\x1b\[[0-9;]*m//g')
    
    if echo "$clean_response" | grep -q '"key":'; then
        if [[ "$QUIET" != "true" ]]; then
            log_success "试用密钥检查通过"
        fi
        return 0
    else
        if [[ "$QUIET" != "true" ]]; then
            log_error "试用密钥检查失败"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "响应: $clean_response"
            fi
        fi
        return 1
    fi
}

# 生成状态报告
generate_report() {
    local passed=0
    local failed=0
    local skipped=0
    local total=4
    
    echo ""
    echo "================================"
    echo "   quota-proxy部署状态报告"
    echo "================================"
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "服务URL: $BASE_URL"
    echo "管理员令牌: $(if [[ -n "$ADMIN_TOKEN" ]]; then echo "已提供"; else echo "未提供"; fi)"
    echo "干运行模式: $(if [[ "$DRY_RUN" == "true" ]]; then echo "是"; else echo "否"; fi)"
    echo "--------------------------------"
    
    # 健康检查
    if check_health; then
        echo "✓ 健康检查: 通过"
        ((passed++))
    else
        echo "✗ 健康检查: 失败"
        ((failed++))
    fi
    
    # 状态检查
    if check_status; then
        echo "✓ 状态检查: 通过"
        ((passed++))
    else
        echo "✗ 状态检查: 失败"
        ((failed++))
    fi
    
    # API密钥检查
    if [[ -n "$ADMIN_TOKEN" ]]; then
        if check_api_keys; then
            echo "✓ API密钥检查: 通过"
            ((passed++))
        else
            echo "✗ API密钥检查: 失败"
            ((failed++))
        fi
    else
        echo "○ API密钥检查: 跳过（无令牌）"
        ((skipped++))
    fi
    
    # 试用密钥检查
    if [[ -n "$ADMIN_TOKEN" ]]; then
        if check_trial_keys; then
            echo "✓ 试用密钥检查: 通过"
            ((passed++))
        else
            echo "✗ 试用密钥检查: 失败"
            ((failed++))
        fi
    else
        echo "○ 试用密钥检查: 跳过（无令牌）"
        ((skipped++))
    fi
    
    echo "--------------------------------"
    echo "总计: $total 项检查"
    echo "通过: $passed"
    echo "失败: $failed"
    echo "跳过: $skipped"
    echo "================================"
    
    if [[ $failed -eq 0 ]]; then
        log_success "所有检查通过！服务运行正常。"
        return 0
    else
        log_error "部分检查失败，请检查服务状态。"
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    if [[ "$QUIET" != "true" ]]; then
        echo "开始检查quota-proxy部署状态..."
        echo "服务URL: $BASE_URL"
        [[ -n "$ADMIN_TOKEN" ]] && echo "管理员令牌: 已提供"
        [[ "$DRY_RUN" == "true" ]] && echo "模式: 干运行"
        echo ""
    fi
    
    # 检查基础URL是否可达
    if [[ "$DRY_RUN" != "true" ]]; then
        if ! check_url "$BASE_URL"; then
            log_error "无法访问服务URL: $BASE_URL"
            log_error "请确保quota-proxy服务正在运行，并且URL正确。"
            exit 1
        fi
    fi
    
    # 执行检查并生成报告
    generate_report
}

# 执行主函数
main "$@"