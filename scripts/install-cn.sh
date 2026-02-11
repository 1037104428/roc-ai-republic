#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN quick install
# Goals:
# - Prefer a mainland-friendly npm registry (npmmirror)
# - Fallback to npmjs if install fails
# - Do NOT permanently change user's npm registry config
# - Self-check: openclaw --version
#
# Usage:
#   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
#   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
#   NPM_REGISTRY=https://registry.npmmirror.com OPENCLAW_VERSION=latest bash install-cn.sh
#
# CI/CD Integration:
#   export CI_MODE=1
#   export OPENCLAW_VERSION=latest
#   export NPM_REGISTRY=https://registry.npmmirror.com
#   export SKIP_INTERACTIVE=1
#   export INSTALL_LOG=/tmp/openclaw-install-ci.log
#   bash install-cn.sh

# Script version for update checking
SCRIPT_VERSION="2026.02.11.1839"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh"

# Logging functions
log_info() {
  color_log "INFO" "$1"
}

log_success() {
  color_log "SUCCESS" "$1"
}

log_warning() {
  color_log "WARNING" "$1"
}

log_error() {
  color_log "ERROR" "$1"
}

log_debug() {
  color_log "DEBUG" "$1"
}

# Version compatibility checking
check_version_compatibility() {
  local version="$1"
  log_info "Checking version compatibility for: $version"
  
  # Extract major.minor.patch if available
  local major=""
  local minor=""
  local patch=""
  
  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    log_debug "Parsed version: major=$major, minor=$minor, patch=$patch"
  elif [[ "$version" == "latest" ]]; then
    log_info "Using 'latest' version - skipping compatibility checks"
    return 0
  else
    log_warning "Version format not recognized: $version - skipping compatibility checks"
    return 0
  fi
  
  # Check Node.js version compatibility
  local node_version
  node_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "0.0.0")
  log_debug "Detected Node.js version: $node_version"
  
  # OpenClaw 0.3.x requires Node.js >= 18.0.0
  if [[ "$major" -eq 0 && "$minor" -eq 3 ]]; then
    local node_major
    node_major=$(echo "$node_version" | cut -d. -f1)
    if [[ "$node_major" -lt 18 ]]; then
      log_warning "OpenClaw 0.3.x requires Node.js 18+ (detected: $node_version)"
      log_warning "Consider upgrading Node.js or using an older OpenClaw version"
      if [[ "${SKIP_INTERACTIVE:-0}" -eq 0 ]]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          log_error "Installation cancelled due to Node.js version incompatibility"
          return 1
        fi
      fi
    fi
  fi
  
  # Check npm version compatibility
  local npm_version
  npm_version=$(npm --version 2>/dev/null || echo "0.0.0")
  log_debug "Detected npm version: $npm_version"
  
  # OpenClaw requires npm >= 8.0.0 for workspace features
  local npm_major
  npm_major=$(echo "$npm_version" | cut -d. -f1)
  if [[ "$npm_major" -lt 8 ]]; then
    log_warning "OpenClaw requires npm 8+ for workspace features (detected: $npm_version)"
    log_warning "Consider upgrading npm: npm install -g npm@latest"
  fi
  
  # Check OS compatibility warnings
  local os_type
  os_type=$(uname -s)
  if [[ "$os_type" == "Darwin" ]]; then
    # macOS specific checks
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null || echo "0.0.0")
    log_debug "Detected macOS version: $macos_version"
    
    # OpenClaw 0.3.x has better macOS support
    if [[ "$major" -eq 0 && "$minor" -eq 3 && "$patch" -lt 5 ]]; then
      log_info "OpenClaw $version may have limited macOS ARM support"
      log_info "Consider upgrading to 0.3.5+ for full Apple Silicon compatibility"
    fi
  elif [[ "$os_type" == "Linux" ]]; then
    # Linux specific checks
    log_debug "Linux system detected - good compatibility"
  else
    log_warning "Unsupported OS detected: $os_type"
    log_warning "OpenClaw may have limited functionality on this platform"
  fi
  
  log_success "Version compatibility check passed for OpenClaw $version"
  return 0
}

# Color logging functions
color_log() {
  local level="$1"
  local message="$2"
  local color_code=""
  local reset="\033[0m"
  
  case "$level" in
    "INFO")
      color_code="\033[0;34m"  # Blue
      ;;
    "SUCCESS")
      color_code="\033[0;32m"  # Green
      ;;
    "WARNING")
      color_code="\033[0;33m"  # Yellow
      ;;
    "ERROR")
      color_code="\033[0;31m"  # Red
      ;;
    "DEBUG")
      color_code="\033[0;36m"  # Cyan
      ;;
    *)
      color_code="\033[0m"     # Default
      ;;
  esac
  
  # In CI mode, don't use colors
  if [[ "${CI_MODE:-0}" -eq 1 ]]; then
    echo "[$level] $message"
  else
    echo -e "${color_code}[$level]${reset} $message"
  fi
}

# Enhanced registry selection with intelligent fallback strategy
select_best_npm_registry() {
  local preferred_registry="${NPM_REGISTRY:-}"
  local test_registries=()
  local selected_registry=""
  local best_latency=99999
  local best_registry=""
  
  # Define registry candidates with priority
  # 1. User-specified registry (highest priority)
  # 2. CN-optimized registries
  # 3. Global fallback registries
  if [[ -n "$preferred_registry" ]]; then
    test_registries=("$preferred_registry")
  fi
  
  # Add CN-optimized registries (mainland-friendly)
  test_registries+=(
    "https://registry.npmmirror.com"
    "https://registry.npm.taobao.org"
    "https://mirrors.cloud.tencent.com/npm/"
  )
  
  # Add global fallback registries
  test_registries+=(
    "https://registry.npmjs.org"
    "https://registry.yarnpkg.com"
  )
  
  color_log "INFO" "测试npm registry连接性，选择最优源..."
  
  # Test each registry for connectivity and latency
  for registry in "${test_registries[@]}"; do
    # Skip duplicates
    if [[ "$registry" == "$selected_registry" ]]; then
      continue
    fi
    
    color_log "DEBUG" "  测试: $registry"
    
    # Test connectivity with timeout
    local start_time
    start_time=$(date +%s%3N)
    
    if curl -fsSL --max-time 5 "$registry" > /dev/null 2>&1; then
      local end_time
      end_time=$(date +%s%3N)
      local latency=$((end_time - start_time))
      
      color_log "DEBUG" "    ✓ 可用，延迟: ${latency}ms"
      
      # Select the fastest available registry
      if [[ $latency -lt $best_latency ]]; then
        best_latency=$latency
        best_registry="$registry"
      fi
    else
      color_log "DEBUG" "    ✗ 不可用"
    fi
  done
  
  if [[ -n "$best_registry" ]]; then
    selected_registry="$best_registry"
    color_log "SUCCESS" "选择最优npm registry: $selected_registry (延迟: ${best_latency}ms)"
  else
    # If no registry is available, use default with warning
    selected_registry="https://registry.npmjs.org"
    color_log "WARNING" "所有npm registry测试失败，使用默认: $selected_registry"
  fi
  
  echo "$selected_registry"
}

# Enhanced install with fallback strategy
install_with_fallback() {
  local package_name="$1"
  local version="${2:-latest}"
  local registry="$3"
  local max_retries="${4:-2}"
  local retry_count=0
  
  while [[ $retry_count -lt $max_retries ]]; do
    color_log "INFO" "尝试安装 $package_name@$version (尝试 $((retry_count + 1))/$max_retries)..."
    
    # Try to install with current registry
    if npm install --global --registry="$registry" --no-fund --no-audit "$package_name@$version" 2>&1; then
      color_log "SUCCESS" "成功安装 $package_name@$version"
      return 0
    fi
    
    retry_count=$((retry_count + 1))
    
    if [[ $retry_count -lt $max_retries ]]; then
      color_log "WARNING" "安装失败，将在5秒后重试..."
      sleep 5
      
      # Try a different registry on retry
      if [[ "$registry" == "https://registry.npmmirror.com" ]]; then
        registry="https://registry.npmjs.org"
        color_log "INFO" "切换到备用registry: $registry"
      elif [[ "$registry" == "https://registry.npmjs.org" ]]; then
        registry="https://registry.yarnpkg.com"
        color_log "INFO" "切换到备用registry: $registry"
      fi
    fi
  done
  
  color_log "ERROR" "安装 $package_name@$version 失败，已尝试 $max_retries 次"
  return 1
}

# Self-check function
self_check_openclaw() {
  color_log "INFO" "执行OpenClaw自检..."
  
  local check_passed=0
  local check_total=0
  
  # Check 1: openclaw command exists
  check_total=$((check_total + 1))
  if ! command -v openclaw > /dev/null 2>&1; then
    color_log "ERROR" "❌ openclaw命令未找到，安装可能失败"
    return 1
  else
    color_log "SUCCESS" "✅ openclaw命令可用"
    check_passed=$((check_passed + 1))
  fi
  
  # Check 2: Get version
  check_total=$((check_total + 1))
  local version_output
  if version_output=$(openclaw --version 2>&1); then
    color_log "SUCCESS" "✅ OpenClaw版本: $version_output"
    check_passed=$((check_passed + 1))
    
    # Check if version matches expected
    if [[ -n "${OPENCLAW_VERSION:-}" ]] && [[ "$OPENCLAW_VERSION" != "latest" ]]; then
      if [[ "$version_output" == *"$OPENCLAW_VERSION"* ]]; then
        color_log "SUCCESS" "✅ 版本验证通过: 期望 $OPENCLAW_VERSION，实际 $version_output"
      else
        color_log "WARNING" "⚠️ 版本不匹配: 期望 $OPENCLAW_VERSION，实际 $version_output"
      fi
    fi
  else
    color_log "ERROR" "❌ 无法获取OpenClaw版本: $version_output"
    return 1
  fi
  
  # Check 3: Test help command
  check_total=$((check_total + 1))
  if openclaw --help > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ 帮助命令可用"
    check_passed=$((check_passed + 1))
  else
    color_log "WARNING" "⚠️ 帮助命令失败"
  fi
  
  # Check 4: Test status command
  check_total=$((check_total + 1))
  if openclaw status > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ 状态命令可用"
    check_passed=$((check_passed + 1))
  else
    color_log "WARNING" "⚠️ 状态命令失败 (可能需要启动gateway)"
  fi
  
  # Check 5: Check workspace directory
  check_total=$((check_total + 1))
  local workspace_dir="$HOME/.openclaw/workspace"
  if [[ -d "$workspace_dir" ]]; then
    color_log "SUCCESS" "✅ 工作空间目录存在: $workspace_dir"
    check_passed=$((check_passed + 1))
  else
    color_log "INFO" "ℹ️ 工作空间目录不存在，将在首次运行时创建"
  fi
  
  # Check 6: Check gateway status
  check_total=$((check_total + 1))
  if openclaw gateway status > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ OpenClaw gateway正在运行"
    check_passed=$((check_passed + 1))
  else
    color_log "INFO" "ℹ️ OpenClaw gateway未运行，可使用 'openclaw gateway start' 启动"
  fi
  
  # Check 7: Check for skills directory
  check_total=$((check_total + 1))
  local node_version
  node_version=$(node --version 2>/dev/null | sed 's/v//')
  if [[ -n "$node_version" ]]; then
    local skills_dir="$HOME/.nvm/versions/node/$node_version/lib/node_modules/openclaw/skills"
    if [[ -d "$skills_dir" ]]; then
      local skill_count=$(find "$skills_dir" -maxdepth 1 -type d 2>/dev/null | wc -l)
      color_log "SUCCESS" "✅ 找到 $((skill_count - 1)) 个已安装技能"
      check_passed=$((check_passed + 1))
    else
      color_log "INFO" "ℹ️ 技能目录不存在，可使用 'openclaw skill install' 安装技能"
    fi
  else
    color_log "WARNING" "⚠️ 无法获取Node.js版本"
  fi
  
  # Check 8: Test basic agent functionality
  check_total=$((check_total + 1))
  if openclaw sessions list --limit 1 > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ 会话列表功能可用"
    check_passed=$((check_passed + 1))
  else
    color_log "INFO" "ℹ️ 会话列表功能不可用 (可能需要gateway运行)"
  fi
  
  # Summary
  color_log "INFO" "自检完成: $check_passed/$check_total 项通过"
  
  if [[ $check_passed -ge 3 ]]; then
    color_log "SUCCESS" "✅ OpenClaw安装验证通过"
    
    # Generate installation summary
    local summary_file="/tmp/openclaw-install-summary-$(date +%s).txt"
    cat > "$summary_file" << EOF
OpenClaw 安装验证报告
=====================
验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
脚本版本: $SCRIPT_VERSION
OpenClaw版本: $version_output
验证结果: $check_passed/$check_total 项通过

系统信息:
- 操作系统: $(uname -s) $(uname -r)
- 架构: $(uname -m)
- Node版本: $(node --version 2>/dev/null || echo "未找到")
- NPM版本: $(npm --version 2>/dev/null || echo "未找到")
- 安装路径: $(which openclaw)
- 工作空间: $workspace_dir

下一步操作:
1. 启动gateway: openclaw gateway start
2. 查看状态: openclaw status
3. 配置代理: 编辑 ~/.openclaw/workspace/SOUL.md
4. 安装技能: openclaw skill install <技能名称>
5. 加入社区: https://discord.com/invite/clawd

故障排除:
- 查看日志: tail -f ~/.openclaw/logs/gateway.log
- 重新安装: npm uninstall -g openclaw && npm install -g openclaw
- 获取支持: https://github.com/openclaw/openclaw/issues
EOF
    
    color_log "INFO" "安装验证报告已保存到: $summary_file"
    color_log "INFO" "查看报告: cat $summary_file"
    
    return 0
  else
    color_log "WARNING" "⚠️ OpenClaw安装验证部分通过 ($check_passed/$check_total)"
    color_log "INFO" "建议检查安装日志并尝试重新安装"
    return 1
  fi
}

# Main installation function
main_install() {
  local start_time
  start_time=$(date +%s)
  
  color_log "INFO" "开始OpenClaw CN安装 (脚本版本: $SCRIPT_VERSION)"
  color_log "INFO" "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  
  # Check prerequisites
  color_log "INFO" "检查系统依赖..."
  
  # Check for npm
  if ! command -v npm > /dev/null 2>&1; then
    color_log "ERROR" "npm未安装，请先安装Node.js和npm"
    color_log "INFO" "参考: https://nodejs.org/ 或使用系统包管理器安装"
    return 1
  fi
  
  # Check for curl
  if ! command -v curl > /dev/null 2>&1; then
    color_log "ERROR" "curl未安装，请先安装curl"
    return 1
  fi
  
  color_log "SUCCESS" "系统依赖检查通过"
  
  # Select best npm registry
  local npm_registry
  npm_registry=$(select_best_npm_registry)
  
  # Get OpenClaw version
  local openclaw_version="${OPENCLAW_VERSION:-latest}"
  
  # Parse command line arguments
  local dry_run=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        if [[ -n "${2:-}" ]]; then
          openclaw_version="$2"
          shift 2
        else
          color_log "ERROR" "--version选项需要参数"
          return 1
        fi
        ;;
      --dry-run)
        dry_run=1
        color_log "INFO" "干运行模式: 只显示安装步骤，不实际执行"
        shift
        ;;
      --help)
        show_help
        return 0
        ;;
      *)
        color_log "WARNING" "未知参数: $1"
        shift
        ;;
    esac
  done
  
  color_log "INFO" "安装OpenClaw版本: $openclaw_version"
  
  # Check version compatibility before installation
  if ! check_version_compatibility "$openclaw_version"; then
    color_log "ERROR" "版本兼容性检查失败，安装中止"
    return 1
  fi
  
  # Dry run mode
  if [[ $dry_run -eq 1 ]]; then
    color_log "INFO" "=== 干运行模式 ==="
    color_log "INFO" "将执行以下步骤:"
    color_log "INFO" "1. 选择最优 npm registry: $npm_registry"
    color_log "INFO" "2. 安装 OpenClaw 版本: $openclaw_version"
    color_log "INFO" "3. 执行自检验证"
    color_log "INFO" "4. 生成安装报告"
    color_log "INFO" "=== 干运行结束 ==="
    return 0
  fi
  
  # Install OpenClaw with fallback strategy
  if ! install_with_fallback "openclaw" "$openclaw_version" "$npm_registry"; then
    color_log "ERROR" "OpenClaw安装失败"
    return 1
  fi
  
  # Self-check
  if ! self_check_openclaw; then
    color_log "WARNING" "OpenClaw自检发现问题，但安装已完成"
  fi
  
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  color_log "SUCCESS" "OpenClaw安装完成！耗时: ${duration}秒"
  color_log "INFO" "下一步:"
  color_log "INFO" "  1. 运行 'openclaw --help' 查看可用命令"
  color_log "INFO" "  2. 运行 'openclaw gateway start' 启动服务"
  color_log "INFO" "  3. 访问 https://docs.openclaw.ai 查看文档"
  color_log "INFO" "  4. 加入社区: https://discord.com/invite/clawd"
  
  return 0
}

# Help function
show_help() {
  cat << EOF
OpenClaw CN 快速安装脚本

用法:
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12

选项:
  --version <version>  指定OpenClaw版本 (默认: latest)
  --dry-run           干运行模式: 只显示安装步骤，不实际执行
  --help               显示此帮助信息

环境变量:
  OPENCLAW_VERSION     指定OpenClaw版本
  NPM_REGISTRY         指定npm registry URL
  CI_MODE=1            启用CI模式 (无颜色输出)
  SKIP_INTERACTIVE=1   跳过交互式确认

特性:
  ✓ 智能registry选择: 自动测试多个npm registry，选择最快可用的源
  ✓ 国内可达源优先: 优先使用国内镜像源 (npmmirror.com, npm.taobao.org)
  ✓ 多层回退策略: 安装失败时自动切换到备用registry重试
  ✓ 完整自检: 安装后自动验证OpenClaw版本和基本功能
  ✓ 详细日志: 彩色输出，便于调试和问题诊断

示例:
  # 使用默认设置安装最新版
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  
  # 安装特定版本
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
  
  # 使用自定义registry
  NPM_REGISTRY=https://registry.npmmirror.com bash install-cn.sh
  
  # CI/CD环境安装
  CI_MODE=1 SKIP_INTERACTIVE=1 OPENCLAW_VERSION=latest bash install-cn.sh

版本: $SCRIPT_VERSION
更新: $SCRIPT_UPDATE_URL
EOF
}

# Handle script update check
check_for_updates() {
  if [[ "${CHECK_UPDATES:-1}" -eq 0 ]]; then
    return 0
  fi
  
  color_log "DEBUG" "检查脚本更新..."
  
  # Skip update check in CI mode or if no internet
  if [[ "${CI_MODE:-0}" -eq 1 ]] || ! command -v curl > /dev/null 2>&1; then
    return 0
  fi
  
  local latest_version
  if latest_version=$(curl -fsSL --max-time 5 "$SCRIPT_UPDATE_URL" 2>/dev/null | grep -o 'SCRIPT_VERSION="[^"]*"' | head -1 | cut -d'"' -f2); then
    if [[ "$latest_version" != "$SCRIPT_VERSION" ]]; then
      color_log "WARNING" "脚本有新版本可用: $latest_version (当前: $SCRIPT_VERSION)"
      color_log "INFO" "运行以下命令更新:"
      color_log "INFO" "  curl -fsSL $SCRIPT_UPDATE_URL -o install-cn.sh && bash install-cn.sh"
    else
      color_log "DEBUG" "脚本已是最新版本: $SCRIPT_VERSION"
    fi
  else
    color_log "DEBUG" "无法检查更新 (网络问题或服务器不可用)"
  fi
}

# Trap for cleanup
cleanup() {
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    color_log "SUCCESS" "安装脚本执行完成"
  else
    color_log "ERROR" "安装脚本执行失败 (退出码: $exit_code)"
  fi
  
  # Log installation summary
  if [[ -n "${INSTALL_LOG:-}" ]]; then
    {
      echo "=== OpenClaw CN 安装日志 ==="
      echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
      echo "脚本版本: $SCRIPT_VERSION"
      echo "OpenClaw版本: ${OPENCLAW_VERSION:-latest}"
      echo "退出码: $exit_code"
      echo "=========================="
    } >> "$INSTALL_LOG"
  fi
  
  exit $exit_code
}

# Set trap
trap cleanup EXIT

# Check for updates at the beginning
check_for_updates

# Parse arguments
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

# Set arguments for main function
set -- "${args[@]}"

# Run main installation
main_install "$@"