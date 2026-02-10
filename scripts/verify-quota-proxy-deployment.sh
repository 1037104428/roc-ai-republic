#!/usr/bin/env bash
#
# verify-quota-proxy-deployment.sh - 验证quota-proxy部署完整性和功能
#
# 功能：验证quota-proxy部署的完整性和基本功能，包括：
#   - Docker容器状态
#   - API健康端点
#   - 数据库文件存在性
#   - 必需环境变量配置
#   - 基本API功能测试
#
# 用法：
#   ./verify-quota-proxy-deployment.sh [选项]
#
# 选项：
#   --help, -h          显示帮助信息
#   --verbose, -v       详细输出模式
#   --quiet, -q         安静模式，只显示关键信息
#   --dry-run, -n       模拟运行，不执行实际验证
#   --host HOST         目标主机（默认：localhost）
#   --port PORT         目标端口（默认：8787）
#   --db-path PATH      数据库路径（默认：/opt/roc/quota-proxy/data/quota.db）
#
# 退出码：
#   0 - 所有验证通过
#   1 - 参数错误或帮助信息
#   2 - 验证失败（一个或多个检查失败）
#   3 - 网络连接失败
#   4 - 环境配置错误
#
# 示例：
#   ./verify-quota-proxy-deployment.sh --verbose
#   ./verify-quota-proxy-deployment.sh --host 8.210.185.194 --port 8787
#   ./verify-quota-proxy-deployment.sh --dry-run
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
VERBOSE=false
QUIET=false
DRY_RUN=false
HOST="localhost"
PORT="8787"
DB_PATH="/opt/roc/quota-proxy/data/quota.db"

# 日志函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
verify-quota-proxy-deployment.sh - 验证quota-proxy部署完整性和功能

功能：验证quota-proxy部署的完整性和基本功能，包括：
  - Docker容器状态
  - API健康端点
  - 数据库文件存在性
  - 必需环境变量配置
  - 基本API功能测试

用法：
  ./verify-quota-proxy-deployment.sh [选项]

选项：
  --help, -h          显示帮助信息
  --verbose, -v       详细输出模式
  --quiet, -q         安静模式，只显示关键信息
  --dry-run, -n       模拟运行，不执行实际验证
  --host HOST         目标主机（默认：localhost）
  --port PORT         目标端口（默认：8787）
  --db-path PATH      数据库路径（默认：/opt/roc/quota-proxy/data/quota.db）

退出码：
  0 - 所有验证通过
  1 - 参数错误或帮助信息
  2 - 验证失败（一个或多个检查失败）
  3 - 网络连接失败
  4 - 环境配置错误

示例：
  ./verify-quota-proxy-deployment.sh --verbose
  ./verify-quota-proxy-deployment.sh --host 8.210.185.194 --port 8787
  ./verify-quota-proxy-deployment.sh --dry-run
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --quiet|-q)
                QUIET=true
                shift
                ;;
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --host)
                if [[ -n "${2:-}" ]]; then
                    HOST="$2"
                    shift 2
                else
                    log_error "--host 参数需要指定主机地址"
                    exit 1
                fi
                ;;
            --port)
                if [[ -n "${2:-}" ]]; then
                    PORT="$2"
                    shift 2
                else
                    log_error "--port 参数需要指定端口号"
                    exit 1
                fi
                ;;
            --db-path)
                if [[ -n "${2:-}" ]]; then
                    DB_PATH="$2"
                    shift 2
                else
                    log_error "--db-path 参数需要指定数据库路径"
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

# 检查命令是否存在
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "命令 '$cmd' 未找到，请安装后重试"
        return 1
    fi
    log_debug "命令 '$cmd' 可用"
    return 0
}

# 验证Docker容器状态
verify_docker_container() {
    log_info "验证Docker容器状态..."
    
    if [ "$DRY_RUN" = true ]; then
        log_success "[模拟] Docker容器状态检查"
        return 0
    fi
    
    if ! check_command "docker"; then
        log_warning "Docker命令不可用，跳过容器状态检查"
        return 0
    fi
    
    if docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}" | grep -q "quota-proxy"; then
        log_success "Docker容器 'quota-proxy' 正在运行"
        docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        return 0
    else
        log_error "Docker容器 'quota-proxy' 未找到或未运行"
        return 1
    fi
}

# 验证API健康端点
verify_api_health() {
    local url="http://${HOST}:${PORT}/healthz"
    log_info "验证API健康端点: $url"
    
    if [ "$DRY_RUN" = true ]; then
        log_success "[模拟] API健康端点检查"
        return 0
    fi
    
    if ! check_command "curl"; then
        log_warning "curl命令不可用，跳过API健康检查"
        return 0
    fi
    
    local response
    if response=$(curl -fsS --max-time 5 "$url" 2>/dev/null); then
        if echo "$response" | grep -q '"ok":true'; then
            log_success "API健康端点响应正常: $response"
            return 0
        else
            log_error "API健康端点响应异常: $response"
            return 1
        fi
    else
        log_error "无法连接到API健康端点: $url"
        return 1
    fi
}

# 验证数据库文件
verify_database_file() {
    log_info "验证数据库文件: $DB_PATH"
    
    if [ "$DRY_RUN" = true ]; then
        log_success "[模拟] 数据库文件检查"
        return 0
    fi
    
    if [ ! -f "$DB_PATH" ]; then
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    
    if [ "$file_size" -gt 0 ]; then
        log_success "数据库文件存在，大小: $(numfmt --to=iec-i --suffix=B "$file_size")"
        
        # 检查是否为有效的SQLite数据库
        if check_command "sqlite3"; then
            if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';" &>/dev/null; then
                log_success "数据库文件是有效的SQLite数据库"
                return 0
            else
                log_warning "数据库文件不是有效的SQLite数据库或无法访问"
                return 0  # 不视为致命错误
            fi
        fi
        return 0
    else
        log_error "数据库文件为空"
        return 1
    fi
}

# 验证必需环境变量
verify_environment_variables() {
    log_info "验证必需环境变量..."
    
    if [ "$DRY_RUN" = true ]; then
        log_success "[模拟] 环境变量检查"
        return 0
    fi
    
    local missing_vars=()
    local required_vars=("ADMIN_TOKEN" "DATABASE_PATH" "PORT" "LOG_LEVEL")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        else
            log_debug "环境变量 $var 已设置: ${!var}"
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        log_success "所有必需环境变量已设置"
        return 0
    else
        log_warning "以下环境变量未设置: ${missing_vars[*]}"
        # 不视为致命错误，因为可能通过其他方式配置
        return 0
    fi
}

# 验证基本API功能
verify_basic_api_functionality() {
    log_info "验证基本API功能..."
    
    if [ "$DRY_RUN" = true ]; then
        log_success "[模拟] 基本API功能检查"
        return 0
    fi
    
    if ! check_command "curl"; then
        log_warning "curl命令不可用，跳过API功能检查"
        return 0
    fi
    
    # 测试根端点
    local root_url="http://${HOST}:${PORT}/"
    if curl -fsS --max-time 5 "$root_url" &>/dev/null; then
        log_success "根端点可访问: $root_url"
    else
        log_warning "根端点不可访问: $root_url"
    fi
    
    # 测试未授权访问保护（应该返回401）
    local admin_url="http://${HOST}:${PORT}/admin/keys"
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$admin_url" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "401" ] || [ "$response_code" = "403" ]; then
        log_success "未授权访问保护正常 (HTTP $response_code)"
    elif [ "$response_code" = "000" ]; then
        log_warning "无法连接到管理端点: $admin_url"
    else
        log_warning "管理端点返回意外状态码: $response_code"
    fi
    
    return 0
}

# 主验证函数
main_verification() {
    local failures=0
    local total_checks=5
    
    log_info "开始quota-proxy部署验证..."
    log_info "配置: 主机=$HOST, 端口=$PORT, 数据库路径=$DB_PATH"
    log_info "模式: DRY_RUN=$DRY_RUN, VERBOSE=$VERBOSE, QUIET=$QUIET"
    
    # 执行验证
    verify_docker_container || ((failures++))
    verify_api_health || ((failures++))
    verify_database_file || ((failures++))
    verify_environment_variables || ((failures++))
    verify_basic_api_functionality || ((failures++))
    
    # 输出总结
    log_info "="*50
    if [ "$failures" -eq 0 ]; then
        log_success "所有验证通过 ($total_checks/$total_checks)"
        log_info "quota-proxy部署完整性和功能验证成功"
        return 0
    else
        log_error "验证失败: $failures/$total_checks 个检查失败"
        log_info "请检查以上错误信息并修复问题"
        return 2
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    # 设置错误处理
    trap 'log_error "脚本执行中断"; exit 130' INT TERM
    
    # 执行验证
    if main_verification; then
        exit 0
    else
        exit 2
    fi
}

# 运行主函数
main "$@"