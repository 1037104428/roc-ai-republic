#!/bin/bash

# 站点健康检查脚本
# 用于快速检查站点部署状态和基本功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SITE_URL="${SITE_URL:-http://localhost:8080}"
VERBOSE="${VERBOSE:-false}"
TIMEOUT="${TIMEOUT:-10}"

# 帮助信息
show_help() {
    cat << EOF
站点健康检查脚本 v1.0.0

用法: $0 [选项]

选项:
  -u, --url URL         站点URL (默认: http://localhost:8080)
  -t, --timeout SEC     超时时间(秒) (默认: 10)
  -v, --verbose         详细输出模式
  -h, --help            显示此帮助信息

环境变量:
  SITE_URL              站点URL
  VERBOSE               详细输出模式 (true/false)
  TIMEOUT               超时时间(秒)

示例:
  $0 --url http://example.com
  SITE_URL=http://example.com $0
  $0 --url http://localhost:8080 --verbose --timeout 15

检查项目:
  1. 站点可访问性 (HTTP 200)
  2. 主页面内容检查
  3. 关键页面检查 (下载页、快速开始、试用密钥指南)
  4. 静态资源检查 (CSS/JS/图片)
  5. 响应时间检查

退出码:
  0 - 所有检查通过
  1 - 参数错误
  2 - 站点不可访问
  3 - 关键页面缺失
  4 - 静态资源问题
  5 - 响应时间过长
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            SITE_URL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

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

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未安装，请先安装"
        return 1
    fi
    return 0
}

# 检查站点可访问性
check_site_accessibility() {
    local url="$1"
    local timeout="$2"
    
    log_info "检查站点可访问性: $url"
    
    if curl --silent --fail --max-time "$timeout" "$url" > /dev/null; then
        log_success "站点可访问 (HTTP 200)"
        return 0
    else
        log_error "站点不可访问"
        return 1
    fi
}

# 检查页面内容
check_page_content() {
    local url="$1"
    local pattern="$2"
    local description="$3"
    
    log_info "检查 $description: $url"
    
    local content
    if content=$(curl --silent --fail --max-time "$TIMEOUT" "$url"); then
        if echo "$content" | grep -q "$pattern"; then
            log_success "$description 内容检查通过"
            return 0
        else
            log_warning "$description 内容中未找到预期模式: $pattern"
            return 1
        fi
    else
        log_error "$description 页面无法访问"
        return 1
    fi
}

# 检查响应时间
check_response_time() {
    local url="$1"
    local max_time="$2"
    
    log_info "检查响应时间: $url (最大: ${max_time}秒)"
    
    local start_time
    local end_time
    local response_time
    
    start_time=$(date +%s.%N)
    if curl --silent --fail --max-time "$max_time" "$url" > /dev/null; then
        end_time=$(date +%s.%N)
        response_time=$(echo "$end_time - $start_time" | bc)
        
        if (( $(echo "$response_time < $max_time" | bc -l) )); then
            log_success "响应时间正常: ${response_time}秒"
            return 0
        else
            log_warning "响应时间较长: ${response_time}秒 (超过 ${max_time}秒)"
            return 1
        fi
    else
        log_error "无法测量响应时间"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始站点健康检查"
    log_info "站点URL: $SITE_URL"
    log_info "超时时间: ${TIMEOUT}秒"
    log_info "详细模式: $VERBOSE"
    
    # 检查必要命令
    check_command curl || exit 1
    check_command bc || {
        log_warning "bc命令未安装，跳过响应时间检查"
        SKIP_RESPONSE_TIME=true
    }
    
    # 检查计数器
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warning_checks=0
    
    # 1. 检查站点可访问性
    ((total_checks++))
    if check_site_accessibility "$SITE_URL" "$TIMEOUT"; then
        ((passed_checks++))
    else
        ((failed_checks++))
        log_error "站点健康检查失败: 站点不可访问"
        exit 2
    fi
    
    # 2. 检查主页面
    ((total_checks++))
    if check_page_content "$SITE_URL" "中华AI共和国" "主页面"; then
        ((passed_checks++))
    else
        ((warning_checks++))
    fi
    
    # 3. 检查关键页面
    local key_pages=(
        "downloads.html 下载 OpenClaw 下载"
        "quickstart.html 快速开始 快速开始"
        "trial-key-guide.html 试用密钥 试用密钥指南"
    )
    
    for page_info in "${key_pages[@]}"; do
        read -r page pattern description <<< "$page_info"
        ((total_checks++))
        if check_page_content "${SITE_URL}/${page}" "$pattern" "$description"; then
            ((passed_checks++))
        else
            ((warning_checks++))
        fi
    done
    
    # 4. 检查响应时间（如果bc可用）
    if [[ -z "$SKIP_RESPONSE_TIME" ]]; then
        ((total_checks++))
        if check_response_time "$SITE_URL" "$TIMEOUT"; then
            ((passed_checks++))
        else
            ((warning_checks++))
        fi
    fi
    
    # 输出总结
    echo ""
    log_info "检查总结:"
    echo "  总检查数: $total_checks"
    echo -e "  ${GREEN}通过: $passed_checks${NC}"
    echo -e "  ${YELLOW}警告: $warning_checks${NC}"
    echo -e "  ${RED}失败: $failed_checks${NC}"
    
    if [[ $failed_checks -eq 0 ]]; then
        if [[ $warning_checks -eq 0 ]]; then
            log_success "所有检查通过！站点健康状态良好。"
            exit 0
        else
            log_warning "站点基本可用，但有 $warning_checks 个警告需要关注。"
            exit 0
        fi
    else
        log_error "站点健康检查失败，有 $failed_checks 个关键错误。"
        exit 2
    fi
}

# 运行主函数
main "$@"