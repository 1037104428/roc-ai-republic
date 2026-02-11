#!/bin/bash
# Admin API性能检查脚本
# 用于快速检查quota-proxy Admin API的响应时间性能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
ADMIN_TOKEN="${ADMIN_TOKEN:-admin123}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
TIMEOUT=10

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

# 显示帮助
show_help() {
    cat << 'HELP'
Admin API性能检查脚本

用法:
  ./check-admin-performance.sh [选项]

选项:
  -t, --token TOKEN      Admin令牌 (默认: admin123)
  -u, --url URL          quota-proxy基础URL (默认: http://127.0.0.1:8787)
  -h, --help             显示此帮助信息

环境变量:
  ADMIN_TOKEN            Admin令牌
  BASE_URL               quota-proxy基础URL

示例:
  ./check-admin-performance.sh
  ADMIN_TOKEN=mysecret ./check-admin-performance.sh
  ./check-admin-performance.sh --url http://localhost:8787 --token myadmin

功能:
  1. 检查Admin API端点响应时间
  2. 测量关键端点的性能
  3. 提供性能基准报告
HELP
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -h|--help)
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
    local missing_deps=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# 测量端点响应时间
measure_endpoint() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    
    local start_time
    local end_time
    local response_time
    
    start_time=$(date +%s%N)
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_output=$(curl -s -X "$method" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "\n%{http_code}" \
            --max-time "$TIMEOUT" \
            "$BASE_URL$endpoint" 2>/dev/null || echo "CURL_ERROR")
    else
        curl_output=$(curl -s -X "$method" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -w "\n%{http_code}" \
            --max-time "$TIMEOUT" \
            "$BASE_URL$endpoint" 2>/dev/null || echo "CURL_ERROR")
    fi
    
    end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 )) # 转换为毫秒
    
    # 提取HTTP状态码
    if [[ "$curl_output" == *CURL_ERROR* ]]; then
        echo "ERROR $response_time"
        return 1
    fi
    
    local http_code
    http_code=$(echo "$curl_output" | tail -n1)
    
    echo "$http_code $response_time"
}

# 主函数
main() {
    log_info "开始Admin API性能检查"
    log_info "配置:"
    log_info "  Base URL: $BASE_URL"
    log_info "  Timeout: ${TIMEOUT}s"
    
    check_dependencies
    
    # 检查服务是否运行
    log_info "检查服务状态..."
    if ! curl -s -f "$BASE_URL/healthz" > /dev/null 2>&1; then
        log_error "服务未运行或无法访问: $BASE_URL/healthz"
        exit 1
    fi
    log_success "服务运行正常"
    
    echo ""
    log_info "开始性能测试..."
    echo "----------------------------------------"
    
    # 测试端点列表
    declare -A endpoints=(
        ["GET /admin/keys"]="GET /admin/keys"
        ["GET /admin/usage"]="GET /admin/usage"
        ["POST /admin/keys"]="POST /admin/keys {\"label\":\"performance-test-$(date +%s)\",\"quota\":1000}"
        ["GET /healthz"]="GET /healthz"
    )
    
    local total_time=0
    local successful_tests=0
    
    for name in "${!endpoints[@]}"; do
        local endpoint_config="${endpoints[$name]}"
        local method
        local endpoint
        local data=""
        
        # 解析配置
        if [[ "$endpoint_config" == *"POST"* ]]; then
            method="POST"
            endpoint=$(echo "$endpoint_config" | awk '{print $2}')
            data=$(echo "$endpoint_config" | cut -d' ' -f3-)
        else
            method=$(echo "$endpoint_config" | awk '{print $1}')
            endpoint=$(echo "$endpoint_config" | awk '{print $2}')
        fi
        
        log_info "测试: $name"
        log_info "  端点: $endpoint"
        
        local result
        result=$(measure_endpoint "$endpoint" "$method" "$data")
        
        if [[ "$result" == ERROR* ]]; then
            local time_ms="${result#ERROR }"
            log_warning "  请求失败 - 响应时间: ${time_ms}ms"
        else
            local http_code="${result%% *}"
            local time_ms="${result#* }"
            
            if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
                log_success "  成功 (HTTP $http_code) - 响应时间: ${time_ms}ms"
                total_time=$((total_time + time_ms))
                successful_tests=$((successful_tests + 1))
            else
                log_warning "  非成功状态码: HTTP $http_code - 响应时间: ${time_ms}ms"
            fi
        fi
        
        echo ""
    done
    
    echo "----------------------------------------"
    log_info "性能测试完成"
    
    if [ $successful_tests -gt 0 ]; then
        local avg_time=$((total_time / successful_tests))
        
        # 性能评级
        local rating=""
        if [ $avg_time -lt 100 ]; then
            rating="优秀"
        elif [ $avg_time -lt 300 ]; then
            rating="良好"
        elif [ $avg_time -lt 500 ]; then
            rating="一般"
        else
            rating="较慢"
        fi
        
        log_success "平均响应时间: ${avg_time}ms ($rating)"
        log_success "成功测试数: $successful_tests/${#endpoints[@]}"
        
        # 建议
        echo ""
        log_info "建议:"
        if [ $avg_time -ge 500 ]; then
            echo "  - 响应时间较慢，建议优化数据库查询或增加缓存"
        elif [ $avg_time -ge 300 ]; then
            echo "  - 响应时间一般，可考虑性能优化"
        else
            echo "  - 响应时间良好，保持当前配置"
        fi
    else
        log_warning "没有成功的测试，无法计算平均响应时间"
    fi
    
    echo ""
    log_info "脚本执行完成"
}

# 运行主函数
main "$@"
