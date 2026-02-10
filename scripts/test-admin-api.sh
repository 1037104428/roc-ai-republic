#!/bin/bash

# test-admin-api.sh - quota-proxy 管理员接口测试脚本
# 用于验证管理员接口功能，包括健康检查、密钥管理、使用统计等

set -e

# 配置参数
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
DEFAULT_BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
DEFAULT_OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"

# 颜色输出
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
quota-proxy 管理员接口测试脚本

用法: $0 [选项]

选项:
  -h, --help                显示此帮助信息
  -t, --token TOKEN         管理员令牌 (默认: \$ADMIN_TOKEN 或 "$DEFAULT_ADMIN_TOKEN")
  -u, --url URL             API基础URL (默认: \$BASE_URL 或 "$DEFAULT_BASE_URL")
  -f, --format FORMAT       输出格式: json, text (默认: "$DEFAULT_OUTPUT_FORMAT")
  -v, --verbose             详细输出模式
  -q, --quiet               安静模式，只输出结果
  --test-health             只测试健康检查接口
  --test-keys               只测试密钥管理接口
  --test-usage              只测试使用统计接口
  --test-all                测试所有接口 (默认)

环境变量:
  ADMIN_TOKEN               管理员令牌
  BASE_URL                  API基础URL
  OUTPUT_FORMAT             输出格式

示例:
  # 使用默认配置测试所有接口
  $0

  # 指定令牌和URL测试
  $0 --token "my-secret-token" --url "http://api.example.com:8787"

  # 只测试健康检查
  $0 --test-health

  # 详细输出模式
  $0 --verbose

  # 安静模式，适合脚本集成
  $0 --quiet --format json
EOF
}

# 解析命令行参数
parse_args() {
    ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
    BASE_URL="$DEFAULT_BASE_URL"
    OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
    VERBOSE=false
    QUIET=false
    TEST_HEALTH=false
    TEST_KEYS=false
    TEST_USAGE=false
    TEST_ALL=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -u|--url)
                BASE_URL="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --test-health)
                TEST_HEALTH=true
                TEST_ALL=false
                shift
                ;;
            --test-keys)
                TEST_KEYS=true
                TEST_ALL=false
                shift
                ;;
            --test-usage)
                TEST_USAGE=true
                TEST_ALL=false
                shift
                ;;
            --test-all)
                TEST_ALL=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果指定了特定测试，更新TEST_ALL
    if [ "$TEST_HEALTH" = true ] || [ "$TEST_KEYS" = true ] || [ "$TEST_USAGE" = true ]; then
        TEST_ALL=false
    fi
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi

    if ! command -v jq &> /dev/null && [ "$OUTPUT_FORMAT" = "json" ]; then
        log_warning "jq 未安装，JSON输出可能无法格式化"
    fi
}

# 发送HTTP请求
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local url="${BASE_URL}${endpoint}"
    
    local curl_cmd="curl -s -X $method"
    
    # 添加管理员令牌头
    curl_cmd="$curl_cmd -H 'X-Admin-Token: $ADMIN_TOKEN'"
    
    # 添加数据（如果是POST/PUT）
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    # 添加超时设置
    curl_cmd="$curl_cmd --connect-timeout 10 --max-time 30"
    
    # 执行curl命令
    if [ "$VERBOSE" = true ] && [ "$QUIET" = false ]; then
        log_info "发送请求: $method $url"
        if [ -n "$data" ]; then
            log_info "请求数据: $data"
        fi
    fi
    
    eval "$curl_cmd '$url'"
}

# 格式化输出
format_output() {
    local response="$1"
    local endpoint="$2"
    
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        if command -v jq &> /dev/null; then
            echo "$response" | jq .
        else
            echo "$response"
        fi
    else
        # 文本格式输出
        echo "端点: $endpoint"
        echo "响应: $response"
        echo "---"
    fi
}

# 测试健康检查接口
test_health() {
    if [ "$QUIET" = false ]; then
        log_info "测试健康检查接口: GET /healthz"
    fi
    
    local response
    response=$(send_request "GET" "/healthz")
    
    if echo "$response" | grep -q '"ok":true'; then
        if [ "$QUIET" = false ]; then
            log_success "健康检查通过"
        fi
        format_output "$response" "/healthz"
        return 0
    else
        if [ "$QUIET" = false ]; then
            log_error "健康检查失败"
        fi
        format_output "$response" "/healthz"
        return 1
    fi
}

# 测试密钥生成接口
test_key_generation() {
    if [ "$QUIET" = false ]; then
        log_info "测试密钥生成接口: POST /admin/keys"
    fi
    
    local test_data='{"name":"test-key-'$(date +%s)'","quota":1000,"expires_in":3600}'
    local response
    response=$(send_request "POST" "/admin/keys" "$test_data")
    
    if echo "$response" | grep -q '"key"'; then
        if [ "$QUIET" = false ]; then
            log_success "密钥生成成功"
        fi
        # 提取生成的密钥用于后续测试
        TEST_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        format_output "$response" "/admin/keys"
        return 0
    else
        if [ "$QUIET" = false ]; then
            log_error "密钥生成失败"
        fi
        format_output "$response" "/admin/keys"
        return 1
    fi
}

# 测试密钥列表接口
test_key_list() {
    if [ "$QUIET" = false ]; then
        log_info "测试密钥列表接口: GET /admin/keys"
    fi
    
    local response
    response=$(send_request "GET" "/admin/keys")
    
    if echo "$response" | grep -q '\[.*\]'; then
        if [ "$QUIET" = false ]; then
            log_success "密钥列表获取成功"
        fi
        format_output "$response" "/admin/keys"
        return 0
    else
        if [ "$QUIET" = false ]; then
            log_warning "密钥列表可能为空或格式不正确"
        fi
        format_output "$response" "/admin/keys"
        return 0  # 不视为失败，可能确实没有密钥
    fi
}

# 测试使用统计接口
test_usage_stats() {
    if [ "$QUIET" = false ]; then
        log_info "测试使用统计接口: GET /admin/usage"
    fi
    
    local response
    response=$(send_request "GET" "/admin/usage")
    
    if echo "$response" | grep -q '{'; then
        if [ "$QUIET" = false ]; then
            log_success "使用统计获取成功"
        fi
        format_output "$response" "/admin/usage"
        return 0
    else
        if [ "$QUIET" = false ]; then
            log_error "使用统计获取失败"
        fi
        format_output "$response" "/admin/usage"
        return 1
    fi
}

# 主测试函数
run_tests() {
    local overall_success=true
    local test_results=""
    
    # 显示测试配置
    if [ "$QUIET" = false ]; then
        echo "========================================"
        echo "quota-proxy 管理员接口测试"
        echo "========================================"
        echo "基础URL: $BASE_URL"
        echo "输出格式: $OUTPUT_FORMAT"
        echo "测试模式: $([ "$VERBOSE" = true ] && echo "详细" || echo "正常")"
        echo "========================================"
        echo ""
    fi
    
    # 运行测试
    if [ "$TEST_ALL" = true ] || [ "$TEST_HEALTH" = true ]; then
        if test_health; then
            test_results="${test_results}健康检查: ✓\n"
        else
            test_results="${test_results}健康检查: ✗\n"
            overall_success=false
        fi
    fi
    
    if [ "$TEST_ALL" = true ] || [ "$TEST_KEYS" = true ]; then
        if test_key_generation; then
            test_results="${test_results}密钥生成: ✓\n"
        else
            test_results="${test_results}密钥生成: ✗\n"
            overall_success=false
        fi
        
        if test_key_list; then
            test_results="${test_results}密钥列表: ✓\n"
        else
            test_results="${test_results}密钥列表: ✗\n"
            # 密钥列表失败不视为整体失败
        fi
    fi
    
    if [ "$TEST_ALL" = true ] || [ "$TEST_USAGE" = true ]; then
        if test_usage_stats; then
            test_results="${test_results}使用统计: ✓\n"
        else
            test_results="${test_results}使用统计: ✗\n"
            overall_success=false
        fi
    fi
    
    # 显示测试摘要
    if [ "$QUIET" = false ]; then
        echo ""
        echo "========================================"
        echo "测试摘要"
        echo "========================================"
        echo -e "$test_results"
        
        if [ "$overall_success" = true ]; then
            log_success "所有测试通过！"
            echo "quota-proxy 管理员接口功能正常。"
        else
            log_error "部分测试失败！"
            echo "请检查管理员令牌、网络连接和服务状态。"
            echo "详细故障排除指南请参考项目文档。"
        fi
        echo "========================================"
    fi
    
    # 返回退出码
    if [ "$overall_success" = true ]; then
        return 0
    else
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    check_dependencies
    
    # 检查管理员令牌
    if [ "$ADMIN_TOKEN" = "your-admin-token-here" ]; then
        log_error "请设置管理员令牌："
        log_error "  1. 通过环境变量: export ADMIN_TOKEN='your-token'"
        log_error "  2. 通过命令行参数: $0 --token 'your-token'"
        log_error "  3. 在脚本中修改 DEFAULT_ADMIN_TOKEN"
        exit 1
    fi
    
    # 运行测试
    if ! run_tests; then
        exit 1
    fi
}

# 执行主函数
main "$@"