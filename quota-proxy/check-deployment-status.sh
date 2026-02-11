#!/bin/bash

# check-deployment-status.sh - 快速检查quota-proxy部署状态
# 提供最简单的部署状态验证，支持健康检查、容器状态、端口检查

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=8787
DEFAULT_HEALTH_PATH="/healthz"
DEFAULT_STATUS_PATH="/status"
DEFAULT_MODELS_PATH="/v1/models"
TIMEOUT=5

# 帮助信息
show_help() {
    cat << EOF
check-deployment-status.sh - 快速检查quota-proxy部署状态

用法:
  ./check-deployment-status.sh [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -q, --quiet         安静模式，只输出结果不显示详细信息
  -H, --host HOST     指定主机地址（默认: 127.0.0.1）
  -p, --port PORT     指定端口（默认: 8787）
  --health-path PATH  健康检查路径（默认: /healthz）
  --status-path PATH  状态查询路径（默认: /status）
  --models-path PATH  模型列表路径（默认: /v1/models）
  -t, --timeout SEC   超时时间（秒，默认: 5）
  --no-color          禁用颜色输出

示例:
  ./check-deployment-status.sh                     # 检查本地部署
  ./check-deployment-status.sh -H 192.168.1.100    # 检查远程主机
  ./check-deployment-status.sh --dry-run           # 干运行模式
  ./check-deployment-status.sh -q                  # 安静模式

功能:
  1. 检查健康端点 (/healthz)
  2. 检查状态端点 (/status)
  3. 检查模型列表端点 (/v1/models)
  4. 检查Docker容器状态（如果可用）
  5. 检查端口监听状态

退出码:
  0 - 所有检查通过
  1 - 部分检查失败
  2 - 参数错误
EOF
}

# 解析参数
parse_args() {
    HOST="127.0.0.1"
    PORT="$DEFAULT_PORT"
    HEALTH_PATH="$DEFAULT_HEALTH_PATH"
    STATUS_PATH="$DEFAULT_STATUS_PATH"
    MODELS_PATH="$DEFAULT_MODELS_PATH"
    DRY_RUN=false
    QUIET=false
    USE_COLOR=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            --health-path)
                HEALTH_PATH="$2"
                shift 2
                ;;
            --status-path)
                STATUS_PATH="$2"
                shift 2
                ;;
            --models-path)
                MODELS_PATH="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --no-color)
                USE_COLOR=false
                shift
                ;;
            *)
                echo "错误: 未知参数: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

# 颜色输出函数
color_echo() {
    if [ "$USE_COLOR" = true ]; then
        local color="$1"
        shift
        echo -e "${color}$*${NC}"
    else
        shift
        echo "$*"
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        color_echo "$YELLOW" "警告: 命令 '$1' 不存在，跳过相关检查"
        return 1
    fi
    return 0
}

# 检查端口监听
check_port() {
    local host="$1"
    local port="$2"
    
    if [ "$DRY_RUN" = true ]; then
        color_echo "$BLUE" "[干运行] 检查端口: nc -z $host $port"
        return 0
    fi
    
    if timeout "$TIMEOUT" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        color_echo "$GREEN" "✓ 端口 $port 在 $host 上可访问"
        return 0
    else
        color_echo "$RED" "✗ 端口 $port 在 $host 上不可访问"
        return 1
    fi
}

# 检查HTTP端点
check_http_endpoint() {
    local url="$1"
    local name="$2"
    local require_json="${3:-false}"
    
    if [ "$DRY_RUN" = true ]; then
        color_echo "$BLUE" "[干运行] 检查端点: curl -s -f -m $TIMEOUT '$url'"
        return 0
    fi
    
    local response
    if response=$(curl -s -f -m "$TIMEOUT" "$url" 2>/dev/null); then
        if [ "$require_json" = true ]; then
            if echo "$response" | jq . >/dev/null 2>&1; then
                color_echo "$GREEN" "✓ $name: 返回有效JSON响应"
                return 0
            else
                color_echo "$YELLOW" "⚠ $name: 返回响应但不是有效JSON"
                return 1
            fi
        else
            color_echo "$GREEN" "✓ $name: 返回成功响应"
            return 0
        fi
    else
        color_echo "$RED" "✗ $name: 请求失败"
        return 1
    fi
}

# 检查Docker容器状态
check_docker() {
    if ! check_command "docker"; then
        return 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        color_echo "$BLUE" "[干运行] 检查Docker容器: docker compose ps"
        color_echo "$BLUE" "[干运行] 检查特定容器: docker ps --filter 'name=quota-proxy'"
        return 0
    fi
    
    local container_count=0
    local running_count=0
    
    # 尝试docker compose
    if check_command "docker-compose" || docker compose version &>/dev/null; then
        if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
            color_echo "$BLUE" "检查docker compose状态..."
            if command -v docker-compose &>/dev/null; then
                docker-compose ps 2>/dev/null | grep -i quota-proxy && container_count=$((container_count + 1))
            else
                docker compose ps 2>/dev/null | grep -i quota-proxy && container_count=$((container_count + 1))
            fi
        fi
    fi
    
    # 检查Docker容器
    color_echo "$BLUE" "检查Docker容器..."
    local docker_output
    docker_output=$(docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true)
    
    if [ -n "$docker_output" ] && [ "$docker_output" != "NAMES" ]; then
        echo "$docker_output"
        running_count=$(echo "$docker_output" | grep -c "Up" || true)
        container_count=$((container_count + $(echo "$docker_output" | wc -l) - 1))
    fi
    
    if [ "$container_count" -gt 0 ]; then
        if [ "$running_count" -eq "$container_count" ]; then
            color_echo "$GREEN" "✓ 所有 $container_count 个quota-proxy容器都在运行"
            return 0
        else
            color_echo "$YELLOW" "⚠ $running_count/$container_count 个quota-proxy容器在运行"
            return 1
        fi
    else
        color_echo "$YELLOW" "⚠ 未找到quota-proxy容器"
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    if [ "$QUIET" = false ]; then
        color_echo "$BLUE" "================================================"
        color_echo "$BLUE" "quota-proxy部署状态检查"
        color_echo "$BLUE" "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        color_echo "$BLUE" "目标: $HOST:$PORT"
        color_echo "$BLUE" "================================================"
        echo
    fi
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # 检查端口
    color_echo "$BLUE" "1. 检查端口监听..."
    total_tests=$((total_tests + 1))
    if check_port "$HOST" "$PORT"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
        if [ "$QUIET" = false ]; then
            color_echo "$YELLOW" "  端口不可用，跳过HTTP端点检查"
        fi
        # 端口不可用，跳过HTTP检查
        color_echo "$BLUE" "2. 检查Docker容器状态..."
        total_tests=$((total_tests + 1))
        if check_docker; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
        
        print_summary
        return $([ "$failed_tests" -eq 0 ] && echo 0 || echo 1)
    fi
    
    # 检查健康端点
    color_echo "$BLUE" "2. 检查健康端点..."
    total_tests=$((total_tests + 1))
    if check_http_endpoint "http://$HOST:$PORT$HEALTH_PATH" "健康端点"; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # 检查状态端点
    color_echo "$BLUE" "3. 检查状态端点..."
    total_tests=$((total_tests + 1))
    if check_http_endpoint "http://$HOST:$PORT$STATUS_PATH" "状态端点" true; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # 检查模型端点
    color_echo "$BLUE" "4. 检查模型端点..."
    total_tests=$((total_tests + 1))
    if check_http_endpoint "http://$HOST:$PORT$MODELS_PATH" "模型端点" true; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    # 检查Docker容器
    color_echo "$BLUE" "5. 检查Docker容器状态..."
    total_tests=$((total_tests + 1))
    if check_docker; then
        passed_tests=$((passed_tests + 1))
    else
        failed_tests=$((failed_tests + 1))
    fi
    
    print_summary
}

# 打印摘要
print_summary() {
    if [ "$QUIET" = false ]; then
        echo
        color_echo "$BLUE" "================================================"
        color_echo "$BLUE" "检查完成"
        color_echo "$BLUE" "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        
        if [ "$passed_tests" -eq "$total_tests" ]; then
            color_echo "$GREEN" "结果: 所有 $total_tests 项检查通过"
        elif [ "$failed_tests" -eq 0 ]; then
            color_echo "$GREEN" "结果: $passed_tests/$total_tests 项检查通过"
        elif [ "$passed_tests" -gt 0 ]; then
            color_echo "$YELLOW" "结果: $passed_tests/$total_tests 项检查通过，$failed_tests 项失败"
        else
            color_echo "$RED" "结果: 所有 $total_tests 项检查失败"
        fi
        
        color_echo "$BLUE" "================================================"
    fi
    
    # 安静模式只输出最终结果
    if [ "$QUIET" = true ]; then
        if [ "$passed_tests" -eq "$total_tests" ]; then
            echo "PASS"
        else
            echo "FAIL"
        fi
    fi
    
    # 返回退出码
    if [ "$failed_tests" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 运行主函数
main "$@"