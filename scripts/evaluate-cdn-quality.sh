#!/bin/bash

# 连接质量评估脚本
# 用于评估不同CDN源的连接质量，为install-cn.sh选择最优源提供数据支持

set -e

SCRIPT_VERSION="2026.02.11.01"
SCRIPT_NAME="CDN连接质量评估脚本"
SCRIPT_DESC="评估不同CDN源的连接质量，包括ping延迟、下载速度和连接稳定性"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认CDN源列表
DEFAULT_CDN_SOURCES=(
    "https://mirrors.aliyun.com"
    "https://mirrors.cloud.tencent.com"
    "https://mirrors.huaweicloud.com"
    "https://mirrors.163.com"
    "https://mirrors.bfsu.edu.cn"
    "https://mirrors.tuna.tsinghua.edu.cn"
    "https://mirrors.ustc.edu.cn"
    "https://mirrors.sjtug.sjtu.edu.cn"
)

# 测试文件（用于下载速度测试）
TEST_FILE="1M.test"
TEST_FILE_SIZE=1048576  # 1MB in bytes

# 输出格式
OUTPUT_FORMAT="text"  # text, json, markdown

# 帮助信息
show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}
${SCRIPT_DESC}

用法: $0 [选项]

选项:
  -s, --sources <源列表>    要测试的CDN源URL列表，用逗号分隔
                            默认: ${DEFAULT_CDN_SOURCES[0]},${DEFAULT_CDN_SOURCES[1]},...
  -t, --timeout <秒>        每个测试的超时时间（默认: 5）
  -r, --retries <次数>      失败重试次数（默认: 2）
  -f, --format <格式>       输出格式: text, json, markdown（默认: text）
  -v, --verbose             详细输出模式
  -q, --quiet               安静模式，只输出结果
  --test-file <文件名>      用于下载速度测试的文件名（默认: ${TEST_FILE}）
  --test-size <字节数>      测试文件大小（默认: ${TEST_FILE_SIZE}）
  -h, --help                显示此帮助信息
  --version                 显示版本信息

示例:
  $0 --sources "https://mirrors.aliyun.com,https://mirrors.cloud.tencent.com"
  $0 --timeout 3 --retries 1 --format json
  $0 --verbose --format markdown

EOF
}

# 显示版本信息
show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
}

# 日志函数
log_info() {
    if [[ "$VERBOSE" == "true" || "$QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "需要命令: $1，但未找到"
        return 1
    fi
    return 0
}

# 测试ping延迟
test_ping_latency() {
    local url="$1"
    local host
    host=$(echo "$url" | sed -e 's|^https\?://||' -e 's|/.*||')
    
    if ! check_command "ping"; then
        echo "N/A"
        return
    fi
    
    # 发送4个ping包，取平均延迟
    local result
    result=$(ping -c 4 -W "$TIMEOUT" "$host" 2>/dev/null | grep -E "rtt min/avg/max/mdev" | awk -F'/' '{print $5}')
    
    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "N/A"
    fi
}

# 测试下载速度
test_download_speed() {
    local url="$1"
    local test_url="${url}/${TEST_FILE}"
    
    if ! check_command "curl"; then
        echo "N/A"
        return
    fi
    
    # 下载测试文件，计算速度
    local start_time
    local end_time
    local download_time
    local speed_kbps
    
    start_time=$(date +%s.%N)
    
    if curl -s -f --max-time "$TIMEOUT" -o /dev/null "$test_url" 2>/dev/null; then
        end_time=$(date +%s.%N)
        download_time=$(echo "$end_time - $start_time" | bc)
        
        if (( $(echo "$download_time > 0" | bc -l) )); then
            # 计算速度 (KB/s)
            speed_kbps=$(echo "scale=2; $TEST_FILE_SIZE / 1024 / $download_time" | bc)
            echo "$speed_kbps"
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

# 测试连接稳定性
test_connection_stability() {
    local url="$1"
    local success_count=0
    
    for ((i=1; i<=3; i++)); do
        if curl -s -f --max-time "$TIMEOUT" -o /dev/null "$url" 2>/dev/null; then
            ((success_count++))
        fi
        sleep 0.5
    done
    
    # 计算成功率百分比
    local success_rate
    success_rate=$((success_count * 100 / 3))
    echo "$success_rate"
}

# 计算质量分数
calculate_quality_score() {
    local latency="$1"
    local speed="$2"
    local stability="$3"
    local score=0
    
    # 延迟评分（越低越好）
    if [[ "$latency" != "N/A" ]]; then
        if (( $(echo "$latency < 50" | bc -l) )); then
            score=$((score + 40))
        elif (( $(echo "$latency < 100" | bc -l) )); then
            score=$((score + 30))
        elif (( $(echo "$latency < 200" | bc -l) )); then
            score=$((score + 20))
        else
            score=$((score + 10))
        fi
    fi
    
    # 速度评分（越高越好）
    if [[ "$speed" != "N/A" ]]; then
        if (( $(echo "$speed > 1000" | bc -l) )); then
            score=$((score + 40))
        elif (( $(echo "$speed > 500" | bc -l) )); then
            score=$((score + 30))
        elif (( $(echo "$speed > 100" | bc -l) )); then
            score=$((score + 20))
        else
            score=$((score + 10))
        fi
    fi
    
    # 稳定性评分
    if [[ "$stability" != "N/A" ]]; then
        score=$((score + stability / 5))  # 将百分比转换为0-20分
    fi
    
    echo "$score"
}

# 文本格式输出
output_text() {
    local results=("$@")
    
    echo "="*60
    echo "CDN连接质量评估报告"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "="*60
    echo ""
    
    printf "%-40s %-12s %-15s %-12s %-10s\n" "CDN源" "延迟(ms)" "速度(KB/s)" "稳定性(%)" "质量分"
    printf "%-40s %-12s %-15s %-12s %-10s\n" "------" "---------" "-----------" "---------" "------"
    
    for result in "${results[@]}"; do
        IFS='|' read -r url latency speed stability score <<< "$result"
        printf "%-40s %-12s %-15s %-12s %-10s\n" "$url" "$latency" "$speed" "$stability" "$score"
    done
    
    echo ""
    echo "质量评分说明:"
    echo "  - 90-100: 优秀 - 延迟低、速度快、稳定性高"
    echo "  - 70-89:  良好 - 各方面表现良好"
    echo "  - 50-69:  一般 - 基本可用，可能有优化空间"
    echo "  - 0-49:   较差 - 建议考虑其他源"
}

# JSON格式输出
output_json() {
    local results=("$@")
    
    echo "["
    for ((i=0; i<${#results[@]}; i++)); do
        IFS='|' read -r url latency speed stability score <<< "${results[i]}"
        
        cat << EOF
  {
    "url": "$url",
    "latency_ms": "$latency",
    "speed_kbps": "$speed",
    "stability_percent": "$stability",
    "quality_score": "$score"
  }$( ((i < ${#results[@]}-1)) && echo "," )
EOF
    done
    echo "]"
}

# Markdown格式输出
output_markdown() {
    local results=("$@")
    
    echo "# CDN连接质量评估报告"
    echo ""
    echo "**生成时间**: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    echo "## 评估结果"
    echo ""
    echo "| CDN源 | 延迟(ms) | 速度(KB/s) | 稳定性(%) | 质量分 |"
    echo "|-------|----------|------------|-----------|--------|"
    
    for result in "${results[@]}"; do
        IFS='|' read -r url latency speed stability score <<< "$result"
        echo "| $url | $latency | $speed | $stability | $score |"
    done
    
    echo ""
    echo "## 质量评分说明"
    echo ""
    echo "- **90-100**: 优秀 - 延迟低、速度快、稳定性高"
    echo "- **70-89**: 良好 - 各方面表现良好"
    echo "- **50-69**: 一般 - 基本可用，可能有优化空间"
    echo "- **0-49**: 较差 - 建议考虑其他源"
}

# 主函数
main() {
    # 解析参数
    local SOURCES=()
    local TIMEOUT=5
    local RETRIES=2
    local VERBOSE=false
    local QUIET=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--sources)
                IFS=',' read -ra SOURCES <<< "$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -r|--retries)
                RETRIES="$2"
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
            --test-file)
                TEST_FILE="$2"
                shift 2
                ;;
            --test-size)
                TEST_FILE_SIZE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定源，使用默认源
    if [[ ${#SOURCES[@]} -eq 0 ]]; then
        SOURCES=("${DEFAULT_CDN_SOURCES[@]}")
    fi
    
    log_info "开始CDN连接质量评估..."
    log_info "测试源数量: ${#SOURCES[@]}"
    log_info "超时时间: ${TIMEOUT}秒"
    log_info "输出格式: ${OUTPUT_FORMAT}"
    
    # 检查必要命令
    check_command "curl" || exit 1
    check_command "bc" || exit 1
    
    # 测试每个源
    local results=()
    local total_sources=${#SOURCES[@]}
    local current_source=1
    
    for url in "${SOURCES[@]}"; do
        log_info "测试源 ${current_source}/${total_sources}: $url"
        
        # 测试延迟
        log_info "  测试ping延迟..."
        local latency
        latency=$(test_ping_latency "$url")
        
        # 测试下载速度
        log_info "  测试下载速度..."
        local speed
        speed=$(test_download_speed "$url")
        
        # 测试连接稳定性
        log_info "  测试连接稳定性..."
        local stability
        stability=$(test_connection_stability "$url")
        
        # 计算质量分数
        local score
        score=$(calculate_quality_score "$latency" "$speed" "$stability")
        
        # 保存结果
        results+=("${url}|${latency}|${speed}|${stability}|${score}")
        
        log_info "  结果: 延迟=${latency}ms, 速度=${speed}KB/s, 稳定性=${stability}%, 质量分=${score}"
        
        ((current_source++))
        
        # 避免请求过于频繁
        sleep 1
    done
    
    # 按质量分排序
    IFS=$'\n' sorted_results=($(printf "%s\n" "${results[@]}" | sort -t'|' -k5 -nr))
    unset IFS
    
    # 输出结果
    case $OUTPUT_FORMAT in
        "text")
            output_text "${sorted_results[@]}"
            ;;
        "json")
            output_json "${sorted_results[@]}"
            ;;
        "markdown")
            output_markdown "${sorted_results[@]}"
            ;;
        *)
            log_error "不支持的输出格式: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    log_success "CDN连接质量评估完成!"
    
    # 输出推荐结果
    if [[ ${#sorted_results[@]} -gt 0 ]]; then
        IFS='|' read -r best_url best_latency best_speed best_stability best_score <<< "${sorted_results[0]}"
        log_info "推荐使用: $best_url (质量分: $best_score)"
    fi
}

# 运行主函数
main "$@"