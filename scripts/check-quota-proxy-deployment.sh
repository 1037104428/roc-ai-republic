#!/bin/bash

# quota-proxy部署状态检查脚本
# 快速验证服务器上的quota-proxy部署状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN="dummy-token"

# 显示帮助信息
show_help() {
    cat << EOM
quota-proxy部署状态检查脚本

用法: $0 [选项]

选项:
  -h, --host HOST       quota-proxy主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT       quota-proxy端口 (默认: $DEFAULT_PORT)
  -t, --token TOKEN     管理令牌 (默认: $DEFAULT_ADMIN_TOKEN)
  -s, --ssh HOST        通过SSH检查远程服务器 (格式: user@host)
  -n, --dry-run         模拟运行，不执行实际检查
  -v, --verbose         详细输出模式
  --help                显示此帮助信息

示例:
  $0 -h 127.0.0.1 -p 8787 -t "my-token"
  $0 -s root@8.210.185.194
  $0 -n -v

退出码:
  0: 所有检查通过
  1: 参数错误或帮助信息
  2: 健康检查失败
  3: 管理接口检查失败
  4: 试用密钥创建失败
  5: SSH连接失败
EOM
}

# 解析命令行参数
parse_args() {
    HOST="$DEFAULT_HOST"
    PORT="$DEFAULT_PORT"
    ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
    SSH_HOST=""
    DRY_RUN=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -s|--ssh)
                SSH_HOST="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --help)
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
}

# 打印信息
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

# 检查本地quota-proxy
check_local() {
    local url="http://$HOST:$PORT"
    
    log_info "检查本地quota-proxy部署状态..."
    log_info "目标: $url"
    log_info "令牌: ${ADMIN_TOKEN:0:4}****"
    
    if $DRY_RUN; then
        log_warning "模拟运行模式 - 跳过实际检查"
        log_success "健康检查: 模拟通过"
        log_success "管理接口: 模拟通过"
        log_success "试用密钥: 模拟创建成功"
        return 0
    fi
    
    # 1. 健康检查
    log_info "1. 执行健康检查..."
    if curl -fsS "${url}/healthz" > /dev/null 2>&1; then
        log_success "健康检查通过"
    else
        log_error "健康检查失败"
        return 2
    fi
    
    # 2. 管理接口检查
    log_info "2. 检查管理接口..."
    local admin_status=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $ADMIN_TOKEN" "${url}/admin/status" -o /dev/null 2>&1)
    
    if [[ "$admin_status" == "200" ]]; then
        log_success "管理接口访问正常"
    else
        log_warning "管理接口返回状态码: $admin_status"
        # 继续检查，管理接口可能未启用
    fi
    
    # 3. 创建试用密钥
    log_info "3. 创建试用密钥..."
    local key_response=$(curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -d '{"name":"deployment-check","quota":100}' \
        "${url}/admin/keys")
    
    if echo "$key_response" | grep -q '"key"'; then
        local trial_key=$(echo "$key_response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_success "试用密钥创建成功: ${trial_key:0:8}****"
        
        # 4. 验证密钥可用性
        log_info "4. 验证密钥可用性..."
        local usage_response=$(curl -s -H "X-API-Key: $trial_key" "${url}/usage")
        
        if echo "$usage_response" | grep -q '"used"'; then
            log_success "密钥验证通过"
        else
            log_warning "密钥验证返回异常响应"
        fi
    else
        log_warning "试用密钥创建失败，响应: $key_response"
        return 4
    fi
    
    log_success "所有部署检查通过!"
    return 0
}

# 检查远程服务器
check_remote() {
    log_info "检查远程服务器: $SSH_HOST"
    
    if $DRY_RUN; then
        log_warning "模拟运行模式 - 跳过SSH检查"
        log_success "SSH连接: 模拟通过"
        log_success "Docker状态: 模拟正常"
        log_success "健康检查: 模拟通过"
        return 0
    fi
    
    # 检查SSH连接
    log_info "1. 测试SSH连接..."
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_HOST" "echo 'SSH连接成功'" > /dev/null 2>&1; then
        log_success "SSH连接成功"
    else
        log_error "SSH连接失败"
        return 5
    fi
    
    # 检查Docker状态
    log_info "2. 检查Docker Compose状态..."
    local docker_output=$(ssh "$SSH_HOST" "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null || echo 'Docker Compose未找到'")
    
    if echo "$docker_output" | grep -q "quota-proxy"; then
        log_success "quota-proxy容器运行中"
        if $VERBOSE; then
            echo "$docker_output"
        fi
    else
        log_error "quota-proxy容器未运行"
        echo "$docker_output"
        return 2
    fi
    
    # 检查健康状态
    log_info "3. 检查服务健康状态..."
    local health_output=$(ssh "$SSH_HOST" "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null || echo '健康检查失败'")
    
    if echo "$health_output" | grep -q '"ok":true'; then
        log_success "服务健康状态正常"
        if $VERBOSE; then
            echo "$health_output"
        fi
    else
        log_error "服务健康检查失败"
        echo "$health_output"
        return 2
    fi
    
    log_success "远程服务器部署检查通过!"
    return 0
}

# 主函数
main() {
    parse_args "$@"
    
    echo "========================================"
    echo "quota-proxy部署状态检查"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "========================================"
    
    if [[ -n "$SSH_HOST" ]]; then
        check_remote
    else
        check_local
    fi
    
    local exit_code=$?
    
    echo "========================================"
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}检查完成: 所有测试通过${NC}"
    else
        echo -e "${RED}检查完成: 部分测试失败 (退出码: $exit_code)${NC}"
    fi
    echo "========================================"
    
    return $exit_code
}

# 执行主函数
main "$@"
