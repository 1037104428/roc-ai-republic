#!/bin/bash
# verify-admin-comprehensive.sh - 综合性quota-proxy管理API验证脚本
# 验证管理API的完整功能，包括健康检查、密钥管理、使用量统计等

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_BASE_URL="http://127.0.0.1:8787"
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token-123}"

# 使用量
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_TESTS=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 测试结果记录
record_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$result" in
        "PASS")
            PASS_COUNT=$((PASS_COUNT + 1))
            echo -e "${GREEN}✓${NC} $test_name: $message"
            ;;
        "FAIL")
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo -e "${RED}✗${NC} $test_name: $message"
            ;;
        "SKIP")
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo -e "${YELLOW}↷${NC} $test_name: $message"
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "安装命令:"
        log_info "  Ubuntu/Debian: sudo apt-get install curl jq"
        log_info "  CentOS/RHEL: sudo yum install curl jq"
        log_info "  macOS: brew install curl jq"
        return 1
    fi
    
    log_success "所有依赖已安装"
    return 0
}

# 健康检查测试
test_health_check() {
    local test_name="健康检查"
    local url="${BASE_URL}/healthz"
    
    log_info "测试: $test_name"
    log_info "URL: $url"
    
    if curl -fsS "$url" &> /dev/null; then
        record_result "$test_name" "PASS" "服务健康检查通过"
        return 0
    else
        record_result "$test_name" "FAIL" "服务健康检查失败"
        return 1
    fi
}

# 管理API健康检查测试
test_admin_health() {
    local test_name="管理API健康检查"
    local url="${BASE_URL}/admin/health"
    
    log_info "测试: $test_name"
    log_info "URL: $url"
    
    local response
    if response=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "$url" 2>/dev/null); then
        if echo "$response" | jq -e '.status == "ok"' &> /dev/null; then
            record_result "$test_name" "PASS" "管理API健康检查通过"
            return 0
        else
            record_result "$test_name" "FAIL" "管理API返回状态异常"
            return 1
        fi
    else
        record_result "$test_name" "FAIL" "管理API健康检查请求失败"
        return 1
    fi
}

# 创建试用密钥测试
test_create_trial_key() {
    local test_name="创建试用密钥"
    local url="${BASE_URL}/admin/keys"
    
    log_info "测试: $test_name"
    log_info "URL: $url"
    
    local payload='{
        "name": "test-trial-key-'$(date +%s)'",
        "quota": 1000,
        "expiresIn": "24h"
    }'
    
    local response
    if response=$(curl -fsS -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -d "$payload" \
        "$url" 2>/dev/null); then
        
        if echo "$response" | jq -e '.key' &> /dev/null; then
            local key=$(echo "$response" | jq -r '.key')
            record_result "$test_name" "PASS" "试用密钥创建成功: ${key:0:10}..."
            echo "$key" > /tmp/test_trial_key.txt
            return 0
        else
            record_result "$test_name" "FAIL" "试用密钥创建响应格式错误"
            return 1
        fi
    else
        record_result "$test_name" "FAIL" "试用密钥创建请求失败"
        return 1
    fi
}

# 列出密钥测试
test_list_keys() {
    local test_name="列出密钥"
    local url="${BASE_URL}/admin/keys"
    
    log_info "测试: $test_name"
    log_info "URL: $url"
    
    local response
    if response=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "$url" 2>/dev/null); then
        if echo "$response" | jq -e '.keys' &> /dev/null; then
            local key_count=$(echo "$response" | jq '.keys | length')
            record_result "$test_name" "PASS" "成功列出 $key_count 个密钥"
            return 0
        else
            record_result "$test_name" "FAIL" "密钥列表响应格式错误"
            return 1
        fi
    else
        record_result "$test_name" "FAIL" "密钥列表请求失败"
        return 1
    fi
}

# 获取使用量统计测试
test_get_usage() {
    local test_name="获取使用量统计"
    local url="${BASE_URL}/admin/usage"
    
    log_info "测试: $test_name"
    log_info "URL: $url"
    
    local response
    if response=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "$url" 2>/dev/null); then
        if echo "$response" | jq -e '.totalRequests' &> /dev/null; then
            local total=$(echo "$response" | jq -r '.totalRequests')
            record_result "$test_name" "PASS" "使用量统计获取成功: $total 次请求"
            return 0
        else
            record_result "$test_name" "FAIL" "使用量统计响应格式错误"
            return 1
        fi
    else
        record_result "$test_name" "FAIL" "使用量统计请求失败"
        return 1
    fi
}

# 清理测试密钥
cleanup_test_key() {
    local key_file="/tmp/test_trial_key.txt"
    
    if [ -f "$key_file" ]; then
        local key=$(cat "$key_file")
        local url="${BASE_URL}/admin/keys/${key}"
        
        log_info "清理测试密钥: ${key:0:10}..."
        
        if curl -fsS -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" "$url" &> /dev/null; then
            log_success "测试密钥清理成功"
        else
            log_warning "测试密钥清理失败"
        fi
        
        rm -f "$key_file"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
综合性quota-proxy管理API验证脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -u, --url URL       设置quota-proxy基础URL (默认: $DEFAULT_BASE_URL)
  -t, --token TOKEN   设置管理令牌 (默认: 从环境变量ADMIN_TOKEN获取)
  --dry-run           模拟运行，不执行实际测试
  --skip-cleanup      跳过测试密钥清理

示例:
  $0
  $0 --url http://localhost:8787 --token my-admin-token
  $0 --dry-run

环境变量:
  ADMIN_TOKEN         管理API令牌 (默认: $DEFAULT_ADMIN_TOKEN)

EOF
}

# 主函数
main() {
    local base_url="$DEFAULT_BASE_URL"
    local admin_token="$DEFAULT_ADMIN_TOKEN"
    local dry_run=false
    local skip_cleanup=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--url)
                base_url="$2"
                shift 2
                ;;
            -t|--token)
                admin_token="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 导出全局变量
    export BASE_URL="$base_url"
    export ADMIN_TOKEN="$admin_token"
    
    log_info "开始综合性管理API验证"
    log_info "基础URL: $BASE_URL"
    log_info "管理令牌: ${ADMIN_TOKEN:0:10}..."
    log_info "模拟运行: $dry_run"
    
    if [ "$dry_run" = true ]; then
        log_info "模拟运行模式 - 只显示测试计划"
        echo "计划执行的测试:"
        echo "1. 健康检查"
        echo "2. 管理API健康检查"
        echo "3. 创建试用密钥"
        echo "4. 列出密钥"
        echo "5. 获取使用量统计"
        echo "6. 清理测试密钥"
        exit 0
    fi
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 执行测试
    log_info "执行测试套件..."
    
    test_health_check
    test_admin_health
    test_create_trial_key
    test_list_keys
    test_get_usage
    
    # 清理
    if [ "$skip_cleanup" = false ]; then
        cleanup_test_key
    fi
    
    # 显示测试结果
    echo ""
    echo "========================================"
    echo "测试完成摘要"
    echo "========================================"
    echo "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}跳过: $SKIP_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        log_success "所有测试通过！"
        exit 0
    else
        log_error "有 $FAIL_COUNT 个测试失败"
        exit 1
    fi
}

# 运行主函数
main "$@"