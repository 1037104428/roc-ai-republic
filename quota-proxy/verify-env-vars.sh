#!/bin/bash
# verify-env-vars.sh - 环境变量验证脚本
# 用于快速检查quota-proxy部署环境的关键配置变量
# 版本: 2026.02.11.15

set -euo pipefail

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

# 帮助信息
show_help() {
    cat << EOF
环境变量验证脚本 - 快速检查quota-proxy部署环境的关键配置变量

用法:
  ./verify-env-vars.sh [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示检查项，不实际检查
  --quick, -q         快速检查模式，只检查必需变量
  --verbose, -v       详细输出模式，显示所有检查细节

检查项目:
  1. 必需环境变量检查
  2. 数据库配置检查
  3. 管理员配置检查
  4. 端口配置检查
  5. 日志配置检查

示例:
  ./verify-env-vars.sh                 # 完整检查
  ./verify-env-vars.sh --quick         # 快速检查必需变量
  ./verify-env-vars.sh --dry-run       # 显示检查项但不执行
  ./verify-env-vars.sh --verbose       # 详细输出

版本: 2026.02.11.15
EOF
}

# 必需环境变量列表
REQUIRED_VARS=(
    "DATABASE_URL"
    "ADMIN_TOKEN"
    "PORT"
)

# 推荐环境变量列表
RECOMMENDED_VARS=(
    "LOG_LEVEL"
    "CORS_ORIGIN"
    "RATE_LIMIT_PER_MINUTE"
    "MAX_REQUEST_SIZE_MB"
)

# 检查单个环境变量
check_env_var() {
    local var_name="$1"
    local required="$2"
    local description="$3"
    
    if [[ -z "${!var_name:-}" ]]; then
        if [[ "$required" == "required" ]]; then
            log_error "必需环境变量未设置: $var_name ($description)"
            return 1
        else
            log_warning "推荐环境变量未设置: $var_name ($description)"
            return 2
        fi
    else
        if [[ "$verbose" == "true" ]]; then
            log_success "环境变量已设置: $var_name=${!var_name} ($description)"
        else
            log_success "环境变量已设置: $var_name"
        fi
        return 0
    fi
}

# 检查端口配置
check_port_config() {
    local port="${PORT:-}"
    
    if [[ -z "$port" ]]; then
        log_error "PORT环境变量未设置"
        return 1
    fi
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "PORT必须是数字: $port"
        return 1
    fi
    
    if [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        log_error "PORT必须在1-65535范围内: $port"
        return 1
    fi
    
    log_success "端口配置有效: $port"
    return 0
}

# 检查数据库URL格式
check_database_url() {
    local db_url="${DATABASE_URL:-}"
    
    if [[ -z "$db_url" ]]; then
        log_error "DATABASE_URL环境变量未设置"
        return 1
    fi
    
    # 检查是否为SQLite格式
    if [[ "$db_url" =~ ^sqlite:///.*\.db$ ]]; then
        local db_file="${db_url#sqlite:///}"
        if [[ ! -f "$db_file" ]]; then
            log_warning "SQLite数据库文件不存在: $db_file (首次运行时会自动创建)"
        else
            log_success "SQLite数据库文件存在: $db_file"
        fi
    elif [[ "$db_url" =~ ^postgresql:// ]]; then
        log_success "PostgreSQL数据库URL格式正确"
    elif [[ "$db_url" =~ ^mysql:// ]]; then
        log_success "MySQL数据库URL格式正确"
    else
        log_warning "未知的数据库URL格式: $db_url"
    fi
    
    return 0
}

# 检查管理员令牌
check_admin_token() {
    local admin_token="${ADMIN_TOKEN:-}"
    
    if [[ -z "$admin_token" ]]; then
        log_error "ADMIN_TOKEN环境变量未设置"
        return 1
    fi
    
    # 检查令牌长度
    local token_length=${#admin_token}
    if [[ "$token_length" -lt 16 ]]; then
        log_warning "管理员令牌较短($token_length字符)，建议使用更长的令牌增强安全性"
    else
        log_success "管理员令牌长度合适: $token_length字符"
    fi
    
    return 0
}

# 主函数
main() {
    local dry_run="false"
    local quick_mode="false"
    local verbose="false"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --dry-run|-d)
                dry_run="true"
                shift
                ;;
            --quick|-q)
                quick_mode="true"
                shift
                ;;
            --verbose|-v)
                verbose="true"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "开始环境变量验证检查"
    log_info "当前目录: $(pwd)"
    log_info "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "干运行模式 - 显示检查项但不执行"
        echo ""
        log_info "将检查的必需环境变量:"
        for var in "${REQUIRED_VARS[@]}"; do
            echo "  - $var"
        done
        
        if [[ "$quick_mode" != "true" ]]; then
            echo ""
            log_info "将检查的推荐环境变量:"
            for var in "${RECOMMENDED_VARS[@]}"; do
                echo "  - $var"
            done
        fi
        
        echo ""
        log_info "将执行的特殊检查:"
        echo "  - 端口配置检查"
        echo "  - 数据库URL格式检查"
        echo "  - 管理员令牌检查"
        exit 0
    fi
    
    # 检查必需环境变量
    log_info "=== 必需环境变量检查 ==="
    local required_errors=0
    for var in "${REQUIRED_VARS[@]}"; do
        case "$var" in
            "DATABASE_URL")
                check_database_url || ((required_errors++))
                ;;
            "ADMIN_TOKEN")
                check_admin_token || ((required_errors++))
                ;;
            "PORT")
                check_port_config || ((required_errors++))
                ;;
            *)
                check_env_var "$var" "required" "必需配置" || ((required_errors++))
                ;;
        esac
    done
    
    if [[ "$quick_mode" != "true" ]]; then
        echo ""
        log_info "=== 推荐环境变量检查 ==="
        local recommended_warnings=0
        for var in "${RECOMMENDED_VARS[@]}"; do
            case "$var" in
                "LOG_LEVEL")
                    check_env_var "$var" "optional" "日志级别(debug/info/warn/error)" || ((recommended_warnings++))
                    ;;
                "CORS_ORIGIN")
                    check_env_var "$var" "optional" "CORS允许的源" || ((recommended_warnings++))
                    ;;
                "RATE_LIMIT_PER_MINUTE")
                    check_env_var "$var" "optional" "每分钟请求限制" || ((recommended_warnings++))
                    ;;
                "MAX_REQUEST_SIZE_MB")
                    check_env_var "$var" "optional" "最大请求大小(MB)" || ((recommended_warnings++))
                    ;;
                *)
                    check_env_var "$var" "optional" "推荐配置" || ((recommended_warnings++))
                    ;;
            esac
        done
    fi
    
    echo ""
    log_info "=== 检查结果汇总 ==="
    
    if [[ "$required_errors" -eq 0 ]]; then
        log_success "所有必需环境变量检查通过"
    else
        log_error "$required_errors 个必需环境变量检查失败"
    fi
    
    if [[ "$quick_mode" != "true" ]]; then
        if [[ "$recommended_warnings" -eq 0 ]]; then
            log_success "所有推荐环境变量检查通过"
        else
            log_warning "$recommended_warnings 个推荐环境变量未设置"
        fi
    fi
    
    echo ""
    if [[ "$required_errors" -eq 0 ]]; then
        log_success "环境变量验证完成 - 部署环境配置基本正常"
        log_info "建议: 运行 ./verify-sqlite-integrity.sh 检查数据库完整性"
        log_info "建议: 运行 curl -fsS http://127.0.0.1:\${PORT:-8787}/healthz 检查服务健康状态"
        return 0
    else
        log_error "环境变量验证失败 - 请修复必需环境变量配置"
        return 1
    fi
}

# 运行主函数
main "$@"