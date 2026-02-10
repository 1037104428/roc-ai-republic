#!/bin/bash
# query-api-usage.sh - 查询quota-proxy API密钥使用情况
# 支持查询单个密钥或所有密钥的使用统计

set -euo pipefail

# 默认配置
DEFAULT_SERVER="127.0.0.1:8787"
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-}"
QUIET_MODE=false
VERBOSE_MODE=false
API_KEY=""
SHOW_ALL=false

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
查询quota-proxy API密钥使用情况

用法: $0 [选项]

选项:
  -s, --server HOST:PORT    quota-proxy服务器地址 (默认: ${DEFAULT_SERVER})
  -t, --token TOKEN         管理员令牌 (默认: 从ADMIN_TOKEN环境变量读取)
  -k, --key API_KEY         查询指定API密钥的使用情况
  -a, --all                 查询所有API密钥的使用统计
  -q, --quiet               安静模式，只输出关键信息
  -v, --verbose             详细模式，输出更多调试信息
  -h, --help                显示此帮助信息

示例:
  $0 -s 127.0.0.1:8787 -t "admin-token-here" -k "test-key-123"
  $0 -s 127.0.0.1:8787 -t "admin-token-here" -a
  ADMIN_TOKEN="admin-token-here" $0 -a

环境变量:
  ADMIN_TOKEN   管理员令牌，用于认证quota-proxy管理接口

EOF
}

# 日志函数
log_info() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [ "$VERBOSE_MODE" = true ]; then
        echo -e "[DEBUG] $*"
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必要的依赖: ${missing_deps[*]}"
        log_error "请安装:"
        for dep in "${missing_deps[@]}"; do
            log_error "  - $dep"
        done
        exit 1
    fi
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server)
                SERVER="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -k|--key)
                API_KEY="$2"
                shift 2
                ;;
            -a|--all)
                SHOW_ALL=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置默认值
    SERVER="${SERVER:-$DEFAULT_SERVER}"
    
    # 验证参数
    if [ -z "$ADMIN_TOKEN" ]; then
        log_error "管理员令牌未提供"
        log_error "请使用 -t 参数或设置 ADMIN_TOKEN 环境变量"
        exit 1
    fi
    
    if [ -z "$API_KEY" ] && [ "$SHOW_ALL" = false ]; then
        log_error "请指定要查询的API密钥 (-k) 或查询所有密钥 (-a)"
        exit 1
    fi
    
    if [ -n "$API_KEY" ] && [ "$SHOW_ALL" = true ]; then
        log_warning "同时指定了 -k 和 -a 参数，将查询所有密钥"
    fi
}

# 检查服务器连接
check_server_connection() {
    log_info "检查服务器连接: http://${SERVER}/healthz"
    
    local response
    if response=$(curl -s -f "http://${SERVER}/healthz" 2>/dev/null); then
        log_success "服务器连接正常"
        log_debug "健康检查响应: $response"
        return 0
    else
        log_error "无法连接到服务器: http://${SERVER}/healthz"
        return 1
    fi
}

# 查询单个API密钥使用情况
query_single_key() {
    local key="$1"
    log_info "查询API密钥使用情况: ${key:0:8}..."
    
    local url="http://${SERVER}/admin/usage"
    local response
    
    if response=$(curl -s -f -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -X GET "${url}?key=${key}" 2>/dev/null); then
        
        log_success "查询成功"
        echo "API密钥使用统计:"
        echo "================="
        echo "$response" | jq .
    else
        log_error "查询失败"
        log_debug "响应: $response"
        return 1
    fi
}

# 查询所有API密钥使用情况
query_all_keys() {
    log_info "查询所有API密钥使用统计"
    
    local url="http://${SERVER}/admin/usage"
    local response
    
    if response=$(curl -s -f -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -X GET "${url}" 2>/dev/null); then
        
        log_success "查询成功"
        
        local total_keys
        total_keys=$(echo "$response" | jq '.keys | length' 2>/dev/null || echo "0")
        
        if [ "$total_keys" -gt 0 ]; then
            echo "所有API密钥使用统计 (共 $total_keys 个密钥):"
            echo "=========================================="
            echo "$response" | jq .
            
            # 显示摘要信息
            local total_used=0
            local total_remaining=0
            
            for i in $(seq 0 $((total_keys - 1))); do
                local used=$(echo "$response" | jq ".keys[$i].used // 0")
                local remaining=$(echo "$response" | jq ".keys[$i].remaining // 0")
                total_used=$((total_used + used))
                total_remaining=$((total_remaining + remaining))
            done
            
            echo ""
            echo "使用情况摘要:"
            echo "-------------"
            echo "总使用量: $total_used"
            echo "总剩余量: $total_remaining"
            echo "总配额: $((total_used + total_remaining))"
        else
            echo "没有找到API密钥使用记录"
        fi
    else
        log_error "查询失败"
        log_debug "响应: $response"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始查询quota-proxy API使用情况"
    log_debug "参数: SERVER=$SERVER, SHOW_ALL=$SHOW_ALL, API_KEY=$API_KEY"
    
    # 检查依赖
    check_dependencies
    
    # 检查服务器连接
    if ! check_server_connection; then
        exit 1
    fi
    
    # 执行查询
    if [ "$SHOW_ALL" = true ]; then
        query_all_keys
    elif [ -n "$API_KEY" ]; then
        query_single_key "$API_KEY"
    fi
    
    log_success "查询完成"
}

# 捕获退出信号
trap 'log_error "脚本被中断"; exit 130' INT TERM

# 执行主函数
parse_args "$@"
main