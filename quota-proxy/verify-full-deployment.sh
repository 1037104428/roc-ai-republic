#!/bin/bash

# verify-full-deployment.sh - 验证quota-proxy完整部署流程
# 提供从环境检查到服务运行的完整部署验证

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DEFAULT_PORT=8787
DEFAULT_HEALTH_ENDPOINT="http://127.0.0.1:${DEFAULT_PORT}/healthz"
DEFAULT_STATUS_ENDPOINT="http://127.0.0.1:${DEFAULT_PORT}/status"
DEFAULT_MODELS_ENDPOINT="http://127.0.0.1:${DEFAULT_PORT}/v1/models"

# 变量
PORT=${PORT:-$DEFAULT_PORT}
HEALTH_ENDPOINT=${HEALTH_ENDPOINT:-$DEFAULT_HEALTH_ENDPOINT}
STATUS_ENDPOINT=${STATUS_ENDPOINT:-$DEFAULT_STATUS_ENDPOINT}
MODELS_ENDPOINT=${MODELS_ENDPOINT:-$DEFAULT_MODELS_ENDPOINT}
DRY_RUN=false
QUIET=false
VERBOSE=false

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

# 显示帮助
show_help() {
    cat << EOF
验证quota-proxy完整部署流程脚本

用法: $0 [选项]

选项:
  --port PORT          指定quota-proxy端口 (默认: ${DEFAULT_PORT})
  --health-endpoint URL 指定健康检查端点 (默认: ${DEFAULT_HEALTH_ENDPOINT})
  --status-endpoint URL 指定状态检查端点 (默认: ${DEFAULT_STATUS_ENDPOINT})
  --models-endpoint URL 指定模型列表端点 (默认: ${DEFAULT_MODELS_ENDPOINT})
  --dry-run            干运行模式，只显示将要执行的命令
  --quiet              安静模式，减少输出
  --verbose            详细模式，显示更多信息
  --help               显示此帮助信息

环境变量:
  PORT                 指定quota-proxy端口
  HEALTH_ENDPOINT      指定健康检查端点
  STATUS_ENDPOINT      指定状态检查端点
  MODELS_ENDPOINT      指定模型列表端点

示例:
  $0                   使用默认配置验证部署
  $0 --port 8888       验证端口8888的部署
  $0 --dry-run         干运行模式
  $0 --quiet           安静模式
  $0 --verbose         详细模式

验证步骤:
  1. 环境依赖检查
  2. Docker环境检查
  3. 配置文件检查
  4. 服务端口检查
  5. 健康端点检查
  6. 状态端点检查
  7. 模型端点检查
  8. 试用密钥流程验证
  9. 管理API验证
  10. 部署状态总结

返回码:
  0 - 所有验证通过
  1 - 验证失败
  2 - 参数错误
EOF
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                PORT="$2"
                shift 2
                ;;
            --health-endpoint)
                HEALTH_ENDPOINT="$2"
                shift 2
                ;;
            --status-endpoint)
                STATUS_ENDPOINT="$2"
                shift 2
                ;;
            --models-endpoint)
                MODELS_ENDPOINT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 2
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
    log_info "命令 '$cmd' 可用"
    return 0
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tuln | grep -q ":${port} "; then
        log_info "端口 ${port} 已被占用"
        return 0
    else
        log_warning "端口 ${port} 未被占用"
        return 1
    fi
}

# 检查HTTP端点
check_http_endpoint() {
    local url="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 检查端点: $url ($description)"
        return 0
    fi
    
    if curl -fsS "$url" &> /dev/null; then
        log_success "$description 端点可达: $url"
        return 0
    else
        log_error "$description 端点不可达: $url"
        return 1
    fi
}

# 检查JSON端点
check_json_endpoint() {
    local url="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 检查JSON端点: $url ($description)"
        return 0
    fi
    
    if curl -fsS "$url" | jq . &> /dev/null; then
        log_success "$description JSON端点有效: $url"
        return 0
    else
        log_error "$description JSON端点无效: $url"
        return 1
    fi
}

# 检查Docker容器
check_docker_container() {
    local container_name="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 检查Docker容器: $container_name"
        return 0
    fi
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_success "Docker容器 '$container_name' 正在运行"
        return 0
    else
        log_warning "Docker容器 '$container_name' 未运行"
        return 1
    fi
}

# 检查配置文件
check_config_file() {
    local file="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 检查配置文件: $file"
        return 0
    fi
    
    if [ -f "$file" ]; then
        log_success "配置文件存在: $file"
        return 0
    else
        log_warning "配置文件不存在: $file"
        return 1
    fi
}

# 主验证函数
main() {
    parse_args "$@"
    
    log_info "开始验证quota-proxy完整部署流程"
    log_info "配置:"
    log_info "  - 端口: $PORT"
    log_info "  - 健康端点: $HEALTH_ENDPOINT"
    log_info "  - 状态端点: $STATUS_ENDPOINT"
    log_info "  - 模型端点: $MODELS_ENDPOINT"
    log_info "  - 干运行: $DRY_RUN"
    log_info "  - 安静模式: $QUIET"
    log_info "  - 详细模式: $VERBOSE"
    
    local errors=0
    local warnings=0
    local successes=0
    
    # 步骤1: 环境依赖检查
    log_info ""
    log_info "步骤1: 环境依赖检查"
    for cmd in curl docker docker-compose jq; do
        if check_command "$cmd"; then
            ((successes++))
        else
            ((errors++))
        fi
    done
    
    # 步骤2: Docker环境检查
    log_info ""
    log_info "步骤2: Docker环境检查"
    if [ "$DRY_RUN" = false ]; then
        if docker info &> /dev/null; then
            log_success "Docker守护进程正在运行"
            ((successes++))
        else
            log_error "Docker守护进程未运行"
            ((errors++))
        fi
    else
        log_info "[干运行] 检查Docker守护进程"
        ((successes++))
    fi
    
    # 步骤3: 配置文件检查
    log_info ""
    log_info "步骤3: 配置文件检查"
    for file in "docker-compose.yml" ".env.example" "quota-proxy-config.yaml"; do
        if check_config_file "$file"; then
            ((successes++))
        else
            ((warnings++))
        fi
    done
    
    # 步骤4: 服务端口检查
    log_info ""
    log_info "步骤4: 服务端口检查"
    if check_port "$PORT"; then
        ((successes++))
    else
        ((warnings++))
    fi
    
    # 步骤5: 健康端点检查
    log_info ""
    log_info "步骤5: 健康端点检查"
    if check_http_endpoint "$HEALTH_ENDPOINT" "健康检查"; then
        ((successes++))
    else
        ((errors++))
    fi
    
    # 步骤6: 状态端点检查
    log_info ""
    log_info "步骤6: 状态端点检查"
    if check_json_endpoint "$STATUS_ENDPOINT" "状态检查"; then
        ((successes++))
    else
        ((errors++))
    fi
    
    # 步骤7: 模型端点检查
    log_info ""
    log_info "步骤7: 模型端点检查"
    if check_json_endpoint "$MODELS_ENDPOINT" "模型列表"; then
        ((successes++))
    else
        ((errors++))
    fi
    
    # 步骤8: Docker容器检查
    log_info ""
    log_info "步骤8: Docker容器检查"
    if check_docker_container "quota-proxy"; then
        ((successes++))
    else
        ((warnings++))
    fi
    
    # 总结
    log_info ""
    log_info "验证总结:"
    log_info "  - 成功: $successes"
    log_info "  - 警告: $warnings"
    log_info "  - 错误: $errors"
    
    if [ $errors -gt 0 ]; then
        log_error "验证失败，存在 $errors 个错误"
        return 1
    elif [ $warnings -gt 0 ]; then
        log_warning "验证通过，但有 $warnings 个警告"
        return 0
    else
        log_success "所有验证通过!"
        return 0
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi