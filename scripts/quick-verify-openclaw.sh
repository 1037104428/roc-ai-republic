#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 快速验证脚本
# 在安装后快速验证OpenClaw安装是否成功
# 目标：提供轻量级、快速的安装验证，无需完整验证脚本

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[快速验证]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[快速验证] ✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[快速验证] ⚠️${NC} $1"
}

log_error() {
  echo -e "${RED}[快速验证] ❌${NC} $1"
}

usage() {
  cat <<'TXT'
OpenClaw 快速验证脚本

用法:
  ./quick-verify-openclaw.sh [选项]

选项:
  --quiet         安静模式，只输出关键信息
  --verbose       详细模式，输出所有检查细节
  --json          以JSON格式输出结果
  --help          显示帮助信息

环境变量:
  OPENCLAW_PATH   指定openclaw可执行文件路径（默认: 自动检测）

退出码:
  0 - 所有检查通过
  1 - 部分检查失败
  2 - 参数错误
TXT
}

# 默认选项
QUIET=0
VERBOSE=0
JSON_OUTPUT=0

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "未知参数: $1"
      usage
      exit 2
      ;;
  esac
done

# 检查结果数组
declare -A CHECK_RESULTS
declare -A CHECK_MESSAGES

# 添加检查结果
add_check() {
  local name="$1"
  local status="$2"
  local message="$3"
  
  CHECK_RESULTS["$name"]="$status"
  CHECK_MESSAGES["$name"]="$message"
}

# 检查1: openclaw命令是否存在
check_openclaw_command() {
  local openclaw_path="${OPENCLAW_PATH:-}"
  
  if [[ -n "$openclaw_path" ]] && [[ -x "$openclaw_path" ]]; then
    add_check "openclaw_command" "success" "openclaw命令在指定路径找到: $openclaw_path"
    echo "$openclaw_path"
    return 0
  fi
  
  # 自动检测
  if command -v openclaw >/dev/null 2>&1; then
    local path=$(command -v openclaw)
    add_check "openclaw_command" "success" "openclaw命令在PATH中找到: $path"
    echo "$path"
    return 0
  fi
  
  # 检查npm全局bin目录
  local npm_bin_path=$(npm bin -g 2>/dev/null || echo "")
  if [[ -n "$npm_bin_path" ]] && [[ -x "$npm_bin_path/openclaw" ]]; then
    add_check "openclaw_command" "warning" "openclaw在npm全局bin目录找到但不在PATH中: $npm_bin_path/openclaw"
    echo "$npm_bin_path/openclaw"
    return 0
  fi
  
  add_check "openclaw_command" "error" "openclaw命令未找到。请确保安装成功且PATH配置正确"
  echo ""
  return 1
}

# 检查2: openclaw版本
check_openclaw_version() {
  local openclaw_path="$1"
  
  if [[ -z "$openclaw_path" ]]; then
    add_check "openclaw_version" "error" "无法检查版本：openclaw命令未找到"
    return 1
  fi
  
  local version_output
  if version_output=$("$openclaw_path" --version 2>/dev/null); then
    add_check "openclaw_version" "success" "OpenClaw版本: $version_output"
    echo "$version_output"
    return 0
  else
    add_check "openclaw_version" "error" "无法获取OpenClaw版本"
    return 1
  fi
}

# 检查3: 配置文件是否存在
check_config_file() {
  local config_path="$HOME/.openclaw/openclaw.json"
  
  if [[ -f "$config_path" ]]; then
    local config_size=$(stat -c%s "$config_path" 2>/dev/null || echo "unknown")
    add_check "config_file" "success" "配置文件存在: $config_path (大小: ${config_size}字节)"
    return 0
  else
    add_check "config_file" "warning" "配置文件不存在: $config_path。运行 'openclaw config init' 创建"
    return 1
  fi
}

# 检查4: 工作空间目录
check_workspace_dir() {
  local workspace_path="$HOME/.openclaw/workspace"
  
  if [[ -d "$workspace_path" ]]; then
    local file_count=$(find "$workspace_path" -type f -name "*.md" 2>/dev/null | wc -l)
    add_check "workspace_dir" "success" "工作空间目录存在: $workspace_path (包含 ${file_count} 个.md文件)"
    return 0
  else
    add_check "workspace_dir" "info" "工作空间目录不存在: $workspace_path。将在首次运行时创建"
    return 0
  fi
}

# 检查5: Gateway状态
check_gateway_status() {
  local openclaw_path="$1"
  
  if [[ -z "$openclaw_path" ]]; then
    add_check "gateway_status" "error" "无法检查Gateway状态：openclaw命令未找到"
    return 1
  fi
  
  if "$openclaw_path" gateway status 2>/dev/null | grep -q "running\|active"; then
    add_check "gateway_status" "success" "Gateway正在运行"
    return 0
  else
    add_check "gateway_status" "warning" "Gateway未运行。运行 'openclaw gateway start' 启动"
    return 1
  fi
}

# 检查6: 模型状态
check_models_status() {
  local openclaw_path="$1"
  
  if [[ -z "$openclaw_path" ]]; then
    add_check "models_status" "error" "无法检查模型状态：openclaw命令未找到"
    return 1
  fi
  
  # 尝试获取模型状态，但忽略错误（模型可能未配置）
  if "$openclaw_path" models status 2>&1 | grep -q -E "(available|configured|error)"; then
    add_check "models_status" "success" "模型状态检查完成"
    return 0
  else
    add_check "models_status" "info" "模型状态检查失败或未配置模型。运行 'openclaw models status' 查看详情"
    return 0
  fi
}

# 主验证函数
main() {
  log_info "开始OpenClaw快速验证..."
  log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo ""
  
  # 执行检查
  local openclaw_path=$(check_openclaw_command)
  check_openclaw_version "$openclaw_path"
  check_config_file
  check_workspace_dir
  check_gateway_status "$openclaw_path"
  check_models_status "$openclaw_path"
  
  echo ""
  log_info "验证结果汇总:"
  echo ""
  
  # 统计结果
  local success_count=0
  local warning_count=0
  local error_count=0
  local info_count=0
  
  for check_name in "${!CHECK_RESULTS[@]}"; do
    local status="${CHECK_RESULTS[$check_name]}"
    local message="${CHECK_MESSAGES[$check_name]}"
    
    case "$status" in
      "success")
        ((success_count++))
        if [[ "$QUIET" -eq 0 ]]; then
          log_success "$message"
        fi
        ;;
      "warning")
        ((warning_count++))
        if [[ "$QUIET" -eq 0 ]] || [[ "$VERBOSE" -eq 1 ]]; then
          log_warning "$message"
        fi
        ;;
      "error")
        ((error_count++))
        if [[ "$QUIET" -eq 0 ]] || [[ "$VERBOSE" -eq 1 ]]; then
          log_error "$message"
        fi
        ;;
      "info")
        ((info_count++))
        if [[ "$VERBOSE" -eq 1 ]]; then
          log_info "$message"
        fi
        ;;
    esac
  done
  
  echo ""
  log_info "检查统计:"
  echo "  ✅ 成功: $success_count"
  echo "  ⚠️  警告: $warning_count"
  echo "  ❌ 错误: $error_count"
  echo "  ℹ️  信息: $info_count"
  echo ""
  
  # JSON输出模式
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"checks\": {"
    local first=true
    for check_name in "${!CHECK_RESULTS[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        echo ","
      fi
      echo -n "    \"$check_name\": {"
      echo -n "\"status\": \"${CHECK_RESULTS[$check_name]}\","
      echo -n "\"message\": \"${CHECK_MESSAGES[$check_name]//\"/\\\"}\""
      echo -n "}"
    done
    echo ""
    echo "  },"
    echo "  \"summary\": {"
    echo "    \"success\": $success_count,"
    echo "    \"warning\": $warning_count,"
    echo "    \"error\": $error_count,"
    echo "    \"info\": $info_count"
    echo "  }"
    echo "}"
  fi
  
  # 最终建议
  if [[ "$error_count" -eq 0 ]] && [[ "$warning_count" -eq 0 ]]; then
    log_success "所有检查通过！OpenClaw安装验证成功。"
    echo ""
    log_info "下一步建议:"
    echo "  1. 配置模型提供商（如DeepSeek）"
    echo "  2. 运行 'openclaw status' 查看完整状态"
    echo "  3. 访问文档: https://docs.openclaw.ai"
    exit 0
  elif [[ "$error_count" -eq 0 ]]; then
    log_warning "安装基本成功，但有警告需要关注。"
    echo ""
    log_info "建议操作:"
    echo "  1. 查看上面的警告信息"
    echo "  2. 运行 'openclaw gateway start'（如果Gateway未运行）"
    echo "  3. 运行 'openclaw config init'（如果配置文件不存在）"
    exit 0
  else
    log_error "安装存在问题，请检查错误信息。"
    echo ""
    log_info "故障排除:"
    echo "  1. 确保Node.js >= 20: node -v"
    echo "  2. 检查npm全局安装: npm list -g openclaw"
    echo "  3. 检查PATH配置: echo \$PATH"
    echo "  4. 重新安装: npm i -g openclaw@latest"
    exit 1
  fi
}

# 运行主函数
main "$@"