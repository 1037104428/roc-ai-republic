#!/usr/bin/env bash
#
# verify-quota-proxy-config.sh - 验证quota-proxy环境变量配置
#
# 用途：检查quota-proxy Docker容器的环境变量配置是否正确
# 支持模式：详细模式、安静模式、模拟运行、列表模式
#
# 退出码：
#   0 - 所有配置验证通过
#   1 - 配置验证失败
#   2 - 参数错误
#   3 - Docker容器未运行
#   4 - 环境变量缺失或无效
#
# 示例：
#   ./verify-quota-proxy-config.sh --verbose
#   ./verify-quota-proxy-config.sh --dry-run
#   ./verify-quota-proxy-config.sh --list
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
CONTAINER_NAME="quota-proxy-quota-proxy-1"
VERBOSE=false
QUIET=false
DRY_RUN=false
LIST_MODE=false
FAIL_ON_WARNING=false

# 必需的环境变量
REQUIRED_ENV_VARS=(
  "ADMIN_TOKEN"
  "DATABASE_PATH"
  "PORT"
  "LOG_LEVEL"
  "MAX_REQUESTS_PER_DAY"
  "TRIAL_KEY_EXPIRY_DAYS"
)

# 可选的环境变量（有默认值）
OPTIONAL_ENV_VARS=(
  "CORS_ORIGIN"
  "REQUEST_TIMEOUT_MS"
  "RATE_LIMIT_WINDOW_MS"
  "ENABLE_METRICS"
  "METRICS_PORT"
)

# 环境变量验证规则
declare -A ENV_VALIDATION_RULES=(
  ["ADMIN_TOKEN"]="^[a-zA-Z0-9_-]{32,128}$"  # 32-128位字母数字下划线短横线
  ["DATABASE_PATH"]="^/.*\.db$"              # 以/开头，以.db结尾
  ["PORT"]="^[0-9]{2,5}$"                    # 2-5位数字
  ["LOG_LEVEL"]="^(debug|info|warn|error)$"  # 预定义日志级别
  ["MAX_REQUESTS_PER_DAY"]="^[0-9]+$"        # 正整数
  ["TRIAL_KEY_EXPIRY_DAYS"]="^[0-9]+$"       # 正整数
  ["CORS_ORIGIN"]="^(\*|https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._-]*)*)?$"  # *或URL
  ["REQUEST_TIMEOUT_MS"]="^[0-9]+$"          # 正整数
  ["RATE_LIMIT_WINDOW_MS"]="^[0-9]+$"        # 正整数
  ["ENABLE_METRICS"]="^(true|false)$"        # true/false
  ["METRICS_PORT"]="^[0-9]{2,5}$"            # 2-5位数字
)

# 环境变量默认值
declare -A ENV_DEFAULT_VALUES=(
  ["CORS_ORIGIN"]="*"
  ["REQUEST_TIMEOUT_MS"]="30000"
  ["RATE_LIMIT_WINDOW_MS"]="60000"
  ["ENABLE_METRICS"]="false"
  ["METRICS_PORT"]="9090"
)

# 环境变量描述
declare -A ENV_DESCRIPTIONS=(
  ["ADMIN_TOKEN"]="管理员令牌，用于保护/admin接口"
  ["DATABASE_PATH"]="SQLite数据库文件路径"
  ["PORT"]="quota-proxy服务监听端口"
  ["LOG_LEVEL"]="日志级别：debug/info/warn/error"
  ["MAX_REQUESTS_PER_DAY"]="每个API密钥每日最大请求数"
  ["TRIAL_KEY_EXPIRY_DAYS"]="试用密钥过期天数"
  ["CORS_ORIGIN"]="CORS允许的源，默认为*"
  ["REQUEST_TIMEOUT_MS"]="请求超时时间（毫秒）"
  ["RATE_LIMIT_WINDOW_MS"]="速率限制窗口时间（毫秒）"
  ["ENABLE_METRICS"]="是否启用指标收集"
  ["METRICS_PORT"]="指标服务端口（如果启用）"
)

# 打印帮助信息
print_help() {
  cat << EOF
验证quota-proxy环境变量配置

用法: $0 [选项]

选项:
  -h, --help            显示此帮助信息
  -v, --verbose         详细输出模式
  -q, --quiet           安静模式，只输出错误
  -d, --dry-run         模拟运行，不实际检查
  -l, --list            列出所有环境变量及其描述
  -c, --container NAME  指定容器名称（默认: $CONTAINER_NAME）
  -f, --fail-on-warning 警告也视为失败

示例:
  $0 --verbose          详细检查配置
  $0 --dry-run          模拟运行
  $0 --list             列出所有环境变量
  $0 -c my-container    检查指定容器

退出码:
  0 - 所有配置验证通过
  1 - 配置验证失败
  2 - 参数错误
  3 - Docker容器未运行
  4 - 环境变量缺失或无效
EOF
}

# 打印带颜色的消息
print_info() {
  if [ "$QUIET" = false ]; then
    echo -e "${BLUE}[INFO]${NC} $1"
  fi
}

print_success() {
  if [ "$QUIET" = false ]; then
    echo -e "${GREEN}[SUCCESS]${NC} $1"
  fi
}

print_warning() {
  if [ "$QUIET" = false ]; then
    echo -e "${YELLOW}[WARNING]${NC} $1"
  fi
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_debug() {
  if [ "$VERBOSE" = true ] && [ "$QUIET" = false ]; then
    echo -e "${MAGENTA}[DEBUG]${NC} $1"
  fi
}

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        print_help
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
      -l|--list)
        LIST_MODE=true
        shift
        ;;
      -c|--container)
        if [[ -z "${2:-}" ]]; then
          print_error "选项 --container 需要一个参数"
          exit 2
        fi
        CONTAINER_NAME="$2"
        shift 2
        ;;
      -f|--fail-on-warning)
        FAIL_ON_WARNING=true
        shift
        ;;
      *)
        print_error "未知选项: $1"
        print_help
        exit 2
        ;;
    esac
  done
}

# 检查Docker容器是否运行
check_docker_container() {
  print_debug "检查Docker容器: $CONTAINER_NAME"
  
  if [ "$DRY_RUN" = true ]; then
    print_info "模拟运行: 跳过Docker容器检查"
    return 0
  fi
  
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Docker容器 '$CONTAINER_NAME' 未运行"
    return 3
  fi
  
  print_success "Docker容器 '$CONTAINER_NAME' 正在运行"
  return 0
}

# 获取容器环境变量
get_container_env_vars() {
  print_debug "获取容器环境变量"
  
  if [ "$DRY_RUN" = true ]; then
    print_info "模拟运行: 返回示例环境变量"
    # 返回示例环境变量
    cat << EOF
ADMIN_TOKEN=supersecretadmintoken1234567890abcdef
DATABASE_PATH=/data/quota.db
PORT=8787
LOG_LEVEL=info
MAX_REQUESTS_PER_DAY=1000
TRIAL_KEY_EXPIRY_DAYS=7
CORS_ORIGIN=*
REQUEST_TIMEOUT_MS=30000
RATE_LIMIT_WINDOW_MS=60000
ENABLE_METRICS=false
METRICS_PORT=9090
EOF
    return 0
  fi
  
  docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{println .}}{{end}}'
}

# 验证环境变量值
validate_env_value() {
  local var_name="$1"
  local var_value="$2"
  local validation_rule="${ENV_VALIDATION_RULES[$var_name]:-}"
  
  if [ -z "$validation_rule" ]; then
    print_warning "变量 '$var_name' 没有验证规则，跳过验证"
    return 0
  fi
  
  if [[ "$var_value" =~ $validation_rule ]]; then
    print_debug "变量 '$var_name' 验证通过: $var_value"
    return 0
  else
    print_error "变量 '$var_name' 验证失败: $var_value (规则: $validation_rule)"
    return 1
  fi
}

# 检查必需的环境变量
check_required_env_vars() {
  local env_vars="$1"
  local missing_vars=()
  local invalid_vars=()
  
  print_debug "检查必需的环境变量"
  
  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    local var_value=$(echo "$env_vars" | grep "^${var_name}=" | cut -d= -f2-)
    
    if [ -z "$var_value" ]; then
      missing_vars+=("$var_name")
      print_error "必需环境变量缺失: $var_name"
    else
      if ! validate_env_value "$var_name" "$var_value"; then
        invalid_vars+=("$var_name")
      else
        print_success "必需环境变量验证通过: $var_name=$var_value"
      fi
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    print_error "缺失必需环境变量: ${missing_vars[*]}"
    return 4
  fi
  
  if [ ${#invalid_vars[@]} -gt 0 ]; then
    print_error "无效的环境变量值: ${invalid_vars[*]}"
    return 4
  fi
  
  return 0
}

# 检查可选的环境变量
check_optional_env_vars() {
  local env_vars="$1"
  local warnings=()
  
  print_debug "检查可选的环境变量"
  
  for var_name in "${OPTIONAL_ENV_VARS[@]}"; do
    local var_value=$(echo "$env_vars" | grep "^${var_name}=" | cut -d= -f2-)
    local default_value="${ENV_DEFAULT_VALUES[$var_name]}"
    
    if [ -z "$var_value" ]; then
      print_warning "可选环境变量未设置 '$var_name'，将使用默认值: $default_value"
      warnings+=("$var_name (使用默认值: $default_value)")
    else
      if ! validate_env_value "$var_name" "$var_value"; then
        print_warning "可选环境变量 '$var_name' 值无效: $var_value，建议使用默认值: $default_value"
        warnings+=("$var_name (无效值: $var_value)")
      else
        print_success "可选环境变量验证通过: $var_name=$var_value"
      fi
    fi
  done
  
  if [ ${#warnings[@]} -gt 0 ] && [ "$FAIL_ON_WARNING" = true ]; then
    print_error "发现警告（--fail-on-warning启用）: ${warnings[*]}"
    return 1
  fi
  
  return 0
}

# 列出所有环境变量
list_env_vars() {
  print_info "quota-proxy环境变量列表:"
  echo ""
  
  echo "必需环境变量:"
  echo "-------------"
  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    local description="${ENV_DESCRIPTIONS[$var_name]}"
    local validation_rule="${ENV_VALIDATION_RULES[$var_name]:-无}"
    echo "  $var_name"
    echo "    描述: $description"
    echo "    验证规则: $validation_rule"
    echo ""
  done
  
  echo "可选环境变量:"
  echo "-------------"
  for var_name in "${OPTIONAL_ENV_VARS[@]}"; do
    local description="${ENV_DESCRIPTIONS[$var_name]}"
    local default_value="${ENV_DEFAULT_VALUES[$var_name]}"
    local validation_rule="${ENV_VALIDATION_RULES[$var_name]:-无}"
    echo "  $var_name"
    echo "    描述: $description"
    echo "    默认值: $default_value"
    echo "    验证规则: $validation_rule"
    echo ""
  done
  
  echo "环境变量配置文件示例 (.env):"
  echo "---------------------------"
  for var_name in "${REQUIRED_ENV_VARS[@]}"; do
    echo "$var_NAME=your_value_here"
  done
  for var_name in "${OPTIONAL_ENV_VARS[@]}"; do
    echo "# $var_NAME=${ENV_DEFAULT_VALUES[$var_name]}"
  done
}

# 主函数
main() {
  parse_args "$@"
  
  if [ "$LIST_MODE" = true ]; then
    list_env_vars
    exit 0
  fi
  
  print_info "开始验证quota-proxy环境变量配置"
  print_info "容器名称: $CONTAINER_NAME"
  print_info "模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际检查")"
  print_info "详细模式: $([ "$VERBOSE" = true ] && echo "是" || echo "否")"
  print_info "安静模式: $([ "$QUIET" = true ] && echo "是" || echo "否")"
  echo ""
  
  # 检查Docker容器
  if ! check_docker_container; then
    exit 3
  fi
  
  # 获取环境变量
  local env_vars
  env_vars=$(get_container_env_vars)
  
  if [ -z "$env_vars" ]; then
    print_error "无法获取容器环境变量"
    exit 4
  fi
  
  print_debug "获取到的环境变量:\n$env_vars"
  
  # 检查必需的环境变量
  if ! check_required_env_vars "$env_vars"; then
    exit 4
  fi
  
  # 检查可选的环境变量
  if ! check_optional_env_vars "$env_vars"; then
    if [ "$FAIL_ON_WARNING" = true ]; then
      exit 1
    fi
  fi
  
  print_success "所有环境变量配置验证通过！"
  print_info "quota-proxy配置正确，服务可以正常运行。"
  
  exit 0
}

# 运行主函数
main "$@"