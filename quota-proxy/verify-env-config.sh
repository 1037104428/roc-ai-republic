#!/bin/bash

# verify-env-config.sh - 验证quota-proxy环境变量配置脚本
# 快速检查部署环境的关键配置变量，帮助用户诊断配置问题

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DRY_RUN=false
VERBOSE=false
CONFIG_FILE=""
ENV_FILE=""

# 显示帮助信息
show_help() {
    cat << 'HELPEOF'
验证quota-proxy环境变量配置脚本

用法: $0 [选项]

选项:
  --dry-run           干运行模式，只显示检查项，不实际验证
  --verbose           详细输出模式
  --config-file FILE  指定配置文件路径（默认：当前目录的.env文件）
  --env-file FILE     指定环境变量文件路径（默认：当前目录的.env文件）
  --help              显示此帮助信息

功能:
  1. 检查必需环境变量是否设置
  2. 验证环境变量格式和有效性
  3. 检查配置文件是否存在和可读
  4. 验证端口和URL格式
  5. 提供配置建议和修复提示

必需环境变量:
  - ADMIN_TOKEN: 管理员令牌（用于管理API）
  - PORT: 服务端口（默认：8787）
  - DATABASE_URL: SQLite数据库路径（可选，默认：./data/quota.db）

示例:
  $0 --dry-run
  $0 --config-file /opt/roc/quota-proxy/.env
  $0 --verbose

HELPEOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 打印消息
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

# 检查环境变量
check_env_var() {
    local var_name="$1"
    local required="${2:-false}"
    local description="$3"
    
    if [ "$DRY_RUN" = true ]; then
        if [ "$required" = true ]; then
            log_info "将检查必需环境变量: $var_name ($description)"
        else
            log_info "将检查可选环境变量: $var_name ($description)"
        fi
        return 0
    fi
    
    # 使用间接引用获取变量值
    local value=""
    if [ -n "${!var_name+x}" ]; then
        value="${!var_name}"
    fi
    
    if [ -z "$value" ]; then
        if [ "$required" = true ]; then
            log_error "必需环境变量未设置: $var_name ($description)"
            return 1
        else
            log_warning "可选环境变量未设置: $var_name ($description)"
            return 0
        fi
    else
        if [ "$VERBOSE" = true ]; then
            log_success "环境变量已设置: $var_name=$value ($description)"
        else
            log_success "环境变量已设置: $var_name"
        fi
        return 0
    fi
}

# 验证端口格式
validate_port() {
    local port="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "将验证端口格式: $port"
        return 0
    fi
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log_error "端口格式无效: $port (必须是数字)"
        return 1
    fi
    
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "端口范围无效: $port (必须在1-65535之间)"
        return 1
    fi
    
    if [ "$port" -lt 1024 ]; then
        log_warning "端口 $port 小于1024，可能需要root权限"
    fi
    
    log_success "端口格式有效: $port"
    return 0
}

# 验证URL格式
validate_url() {
    local url="$1"
    local var_name="$2"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "将验证URL格式: $var_name=$url"
        return 0
    fi
    
    if [[ "$url" =~ ^https?:// ]]; then
        log_success "URL格式有效: $var_name"
        return 0
    else
        log_warning "URL格式可能无效: $var_name=$url (应以http://或https://开头)"
        return 0
    fi
}

# 验证数据库路径
validate_db_path() {
    local db_path="$1"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "将验证数据库路径: $db_path"
        return 0
    fi
    
    if [[ "$db_path" == *.db ]] || [[ "$db_path" == *.sqlite ]] || [[ "$db_path" == *.sqlite3 ]]; then
        log_success "数据库路径格式有效: $db_path"
        return 0
    else
        log_warning "数据库路径可能无效: $db_path (建议使用.db、.sqlite或.sqlite3扩展名)"
        return 0
    fi
}

# 加载环境变量文件
load_env_file() {
    local env_file="${ENV_FILE:-${CONFIG_FILE:-.env}}"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "将加载环境变量文件: $env_file"
        return 0
    fi
    
    if [ -f "$env_file" ]; then
        if [ -r "$env_file" ]; then
            # 安全地加载环境变量，不执行代码
            while IFS='=' read -r key value || [ -n "$key" ]; do
                # 跳过注释和空行
                [[ "$key" =~ ^#.*$ ]] && continue
                [[ -z "$key" ]] && continue
                
                # 移除可能的引号
                key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^['\"]//;s/['\"]$//")
                
                # 设置环境变量
                export "$key"="$value"
                
                if [ "$VERBOSE" = true ]; then
                    log_info "从文件加载: $key=$value"
                fi
            done < "$env_file"
            
            log_success "环境变量文件加载成功: $env_file"
            return 0
        else
            log_error "环境变量文件不可读: $env_file"
            return 1
        fi
    else
        log_warning "环境变量文件不存在: $env_file (将检查已设置的环境变量)"
        return 0
    fi
}

# 主验证函数
main_validation() {
    local errors=0
    local warnings=0
    
    log_info "开始验证quota-proxy环境变量配置..."
    
    # 加载环境变量文件
    if ! load_env_file; then
        errors=$((errors + 1))
    fi
    
    # 检查必需环境变量
    log_info "检查必需环境变量..."
    
    if ! check_env_var "ADMIN_TOKEN" true "管理员令牌（用于管理API）"; then
        errors=$((errors + 1))
    fi
    
    # 检查可选环境变量
    log_info "检查可选环境变量..."
    
    check_env_var "PORT" false "服务端口（默认：8787）"
    check_env_var "DATABASE_URL" false "SQLite数据库路径（默认：./data/quota.db）"
    check_env_var "LOG_LEVEL" false "日志级别（默认：info）"
    check_env_var "CORS_ORIGIN" false "CORS允许的源（默认：*）"
    check_env_var "RATE_LIMIT" false "速率限制（默认：100/分钟）"
    
    # 验证端口格式
    if [ -n "${PORT:-}" ]; then
        if ! validate_port "$PORT"; then
            errors=$((errors + 1))
        fi
    fi
    
    # 验证数据库路径格式
    if [ -n "${DATABASE_URL:-}" ]; then
        if ! validate_db_path "$DATABASE_URL"; then
            warnings=$((warnings + 1))
        fi
    fi
    
    # 验证其他URL格式的变量
    if [ -n "${CORS_ORIGIN:-}" ] && [ "$CORS_ORIGIN" != "*" ]; then
        validate_url "$CORS_ORIGIN" "CORS_ORIGIN"
    fi
    
    # 提供配置建议
    log_info "配置建议检查..."
    
    if [ -z "${PORT:-}" ]; then
        log_warning "建议设置PORT环境变量（默认使用8787）"
        warnings=$((warnings + 1))
    fi
    
    if [ -z "${DATABASE_URL:-}" ]; then
        log_warning "建议设置DATABASE_URL环境变量以启用持久化（默认：./data/quota.db）"
        warnings=$((warnings + 1))
    fi
    
    if [ -z "${LOG_LEVEL:-}" ]; then
        log_info "建议设置LOG_LEVEL环境变量控制日志详细程度（可选：debug, info, warn, error）"
    fi
    
    # 总结
    log_info "验证完成"
    log_info "错误数: $errors"
    log_info "警告数: $warnings"
    
    if [ "$errors" -gt 0 ]; then
        log_error "环境变量配置验证失败，请修复上述错误"
        return 1
    elif [ "$warnings" -gt 0 ]; then
        log_warning "环境变量配置验证通过，但有警告需要关注"
        return 0
    else
        log_success "环境变量配置验证通过"
        return 0
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "=== 干运行模式 ==="
        log_info "将执行以下验证步骤:"
        log_info "1. 加载环境变量文件"
        log_info "2. 检查必需环境变量 (ADMIN_TOKEN)"
        log_info "3. 检查可选环境变量 (PORT, DATABASE_URL等)"
        log_info "4. 验证端口格式"
        log_info "5. 验证数据库路径格式"
        log_info "6. 提供配置建议"
        log_info "=== 干运行结束 ==="
        exit 0
    fi
    
    if ! main_validation; then
        exit 1
    fi
}

# 运行主函数
main "$@"