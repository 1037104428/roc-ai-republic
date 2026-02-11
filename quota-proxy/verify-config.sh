#!/bin/bash
# quota-proxy 配置验证脚本
# 版本: 1.0.0
# 日期: 2026-02-11
# 功能: 验证 quota-proxy 环境变量配置是否正确

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
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
quota-proxy 配置验证脚本

用法: ./verify-config.sh [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示检查项不实际执行
  --env-file FILE     从指定环境文件加载配置（默认: .env）
  --strict, -s        严格模式，任何检查失败都会导致脚本退出

功能:
  1. 检查必需环境变量是否存在
  2. 验证环境变量格式是否正确
  3. 检查端口是否可用
  4. 验证数据库文件路径
  5. 检查管理员令牌格式

示例:
  ./verify-config.sh                    # 基本验证
  ./verify-config.sh --dry-run          # 干运行模式
  ./verify-config.sh --env-file .env.production  # 指定环境文件
  ./verify-config.sh --strict           # 严格模式

退出码:
  0 - 所有检查通过
  1 - 检查失败
  2 - 参数错误
EOF
}

# 解析参数
DRY_RUN=false
STRICT=false
ENV_FILE=".env"

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --strict|-s)
            STRICT=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 2
            ;;
    esac
done

# 检查环境文件
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warning "环境文件 $ENV_FILE 不存在，使用环境变量"
        return 1
    fi
    
    log_info "加载环境文件: $ENV_FILE"
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 将加载环境文件 $ENV_FILE"
        return 0
    fi
    
    # 安全地加载环境文件
    if [ -f "$ENV_FILE" ]; then
        # 只导出有效的变量赋值
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # 跳过注释和空行
            if [[ $key =~ ^# ]] || [[ -z "$key" ]] || [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                continue
            fi
            
            # 提取变量名和值
            var_name=$(echo "$key" | cut -d'=' -f1)
            var_value=$(echo "$key" | cut -d'=' -f2-)
            
            # 移除引号
            var_value=$(echo "$var_value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            # 导出变量
            export "$var_name"="$var_value"
        done < "$ENV_FILE"
    fi
    
    return 0
}

# 检查必需环境变量
check_required_vars() {
    log_info "检查必需环境变量..."
    
    local missing_vars=()
    local required_vars=("PORT" "ADMIN_TOKEN")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "缺少必需环境变量: ${missing_vars[*]}"
        return 1
    fi
    
    log_success "所有必需环境变量都存在"
    return 0
}

# 验证环境变量格式
validate_var_formats() {
    log_info "验证环境变量格式..."
    
    local errors=0
    
    # 验证端口号
    if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        log_error "PORT 必须是 1-65535 之间的数字，当前值: $PORT"
        errors=$((errors + 1))
    else
        log_success "PORT 格式正确: $PORT"
    fi
    
    # 验证管理员令牌长度
    if [ -n "$ADMIN_TOKEN" ]; then
        local token_len=${#ADMIN_TOKEN}
        if [ $token_len -lt 16 ]; then
            log_warning "ADMIN_TOKEN 长度较短 ($token_len 字符)，建议至少 32 字符"
        else
            log_success "ADMIN_TOKEN 长度合适: $token_len 字符"
        fi
    fi
    
    # 验证数据库文件路径（如果设置了）
    if [ -n "$DB_PATH" ]; then
        local dir=$(dirname "$DB_PATH")
        if [ ! -d "$dir" ]; then
            log_warning "数据库目录不存在: $dir"
        else
            log_success "数据库目录存在: $dir"
        fi
    fi
    
    # 验证日志级别
    if [ -n "$LOG_LEVEL" ]; then
        local valid_levels=("debug" "info" "warn" "error")
        local found=false
        for level in "${valid_levels[@]}"; do
            if [ "$LOG_LEVEL" = "$level" ]; then
                found=true
                break
            fi
        done
        
        if [ "$found" = false ]; then
            log_error "LOG_LEVEL 必须是 debug/info/warn/error 之一，当前值: $LOG_LEVEL"
            errors=$((errors + 1))
        else
            log_success "LOG_LEVEL 有效: $LOG_LEVEL"
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "所有环境变量格式验证通过"
        return 0
    else
        log_error "发现 $errors 个格式错误"
        return 1
    fi
}

# 检查端口是否可用
check_port_availability() {
    log_info "检查端口可用性..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 将检查端口 $PORT 是否可用"
        return 0
    fi
    
    # 检查端口是否被占用
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i :$PORT >/dev/null 2>&1; then
            log_warning "端口 $PORT 已被占用"
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$PORT "; then
            log_warning "端口 $PORT 已被占用"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":$PORT "; then
            log_warning "端口 $PORT 已被占用"
            return 1
        fi
    else
        log_warning "无法检查端口占用情况（缺少 lsof/netstat/ss 命令）"
    fi
    
    log_success "端口 $PORT 可用"
    return 0
}

# 验证数据库文件
validate_database_file() {
    log_info "验证数据库文件..."
    
    if [ -z "$DB_PATH" ]; then
        log_info "未设置 DB_PATH，使用默认内存数据库"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 将检查数据库文件 $DB_PATH"
        return 0
    fi
    
    # 检查数据库文件是否存在
    if [ -f "$DB_PATH" ]; then
        # 检查文件是否可读写
        if [ -r "$DB_PATH" ] && [ -w "$DB_PATH" ]; then
            log_success "数据库文件可读写: $DB_PATH"
            
            # 检查文件大小
            local size=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH" 2>/dev/null || echo "0")
            log_info "数据库文件大小: $size 字节"
            
            # 简单检查是否为 SQLite 文件
            if [ $size -ge 100 ]; then
                if head -c 16 "$DB_PATH" | grep -q "SQLite format"; then
                    log_success "数据库文件是有效的 SQLite 格式"
                else
                    log_warning "数据库文件可能不是有效的 SQLite 格式"
                fi
            fi
        else
            log_error "数据库文件不可读写: $DB_PATH"
            return 1
        fi
    else
        log_info "数据库文件不存在，将在启动时创建: $DB_PATH"
        
        # 检查目录是否可写
        local dir=$(dirname "$DB_PATH")
        if [ -w "$dir" ]; then
            log_success "数据库目录可写: $dir"
        else
            log_error "数据库目录不可写: $dir"
            return 1
        fi
    fi
    
    return 0
}

# 验证管理员令牌格式
validate_admin_token() {
    log_info "验证管理员令牌格式..."
    
    if [ -z "$ADMIN_TOKEN" ]; then
        log_error "ADMIN_TOKEN 未设置"
        return 1
    fi
    
    # 检查令牌长度
    local token_len=${#ADMIN_TOKEN}
    if [ $token_len -lt 8 ]; then
        log_error "ADMIN_TOKEN 太短（$token_len 字符），建议至少 16 字符"
        return 1
    fi
    
    # 检查令牌复杂度（至少包含字母和数字）
    if [[ ! "$ADMIN_TOKEN" =~ [A-Za-z] ]] || [[ ! "$ADMIN_TOKEN" =~ [0-9] ]]; then
        log_warning "ADMIN_TOKEN 复杂度较低，建议包含字母和数字"
    fi
    
    log_success "管理员令牌格式基本正确（长度: $token_len 字符）"
    return 0
}

# 显示配置摘要
show_config_summary() {
    log_info "配置摘要:"
    
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│                quota-proxy 配置摘要                 │"
    echo "├─────────────────────────────────────────────────────┤"
    echo "│ 环境文件:    ${ENV_FILE:-未指定}                    "
    echo "│ 端口:        ${PORT:-未设置}                        "
    echo "│ 数据库路径:  ${DB_PATH:-内存数据库}                 "
    echo "│ 日志级别:    ${LOG_LEVEL:-info}                     "
    echo "│ 管理员令牌:  ${ADMIN_TOKEN:0:8}... (长度: ${#ADMIN_TOKEN})"
    echo "└─────────────────────────────────────────────────────┘"
    
    if [ -n "$TRIAL_KEY_EXPIRY_DAYS" ]; then
        echo "试用密钥有效期: $TRIAL_KEY_EXPIRY_DAYS 天"
    fi
    
    if [ -n "$DAILY_QUOTA_LIMIT" ]; then
        echo "每日配额限制: $DAILY_QUOTA_LIMIT 次"
    fi
}

# 主函数
main() {
    log_info "开始 quota-proxy 配置验证"
    log_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_info "工作目录: $(pwd)"
    
    # 加载环境文件
    check_env_file
    
    # 显示配置摘要
    show_config_summary
    
    # 执行检查
    local check_results=()
    
    log_info "执行配置检查..."
    echo "──────────────────────────────────────────────────────"
    
    # 检查必需环境变量
    if check_required_vars; then
        check_results+=("✓ 必需环境变量")
    else
        check_results+=("✗ 必需环境变量")
        if [ "$STRICT" = true ]; then
            log_error "严格模式: 必需环境变量检查失败"
            exit 1
        fi
    fi
    
    # 验证环境变量格式
    if validate_var_formats; then
        check_results+=("✓ 环境变量格式")
    else
        check_results+=("✗ 环境变量格式")
        if [ "$STRICT" = true ]; then
            log_error "严格模式: 环境变量格式验证失败"
            exit 1
        fi
    fi
    
    # 检查端口可用性
    if check_port_availability; then
        check_results+=("✓ 端口可用性")
    else
        check_results+=("✗ 端口可用性")
        if [ "$STRICT" = true ]; then
            log_error "严格模式: 端口可用性检查失败"
            exit 1
        fi
    fi
    
    # 验证数据库文件
    if validate_database_file; then
        check_results+=("✓ 数据库文件")
    else
        check_results+=("✗ 数据库文件")
        if [ "$STRICT" = true ]; then
            log_error "严格模式: 数据库文件验证失败"
            exit 1
        fi
    fi
    
    # 验证管理员令牌
    if validate_admin_token; then
        check_results+=("✓ 管理员令牌")
    else
        check_results+=("✗ 管理员令牌")
        if [ "$STRICT" = true ]; then
            log_error "严格模式: 管理员令牌验证失败"
            exit 1
        fi
    fi
    
    echo "──────────────────────────────────────────────────────"
    
    # 显示检查结果
    log_info "检查结果汇总:"
    for result in "${check_results[@]}"; do
        if [[ $result == ✓* ]]; then
            echo -e "  ${GREEN}$result${NC}"
        else
            echo -e "  ${RED}$result${NC}"
        fi
    done
    
    # 统计结果
    local total_checks=${#check_results[@]}
    local passed_checks=0
    for result in "${check_results[@]}"; do
        if [[ $result == ✓* ]]; then
            passed_checks=$((passed_checks + 1))
        fi
    done
    
    local failed_checks=$((total_checks - passed_checks))
    
    echo "──────────────────────────────────────────────────────"
    
    if [ $failed_checks -eq 0 ]; then
        log_success "所有检查通过 ($passed_checks/$total_checks)"
        log_success "配置验证完成，quota-proxy 可以正常启动"
        exit 0
    else
        log_warning "部分检查失败 ($passed_checks/$total_checks 通过)"
        log_warning "发现 $failed_checks 个问题需要修复"
        
        if [ "$DRY_RUN" = true ]; then
            log_info "干运行模式完成，未执行实际检查"
            exit 0
        else
            exit 1
        fi
    fi
}

# 执行主函数
main "$@"