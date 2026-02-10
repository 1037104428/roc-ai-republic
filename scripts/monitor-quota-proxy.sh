#!/bin/bash

# quota-proxy 状态监控脚本
# 提供实时服务状态监控和关键指标查看功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_TIMEOUT=5
DEFAULT_INTERVAL=10

# 帮助信息
show_help() {
    cat << EOF
${BOLD}quota-proxy 状态监控脚本${NC}

${CYAN}用法:${NC}
  $(basename "$0") [选项]

${CYAN}选项:${NC}
  -h, --help              显示此帮助信息
  -H, --host HOST         指定 quota-proxy 主机地址 (默认: ${DEFAULT_HOST})
  -p, --port PORT         指定 quota-proxy 端口 (默认: ${DEFAULT_PORT})
  -t, --timeout SECONDS   请求超时时间 (默认: ${DEFAULT_TIMEOUT}秒)
  -i, --interval SECONDS  监控间隔时间 (默认: ${DEFAULT_INTERVAL}秒)
  -c, --continuous        持续监控模式
  -o, --once              单次检查模式 (默认)
  -v, --verbose           详细输出模式
  -q, --quiet             安静输出模式 (仅显示关键信息)
  -d, --dry-run           模拟运行，不实际发送请求
  --no-color              禁用彩色输出

${CYAN}示例:${NC}
  $(basename "$0")                        # 单次检查本地服务状态
  $(basename "$0") -c -i 30               # 持续监控，每30秒检查一次
  $(basename "$0") -H 192.168.1.100 -p 8080  # 检查远程服务
  $(basename "$0") --dry-run              # 模拟运行

${CYAN}退出码:${NC}
  0: 服务正常
  1: 服务异常
  2: 配置错误
  3: 网络错误
  4: 脚本执行错误

${CYAN}功能:${NC}
  - Docker 容器状态检查
  - API 健康端点检查
  - 数据库连接状态
  - 服务运行时间
  - 关键指标统计
  - 实时状态监控
EOF
}

# 解析命令行参数
parse_args() {
    HOST="$DEFAULT_HOST"
    PORT="$DEFAULT_PORT"
    TIMEOUT="$DEFAULT_TIMEOUT"
    INTERVAL="$DEFAULT_INTERVAL"
    CONTINUOUS=false
    VERBOSE=false
    QUIET=false
    DRY_RUN=false
    NO_COLOR=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -o|--once)
                CONTINUOUS=false
                shift
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
            --no-color)
                NO_COLOR=true
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}" >&2
                exit 2
                ;;
        esac
    done
    
    # 验证参数
    if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        echo -e "${RED}错误: 端口号必须为1-65535之间的数字${NC}" >&2
        exit 2
    fi
    
    if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]] || (( TIMEOUT < 1 )); then
        echo -e "${RED}错误: 超时时间必须为正整数${NC}" >&2
        exit 2
    fi
    
    if [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || (( INTERVAL < 1 )); then
        echo -e "${RED}错误: 监控间隔必须为正整数${NC}" >&2
        exit 2
    fi
}

# 检查 Docker 容器状态
check_docker_status() {
    if command -v docker &> /dev/null; then
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q quota-proxy; then
            local container_info=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep quota-proxy)
            echo -e "${GREEN}✓ Docker 容器状态:${NC}"
            echo "$container_info" | while read line; do
                echo -e "  ${CYAN}$line${NC}"
            done
            return 0
        else
            echo -e "${YELLOW}⚠ Docker 容器未找到或未运行${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Docker 命令未找到，跳过容器状态检查${NC}"
        return 2
    fi
}

# 检查 API 健康端点
check_health_endpoint() {
    local url="http://${HOST}:${PORT}/healthz"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${MAGENTA}[模拟] 检查健康端点: ${url}${NC}"
        echo -e "${MAGENTA}[模拟] 返回: {\"ok\":true}${NC}"
        return 0
    fi
    
    if command -v curl &> /dev/null; then
        local response
        if response=$(curl -s -f -m "$TIMEOUT" "$url" 2>/dev/null); then
            if echo "$response" | grep -q '"ok":true'; then
                echo -e "${GREEN}✓ API 健康端点: 正常${NC}"
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "  响应: ${CYAN}$response${NC}"
                fi
                return 0
            else
                echo -e "${RED}✗ API 健康端点: 响应异常${NC}"
                echo -e "  响应: ${YELLOW}$response${NC}"
                return 1
            fi
        else
            echo -e "${RED}✗ API 健康端点: 连接失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ curl 命令未找到，跳过API检查${NC}"
        return 2
    fi
}

# 检查数据库连接
check_database() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${MAGENTA}[模拟] 检查数据库连接${NC}"
        echo -e "${MAGENTA}[模拟] 数据库: /opt/roc/quota-proxy/data/quota.db${NC}"
        echo -e "${MAGENTA}[模拟] 状态: 正常${NC}"
        return 0
    fi
    
    # 尝试检查数据库文件（假设在服务器上运行）
    local db_path="/opt/roc/quota-proxy/data/quota.db"
    if [[ -f "$db_path" ]]; then
        local db_size=$(du -h "$db_path" | cut -f1)
        echo -e "${GREEN}✓ 数据库文件: 存在 (${db_size})${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 数据库文件: 未找到${NC}"
        return 1
    fi
}

# 获取服务运行时间
get_uptime() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${MAGENTA}[模拟] 服务运行时间: 3小时15分钟${NC}"
        return 0
    fi
    
    if command -v docker &> /dev/null; then
        local uptime=$(docker inspect --format='{{.State.StartedAt}}' quota-proxy-quota-proxy-1 2>/dev/null || true)
        if [[ -n "$uptime" ]]; then
            local start_time=$(date -d "$uptime" +%s)
            local current_time=$(date +%s)
            local diff=$((current_time - start_time))
            local hours=$((diff / 3600))
            local minutes=$(( (diff % 3600) / 60 ))
            echo -e "${GREEN}✓ 服务运行时间: ${hours}小时${minutes}分钟${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ 服务运行时间: 无法获取${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ 服务运行时间: 无法获取（Docker不可用）${NC}"
        return 2
    fi
}

# 单次检查
single_check() {
    local exit_code=0
    
    echo -e "${BOLD}${BLUE}=== quota-proxy 状态检查 ===${NC}"
    echo -e "${CYAN}时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}目标:${NC} ${HOST}:${PORT}"
    echo
    
    # 执行各项检查
    check_docker_status || exit_code=1
    echo
    
    check_health_endpoint || exit_code=1
    echo
    
    check_database || exit_code=1
    echo
    
    get_uptime || exit_code=1
    echo
    
    # 总结
    echo -e "${BOLD}${BLUE}=== 检查完成 ===${NC}"
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有检查通过，服务状态正常${NC}"
    else
        echo -e "${YELLOW}⚠ 部分检查未通过，服务可能存在异常${NC}"
    fi
    
    return $exit_code
}

# 持续监控
continuous_monitor() {
    local check_count=0
    local success_count=0
    local failure_count=0
    
    echo -e "${BOLD}${BLUE}=== quota-proxy 持续监控模式 ===${NC}"
    echo -e "${CYAN}目标:${NC} ${HOST}:${PORT}"
    echo -e "${CYAN}间隔:${NC} 每 ${INTERVAL} 秒"
    echo -e "${CYAN}开始时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    trap 'echo -e "\n${YELLOW}监控已停止${NC}"; exit 0' INT TERM
    
    while true; do
        check_count=$((check_count + 1))
        local timestamp=$(date '+%H:%M:%S')
        
        echo -e "${CYAN}[${timestamp}] 第 ${check_count} 次检查${NC}"
        
        # 简化的检查逻辑
        local health_check=0
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${MAGENTA}[模拟] 健康检查通过${NC}"
            health_check=0
        elif command -v curl &> /dev/null; then
            if curl -s -f -m "$TIMEOUT" "http://${HOST}:${PORT}/healthz" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ 健康检查通过${NC}"
                health_check=0
                success_count=$((success_count + 1))
            else
                echo -e "${RED}✗ 健康检查失败${NC}"
                health_check=1
                failure_count=$((failure_count + 1))
            fi
        else
            echo -e "${YELLOW}⚠ curl 不可用，跳过检查${NC}"
            health_check=2
        fi
        
        # 显示统计信息
        if [[ $check_count -gt 1 ]]; then
            local success_rate=0
            if [[ $check_count -gt 0 ]]; then
                success_rate=$((success_count * 100 / check_count))
            fi
            echo -e "${CYAN}统计:${NC} 检查 ${check_count} 次，成功 ${success_count} 次，失败 ${failure_count} 次，成功率 ${success_rate}%"
        fi
        
        echo
        
        # 如果不是最后一次检查，则等待
        if [[ "$CONTINUOUS" == true ]]; then
            sleep "$INTERVAL"
        else
            break
        fi
    done
    
    return $health_check
}

# 主函数
main() {
    parse_args "$@"
    
    # 禁用颜色
    if [[ "$NO_COLOR" == true ]]; then
        RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''; BOLD=''
    fi
    
    # 安静模式
    if [[ "$QUIET" == true ]]; then
        exec 1>/dev/null
    fi
    
    # 执行监控
    if [[ "$CONTINUOUS" == true ]]; then
        continuous_monitor
    else
        single_check
    fi
    
    return $?
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi