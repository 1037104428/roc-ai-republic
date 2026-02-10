#!/usr/bin/env bash
#
# quota-proxy 健康检查脚本
# 检查 quota-proxy Docker 容器的运行状态和 API 健康状态
#
# 用法：
#   ./check-quota-proxy-health.sh [选项]
#
# 选项：
#   -h, --help           显示帮助信息
#   -v, --verbose        详细输出模式
#   -q, --quiet          安静模式，只输出关键信息
#   -d, --dry-run        模拟运行，不实际执行检查
#   --host HOST          服务器主机地址（默认：127.0.0.1）
#   --port PORT          服务端口（默认：8787）
#   --timeout SECONDS    超时时间（默认：10秒）
#   --docker-compose-path PATH  docker-compose.yml 路径（默认：当前目录）
#
# 退出码：
#   0 - 所有检查通过
#   1 - 参数错误或帮助信息
#   2 - Docker 容器检查失败
#   3 - API 健康检查失败
#   4 - 数据库连接检查失败（如果配置了数据库）
#   5 - 其他错误
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
HOST="127.0.0.1"
PORT="8787"
TIMEOUT=10
DOCKER_COMPOSE_PATH="."

# 输出函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 健康检查脚本

检查 quota-proxy Docker 容器的运行状态和 API 健康状态。

用法：
  $0 [选项]

选项：
  -h, --help           显示帮助信息
  -v, --verbose        详细输出模式
  -q, --quiet          安静模式，只输出关键信息
  -d, --dry-run        模拟运行，不实际执行检查
  --host HOST          服务器主机地址（默认：127.0.0.1）
  --port PORT          服务端口（默认：8787）
  --timeout SECONDS    超时时间（默认：10秒）
  --docker-compose-path PATH  docker-compose.yml 路径（默认：当前目录）

检查项目：
  1. Docker 容器状态检查
  2. API 健康端点检查 (/healthz)
  3. 数据库连接检查（如果配置了数据库环境变量）

退出码：
  0 - 所有检查通过
  1 - 参数错误或帮助信息
  2 - Docker 容器检查失败
  3 - API 健康检查失败
  4 - 数据库连接检查失败
  5 - 其他错误

示例：
  $0 --host 127.0.0.1 --port 8787
  $0 --verbose --docker-compose-path /opt/roc/quota-proxy
  $0 --quiet --timeout 5
EOF
}

# 解析命令行参数
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
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --host)
                HOST="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --docker-compose-path)
                DOCKER_COMPOSE_PATH="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查 Docker 容器状态
check_docker_container() {
    log_info "检查 Docker 容器状态..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "模拟运行：检查 Docker 容器状态"
        log_debug "docker-compose -f \"$DOCKER_COMPOSE_PATH/docker-compose.yml\" ps --services --filter \"status=running\""
        return 0
    fi
    
    # 检查 docker-compose.yml 文件是否存在
    if [ ! -f "$DOCKER_COMPOSE_PATH/docker-compose.yml" ]; then
        log_error "docker-compose.yml 文件不存在: $DOCKER_COMPOSE_PATH/docker-compose.yml"
        return 2
    fi
    
    # 检查容器是否运行
    cd "$DOCKER_COMPOSE_PATH" || {
        log_error "无法切换到目录: $DOCKER_COMPOSE_PATH"
        return 2
    }
    
    local running_services
    running_services=$(docker compose ps --services --filter "status=running" 2>/dev/null || docker-compose ps --services --filter "status=running" 2>/dev/null)
    
    if [ -z "$running_services" ]; then
        log_error "没有运行中的容器"
        return 2
    fi
    
    # 检查 quota-proxy 服务是否在运行
    if echo "$running_services" | grep -q "quota-proxy"; then
        log_success "quota-proxy 容器正在运行"
        
        # 获取详细状态
        local container_status
        container_status=$(docker compose ps quota-proxy 2>/dev/null || docker-compose ps quota-proxy 2>/dev/null)
        log_debug "容器状态:\n$container_status"
        
        # 检查容器健康状态
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose ps -q quota-proxy 2>/dev/null || docker-compose ps -q quota-proxy 2>/dev/null)" 2>/dev/null || echo "unknown")
        
        if [ "$health_status" = "healthy" ]; then
            log_success "容器健康状态: $health_status"
        elif [ "$health_status" = "unknown" ]; then
            log_warning "容器健康状态: $health_status (未配置健康检查)"
        else
            log_warning "容器健康状态: $health_status"
        fi
        
        return 0
    else
        log_error "quota-proxy 容器未运行"
        return 2
    fi
}

# 检查 API 健康端点
check_api_health() {
    log_info "检查 API 健康端点..."
    
    local health_url="http://$HOST:$PORT/healthz"
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "模拟运行：检查 API 健康端点"
        log_debug "curl -fsS --max-time $TIMEOUT \"$health_url\""
        return 0
    fi
    
    # 使用 curl 检查健康端点
    local response
    response=$(curl -fsS --max-time "$TIMEOUT" "$health_url" 2>/dev/null || true)
    
    if [ -z "$response" ]; then
        log_error "无法连接到健康端点: $health_url"
        return 3
    fi
    
    # 检查响应是否为有效的 JSON
    if echo "$response" | jq -e . >/dev/null 2>&1; then
        # 检查响应内容
        local ok_status
        ok_status=$(echo "$response" | jq -r '.ok // false')
        
        if [ "$ok_status" = "true" ]; then
            log_success "API 健康检查通过: $response"
            return 0
        else
            log_error "API 健康检查失败: $response"
            return 3
        fi
    else
        # 如果不是 JSON，检查是否为简单的 "ok" 响应
        if [ "$response" = "ok" ] || [ "$response" = "OK" ]; then
            log_success "API 健康检查通过: $response"
            return 0
        else
            log_error "API 返回无效响应: $response"
            return 3
        fi
    fi
}

# 检查数据库连接（如果配置了数据库）
check_database_connection() {
    log_info "检查数据库连接..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "模拟运行：检查数据库连接"
        return 0
    fi
    
    # 检查环境变量中是否有数据库配置
    local db_path
    db_path=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$(docker compose ps -q quota-proxy 2>/dev/null || docker-compose ps -q quota-proxy 2>/dev/null)" 2>/dev/null | grep -E '^DATABASE_PATH=|^DB_PATH=' | cut -d= -f2 || echo "")
    
    if [ -z "$db_path" ]; then
        log_warning "未找到数据库路径配置，跳过数据库连接检查"
        return 0
    fi
    
    log_debug "数据库路径: $db_path"
    
    # 检查数据库文件是否存在（在容器内）
    local container_id
    container_id=$(docker compose ps -q quota-proxy 2>/dev/null || docker-compose ps -q quota-proxy 2>/dev/null)
    
    if [ -z "$container_id" ]; then
        log_error "无法获取容器 ID"
        return 4
    fi
    
    # 检查数据库文件是否存在
    if docker exec "$container_id" test -f "$db_path" 2>/dev/null; then
        log_success "数据库文件存在: $db_path"
        
        # 检查数据库是否可读
        if docker exec "$container_id" sqlite3 "$db_path" "SELECT 1;" 2>/dev/null; then
            log_success "数据库连接正常"
            return 0
        else
            log_error "数据库无法连接或查询失败"
            return 4
        fi
    else
        log_error "数据库文件不存在: $db_path"
        return 4
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "开始 quota-proxy 健康检查"
    log_debug "配置: host=$HOST, port=$PORT, timeout=$TIMEOUT, docker-compose-path=$DOCKER_COMPOSE_PATH"
    log_debug "模式: verbose=$VERBOSE, quiet=$QUIET, dry-run=$DRY_RUN"
    
    local exit_code=0
    local failed_checks=()
    
    # 执行检查
    if ! check_docker_container; then
        exit_code=2
        failed_checks+=("Docker容器检查")
    fi
    
    if ! check_api_health; then
        exit_code=3
        failed_checks+=("API健康检查")
    fi
    
    if ! check_database_connection; then
        # 数据库检查失败不影响整体健康状态，只记录警告
        if [ $? -eq 4 ]; then
            failed_checks+=("数据库连接检查")
            # 数据库检查失败不改变退出码，除非其他检查也失败
            if [ $exit_code -eq 0 ]; then
                exit_code=4
            fi
        fi
    fi
    
    # 输出总结
    if [ ${#failed_checks[@]} -eq 0 ]; then
        log_success "所有健康检查通过"
        if [ "$QUIET" = false ]; then
            echo -e "${GREEN}✓ 健康状态: 正常${NC}"
        fi
    else
        log_error "健康检查失败: ${failed_checks[*]}"
        if [ "$QUIET" = false ]; then
            echo -e "${RED}✗ 健康状态: 异常${NC}"
            echo -e "${RED}失败项目: ${failed_checks[*]}${NC}"
        fi
    fi
    
    log_info "健康检查完成，退出码: $exit_code"
    exit $exit_code
}

# 运行主函数
main "$@"