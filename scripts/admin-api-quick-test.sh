#!/bin/bash

# Quota-Proxy 管理 API 快速测试脚本
# 用于快速验证管理 API 的基本功能

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

# 配置
ADMIN_TOKEN=${ADMIN_TOKEN:-""}
BASE_URL=${BASE_URL:-"http://127.0.0.1:8787"}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# 帮助信息
show_help() {
    cat << EOF
Quota-Proxy 管理 API 快速测试脚本

用法: $0 [选项]

选项:
  --token TOKEN      指定 ADMIN_TOKEN
  --url URL         指定 API 基础 URL (默认: http://127.0.0.1:8787)
  --dry-run         只显示将要执行的命令，不实际执行
  --verbose         显示详细输出
  --help            显示此帮助信息

环境变量:
  ADMIN_TOKEN       管理令牌
  BASE_URL         API 基础 URL

示例:
  $0 --token "your-token"
  ADMIN_TOKEN="your-token" $0
  $0 --dry-run --verbose
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --url)
            BASE_URL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查依赖
check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq 未安装，JSON 输出将无法格式化"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        exit 1
    fi
}

# 检查服务状态
check_service() {
    log_info "检查服务状态..."
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "curl -fsS \"$BASE_URL/healthz\""
        return 0
    fi
    
    if curl -fsS "$BASE_URL/healthz" > /dev/null 2>&1; then
        log_success "服务正常运行"
        return 0
    else
        log_error "服务无法访问"
        return 1
    fi
}

# 检查认证
check_auth() {
    log_info "检查认证..."
    
    if [[ -z "$ADMIN_TOKEN" ]]; then
        log_error "ADMIN_TOKEN 未设置"
        log_info "请通过 --token 参数或环境变量设置"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "ADMIN_TOKEN=\"$ADMIN_TOKEN\""
        return 0
    fi
    
    log_success "认证令牌已设置"
    return 0
}

# 测试生成密钥
test_generate_key() {
    log_info "测试生成试用密钥..."
    
    local cmd="curl -s -X POST \"$BASE_URL/admin/keys\" \
      -H \"Authorization: Bearer $ADMIN_TOKEN\" \
      -H \"Content-Type: application/json\" \
      -d '{\"note\": \"API测试生成\"}'"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "$cmd"
        echo "TEST_KEY=\"trial_test_123\""
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if [[ "$VERBOSE" == true ]]; then
        echo "响应: $response"
    fi
    
    if echo "$response" | grep -q "key"; then
        TEST_KEY=$(echo "$response" | jq -r '.key' 2>/dev/null || echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_success "密钥生成成功: $TEST_KEY"
        return 0
    else
        log_error "密钥生成失败"
        return 1
    fi
}

# 测试查看使用情况
test_check_usage() {
    log_info "测试查看使用情况..."
    
    local cmd="curl -s -X GET \"$BASE_URL/admin/usage\" \
      -H \"Authorization: Bearer $ADMIN_TOKEN\""
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if [[ "$VERBOSE" == true ]]; then
        echo "响应: $response"
    fi
    
    if echo "$response" | grep -q "total_keys"; then
        local total_keys=$(echo "$response" | jq -r '.total_keys' 2>/dev/null || echo "$response" | grep -o '"total_keys":[0-9]*' | cut -d: -f2)
        log_success "使用情况查询成功，总密钥数: $total_keys"
        return 0
    else
        log_error "使用情况查询失败"
        return 1
    fi
}

# 测试列出密钥
test_list_keys() {
    log_info "测试列出所有密钥..."
    
    local cmd="curl -s -X GET \"$BASE_URL/admin/keys\" \
      -H \"Authorization: Bearer $ADMIN_TOKEN\""
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "$cmd"
        return 0
    fi
    
    local response
    response=$(eval "$cmd")
    
    if [[ "$VERBOSE" == true ]]; then
        echo "响应: $response"
    fi
    
    if echo "$response" | grep -q "keys"; then
        log_success "密钥列表查询成功"
        return 0
    else
        log_error "密钥列表查询失败"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}=== Quota-Proxy 管理 API 快速测试 ===${NC}"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 检查服务
    if ! check_service; then
        log_error "服务检查失败，测试终止"
        exit 1
    fi
    
    # 检查认证
    if ! check_auth; then
        exit 1
    fi
    
    echo ""
    log_info "开始 API 测试..."
    echo ""
    
    local tests_passed=0
    local tests_total=0
    
    # 测试1: 生成密钥
    ((tests_total++))
    if test_generate_key; then
        ((tests_passed++))
    fi
    
    echo ""
    
    # 测试2: 查看使用情况
    ((tests_total++))
    if test_check_usage; then
        ((tests_passed++))
    fi
    
    echo ""
    
    # 测试3: 列出密钥
    ((tests_total++))
    if test_list_keys; then
        ((tests_passed++))
    fi
    
    echo ""
    echo -e "${BLUE}=== 测试结果 ===${NC}"
    echo ""
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "所有测试通过 ($tests_passed/$tests_total)"
        echo ""
        log_info "管理 API 功能正常"
        log_info "详细文档请查看: docs/admin-api-quick-guide.md"
    else
        log_warning "部分测试失败 ($tests_passed/$tests_total)"
        echo ""
        log_info "请检查:"
        log_info "1. ADMIN_TOKEN 是否正确"
        log_info "2. 服务是否正常运行"
        log_info "3. 网络连接是否正常"
    fi
    
    echo ""
    echo -e "${BLUE}=== 测试完成 ===${NC}"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        return 0
    else
        return 1
    fi
}

# 执行主函数
main "$@"