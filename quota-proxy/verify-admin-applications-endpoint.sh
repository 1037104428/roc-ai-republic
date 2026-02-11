#!/usr/bin/env bash
set -euo pipefail

# 验证 quota-proxy 的管理员应用列表端点
# 提供 /admin/applications 端点的验证功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示帮助信息
show_help() {
    cat << EOF
验证 quota-proxy 管理员应用列表端点 (/admin/applications)

用法: $(basename "$0") [选项]

选项:
  -h, --help                显示此帮助信息
  -u, --url URL             服务器URL (默认: http://127.0.0.1:8787)
  -t, --token TOKEN         管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 获取)
  --dry-run                 干运行模式，只显示将要执行的命令
  -v, --verbose             详细输出模式
  --no-color                禁用彩色输出

环境变量:
  ADMIN_TOKEN               管理员令牌 (优先级低于命令行参数)

示例:
  # 使用默认配置验证
  ADMIN_TOKEN="my-secret-token" ./verify-admin-applications-endpoint.sh

  # 指定服务器URL和令牌
  ./verify-admin-applications-endpoint.sh --url http://localhost:8787 --token "admin-token"

  # 干运行模式
  ./verify-admin-applications-endpoint.sh --dry-run

  # 详细输出
  ./verify-admin-applications-endpoint.sh --verbose
EOF
}

# 默认配置
SERVER_URL="http://127.0.0.1:8787"
ADMIN_TOKEN=""
DRY_RUN=false
VERBOSE=false
USE_COLOR=true

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--url)
            SERVER_URL="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-color)
            USE_COLOR=false
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 如果未通过命令行指定令牌，尝试从环境变量获取
if [[ -z "${ADMIN_TOKEN:-}" ]]; then
    log_error "未提供管理员令牌。请通过 -t/--token 参数或 ADMIN_TOKEN 环境变量设置。"
    exit 1
fi

# 禁用颜色输出
if [[ "$USE_COLOR" == "false" ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# 执行curl命令的函数
run_curl() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers=()
    
    headers+=("-H" "Authorization: Bearer $ADMIN_TOKEN")
    headers+=("-H" "Content-Type: application/json")
    
    local curl_cmd=("curl" "-s" "-X" "$method" "${headers[@]}")
    
    if [[ -n "$data" ]]; then
        curl_cmd+=("-d" "$data")
    fi
    
    curl_cmd+=("$url")
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "执行命令: ${curl_cmd[*]}"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[干运行] ${curl_cmd[*]}"
        echo '{"status": "dry-run", "applications": []}'
        return 0
    fi
    
    "${curl_cmd[@]}"
}

# 验证健康端点
verify_health_endpoint() {
    log_info "验证健康端点: $SERVER_URL/healthz"
    
    local response
    response=$(run_curl "$SERVER_URL/healthz" "GET")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "干运行模式: 健康端点验证跳过"
        return 0
    fi
    
    if echo "$response" | grep -q "OK"; then
        log_success "健康端点正常: $response"
        return 0
    else
        log_error "健康端点异常: $response"
        return 1
    fi
}

# 验证管理员应用列表端点
verify_admin_applications_endpoint() {
    log_info "验证管理员应用列表端点: $SERVER_URL/admin/applications"
    
    local response
    response=$(run_curl "$SERVER_URL/admin/applications" "GET")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "干运行模式: 管理员应用列表端点验证跳过"
        return 0
    fi
    
    # 检查响应是否为有效的JSON
    if echo "$response" | jq . > /dev/null 2>&1; then
        log_success "管理员应用列表端点返回有效JSON"
        
        # 检查响应结构
        if echo "$response" | jq -e '.applications' > /dev/null 2>&1; then
            local app_count
            app_count=$(echo "$response" | jq '.applications | length')
            log_success "找到 $app_count 个应用"
            
            # 显示应用列表（如果详细模式）
            if [[ "$VERBOSE" == "true" ]] && [[ "$app_count" -gt 0 ]]; then
                log_info "应用列表:"
                echo "$response" | jq -r '.applications[] | "  - \(.name) (ID: \(.id), 状态: \(.status))"'
            fi
            
            return 0
        else
            log_warning "响应缺少 'applications' 字段: $response"
            return 1
        fi
    else
        log_error "管理员应用列表端点返回无效JSON: $response"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始验证 quota-proxy 管理员应用列表端点"
    log_info "服务器URL: $SERVER_URL"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:4}****${ADMIN_TOKEN: -4}"
    
    local exit_code=0
    
    # 验证健康端点
    if ! verify_health_endpoint; then
        log_error "健康端点验证失败"
        exit_code=1
    fi
    
    # 验证管理员应用列表端点
    if ! verify_admin_applications_endpoint; then
        log_error "管理员应用列表端点验证失败"
        exit_code=1
    fi
    
    # 总结
    if [[ "$exit_code" -eq 0 ]]; then
        log_success "✅ 所有验证通过"
    else
        log_error "❌ 部分验证失败"
    fi
    
    return $exit_code
}

# 检查jq是否安装
if ! command -v jq > /dev/null 2>&1; then
    log_error "需要安装 jq 命令。请运行: sudo apt-get install jq 或 sudo yum install jq"
    exit 1
fi

# 运行主函数
main "$@"