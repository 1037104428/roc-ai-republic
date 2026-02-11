#!/bin/bash

# test-cdn-sources.sh - 多CDN源测试脚本
# 测试多个国内CDN源的连接速度，为install-cn.sh选择最优源提供数据支持

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_TIMEOUT=5
DEFAULT_RETRIES=2
VERBOSE=false
OUTPUT_FORMAT="text"

# CDN源列表（国内可达源）
CDN_SOURCES=(
    "https://registry.npmmirror.com"
    "https://mirrors.cloud.tencent.com/npm"
    "https://registry.npm.taobao.org"
    "https://npm.pkg.github.com"
    "https://registry.yarnpkg.com"
)

# 帮助信息
show_help() {
    cat << EOF
多CDN源测试脚本 v1.0.0

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -t, --timeout N     设置超时时间（秒，默认: $DEFAULT_TIMEOUT）
  -r, --retries N     设置重试次数（默认: $DEFAULT_RETRIES）
  -f, --format FORMAT 输出格式（text|json|markdown，默认: text）
  --test-url URL      测试特定URL（覆盖默认CDN源列表）

示例:
  $0                     # 测试所有CDN源
  $0 -v -t 10           # 详细模式，10秒超时
  $0 --format json      # JSON格式输出
  $0 --test-url https://example.com  # 测试特定URL

功能:
  1. 测试多个国内CDN源的连接速度
  2. 测量响应时间和可用性
  3. 为install-cn.sh选择最优源提供数据支持
  4. 支持多种输出格式

EOF
}

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

# 测试单个URL
test_url() {
    local url="$1"
    local timeout="$2"
    local retries="$3"
    
    local total_time=0
    local success_count=0
    local best_time=999999
    local worst_time=0
    
    log_info "测试 URL: $url"
    
    for ((i=1; i<=retries; i++)); do
        if $VERBOSE; then
            echo -n "  尝试 $i/$retries: "
        fi
        
        # 使用curl测试连接
        local start_time
        start_time=$(date +%s%3N)
        
        if curl -s -f --max-time "$timeout" "$url" > /dev/null 2>&1; then
            local end_time
            end_time=$(date +%s%3N)
            local duration=$((end_time - start_time))
            
            total_time=$((total_time + duration))
            success_count=$((success_count + 1))
            
            if [ "$duration" -lt "$best_time" ]; then
                best_time="$duration"
            fi
            
            if [ "$duration" -gt "$worst_time" ]; then
                worst_time="$duration"
            fi
            
            if $VERBOSE; then
                echo -e "${GREEN}成功${NC} (${duration}ms)"
            fi
        else
            if $VERBOSE; then
                echo -e "${RED}失败${NC}"
            fi
        fi
    done
    
    # 计算统计信息
    if [ "$success_count" -eq 0 ]; then
        echo "  ❌ 不可用 (0/$retries 成功)"
        return 1
    fi
    
    local avg_time=$((total_time / success_count))
    local success_rate=$((success_count * 100 / retries))
    
    echo "  ✅ 可用性: $success_rate% ($success_count/$retries)"
    echo "     平均响应时间: ${avg_time}ms"
    echo "     最佳响应时间: ${best_time}ms"
    echo "     最差响应时间: ${worst_time}ms"
    
    # 返回结果
    echo "$url|$success_rate|$avg_time|$best_time|$worst_time"
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -t|--timeout)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    DEFAULT_TIMEOUT="$2"
                    shift 2
                else
                    log_error "--timeout 需要参数"
                    exit 1
                fi
                ;;
            -r|--retries)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    DEFAULT_RETRIES="$2"
                    shift 2
                else
                    log_error "--retries 需要参数"
                    exit 1
                fi
                ;;
            -f|--format)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    OUTPUT_FORMAT="$2"
                    shift 2
                else
                    log_error "--format 需要参数"
                    exit 1
                fi
                ;;
            --test-url)
                if [[ -n "${2:-}" && "${2:0:1}" != "-" ]]; then
                    CDN_SOURCES=("$2")
                    shift 2
                else
                    log_error "--test-url 需要参数"
                    exit 1
                fi
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "开始CDN源测试"
    log_info "超时时间: ${DEFAULT_TIMEOUT}秒"
    log_info "重试次数: ${DEFAULT_RETRIES}次"
    log_info "测试源数量: ${#CDN_SOURCES[@]}"
    echo
    
    # 存储测试结果
    local results=()
    local available_sources=()
    
    # 测试所有CDN源
    for url in "${CDN_SOURCES[@]}"; do
        echo "========================================"
        if result=$(test_url "$url" "$DEFAULT_TIMEOUT" "$DEFAULT_RETRIES"); then
            results+=("$result")
            available_sources+=("$url")
        fi
        echo
    done
    
    echo "========================================"
    log_info "测试完成"
    echo
    
    # 输出摘要
    if [ "${#available_sources[@]}" -eq 0 ]; then
        log_error "没有可用的CDN源"
        exit 1
    fi
    
    log_success "找到 ${#available_sources[@]} 个可用CDN源"
    
    # 按平均响应时间排序
    echo "推荐顺序（按响应时间排序）:"
    echo "----------------------------------------"
    
    # 提取并排序结果
    local sorted_results=()
    for result in "${results[@]}"; do
        IFS='|' read -r url success_rate avg_time best_time worst_time <<< "$result"
        sorted_results+=("$avg_time|$url|$success_rate|$best_time|$worst_time")
    done
    
    # 排序（按响应时间升序）
    IFS=$'\n' sorted_results=($(sort -n <<< "${sorted_results[*]}"))
    unset IFS
    
    # 输出排序结果
    local rank=1
    for sorted_result in "${sorted_results[@]}"; do
        IFS='|' read -r avg_time url success_rate best_time worst_time <<< "$sorted_result"
        echo "$rank. $url"
        echo "   可用性: ${success_rate}% | 平均响应: ${avg_time}ms"
        rank=$((rank + 1))
    done
    
    # 输出最佳推荐
    if [ "${#sorted_results[@]}" -gt 0 ]; then
        IFS='|' read -r best_time best_url success_rate best_best_time best_worst_time <<< "${sorted_results[0]}"
        echo
        log_success "推荐使用: $best_url"
        echo "   理由: 平均响应时间最短 (${best_time}ms)，可用性 ${success_rate}%"
    fi
    
    # 输出格式处理
    case $OUTPUT_FORMAT in
        json)
            echo
            echo '{"test_results": ['
            local first=true
            for sorted_result in "${sorted_results[@]}"; do
                IFS='|' read -r avg_time url success_rate best_time worst_time <<< "$sorted_result"
                if $first; then
                    first=false
                else
                    echo ','
                fi
                cat << EOF
  {
    "url": "$url",
    "availability_percent": $success_rate,
    "avg_response_ms": $avg_time,
    "best_response_ms": $best_time,
    "worst_response_ms": $worst_time
  }
EOF
            done
            echo ']}'
            ;;
        markdown)
            echo
            echo '## CDN源测试结果'
            echo
            echo '| 排名 | URL | 可用性 | 平均响应时间 | 最佳响应时间 | 最差响应时间 |'
            echo '|------|-----|--------|-------------|-------------|-------------|'
            local rank=1
            for sorted_result in "${sorted_results[@]}"; do
                IFS='|' read -r avg_time url success_rate best_time worst_time <<< "$sorted_result"
                echo "| $rank | \`$url\` | ${success_rate}% | ${avg_time}ms | ${best_time}ms | ${worst_time}ms |"
                rank=$((rank + 1))
            done
            ;;
    esac
    
    exit 0
}

# 运行主函数
main "$@"