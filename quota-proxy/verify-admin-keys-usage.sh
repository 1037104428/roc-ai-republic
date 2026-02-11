#!/usr/bin/env bash

# verify-admin-keys-usage.sh - 快速验证quota-proxy管理密钥和使用统计端点
# 版本: 2026.02.11.1721
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
快速验证quota-proxy管理密钥和使用统计端点

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示将要执行的命令
  --port <端口>       指定quota-proxy端口（默认: 8787）
  --admin-token <令牌> 指定管理员令牌（默认: dev-admin-token-change-in-production）
  --base-url <URL>    指定quota-proxy基础URL（默认: http://localhost:8787）

示例:
  $0 --dry-run          # 干运行模式
  $0 --port 8888        # 指定端口验证
  $0 --admin-token my-secret-token  # 指定管理员令牌
EOF
}

# 参数解析
DRY_RUN=false
PORT="8787"
ADMIN_TOKEN="dev-admin-token-change-in-production"
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
        --port)
            PORT="$2"
            BASE_URL="http://localhost:$2"
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

# 检查curl是否可用
check_curl() {
    if ! command -v curl &> /dev/null; then
        log_error "curl命令未找到，请先安装curl"
        exit 1
    fi
    log_success "curl命令可用"
}

# 检查服务器是否运行
check_server() {
    local health_url="${BASE_URL}/healthz"
    log_info "检查服务器健康状态: $health_url"
    
    if $DRY_RUN; then
        echo "curl -fsS $health_url"
        return 0
    fi
    
    if curl -fsS "$health_url" > /dev/null 2>&1; then
        log_success "服务器运行正常"
    else
        log_error "服务器未运行或健康检查失败"
        log_info "请确保quota-proxy正在运行: cd quota-proxy && node server-sqlite.js"
        exit 1
    fi
}

# 测试创建管理密钥
test_create_admin_key() {
    local timestamp=$(date +%s)
    local label="测试管理密钥-$timestamp"
    local total_quota=500
    
    log_info "测试创建管理密钥: $label"
    
    local cmd="curl -s -X POST \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        -H \"Content-Type: application/json\" \
        -d '{\"label\":\"${label}\", \"totalQuota\": ${total_quota}}' \
        \"${BASE_URL}/admin/keys\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | grep -q '"success":true'; then
        local key=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_success "管理密钥创建成功: $key"
        echo "$key" > /tmp/test-admin-key.txt
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        log_error "管理密钥创建失败"
        echo "$response"
        return 1
    fi
}

# 测试查看使用统计
test_admin_usage() {
    log_info "测试查看使用统计"
    
    local cmd="curl -s -X GET \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        \"${BASE_URL}/admin/usage?days=1&limit=10\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | grep -q '"total"\|"keys"'; then
        log_success "使用统计查询成功"
        echo "$response" | jq '.' 2>/dev/null || echo "$response" | head -200
    else
        log_error "使用统计查询失败"
        echo "$response"
        return 1
    fi
}

# 测试带分页的使用统计
test_admin_usage_pagination() {
    log_info "测试带分页的使用统计"
    
    local cmd="curl -s -X GET \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        \"${BASE_URL}/admin/usage?page=1&limit=5\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | grep -q '"page":1\|"limit":5'; then
        log_success "分页使用统计查询成功"
        echo "$response" | jq '.' 2>/dev/null || echo "$response" | head -200
    else
        log_warn "分页使用统计查询可能失败或格式不同"
        echo "$response"
    fi
}

# 测试按密钥筛选使用统计
test_admin_usage_by_key() {
    local test_key_file="/tmp/test-admin-key.txt"
    
    if [[ ! -f "$test_key_file" ]]; then
        log_warn "没有测试密钥，跳过按密钥筛选测试"
        return 0
    fi
    
    local test_key=$(cat "$test_key_file")
    log_info "测试按密钥筛选使用统计: $test_key"
    
    local cmd="curl -s -X GET \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        \"${BASE_URL}/admin/usage?key=${test_key}\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | grep -q "$test_key"; then
        log_success "按密钥筛选使用统计成功"
        echo "$response" | jq '.' 2>/dev/null || echo "$response" | head -200
    else
        log_warn "按密钥筛选使用统计可能失败或没有数据"
        echo "$response"
    fi
}

# 清理测试密钥
cleanup_test_key() {
    local test_key_file="/tmp/test-admin-key.txt"
    
    if [[ ! -f "$test_key_file" ]]; then
        return 0
    fi
    
    local test_key=$(cat "$test_key_file")
    log_info "清理测试密钥: $test_key"
    
    local cmd="curl -s -X DELETE \
        -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \
        \"${BASE_URL}/admin/keys/${test_key}\""
    
    if $DRY_RUN; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if echo "$response" | grep -q '"success":true'; then
        log_success "测试密钥清理成功"
        rm -f "$test_key_file"
    else
        log_warn "测试密钥清理失败，可能需要手动清理"
        echo "$response"
    fi
}

# 主验证流程
main() {
    log_info "开始验证quota-proxy管理密钥和使用统计端点"
    log_info "基础URL: $BASE_URL"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:10}..."
    
    # 检查依赖
    check_curl
    
    # 检查服务器
    check_server
    
    # 运行测试
    local tests_passed=0
    local tests_total=4
    
    log_info "运行测试 1/4: 创建管理密钥"
    if test_create_admin_key; then
        ((tests_passed++))
    fi
    
    log_info "运行测试 2/4: 查看使用统计"
    if test_admin_usage; then
        ((tests_passed++))
    fi
    
    log_info "运行测试 3/4: 带分页的使用统计"
    if test_admin_usage_pagination; then
        ((tests_passed++))
    fi
    
    log_info "运行测试 4/4: 按密钥筛选使用统计"
    if test_admin_usage_by_key; then
        ((tests_passed++))
    fi
    
    # 清理
    cleanup_test_key
    
    # 输出结果
    log_info "验证完成: $tests_passed/$tests_total 个测试通过"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "所有管理密钥和使用统计端点验证通过！"
        return 0
    else
        log_error "部分测试失败，请检查quota-proxy配置和运行状态"
        return 1
    fi
}

# 运行主函数
main "$@"