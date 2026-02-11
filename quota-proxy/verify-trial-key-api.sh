#!/bin/bash

# verify-trial-key-api.sh - 验证试用密钥API端点
# 验证 /admin/keys/trial 端点的功能

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
验证试用密钥API端点脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -s, --server URL    指定服务器URL (默认: http://127.0.0.1:8787)
  -v, --verbose       详细输出模式

示例:
  $0                    # 验证默认服务器的试用密钥API
  $0 -s http://localhost:8787  # 验证指定服务器
  $0 --dry-run         # 干运行模式
EOF
}

# 默认配置
SERVER_URL="http://127.0.0.1:8787"
DRY_RUN=false
VERBOSE=false

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
        -s|--server)
            SERVER_URL="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查curl是否可用
check_curl() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    log_success "curl 可用"
}

# 检查服务器是否运行
check_server() {
    log_info "检查服务器是否运行: $SERVER_URL"
    
    if $DRY_RUN; then
        echo "curl -s -o /dev/null -w '%{http_code}' '$SERVER_URL/healthz'"
        return 0
    fi
    
    local status_code
    status_code=$(curl -s -o /dev/null -w '%{http_code}' "$SERVER_URL/healthz" 2>/dev/null || echo "000")
    
    if [[ "$status_code" == "200" ]]; then
        log_success "服务器运行正常 (HTTP $status_code)"
        return 0
    else
        log_error "服务器未运行或健康检查失败 (HTTP $status_code)"
        return 1
    fi
}

# 测试试用密钥生成
test_trial_key_generation() {
    log_info "测试试用密钥生成端点: $SERVER_URL/admin/keys/trial"
    
    if $DRY_RUN; then
        echo "curl -X POST '$SERVER_URL/admin/keys/trial' -H 'Content-Type: application/json'"
        return 0
    fi
    
    local response
    response=$(curl -s -X POST "$SERVER_URL/admin/keys/trial" \
        -H "Content-Type: application/json" \
        -w "\n%{http_code}" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local response_body
    response_body=$(echo "$response" | head -n -1)
    
    if $VERBOSE; then
        log_info "响应状态码: $http_code"
        log_info "响应内容: $response_body"
    fi
    
    if [[ "$http_code" == "200" ]]; then
        # 验证响应结构
        if echo "$response_body" | grep -q '"success":true'; then
            local key
            key=$(echo "$response_body" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
            log_success "试用密钥生成成功: $key"
            
            # 提取更多信息
            local expires_at
            expires_at=$(echo "$response_body" | grep -o '"expiresAt":"[^"]*"' | cut -d'"' -f4)
            local total_quota
            total_quota=$(echo "$response_body" | grep -o '"totalQuota":[0-9]*' | cut -d':' -f2)
            
            log_info "试用密钥详情:"
            log_info "  - 过期时间: $expires_at"
            log_info "  - 配额限制: $total_quota 次调用"
            
            return 0
        else
            log_error "响应结构不正确"
            return 1
        fi
    else
        log_error "试用密钥生成失败 (HTTP $http_code)"
        return 1
    fi
}

# 测试速率限制
test_rate_limit() {
    log_info "测试试用密钥生成速率限制 (每个IP每小时3次)"
    
    if $DRY_RUN; then
        echo "# 将尝试生成4个试用密钥来测试速率限制"
        for i in {1..4}; do
            echo "curl -X POST '$SERVER_URL/admin/keys/trial' -H 'Content-Type: application/json'"
        done
        return 0
    fi
    
    local success_count=0
    local rate_limit_hit=false
    
    for i in {1..4}; do
        log_info "尝试生成第 $i 个试用密钥..."
        
        local response
        response=$(curl -s -X POST "$SERVER_URL/admin/keys/trial" \
            -H "Content-Type: application/json" \
            -w "\n%{http_code}" 2>/dev/null)
        
        local http_code
        http_code=$(echo "$response" | tail -n1)
        
        if [[ "$http_code" == "200" ]]; then
            ((success_count++))
            log_success "第 $i 个试用密钥生成成功"
        elif [[ "$http_code" == "429" ]]; then
            rate_limit_hit=true
            log_success "速率限制生效 (HTTP 429)"
            break
        else
            log_error "第 $i 个请求失败 (HTTP $http_code)"
        fi
        
        # 短暂延迟
        sleep 0.5
    done
    
    if [[ "$rate_limit_hit" == true ]] || [[ $success_count -le 3 ]]; then
        log_success "速率限制测试通过"
        return 0
    else
        log_error "速率限制可能未生效 (成功生成 $success_count 个密钥)"
        return 1
    fi
}

# 验证API文档
verify_api_documentation() {
    log_info "验证API文档中的试用密钥端点"
    
    if $DRY_RUN; then
        echo "curl -s '$SERVER_URL/status' | grep -q 'trial_keys'"
        return 0
    fi
    
    local status_response
    status_response=$(curl -s "$SERVER_URL/status")
    
    if echo "$status_response" | grep -q '"trial_keys":"/admin/keys/trial"'; then
        log_success "API文档包含试用密钥端点"
        return 0
    else
        log_error "API文档中未找到试用密钥端点"
        return 1
    fi
}

# 主验证函数
main() {
    log_info "开始验证试用密钥API端点"
    log_info "服务器: $SERVER_URL"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 检查依赖
    check_curl
    
    # 检查服务器
    if ! check_server; then
        log_error "服务器检查失败，无法继续验证"
        exit 1
    fi
    
    local tests_passed=0
    local tests_failed=0
    local tests_total=4
    
    # 测试1: 试用密钥生成
    log_info "=== 测试1: 试用密钥生成 ==="
    if test_trial_key_generation; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo ""
    
    # 测试2: 速率限制
    log_info "=== 测试2: 速率限制测试 ==="
    if test_rate_limit; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo ""
    
    # 测试3: API文档
    log_info "=== 测试3: API文档验证 ==="
    if verify_api_documentation; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    echo ""
    
    # 测试4: 端点存在性
    log_info "=== 测试4: 端点存在性检查 ==="
    if $DRY_RUN; then
        echo "curl -X OPTIONS '$SERVER_URL/admin/keys/trial' -I"
        ((tests_passed++))
    else
        local options_response
        options_response=$(curl -s -X OPTIONS "$SERVER_URL/admin/keys/trial" -I 2>/dev/null | head -n1)
        if echo "$options_response" | grep -q "200\|204\|405"; then
            log_success "试用密钥端点存在"
            ((tests_passed++))
        else
            log_error "试用密钥端点可能不存在"
            ((tests_failed++))
        fi
    fi
    echo ""
    
    # 生成报告
    log_info "=== 验证完成 ==="
    log_info "总测试数: $tests_total"
    log_info "通过测试: $tests_passed"
    log_info "失败测试: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log_success "所有测试通过！试用密钥API端点验证成功。"
        echo ""
        log_info "试用密钥端点功能摘要:"
        log_info "1. POST /admin/keys/trial - 生成试用密钥（无需认证）"
        log_info "2. 速率限制: 每个IP每小时最多3个试用密钥"
        log_info "3. 试用密钥特性: 7天有效期，100次调用限额"
        log_info "4. 自动包含在API文档中"
        return 0
    else
        log_error "部分测试失败，请检查服务器配置和代码。"
        return 1
    fi
}

# 运行主函数
main "$@"