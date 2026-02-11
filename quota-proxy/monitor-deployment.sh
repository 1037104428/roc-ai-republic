#!/bin/bash

# quota-proxy 部署状态监控脚本
# 定期检查服务状态并记录日志

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_INTERVAL=300  # 5分钟
DEFAULT_LOG_FILE="/var/log/quota-proxy-monitor.log"
DEFAULT_MAX_LOG_SIZE=10485760  # 10MB

# 显示帮助信息
show_help() {
    cat << 'HELP'
quota-proxy 部署状态监控脚本

用法:
  ./monitor-deployment.sh [选项]

选项:
  -h, --help              显示此帮助信息
  -H, --host HOST         监控主机地址 (默认: 127.0.0.1)
  -p, --port PORT         监控端口 (默认: 8787)
  -i, --interval SECONDS  检查间隔秒数 (默认: 300)
  -l, --log FILE          日志文件路径 (默认: /var/log/quota-proxy-monitor.log)
  -m, --max-size BYTES    日志文件最大大小 (默认: 10485760 = 10MB)
  -d, --daemon            以守护进程模式运行
  -v, --verbose           详细输出模式
  --dry-run               干运行模式，不实际执行检查

示例:
  # 基本使用
  ./monitor-deployment.sh
  
  # 指定主机和端口
  ./monitor-deployment.sh --host 192.168.1.100 --port 8787
  
  # 以守护进程模式运行
  ./monitor-deployment.sh --daemon --interval 60
  
  # 详细输出模式
  ./monitor-deployment.sh --verbose --interval 120

功能:
  1. 检查 quota-proxy 健康端点 (/healthz)
  2. 检查 quota-proxy 状态端点 (/status)
  3. 检查 Docker 容器状态
  4. 记录检查结果到日志文件
  5. 自动轮转日志文件

HELP
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--host)
                MONITOR_HOST="$2"
                shift 2
                ;;
            -p|--port)
                MONITOR_PORT="$2"
                shift 2
                ;;
            -i|--interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -m|--max-size)
                MAX_LOG_SIZE="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 初始化配置
init_config() {
    MONITOR_HOST=${MONITOR_HOST:-$DEFAULT_HOST}
    MONITOR_PORT=${MONITOR_PORT:-$DEFAULT_PORT}
    MONITOR_INTERVAL=${MONITOR_INTERVAL:-$DEFAULT_INTERVAL}
    LOG_FILE=${LOG_FILE:-$DEFAULT_LOG_FILE}
    MAX_LOG_SIZE=${MAX_LOG_SIZE:-$DEFAULT_MAX_LOG_SIZE}
    DAEMON_MODE=${DAEMON_MODE:-false}
    VERBOSE=${VERBOSE:-false}
    DRY_RUN=${DRY_RUN:-false}
    
    # 创建日志目录
    LOG_DIR=$(dirname "$LOG_FILE")
    if [ ! -d "$LOG_DIR" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}[干运行] 将创建日志目录: $LOG_DIR${NC}"
        else
            mkdir -p "$LOG_DIR"
            echo -e "${GREEN}创建日志目录: $LOG_DIR${NC}"
        fi
    fi
}

# 检查日志文件大小并轮转
rotate_log_if_needed() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            local rotated_file="${LOG_FILE}.${timestamp}"
            if [ "$DRY_RUN" = true ]; then
                echo -e "${YELLOW}[干运行] 将轮转日志文件: $LOG_FILE -> $rotated_file${NC}"
            else
                mv "$LOG_FILE" "$rotated_file"
                echo -e "${YELLOW}轮转日志文件: $LOG_FILE -> $rotated_file${NC}"
            fi
        fi
    fi
}

# 记录日志
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 控制台输出
    if [ "$VERBOSE" = true ] || [ "$level" = "ERROR" ]; then
        case "$level" in
            "INFO")
                echo -e "${GREEN}[$timestamp] [$level] $message${NC}"
                ;;
            "WARN")
                echo -e "${YELLOW}[$timestamp] [$level] $message${NC}"
                ;;
            "ERROR")
                echo -e "${RED}[$timestamp] [$level] $message${NC}"
                ;;
            *)
                echo -e "${BLUE}[$timestamp] [$level] $message${NC}"
                ;;
        esac
    fi
    
    # 文件日志
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[干运行] 将记录日志: [$timestamp] [$level] $message${NC}"
    else
        rotate_log_if_needed
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# 检查健康端点
check_health() {
    local url="http://${MONITOR_HOST}:${MONITOR_PORT}/healthz"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "干运行: 将检查健康端点 $url"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -m 10 "$url" 2>/dev/null); then
        log_message "INFO" "健康端点检查成功: $url"
        return 0
    else
        log_message "ERROR" "健康端点检查失败: $url"
        return 1
    fi
}

# 检查状态端点
check_status() {
    local url="http://${MONITOR_HOST}:${MONITOR_PORT}/status"
    
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "干运行: 将检查状态端点 $url"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -m 10 "$url" 2>/dev/null); then
        log_message "INFO" "状态端点检查成功: $url"
        return 0
    else
        log_message "WARN" "状态端点检查失败: $url"
        return 1
    fi
}

# 检查Docker容器
check_docker() {
    if [ "$DRY_RUN" = true ]; then
        log_message "INFO" "干运行: 将检查Docker容器状态"
        return 0
    fi
    
    if command -v docker >/dev/null 2>&1; then
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "quota-proxy"; then
            local container_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "quota-proxy")
            log_message "INFO" "Docker容器运行正常: $container_status"
            return 0
        else
            log_message "ERROR" "未找到运行的 quota-proxy Docker容器"
            return 1
        fi
    else
        log_message "WARN" "未找到 docker 命令，跳过Docker检查"
        return 0
    fi
}

# 执行一次完整的检查
perform_check() {
    log_message "INFO" "开始执行部署状态检查"
    
    local health_ok=true
    local status_ok=true
    local docker_ok=true
    
    # 检查健康端点
    if ! check_health; then
        health_ok=false
    fi
    
    # 检查状态端点
    if ! check_status; then
        status_ok=false
    fi
    
    # 检查Docker容器
    if ! check_docker; then
        docker_ok=false
    fi
    
    # 汇总结果
    if [ "$health_ok" = true ] && [ "$status_ok" = true ] && [ "$docker_ok" = true ]; then
        log_message "INFO" "所有检查通过: 服务运行正常"
        return 0
    else
        log_message "ERROR" "检查失败: 健康=$health_ok, 状态=$status_ok, Docker=$docker_ok"
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    init_config
    
    log_message "INFO" "启动 quota-proxy 部署状态监控"
    log_message "INFO" "配置: 主机=$MONITOR_HOST, 端口=$MONITOR_PORT, 间隔=${MONITOR_INTERVAL}秒"
    log_message "INFO" "日志: $LOG_FILE, 最大大小=${MAX_LOG_SIZE}字节"
    
    if [ "$DAEMON_MODE" = true ]; then
        log_message "INFO" "以守护进程模式运行，检查间隔: ${MONITOR_INTERVAL}秒"
        
        while true; do
            perform_check
            sleep "$MONITOR_INTERVAL"
        done
    else
        perform_check
        local exit_code=$?
        log_message "INFO" "监控检查完成，退出码: $exit_code"
        exit $exit_code
    fi
}

# 运行主函数
main "$@"
