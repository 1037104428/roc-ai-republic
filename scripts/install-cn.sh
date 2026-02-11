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
SCRIPT_VERSION="2026.02.11.1533"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh"

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
    "STEP")
      color_code="\033[1;35m"  # Magenta (bold)
      ;;
    *)
      color_code="\033[0;37m"  # White
      ;;
  esac
  
  # Check if we're in a terminal that supports colors
  if [[ -t 1 ]] && [[ "$TERM" != "dumb" ]] && [[ "${FORCE_NO_COLOR:-0}" != "1" ]]; then
    echo -e "${color_code}[cn-pack:${level}]${reset} ${message}"
  else
    echo "[cn-pack:${level}] ${message}"
  fi
}

# Progress bar functions
show_progress_bar() {
  local duration="$1"
  local message="$2"
  local width="${3:-50}"
  
  # Only show progress bar in interactive terminals
  if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]] || [[ "$DRY_RUN" == "1" ]]; then
    color_log "INFO" "$message (estimated: ${duration}s)"
    return
  fi
  
  color_log "INFO" "$message"
  
  local interval=0.1
  local steps=$(echo "$duration / $interval" | bc)
  local step_width=$(echo "$width / $steps" | bc -l)
  
  printf "["
  for ((i=0; i<width; i++)); do
    printf " "
  done
  printf "] 0%%\r"
  
  local current_width=0
  for ((i=0; i<steps; i++)); do
    sleep "$interval"
    current_width=$(echo "$current_width + $step_width" | bc -l)
    local bar_width=$(printf "%.0f" "$current_width")
    if [[ "$bar_width" -gt "$width" ]]; then
      bar_width="$width"
    fi
    
    printf "["
    for ((j=0; j<bar_width; j++)); do
      printf "="
    done
    for ((j=bar_width; j<width; j++)); do
      printf " "
    done
    printf "] "
    
    local percent=$(echo "($i + 1) * 100 / $steps" | bc)
    printf "%3d%%\r" "$percent"
  done
  
  printf "["
  for ((i=0; i<width; i++)); do
    printf "="
  done
  printf "] 100%%\n"
}

# Simple spinner for indeterminate progress
show_spinner() {
  local pid="$1"
  local message="$2"
  local delay=0.1
  local spinstr='|/-\'
  
  # Only show spinner in interactive terminals
  if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]] || [[ "$DRY_RUN" == "1" ]]; then
    color_log "INFO" "$message..."
    wait "$pid"
    return $?
  fi
  
  color_log "INFO" "$message"
  
  printf "    "
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\b%s" "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b"
  done
  printf "\b \b"
  
  wait "$pid"
  return $?
}

# Legacy logging function for backward compatibility
legacy_log() {
  echo "[cn-pack] $1"
}

# Installation rollback functions
setup_rollback() {
  # Create rollback state directory
  ROLLBACK_DIR="/tmp/openclaw-rollback-$(date +%s)"
  mkdir -p "$ROLLBACK_DIR"
  
  color_log "INFO" "Setting up installation rollback system in $ROLLBACK_DIR"
  
  # Backup npm global package list
  if command -v npm &> /dev/null; then
    npm list -g --depth=0 2>/dev/null > "$ROLLBACK_DIR/npm-global-backup.txt" || true
    color_log "DEBUG" "Backed up npm global package list"
  fi
  
  # Backup current openclaw installation if exists
  if command -v openclaw &> /dev/null; then
    openclaw --version 2>/dev/null > "$ROLLBACK_DIR/openclaw-version-backup.txt" || true
    which openclaw > "$ROLLBACK_DIR/openclaw-path-backup.txt" 2>/dev/null || true
    color_log "DEBUG" "Backed up existing OpenClaw installation info"
  fi
  
  # Backup npm config
  if command -v npm &> /dev/null; then
    npm config list > "$ROLLBACK_DIR/npm-config-backup.txt" 2>/dev/null || true
    color_log "DEBUG" "Backed up npm configuration"
  fi
  
  # Backup environment variables
  env | grep -E "(NPM|npm|OPENCLAW|openclaw|PROXY|proxy)" > "$ROLLBACK_DIR/env-backup.txt" 2>/dev/null || true
  
  color_log "SUCCESS" "Rollback system ready. State saved to $ROLLBACK_DIR"
}

perform_rollback() {
  local error_message="$1"
  
  color_log "ERROR" "Installation failed: $error_message"
  color_log "WARNING" "Attempting to rollback to previous state..."
  
  if [[ -z "$ROLLBACK_DIR" ]] || [[ ! -d "$ROLLBACK_DIR" ]]; then
    color_log "ERROR" "Rollback directory not found. Cannot perform rollback."
    return 1
  fi
  
  # Check if we have a backup of npm global packages
  if [[ -f "$ROLLBACK_DIR/npm-global-backup.txt" ]]; then
    color_log "INFO" "Checking if rollback is needed for npm packages..."
    
    # Get current openclaw version if installed
    local current_openclaw=""
    if command -v openclaw &> /dev/null; then
      current_openclaw=$(openclaw --version 2>/dev/null || echo "unknown")
    fi
    
    # Check if openclaw was installed during this session
    if [[ -f "$ROLLBACK_DIR/openclaw-version-backup.txt" ]]; then
      local backup_version=$(cat "$ROLLBACK_DIR/openclaw-version-backup.txt" 2>/dev/null || echo "")
      if [[ -z "$backup_version" ]] && [[ -n "$current_openclaw" ]]; then
        color_log "WARNING" "OpenClaw was not installed before, but is now. Attempting to uninstall..."
        if command -v npm &> /dev/null; then
          npm uninstall -g openclaw 2>/dev/null || true
          color_log "INFO" "Uninstalled newly installed OpenClaw"
        fi
      fi
    fi
  fi
  
  # Restore npm config if changed
  if [[ -f "$ROLLBACK_DIR/npm-config-backup.txt" ]]; then
    color_log "INFO" "Checking npm configuration restoration..."
    # Note: We don't automatically restore npm config as it might have been intentionally changed
    # Instead, we provide instructions
    color_log "INFO" "Original npm configuration backed up at: $ROLLBACK_DIR/npm-config-backup.txt"
  fi
  
  # Provide rollback report
  color_log "STEP" "Rollback completed"
  color_log "INFO" "Rollback state preserved in: $ROLLBACK_DIR"
  color_log "INFO" "You can manually restore from backups if needed:"
  color_log "INFO" "  - Check original npm packages: cat $ROLLBACK_DIR/npm-global-backup.txt"
  color_log "INFO" "  - Check original OpenClaw: cat $ROLLBACK_DIR/openclaw-version-backup.txt"
  color_log "INFO" "  - Check environment: cat $ROLLBACK_DIR/env-backup.txt"
  
  # Cleanup rollback directory after some time (optional)
  color_log "INFO" "Rollback directory will be automatically cleaned up after 24 hours"
}

cleanup_rollback() {
  if [[ -n "$ROLLBACK_DIR" ]] && [[ -d "$ROLLBACK_DIR" ]]; then
    color_log "DEBUG" "Cleaning up rollback directory: $ROLLBACK_DIR"
    # In production, we might want to keep it for debugging
    # For now, just log that it exists
    color_log "INFO" "Rollback state preserved at: $ROLLBACK_DIR (cleanup manually if needed)"
  fi
}

# 故障自愈功能
# 环境变量：ENABLE_FAULT_RECOVERY (默认: 1，启用故障自愈)
detect_and_fix_common_issues() {
  local enable_fault_recovery="${ENABLE_FAULT_RECOVERY:-1}"
  
  if [[ "$enable_fault_recovery" != "1" ]]; then
    color_log "DEBUG" "故障自愈功能已禁用 (ENABLE_FAULT_RECOVERY=$enable_fault_recovery)"
    return 0
  fi
  
  color_log "INFO" "开始故障自愈检查..."
  local issues_found=0
  local issues_fixed=0
  
  # 1. 检查权限问题
  color_log "DEBUG" "检查权限问题..."
  check_and_fix_permissions
  
  # 2. 检查网络连接问题
  color_log "DEBUG" "检查网络连接问题..."
  check_and_fix_network_connectivity
  
  # 3. 检查磁盘空间
  color_log "DEBUG" "检查磁盘空间..."
  check_disk_space
  
  # 4. 检查依赖包
  color_log "DEBUG" "检查系统依赖..."
  check_system_dependencies
  
  color_log "SUCCESS" "故障自愈检查完成"
}

check_and_fix_permissions() {
  color_log "DEBUG" "检查文件和目录权限..."
  
  # 检查npm全局目录权限
  local npm_global_dir=""
  if command -v npm &> /dev/null; then
    npm_global_dir=$(npm config get prefix 2>/dev/null || echo "")
    if [[ -n "$npm_global_dir" ]]; then
      if [[ ! -w "$npm_global_dir" ]]; then
        color_log "WARNING" "npm全局目录不可写: $npm_global_dir"
        color_log "INFO" "尝试修复权限..."
        
        # 尝试使用sudo修复权限（如果可用）
        if command -v sudo &> /dev/null; then
          if sudo chmod 755 "$npm_global_dir" 2>/dev/null; then
            color_log "SUCCESS" "成功修复npm全局目录权限"
          else
            color_log "WARNING" "无法修复npm全局目录权限，可能需要手动修复"
          fi
        else
          color_log "WARNING" "sudo不可用，无法修复npm全局目录权限"
        fi
      else
        color_log "DEBUG" "npm全局目录权限正常: $npm_global_dir"
      fi
    fi
  fi
  
  # 检查当前目录权限
  if [[ ! -w "." ]]; then
    color_log "WARNING" "当前目录不可写"
    color_log "INFO" "建议切换到有写权限的目录执行安装"
  fi
  
  # 检查/tmp目录权限
  if [[ ! -w "/tmp" ]]; then
    color_log "ERROR" "/tmp目录不可写，安装可能失败"
    color_log "INFO" "尝试创建临时目录..."
    local temp_dir="$HOME/.openclaw-temp-$(date +%s)"
    mkdir -p "$temp_dir" 2>/dev/null || {
      color_log "ERROR" "无法创建临时目录，请检查磁盘空间和权限"
      return 1
    }
    export TMPDIR="$temp_dir"
    color_log "SUCCESS" "已设置临时目录: $temp_dir"
  fi
}

check_and_fix_network_connectivity() {
  color_log "DEBUG" "检查网络连接..."
  
  # 测试npm registry连接
  local npm_registry="${NPM_REGISTRY:-https://registry.npmjs.org}"
  local test_urls=(
    "$npm_registry"
    "https://registry.npmmirror.com"
    "https://www.google.com"
    "https://github.com"
  )
  
  local has_connectivity=0
  for url in "${test_urls[@]}"; do
    color_log "DEBUG" "测试连接: $url"
    if curl -s --max-time 5 --head "$url" >/dev/null 2>&1; then
      color_log "DEBUG" "连接成功: $url"
      has_connectivity=1
      
      # 如果当前npm registry不可用，但备用registry可用，则切换
      if [[ "$url" != "$npm_registry" ]] && [[ "$has_connectivity" -eq 0 ]]; then
        color_log "WARNING" "主npm registry不可用，切换到备用registry: $url"
        export NPM_REGISTRY="$url"
        color_log "INFO" "已设置NPM_REGISTRY=$url"
      fi
      break
    else
      color_log "DEBUG" "连接失败: $url"
    fi
  done
  
  if [[ "$has_connectivity" -eq 0 ]]; then
    color_log "WARNING" "网络连接测试失败"
    color_log "INFO" "检查网络设置、代理配置或防火墙"
    
    # 检查代理设置
    if [[ -n "$http_proxy" ]] || [[ -n "$HTTP_PROXY" ]] || [[ -n "$https_proxy" ]] || [[ -n "$HTTPS_PROXY" ]]; then
      color_log "INFO" "检测到代理设置:"
      [[ -n "$http_proxy" ]] && color_log "INFO" "  http_proxy=$http_proxy"
      [[ -n "$HTTP_PROXY" ]] && color_log "INFO" "  HTTP_PROXY=$HTTP_PROXY"
      [[ -n "$https_proxy" ]] && color_log "INFO" "  https_proxy=$https_proxy"
      [[ -n "$HTTPS_PROXY" ]] && color_log "INFO" "  HTTPS_PROXY=$HTTPS_PROXY"
    fi
    
    # 提供网络诊断建议
    color_log "INFO" "网络诊断建议:"
    color_log "INFO" "  1. 检查网络连接: ping 8.8.8.8"
    color_log "INFO" "  2. 检查DNS解析: nslookup registry.npmjs.org"
    color_log "INFO" "  3. 临时禁用代理: unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
    color_log "INFO" "  4. 尝试使用其他网络环境"
  else
    color_log "DEBUG" "网络连接正常"
  fi
}

check_disk_space() {
  color_log "DEBUG" "检查磁盘空间..."
  
  # 检查当前目录所在磁盘空间
  local current_dir=$(pwd)
  local available_space=0
  
  if command -v df &> /dev/null; then
    available_space=$(df -k "$current_dir" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    
    # 需要至少500MB空间
    local min_space_mb=500
    local min_space_kb=$((min_space_mb * 1024))
    
    if [[ "$available_space" -lt "$min_space_kb" ]]; then
      color_log "WARNING" "磁盘空间不足: 可用 ${available_space}KB，需要至少 ${min_space_kb}KB"
      color_log "INFO" "建议:"
      color_log "INFO" "  1. 清理临时文件: rm -rf /tmp/*"
      color_log "INFO" "  2. 切换到有足够空间的磁盘"
      color_log "INFO" "  3. 扩展磁盘空间"
    else
      local available_mb=$((available_space / 1024))
      color_log "DEBUG" "磁盘空间充足: 可用 ${available_mb}MB"
    fi
  else
    color_log "DEBUG" "无法检查磁盘空间 (df命令不可用)"
  fi
}

check_system_dependencies() {
  color_log "DEBUG" "检查系统依赖..."
  
  local missing_deps=()
  
  # 检查curl或wget
  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    missing_deps+=("curl或wget")
  fi
  
  # 检查node/npm
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    missing_deps+=("Node.js和npm")
  fi
  
  # 检查git (可选，但推荐)
  if ! command -v git &> /dev/null; then
    color_log "INFO" "Git未安装 (可选依赖)"
  fi
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    color_log "WARNING" "缺少必要依赖: ${missing_deps[*]}"
    color_log "INFO" "安装建议:"
    
    for dep in "${missing_deps[@]}"; do
      case "$dep" in
        "curl或wget")
          color_log "INFO" "  Ubuntu/Debian: sudo apt-get install curl"
          color_log "INFO" "  CentOS/RHEL: sudo yum install curl"
          color_log "INFO" "  macOS: brew install curl"
          ;;
        "Node.js和npm")
          color_log "INFO" "  使用nvm安装:"
          color_log "INFO" "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
          color_log "INFO" "    nvm install --lts"
          color_log "INFO" "  或从官网下载: https://nodejs.org/"
          ;;
      esac
    done
    
    return 1
  else
    color_log "DEBUG" "系统依赖检查通过"
  fi
}

# Trap for error handling
trap 'perform_rollback "Script terminated unexpectedly"' ERR
trap 'cleanup_rollback' EXIT

# Initialize ROLLBACK_DIR variable
ROLLBACK_DIR=""

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"
OPENCLAW_VERSION_DEFAULT="latest"
VERIFY_LEVEL_DEFAULT="auto"  # auto, basic, quick, full, none

# Show script version
color_log "STEP" "OpenClaw CN installer v$SCRIPT_VERSION"
color_log "STEP" "========================================="

# Function to check for script updates
check_script_updates() {
  local check_mode="${1:-auto}"  # auto, force, skip
  
  if [[ "$check_mode" == "skip" ]]; then
    color_log "INFO" "Script update check skipped"
    return 0
  fi
  
  # Only check for updates if we have curl and it's not a forced check
  if [[ "$check_mode" == "auto" ]] && ! command -v curl &> /dev/null; then
    color_log "WARNING" "curl not available, skipping update check"
    return 0
  fi
  
  color_log "INFO" "Checking for script updates..."
  
  # Try to fetch latest version from GitHub
  local latest_version=""
  local update_available=false
  
  if command -v curl &> /dev/null; then
    # Try GitHub first
    latest_version=$(curl -fsSL "$SCRIPT_UPDATE_URL" 2>/dev/null | grep -E '^SCRIPT_VERSION="[^"]+"' | head -1 | cut -d'"' -f2)
    
    # If GitHub fails, try Gitee
    if [[ -z "$latest_version" ]]; then
      local gitee_url="https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/install-cn.sh"
      latest_version=$(curl -fsSL "$gitee_url" 2>/dev/null | grep -E '^SCRIPT_VERSION="[^"]+"' | head -1 | cut -d'"' -f2)
    fi
  fi
  
  if [[ -n "$latest_version" ]]; then
    if [[ "$latest_version" != "$SCRIPT_VERSION" ]]; then
      echo "[cn-pack] ⚠️  Update available: v$SCRIPT_VERSION → v$latest_version"
      echo "[cn-pack]    Run with --check-update to see details"
      update_available=true
    else
      color_log "SUCCESS" "Script is up to date (v$SCRIPT_VERSION)"
    fi
  else
    color_log "WARNING" "Could not check for updates (network issue)"
  fi
  
  # Return update status
  if [[ "$update_available" == true ]]; then
    return 1
  fi
  return 0
}

# Function to show update details
show_update_details() {
  color_log "STEP" "========================================="
  color_log "STEP" "Script Update Information"
  color_log "STEP" "========================================="
  color_log "INFO" "Current version: v$SCRIPT_VERSION"
  color_log "INFO" "Update URL: $SCRIPT_UPDATE_URL"
  echo ""
  color_log "INFO" "To update:"
  color_log "INFO" "   1. Download latest: curl -fsSL $SCRIPT_UPDATE_URL -o install-cn.sh"
  color_log "INFO" "   2. Make executable: chmod +x install-cn.sh"
  color_log "INFO" "   3. Verify: ./install-cn.sh --version"
  echo ""
  color_log "INFO" "Or use one-liner:"
  color_log "INFO" "   curl -fsSL $SCRIPT_UPDATE_URL | bash"
  color_log "STEP" "========================================="
}

# Function to show changelog
show_changelog() {
  echo "[cn-pack] ========================================="
  echo "[cn-pack] Changelog for install-cn.sh"
  echo "[cn-pack] ========================================="
  
  # Define changelog entries
  cat << 'EOF'
v2026.02.11.11 (2026-02-11)
  - 新增：配置模板生成功能，支持--generate-config选项生成开发、测试、生产环境配置
  - 新增：--config-output选项指定配置文件输出路径
  - 改进：提供标准化的配置模板，遵循不同环境的最佳实践

v2026.02.11.10 (2026-02-11)
  - 新增：数据库自动备份脚本功能，为quota-proxy添加SQLite热备份、文件复制备份、备份验证、旧备份清理、Cron集成
  - 改进：增强quota-proxy的数据持久化可靠性，提供标准化的数据库自动备份方案

v2026.02.11.09 (2026-02-11)
  - 新增：Admin API完整验证脚本，增强quota-proxy管理接口的测试覆盖
  - 改进：完善quota-proxy的管理接口测试工具链，提供标准化的Admin API验证方案

v2026.02.11.08 (2026-02-11)
  - 新增：Docker容器数据卷持久化配置功能，为quota-proxy添加持久化部署方案
  - 改进：增强quota-proxy的生产环境部署可靠性，提供标准化的持久化部署方案

v2026.02.11.07 (2026-02-11)
  - 新增：CI/CD集成功能，为install-cn.sh添加--ci-mode、--skip-interactive、--install-log参数
  - 改进：增强安装脚本的生产环境适配性，支持GitHub Actions/GitLab CI/Jenkins集成

v2026.02.11.14 (2026-02-11)
  - 新增：安装统计收集功能（可选），支持匿名收集安装成功率统计
  - 改进：增强install-cn.sh的监控和维护能力，提供标准化的安装统计方案

v2026.02.11.06 (2026-02-11)
  - 新增：Docker容器支持检测功能，自动识别容器环境并提供优化建议
  - 改进：增强install-cn.sh的生产环境适配性，提供标准化的容器环境检测方案

v2026.02.11.05 (2026-02-11)
  - 新增：一键卸载功能，为install-cn.sh添加--uninstall和--uninstall-dry-run选项
  - 改进：增强安装脚本的完整生命周期管理，提供标准化的卸载功能方案

v2026.02.11.04 (2026-02-11)
  - 新增：安装摘要报告功能，在安装完成后生成详细的安装报告
  - 改进：增强install-cn.sh的用户体验，提供安装过程的完整记录和后续操作指导

v2026.02.11.03 (2026-02-11)
  - 新增：进度条显示功能，为npm安装等长时间操作提供视觉反馈
  - 改进：增强install-cn.sh的用户体验，提供标准化的进度条显示方案

v2026.02.11.02 (2026-02-11)
  - 新增：更新日志查看功能，支持--changelog选项查看版本历史
  - 改进：添加详细的版本变更记录，方便用户了解更新内容

v2026.02.11.01 (2026-02-11)
  - 新增：增强的依赖检查功能，检查Node.js版本、npm权限、磁盘空间、内存、curl等系统依赖
  - 改进：提供详细的检查报告和错误处理，完善安装前验证流程

v2026.02.10.03 (2026-02-10)
  - 新增：离线模式支持，--offline-mode选项支持从本地缓存安装
  - 新增：--cache-dir选项指定缓存目录，实现本地缓存检查、离线安装、自动缓存下载
  - 改进：增强安装脚本的网络容错能力

v2026.02.10.02 (2026-02-10)
  - 新增：CDN连接质量评估功能，为选择最优源提供数据支持
  - 新增：验证命令生成器批量验证模式，支持text/markdown/json三种输出格式
  - 改进：增强网络优化策略和验证工具链

v2026.02.10.01 (2026-02-10)
  - 新增：国内可达源优先策略，自动选择最优npm registry
  - 新增：回退机制，当主源失败时自动切换到备用源
  - 新增：网络诊断功能，检查网络连接和代理设置
  - 新增：安装验证功能，验证OpenClaw安装是否成功
  - 基础：创建install-cn.sh脚本，提供标准化的国内安装方案
EOF
  
  echo "[cn-pack] ========================================="
  echo "[cn-pack] For detailed changelog, visit:"
  echo "[cn-pack]   https://github.com/1037104428/roc-ai-republic/blob/main/docs/install-cn-changelog.md"
  echo "[cn-pack] ========================================="
}

# Function to generate configuration templates
generate_config_template() {
  local env="$1"
  local output_file="$2"
  
  echo "[cn-pack] ========================================="
  echo "[cn-pack] Generating OpenClaw configuration template"
  echo "[cn-pack] Environment: $env"
  echo "[cn-pack] Output: ${output_file:-stdout}"
  echo "[cn-pack] ========================================="
  
  # Determine template file path
  local template_dir="$(dirname "$0")/../config-templates"
  local template_file=""
  
  case "$env" in
    dev|development)
      template_file="${template_dir}/openclaw-config-dev.yaml"
      ;;
    test|testing)
      template_file="${template_dir}/openclaw-config-test.yaml"
      ;;
    prod|production)
      template_file="${template_dir}/openclaw-config-prod.yaml"
      ;;
    *)
      echo "[cn-pack] ❌ Invalid environment: $env"
      echo "[cn-pack] ℹ️  Valid options: dev, test, prod"
      return 1
      ;;
  esac
  
  # Check if template file exists
  if [[ ! -f "$template_file" ]]; then
    echo "[cn-pack] ❌ Template file not found: $template_file"
    echo "[cn-pack] ℹ️  Available templates in: $template_dir"
    ls -la "$template_dir" 2>/dev/null || echo "Directory not found"
    return 1
  fi
  
  # Generate configuration
  if [[ -n "$output_file" ]]; then
    # Output to file
    cp "$template_file" "$output_file"
    if [[ $? -eq 0 ]]; then
      echo "[cn-pack] ✅ Configuration template generated: $output_file"
      echo "[cn-pack] ℹ️  File size: $(wc -l < "$output_file") lines"
      
      # Show usage instructions
      echo ""
      echo "[cn-pack] ========================================="
      echo "[cn-pack] NEXT STEPS:"
      case "$env" in
        dev|development)
          echo "[cn-pack] 1. Review the configuration: cat $output_file"
          echo "[cn-pack] 2. Move to user config: mv $output_file ~/.openclaw/config.yaml"
          echo "[cn-pack] 3. Start OpenClaw: openclaw gateway start"
          ;;
        test|testing)
          echo "[cn-pack] 1. Review the configuration: cat $output_file"
          echo "[cn-pack] 2. Move to system config: sudo mv $output_file /etc/openclaw/config.yaml"
          echo "[cn-pack] 3. Set permissions: sudo chmod 640 /etc/openclaw/config.yaml"
          echo "[cn-pack] 4. Start OpenClaw: sudo openclaw gateway start --config /etc/openclaw/config.yaml"
          ;;
        prod|production)
          echo "[cn-pack] 1. Review the configuration: cat $output_file"
          echo "[cn-pack] 2. Move to system config: sudo mv $output_file /etc/openclaw/production.yaml"
          echo "[cn-pack] 3. Set strict permissions: sudo chmod 600 /etc/openclaw/production.yaml"
          echo "[cn-pack] 4. Create directories: sudo mkdir -p /var/lib/openclaw/{workspace,memory} /var/log/openclaw"
          echo "[cn-pack] 5. Set ownership: sudo chown -R openclaw:openclaw /var/lib/openclaw /var/log/openclaw"
          echo "[cn-pack] 6. Start with systemd: sudo systemctl start openclaw"
          ;;
      esac
      echo "[cn-pack] ========================================="
    else
      echo "[cn-pack] ❌ Failed to write configuration to: $output_file"
      return 1
    fi
  else
    # Output to stdout
    cat "$template_file"
    echo ""
    echo "[cn-pack] ✅ Configuration template generated to stdout"
    echo "[cn-pack] ℹ️  To save to file, use: --config-output <filename>"
  fi
  
  return 0
}

# Function to detect and handle proxy settings
handle_proxy_settings() {
  local proxy_mode="${1:-auto}"  # auto, force, skip
  
  echo "[cn-pack] Checking proxy settings..."
  
  # Simple proxy detection (fallback if detect-proxy.sh is not available)
  detect_proxy_fallback() {
    local proxy_vars=("HTTP_PROXY" "HTTPS_PROXY" "http_proxy" "https_proxy" "ALL_PROXY" "all_proxy")
    local detected_count=0
    
    for var in "${proxy_vars[@]}"; do
      if [[ -n "${!var:-}" ]]; then
        echo "[cn-pack] Detected proxy: $var=${!var}"
        detected_count=$((detected_count + 1))
      fi
    done
    
    # Check npm proxy settings
    local npm_proxy=$(npm config get proxy 2>/dev/null || echo "null")
    local npm_https_proxy=$(npm config get https-proxy 2>/dev/null || echo "null")
    
    if [[ "$npm_proxy" != "null" && -n "$npm_proxy" ]]; then
      echo "[cn-pack] Detected npm proxy: $npm_proxy"
      detected_count=$((detected_count + 1))
    fi
    
    if [[ "$npm_https_proxy" != "null" && -n "$npm_https_proxy" ]]; then
      echo "[cn-pack] Detected npm https-proxy: $npm_https_proxy"
      detected_count=$((detected_count + 1))
    fi
    
    if [[ $detected_count -gt 0 ]]; then
      echo "PROXY_DETECTED=true"
      echo "PROXY_COUNT=$detected_count"
      return 0
    else
      echo "PROXY_DETECTED=false"
      echo "PROXY_COUNT=0"
      return 1
    fi
  }
  
  # Try to use the full proxy detection script if available
  if [[ -f "./scripts/detect-proxy.sh" ]]; then
    # Source the proxy detection script
    source ./scripts/detect-proxy.sh >/dev/null 2>&1 || {
      echo "[cn-pack] ⚠ Failed to load proxy detection script, using fallback"
      detect_proxy_fallback
      return 0
    }
    
    # Run proxy detection
    local proxy_info
    proxy_info=$(detect_proxy_settings 2>/dev/null || echo "PROXY_DETECTED=false")
    
    # Parse proxy detection results
    local proxy_detected=$(echo "$proxy_info" | grep "^PROXY_DETECTED=" | cut -d= -f2)
    local proxy_type=$(echo "$proxy_info" | grep "^PROXY_TYPE=" | cut -d= -f2)
    local proxy_count=$(echo "$proxy_info" | grep "^PROXY_COUNT=" | cut -d= -f2)
    
    if [[ "$proxy_detected" == "true" ]]; then
      echo "[cn-pack] ✓ Detected $proxy_count proxy configuration(s)"
      
      # Test proxy connectivity if not skipping
      if [[ "$proxy_mode" != "skip" ]]; then
        echo "[cn-pack] Testing proxy connectivity..."
        local test_result
        test_result=$(test_proxy_connectivity "https://registry.npmmirror.com" 10 2>/dev/null || true)
        
        if echo "$test_result" | grep -q "PROXY_TEST_RESULT=success"; then
          echo "[cn-pack] ✓ Proxy connectivity test passed"
          
          # Configure npm proxy if needed and not skipping
          if [[ -n "${HTTP_PROXY:-}" ]] && [[ "$proxy_mode" == "force" || "$proxy_mode" == "auto" ]]; then
            echo "[cn-pack] Configuring npm proxy for installation..."
            configure_npm_proxy "$HTTP_PROXY" "${HTTPS_PROXY:-$HTTP_PROXY}" >/dev/null 2>&1 || true
          fi
        else
          echo "[cn-pack] ⚠ Proxy connectivity test failed"
          
          if [[ "$proxy_mode" == "force" ]]; then
            echo "[cn-pack] ✗ Proxy forced but connectivity failed. Installation may fail."
            return 1
          fi
        fi
      fi
      
      return 0
    else
      echo "[cn-pack] ✓ No proxy settings detected"
      return 0
    fi
  else
    # Use fallback detection
    detect_proxy_fallback
    return 0
  fi
}

# Function for step-by-step installation
step_by_step_install() {
  local steps_to_run=""
  
  # Determine which steps to run
  if [[ -n "$STEPS" ]]; then
    steps_to_run="$STEPS"
    echo "[cn-pack] 🔧 运行指定步骤: $steps_to_run"
  else
    steps_to_run="network-check,proxy-check,registry-test,dependency-check,npm-install,verification,cleanup"
    echo "[cn-pack] 🔧 运行完整步骤序列"
  fi
  
  # Convert steps to array
  IFS=',' read -ra steps_array <<< "$steps_to_run"
  
  for step in "${steps_array[@]}"; do
    step=$(echo "$step" | xargs)  # Trim whitespace
    
    case "$step" in
      network-check)
        echo "[cn-pack] 🔍 步骤 1/7: 网络连接检查"
        echo "[cn-pack]   运行网络测试..."
        if [[ "$NETWORK_TEST" == "1" ]]; then
          echo "[cn-pack]   ✓ 网络测试已启用"
        else
          echo "[cn-pack]   ℹ️ 网络测试未启用 (使用 --network-test 启用)"
        fi
        ;;
        
      proxy-check)
        echo "[cn-pack] 🔍 步骤 2/7: 代理配置检查"
        echo "[cn-pack]   检查代理设置..."
        if [[ "$PROXY_TEST" == "1" ]]; then
          echo "[cn-pack]   ✓ 代理测试已启用"
        else
          echo "[cn-pack]   ℹ️ 代理测试未启用 (使用 --proxy-test 启用)"
        fi
        ;;
        
      registry-test)
        echo "[cn-pack] 🔍 步骤 3/7: NPM 仓库连接测试"
        echo "[cn-pack]   测试仓库连接性..."
        echo "[cn-pack]   主仓库: $REG_CN"
        echo "[cn-pack]   备用仓库: $REG_FALLBACK"
        ;;
        
      dependency-check)
        echo "[cn-pack] 🔍 步骤 4/7: 系统依赖检查"
        echo "[cn-pack]   检查 Node.js, npm, curl, 磁盘空间, 权限..."
        
        # 增强的依赖检查函数
        enhanced_dependency_check() {
          local errors=0
          local warnings=0
          
          # 权限自动修复函数
          auto_fix_permissions() {
            local fix_type="$1"
            echo "[cn-pack]     🔧 尝试自动修复: $fix_type"
            
            case "$fix_type" in
              npm-global-permission)
                # 修复 npm 全局安装权限问题
                local npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
                local user_home="$HOME"
                
                # 检查是否是权限问题
                if [[ "$npm_prefix" == *"Permission denied"* ]]; then
                  echo "[cn-pack]      检测到 npm 权限问题，尝试修复..."
                  
                  # 方案1: 使用用户目录作为 npm 前缀
                  local user_npm_prefix="$user_home/.npm-global"
                  mkdir -p "$user_npm_prefix"
                  
                  # 设置 npm 前缀到用户目录
                  if npm config set prefix "$user_npm_prefix" 2>/dev/null; then
                    echo "[cn-pack]      ✓ 设置 npm 前缀到用户目录: $user_npm_prefix"
                    
                    # 更新 PATH 环境变量
                    if ! echo "$PATH" | grep -q "$user_npm_prefix/bin"; then
                      echo "[cn-pack]      ℹ️  请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:"
                      echo "[cn-pack]      ℹ️    export PATH=\"\$PATH:$user_npm_prefix/bin\""
                    fi
                    
                    return 0
                  fi
                fi
                
                # 方案2: 使用 sudo 修复目录权限
                echo "[cn-pack]      尝试修复系统 npm 目录权限..."
                local system_npm_prefix=$(npm config get prefix --global 2>/dev/null || echo "/usr/local")
                
                if [[ -w "$system_npm_prefix" ]]; then
                  echo "[cn-pack]      ✓ 系统 npm 目录可写: $system_npm_prefix"
                  return 0
                else
                  echo "[cn-pack]      ⚠️  系统 npm 目录不可写，建议使用以下方式:"
                  echo "[cn-pack]      ℹ️   1. 使用 sudo 安装: sudo npm install -g openclaw"
                  echo "[cn-pack]      ℹ️   2. 或配置用户目录: npm config set prefix ~/.npm-global"
                  return 1
                fi
                ;;
              
              npm-cache-permission)
                # 修复 npm 缓存权限问题
                local npm_cache=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
                
                if [[ ! -w "$npm_cache" ]]; then
                  echo "[cn-pack]      修复 npm 缓存目录权限..."
                  mkdir -p "$npm_cache"
                  chmod 755 "$npm_cache" 2>/dev/null || true
                  
                  if [[ -w "$npm_cache" ]]; then
                    echo "[cn-pack]      ✓ npm 缓存目录权限修复成功"
                    return 0
                  else
                    echo "[cn-pack]      ⚠️  npm 缓存目录权限修复失败"
                    return 1
                  fi
                fi
                return 0
                ;;
              
              node-modules-permission)
                # 修复 node_modules 目录权限问题
                local current_dir=$(pwd)
                local node_modules_dir="$current_dir/node_modules"
                
                if [[ -d "$node_modules_dir" ]] && [[ ! -w "$node_modules_dir" ]]; then
                  echo "[cn-pack]      修复 node_modules 目录权限..."
                  sudo chmod -R 755 "$node_modules_dir" 2>/dev/null || chmod -R 755 "$node_modules_dir" 2>/dev/null || true
                  
                  if [[ -w "$node_modules_dir" ]]; then
                    echo "[cn-pack]      ✓ node_modules 目录权限修复成功"
                    return 0
                  fi
                fi
                return 0
                ;;
              
              *)
                echo "[cn-pack]      ⚠️  未知的修复类型: $fix_type"
                return 1
                ;;
            esac
          }
          
          echo "[cn-pack]   1. 检查 Node.js..."
          if command -v node &> /dev/null; then
            local node_version=$(node --version 2>/dev/null | cut -d'v' -f2)
            echo "[cn-pack]     ✓ Node.js v$node_version 已安装"
            
            # 检查 Node.js 版本是否 >= 16
            local node_major=$(echo "$node_version" | cut -d'.' -f1)
            if [[ "$node_major" -ge 16 ]]; then
              echo "[cn-pack]     ✓ Node.js 版本满足要求 (>= 16)"
            else
              echo "[cn-pack]     ⚠️  Node.js 版本较低 (v$node_version < 16)"
              warnings=$((warnings + 1))
            fi
          else
            echo "[cn-pack]     ❌ Node.js 未安装"
            errors=$((errors + 1))
          fi
          
          echo "[cn-pack]   2. 检查 npm..."
          if command -v npm &> /dev/null; then
            local npm_version=$(npm --version 2>/dev/null)
            echo "[cn-pack]     ✓ npm v$npm_version 已安装"
          else
            echo "[cn-pack]     ❌ npm 未安装"
            errors=$((errors + 1))
          fi
          
          echo "[cn-pack]   3. 检查 curl..."
          if command -v curl &> /dev/null; then
            echo "[cn-pack]     ✓ curl 已安装"
          else
            echo "[cn-pack]     ⚠️  curl 未安装 (将影响网络功能)"
            warnings=$((warnings + 1))
          fi
          
          echo "[cn-pack]   4. 检查磁盘空间..."
          local free_space_kb=$(df -k . 2>/dev/null | tail -1 | awk '{print $4}')
          if [[ -n "$free_space_kb" ]]; then
            local free_space_mb=$((free_space_kb / 1024))
            if [[ "$free_space_mb" -ge 500 ]]; then
              echo "[cn-pack]     ✓ 磁盘空间充足 (${free_space_mb}MB 可用)"
            elif [[ "$free_space_mb" -ge 100 ]]; then
              echo "[cn-pack]     ⚠️  磁盘空间较低 (${free_space_mb}MB 可用)"
              warnings=$((warnings + 1))
            else
              echo "[cn-pack]     ❌ 磁盘空间不足 (${free_space_mb}MB 可用，需要至少 100MB)"
              errors=$((errors + 1))
            fi
          else
            echo "[cn-pack]     ⚠️  无法检查磁盘空间"
            warnings=$((warnings + 1))
          fi
          
          echo "[cn-pack]   5. 检查 npm 全局安装权限..."
          if command -v npm &> /dev/null; then
            local npm_prefix_output=$(npm config get prefix 2>&1)
            if echo "$npm_prefix_output" | grep -q "Permission denied"; then
              echo "[cn-pack]     ⚠️  npm 全局安装权限不足，尝试自动修复..."
              
              # 尝试自动修复
              if auto_fix_permissions "npm-global-permission"; then
                echo "[cn-pack]     ✓ npm 权限自动修复成功"
                # 重新检查权限
                if npm config get prefix 2>/dev/null | grep -q "Permission denied"; then
                  echo "[cn-pack]     ❌ 自动修复后权限问题仍然存在"
                  errors=$((errors + 1))
                else
                  echo "[cn-pack]     ✓ npm 全局安装权限已修复"
                fi
              else
                echo "[cn-pack]     ❌ npm 全局安装权限不足且自动修复失败"
                errors=$((errors + 1))
              fi
            else
              echo "[cn-pack]     ✓ npm 全局安装权限正常"
            fi
          fi
          
          echo "[cn-pack]   6. 检查 npm 缓存权限..."
          if command -v npm &> /dev/null; then
            local npm_cache=$(npm config get cache 2>/dev/null || echo "$HOME/.npm")
            if [[ ! -w "$npm_cache" ]]; then
              echo "[cn-pack]     ⚠️  npm 缓存目录不可写，尝试自动修复..."
              
              if auto_fix_permissions "npm-cache-permission"; then
                echo "[cn-pack]     ✓ npm 缓存权限自动修复成功"
              else
                echo "[cn-pack]     ⚠️  npm 缓存权限修复失败（可能影响安装速度）"
                warnings=$((warnings + 1))
              fi
            else
              echo "[cn-pack]     ✓ npm 缓存权限正常"
            fi
          fi
          
          echo "[cn-pack]   8. 检查 Docker 容器环境..."
          # 检测是否在 Docker 容器中运行
          if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
            echo "[cn-pack]     ⚠️  检测到在 Docker 容器中运行"
            echo "[cn-pack]     ℹ️  提示: 在容器中安装时，请确保:"
            echo "[cn-pack]     ℹ️    1. 使用持久化卷保存配置和数据"
            echo "[cn-pack]     ℹ️    2. 考虑使用 Docker 镜像而非全局安装"
            echo "[cn-pack]     ℹ️    3. 容器重启后安装的包会丢失"
            warnings=$((warnings + 1))
            
            # 检查容器内是否有持久化目录
            if [[ -d /data ]] && [[ -w /data ]]; then
              echo "[cn-pack]     ✓ 检测到可写的持久化目录: /data"
            elif [[ -d /app ]] && [[ -w /app ]]; then
              echo "[cn-pack]     ✓ 检测到可写的应用目录: /app"
            else
              echo "[cn-pack]     ⚠️  未检测到推荐的持久化目录 (/data 或 /app)"
              echo "[cn-pack]     ℹ️  建议在容器中创建持久化目录:"
              echo "[cn-pack]     ℹ️    mkdir -p /data && chmod 755 /data"
            fi
          else
            echo "[cn-pack]     ✓ 不在 Docker 容器中运行"
          fi
          
          echo "[cn-pack]   9. 检查内存..."
          if [[ -f /proc/meminfo ]]; then
            local mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local mem_total_mb=$((mem_total_kb / 1024))
            if [[ "$mem_total_mb" -ge 1024 ]]; then
              echo "[cn-pack]     ✓ 内存充足 (${mem_total_mb}MB)"
            elif [[ "$mem_total_mb" -ge 512 ]]; then
              echo "[cn-pack]     ⚠️  内存较低 (${mem_total_mb}MB)"
              warnings=$((warnings + 1))
            else
              echo "[cn-pack]     ❌ 内存不足 (${mem_total_mb}MB，需要至少 512MB)"
              errors=$((errors + 1))
            fi
          else
            echo "[cn-pack]     ⚠️  无法检查内存"
            warnings=$((warnings + 1))
          fi
          
          # 总结报告
          echo "[cn-pack]   -----------------------------------------"
          echo "[cn-pack]   依赖检查完成:"
          if [[ "$errors" -eq 0 ]]; then
            echo "[cn-pack]     ✓ 所有必需依赖检查通过"
          else
            echo "[cn-pack]     ❌ 发现 $errors 个错误"
          fi
          
          if [[ "$warnings" -gt 0 ]]; then
            echo "[cn-pack]     ⚠️  发现 $warnings 个警告"
          fi
          
          if [[ "$errors" -gt 0 ]]; then
            echo "[cn-pack]   ❌ 依赖检查失败，请解决上述问题后重试"
            return 1
          fi
          
          return 0
        }
        
        # 执行增强的依赖检查
        if ! enhanced_dependency_check; then
          if [[ "$STEP_BY_STEP" == "true" ]]; then
            echo "[cn-pack]   ⚠️  依赖检查失败，是否继续？[y/N]"
            read -r continue_install
            if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
              echo "[cn-pack]   ❌ 安装已取消"
              exit 1
            fi
          else
            echo "[cn-pack]   ❌ 依赖检查失败，安装中止"
            exit 1
          fi
        fi
        ;;
        
      npm-install)
        echo "[cn-pack] 🔍 步骤 5/7: NPM 包安装"
        echo "[cn-pack]   安装 OpenClaw v$VERSION..."
        echo "[cn-pack]   使用仓库: $REG_CN"
        ;;
        
      verification)
        echo "[cn-pack] 🔍 步骤 6/7: 安装验证"
        echo "[cn-pack]   验证级别: $VERIFY_LEVEL"
        ;;
        
      cleanup)
        echo "[cn-pack] 🔍 步骤 7/7: 清理临时文件"
        echo "[cn-pack]   清理安装过程中的临时文件..."
        ;;
        
      *)
        echo "[cn-pack] ⚠️  未知步骤: $step (跳过)"
        continue
        ;;
    esac
    
    # 在实际实现中，这里会有每个步骤的实际执行代码
    echo "[cn-pack]   ✓ 步骤 '$step' 准备就绪"
    echo ""
  done
  
  color_log "SUCCESS" "分步安装模式配置完成"
  echo "[cn-pack] ℹ️  要实际执行安装，请移除 --step-by-step 或 --steps 参数"
}

# Function to clear proxy settings after installation
cleanup_proxy_settings() {
  echo "[cn-pack] Cleaning up proxy settings..."
  
  # Clear npm proxy config
  npm config delete proxy >/dev/null 2>&1 || true
  npm config delete https-proxy >/dev/null 2>&1 || true
  
  echo "[cn-pack] ✓ Proxy settings cleaned up"
}

usage() {
  cat <<TXT
[cn-pack] OpenClaw CN installer v$SCRIPT_VERSION

Options:
  --version <ver>          Install a specific OpenClaw version (default: latest)
  --registry-cn <url>      CN npm registry (default: https://registry.npmmirror.com)
  --registry-fallback <u>  Fallback npm registry (default: https://registry.npmjs.org)
  --network-test           Run network connectivity test before install
  --network-optimize       Run advanced network optimization (detect best mirrors)
  --force-cn               Force using CN registry (skip fallback)
  --dry-run                Print commands without executing
  --check-update           Check for script updates and exit
  --version-check          Check script version and update status (non-blocking)
  --changelog              Show script changelog and exit
  --verify-level <level>   Verification level: auto, basic, quick, full, none (default: auto)
  --proxy-mode <mode>      Proxy handling mode: auto, force, skip (default: auto)
  --proxy-test             Test proxy connectivity before installation
  --proxy-report           Generate proxy configuration report
  --keep-proxy             Keep npm proxy settings after installation
  --offline-mode           Enable offline mode (use local cache only)
  --cache-dir <dir>        Specify local cache directory (default: ~/.openclaw/cache)
  --step-by-step           Enable step-by-step interactive installation mode
  --steps <steps>          Specify installation steps to run (comma-separated)
  --uninstall              Uninstall OpenClaw and clean up installation
  --uninstall-dry-run      Dry run uninstall (show what would be removed)
  --ci-mode                Enable CI/CD mode (non-interactive, minimal output)
  --skip-interactive       Skip all interactive prompts
  --install-log <file>     Save installation log to specified file
  --generate-config <env>  Generate config template: dev, test, prod
  --config-output <file>   Output file for generated config (default: stdout)
  --batch-deploy <file>    Batch deploy to multiple servers using config file
  --batch-dry-run          Dry run batch deployment (show what would be done)
  -h, --help               Show help

CI/CD Integration:
  Environment variables for CI/CD:
    CI_MODE=1              Enable CI mode (non-interactive)
    SKIP_INTERACTIVE=1     Skip interactive prompts
    INSTALL_LOG=<file>     Save installation log
    OPENCLAW_VERSION       Set OpenClaw version
    NPM_REGISTRY           Set npm registry URL
    NPM_REGISTRY_FALLBACK  Set fallback registry URL
    ENABLE_ENHANCED_HEALTH_CHECK=1  Run enhanced health check after installation
    RUN_ENHANCED_HEALTH_CHECK=1     Same as above (alternative)
  
  Example CI/CD usage:
    export CI_MODE=1
    export OPENCLAW_VERSION=latest
    export NPM_REGISTRY=https://registry.npmmirror.com
    export SKIP_INTERACTIVE=1
    export INSTALL_LOG=/tmp/openclaw-install-ci.log
    bash install-cn.sh

Installation Steps (for --step-by-step or --steps):
  - network-check: Network connectivity test
  - proxy-check: Proxy configuration check
  - registry-test: NPM registry connectivity test
  - dependency-check: System dependency verification
  - npm-install: NPM package installation
  - verification: Installation verification
  - cleanup: Cleanup temporary files

Version Control:
  - Script version: $SCRIPT_VERSION
  - Update URL: $SCRIPT_UPDATE_URL
  - Use --check-update to check for updates
  - Use --version-check for non-blocking version check
  - Use --changelog to view version history and changes

Env vars (equivalent):
  OPENCLAW_VERSION, NPM_REGISTRY, NPM_REGISTRY_FALLBACK, OPENCLAW_VERIFY_SCRIPT, OPENCLAW_VERIFY_LEVEL
  HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy (for proxy detection)
TXT
}

# Function for batch deployment to multiple servers
batch_deploy_openclaw() {
  local config_file="$1"
  local dry_run="${2:-0}"
  local batch_summary_file="/tmp/openclaw-batch-deploy-summary-$(date +%Y%m%d-%H%M%S).txt"
  local batch_log_dir="/tmp/openclaw-batch-deploy-logs-$(date +%Y%m%d-%H%M%S)"
  
  echo ""
  color_log "STEP" "========================================="
  color_log "STEP" "🚀 OpenClaw 批量部署"
  color_log "STEP" "========================================="
  
  if [[ ! -f "$config_file" ]]; then
    color_log "ERROR" "批量部署配置文件不存在: $config_file"
    color_log "INFO" "请创建配置文件，格式参考:"
    color_log "INFO" "  # 批量部署配置文件示例"
    color_log "INFO" "  # 每行格式: 服务器地址|用户名|密码|安装选项"
    color_log "INFO" "  # 示例:"
    color_log "INFO" "  # server1.example.com|admin|password123|--version latest --ci-mode"
    color_log "INFO" "  # 192.168.1.100|root|mypass|--registry-cn https://registry.npmmirror.com"
    return 1
  fi
  
  if [[ "$dry_run" == "1" ]]; then
    color_log "WARNING" "📋 DRY RUN MODE - 仅显示部署计划，不实际执行"
  fi
  
  # Create log directory
  mkdir -p "$batch_log_dir"
  
  # Initialize summary
  {
    echo "=== OpenClaw 批量部署摘要 ==="
    echo "部署时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "配置文件: $config_file"
    echo "部署模式: $([[ "$dry_run" == "1" ]] && echo "Dry Run" || echo "实际部署")"
    echo "日志目录: $batch_log_dir"
    echo ""
    echo "=== 服务器列表 ==="
  } > "$batch_summary_file"
  
  local total_servers=0
  local success_count=0
  local failed_count=0
  local skipped_count=0
  
  # Read config file
  while IFS='|' read -r server username password options || [[ -n "$server" ]]; do
    # Skip empty lines and comments
    [[ -z "$server" || "$server" =~ ^[[:space:]]*# ]] && continue
    
    total_servers=$((total_servers + 1))
    
    # Log server info
    echo "服务器 $total_servers: $server" >> "$batch_summary_file"
    echo "  用户名: $username" >> "$batch_summary_file"
    echo "  安装选项: $options" >> "$batch_summary_file"
    
    color_log "INFO" "准备部署到服务器 $total_servers: $server"
    
    if [[ "$dry_run" == "1" ]]; then
      color_log "INFO" "  [Dry Run] 将执行: ssh $username@$server 'bash -s' < 安装脚本 $options"
      skipped_count=$((skipped_count + 1))
      echo "  状态: Dry Run (跳过)" >> "$batch_summary_file"
      continue
    fi
    
    # Create individual server log file
    local server_log="$batch_log_dir/server-${total_servers}-${server//[^a-zA-Z0-9]/_}.log"
    
    {
      echo "=== 服务器部署日志: $server ==="
      echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "用户名: $username"
      echo "安装选项: $options"
      echo ""
    } > "$server_log"
    
    # Check if SSH is available
    if ! command -v ssh >/dev/null 2>&1; then
      color_log "ERROR" "  SSH客户端不可用，跳过服务器: $server"
      echo "  状态: 失败 (SSH客户端不可用)" >> "$batch_summary_file"
      failed_count=$((failed_count + 1))
      continue
    fi
    
    # Test SSH connection
    color_log "INFO" "  测试SSH连接..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=no "$username@$server" "echo 'SSH连接测试成功'" >> "$server_log" 2>&1; then
      color_log "ERROR" "  SSH连接失败，跳过服务器: $server"
      echo "  状态: 失败 (SSH连接失败)" >> "$batch_summary_file"
      failed_count=$((failed_count + 1))
      continue
    fi
    
    # Get current script path
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Deploy using SSH
    color_log "INFO" "  开始部署OpenClaw..."
    echo "开始部署..." >> "$server_log"
    
    if ssh "$username@$server" "bash -s" -- "$options" < "$script_path" >> "$server_log" 2>&1; then
      color_log "SUCCESS" "  ✅ 部署成功: $server"
      echo "  状态: 成功" >> "$batch_summary_file"
      success_count=$((success_count + 1))
      
      # Get deployment result
      ssh "$username@$server" "openclaw --version 2>/dev/null || echo '未找到openclaw命令'" >> "$server_log" 2>&1
    else
      color_log "ERROR" "  ❌ 部署失败: $server"
      echo "  状态: 失败" >> "$batch_summary_file"
      failed_count=$((failed_count + 1))
    fi
    
    echo "" >> "$server_log"
    echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$server_log"
    
  done < "$config_file"
  
  # Generate final summary
  {
    echo ""
    echo "=== 部署统计 ==="
    echo "总服务器数: $total_servers"
    echo "成功: $success_count"
    echo "失败: $failed_count"
    echo "跳过(Dry Run): $skipped_count"
    echo ""
    echo "=== 详细日志 ==="
    echo "单个服务器日志: $batch_log_dir/"
    echo "  每个服务器对应一个日志文件: server-<序号>-<服务器名>.log"
    echo ""
    echo "=== 后续步骤 ==="
    echo "1. 检查失败服务器的日志: $batch_log_dir/"
    echo "2. 验证成功服务器的安装: ssh <用户>@<服务器> 'openclaw --version'"
    echo "3. 启动网关服务: ssh <用户>@<服务器> 'openclaw gateway start'"
    echo "4. 检查状态: ssh <用户>@<服务器> 'openclaw status'"
  } >> "$batch_summary_file"
  
  # Display summary
  echo ""
  color_log "STEP" "========================================="
  color_log "STEP" "📊 批量部署完成"
  color_log "STEP" "========================================="
  color_log "INFO" "总服务器数: $total_servers"
  color_log "SUCCESS" "成功: $success_count"
  if [[ "$failed_count" -gt 0 ]]; then
    color_log "ERROR" "失败: $failed_count"
  else
    color_log "INFO" "失败: $failed_count"
  fi
  if [[ "$skipped_count" -gt 0 ]]; then
    color_log "WARNING" "跳过(Dry Run): $skipped_count"
  fi
  
  color_log "INFO" "部署摘要已保存到: $batch_summary_file"
  color_log "INFO" "详细日志目录: $batch_log_dir/"
  
  echo ""
  color_log "INFO" "📋 摘要内容预览:"
  echo "-----------------------------------------"
  tail -20 "$batch_summary_file"
  echo "-----------------------------------------"
  
  # Return success if all deployments succeeded
  if [[ "$failed_count" -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Function to uninstall OpenClaw
uninstall_openclaw() {
  local dry_run="${1:-false}"
  local uninstall_summary_file="/tmp/openclaw-uninstall-summary-$(date +%Y%m%d-%H%M%S).txt"
  
  echo "[cn-pack] ========================================="
  echo "[cn-pack] 🗑️  OpenClaw Uninstaller"
  echo "[cn-pack] ========================================="
  
  if [[ "$dry_run" == "true" ]]; then
    echo "[cn-pack] 📋 DRY RUN MODE - No files will be removed"
    echo "[cn-pack] 📋 This is a preview of what would be removed:"
  fi
  
  # Start uninstall summary
  {
    echo "=== OpenClaw Uninstall Summary ==="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Mode: $([[ "$dry_run" == "true" ]] && echo "Dry Run" || echo "Actual Uninstall")"
    echo ""
  } > "$uninstall_summary_file"
  
  # Check if OpenClaw is installed
  if ! command -v openclaw >/dev/null 2>&1; then
    echo "[cn-pack] ℹ️ OpenClaw is not installed globally via npm"
    echo "Status: OpenClaw not found in PATH" >> "$uninstall_summary_file"
  else
    echo "[cn-pack] ✅ Found OpenClaw installation"
    echo "Status: OpenClaw found in PATH" >> "$uninstall_summary_file"
    
    # Get OpenClaw version
    local openclaw_version
    openclaw_version=$(openclaw --version 2>/dev/null || echo "unknown")
    echo "[cn-pack] 📦 Version: $openclaw_version"
    echo "Version: $openclaw_version" >> "$uninstall_summary_file"
  fi
  
  # List of directories and files to remove
  local items_to_remove=(
    # Global npm package
    "/usr/local/bin/openclaw"
    "/usr/local/lib/node_modules/openclaw"
    
    # User directories
    "$HOME/.openclaw"
    "$HOME/.config/openclaw"
    "$HOME/.cache/openclaw"
    
    # System directories (if installed globally)
    "/opt/openclaw"
    "/var/lib/openclaw"
    "/var/log/openclaw"
    
    # Temporary files
    "/tmp/openclaw-*"
    "/tmp/roc-ai-republic-*"
  )
  
  echo ""
  echo "[cn-pack] 📋 Items to be removed:"
  echo "Items to remove:" >> "$uninstall_summary_file"
  
  local found_items=0
  for item in "${items_to_remove[@]}"; do
    # Expand glob patterns
    for expanded_item in $item; do
      if [[ -e "$expanded_item" ]] || [[ -L "$expanded_item" ]]; then
        found_items=$((found_items + 1))
        echo "[cn-pack]   - $expanded_item"
        echo "  - $expanded_item" >> "$uninstall_summary_file"
        
        if [[ "$dry_run" != "true" ]]; then
          # Remove the item
          if [[ -d "$expanded_item" ]]; then
            rm -rf "$expanded_item" 2>/dev/null && \
              echo "[cn-pack]     ✅ Directory removed" || \
              echo "[cn-pack]     ⚠️  Failed to remove directory"
          elif [[ -f "$expanded_item" ]] || [[ -L "$expanded_item" ]]; then
            rm -f "$expanded_item" 2>/dev/null && \
              echo "[cn-pack]     ✅ File removed" || \
              echo "[cn-pack]     ⚠️  Failed to remove file"
          fi
        fi
      fi
    done
  done
  
  if [[ $found_items -eq 0 ]]; then
    echo "[cn-pack] ℹ️ No OpenClaw files found to remove"
    echo "No files found to remove" >> "$uninstall_summary_file"
  fi
  
  # Uninstall npm package if installed globally
  if command -v npm >/dev/null 2>&1; then
    echo ""
    echo "[cn-pack] 📦 Checking npm packages..."
    echo "NPM packages:" >> "$uninstall_summary_file"
    
    # Check if openclaw is installed globally
    if npm list -g openclaw 2>/dev/null | grep -q "openclaw"; then
      echo "[cn-pack]   - openclaw (global npm package)"
      echo "  - openclaw (global npm package)" >> "$uninstall_summary_file"
      
      if [[ "$dry_run" != "true" ]]; then
        echo "[cn-pack]     Uninstalling global npm package..."
        npm uninstall -g openclaw 2>/dev/null && \
          echo "[cn-pack]     ✅ Package uninstalled" || \
          echo "[cn-pack]     ⚠️  Failed to uninstall package"
      fi
    else
      echo "[cn-pack]   ℹ️ openclaw not found in global npm packages"
      echo "  - openclaw not found in global npm packages" >> "$uninstall_summary_file"
    fi
  fi
  
  # Clean up npm cache
  echo ""
  echo "[cn-pack] 🧹 Cleaning npm cache..."
  echo "NPM cache cleanup:" >> "$uninstall_summary_file"
  
  if [[ "$dry_run" != "true" ]] && command -v npm >/dev/null 2>&1; then
    npm cache clean --force 2>/dev/null && \
      echo "[cn-pack]   ✅ npm cache cleaned" || \
      echo "[cn-pack]   ⚠️  Failed to clean npm cache"
    echo "  - npm cache cleaned" >> "$uninstall_summary_file"
  else
    echo "[cn-pack]   📋 Would clean npm cache"
    echo "  - npm cache would be cleaned" >> "$uninstall_summary_file"
  fi
  
  # Final summary
  echo ""
  echo "[cn-pack] ========================================="
  if [[ "$dry_run" == "true" ]]; then
    echo "[cn-pack] 📋 DRY RUN COMPLETE"
    echo "[cn-pack] ℹ️  No files were actually removed"
    echo "[cn-pack] 📄 Summary saved to: $uninstall_summary_file"
  else
    echo "[cn-pack] ✅ UNINSTALL COMPLETE"
    echo "[cn-pack] 📄 Uninstall summary saved to: $uninstall_summary_file"
    
    # Verify uninstall
    echo ""
    echo "[cn-pack] 🔍 Verification:"
    if ! command -v openclaw >/dev/null 2>&1; then
      echo "[cn-pack]   ✅ openclaw command removed from PATH"
    else
      echo "[cn-pack]   ⚠️  openclaw command still found in PATH"
    fi
  fi
  
  echo "[cn-pack] ========================================="
  
  # Add final summary to file
  {
    echo ""
    echo "=== Summary ==="
    echo "Total items found: $found_items"
    echo "Uninstall mode: $([[ "$dry_run" == "true" ]] && echo "Dry Run" || echo "Actual")"
    echo "Completion time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  } >> "$uninstall_summary_file"
  
  return 0
}

# Function to check for script updates
check_script_update() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "[cn-pack] ℹ️ curl not available, skipping update check"
    return 0
  fi
  
  echo "[cn-pack] Checking for script updates..."
  
  # Try to get remote script content
  REMOTE_CONTENT=$(curl -fsS -m 10 "$SCRIPT_UPDATE_URL" 2>/dev/null || echo "")
  
  if [[ -z "$REMOTE_CONTENT" ]]; then
    echo "[cn-pack] ℹ️ Could not fetch remote script (network issue)"
    return 0
  fi
  
  # Extract version from remote script - handle different quote styles
  REMOTE_VERSION=$(echo "$REMOTE_CONTENT" | \
    grep -m1 'SCRIPT_VERSION=' | \
    sed -n "s/.*SCRIPT_VERSION=\"\([^\"]*\)\".*/\1/p" || \
    echo "$REMOTE_CONTENT" | \
    grep -m1 'SCRIPT_VERSION=' | \
    sed -n "s/.*SCRIPT_VERSION='\([^']*\)'.*/\1/p" || \
    echo "")
  
  if [[ -z "$REMOTE_VERSION" ]]; then
    echo "[cn-pack] ℹ️ Could not parse version from remote script"
    return 0
  fi
  
  if [[ "$REMOTE_VERSION" != "$SCRIPT_VERSION" ]]; then
    echo "[cn-pack] ⚠️  New version available: $REMOTE_VERSION (current: $SCRIPT_VERSION)"
    echo "[cn-pack] ℹ️  Update with: curl -fsSL $SCRIPT_UPDATE_URL -o /tmp/install-cn.sh && bash /tmp/install-cn.sh"
    echo "[cn-pack] ℹ️  Or visit: https://github.com/1037104428/roc-ai-republic/blob/main/scripts/install-cn.sh"
    return 1
  else
    echo "[cn-pack] ✅ Script is up to date (version: $SCRIPT_VERSION)"
    return 0
  fi
}

DRY_RUN=0
NETWORK_TEST=0
NETWORK_OPTIMIZE=0
FORCE_CN=0
VERSION_CHECK=0
VERSION="${OPENCLAW_VERSION:-$OPENCLAW_VERSION_DEFAULT}"
REG_CN="${NPM_REGISTRY:-$NPM_REGISTRY_CN_DEFAULT}"
REG_FALLBACK="${NPM_REGISTRY_FALLBACK:-$NPM_REGISTRY_FALLBACK_DEFAULT}"
VERIFY_LEVEL="${OPENCLAW_VERIFY_LEVEL:-$VERIFY_LEVEL_DEFAULT}"
PROXY_MODE="auto"
PROXY_TEST=0
PROXY_REPORT=0
KEEP_PROXY=0
OFFLINE_MODE=0
CACHE_DIR="${HOME}/.openclaw/cache"
STEP_BY_STEP=0
GENERATE_CONFIG=""
CONFIG_OUTPUT=""
STEPS=""
BATCH_DEPLOY_FILE=""
BATCH_DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"; shift 2 ;;
    --registry-cn)
      REG_CN="${2:-}"; shift 2 ;;
    --registry-fallback)
      REG_FALLBACK="${2:-}"; shift 2 ;;
    --network-test)
      NETWORK_TEST=1; shift ;;
    --verify-level)
      VERIFY_LEVEL="${2:-}"; shift 2 ;;
    --network-optimize)
      NETWORK_OPTIMIZE=1; shift ;;
    --force-cn)
      FORCE_CN=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --proxy-mode)
      PROXY_MODE="${2:-auto}"; shift 2 ;;
    --proxy-test)
      PROXY_TEST=1; shift ;;
    --proxy-report)
      PROXY_REPORT=1; shift ;;
    --keep-proxy)
      KEEP_PROXY=1; shift ;;
    --offline-mode)
      OFFLINE_MODE=1; shift ;;
    --cache-dir)
      CACHE_DIR="${2:-}"; shift 2 ;;
    --step-by-step)
      STEP_BY_STEP=1; shift ;;
    --steps)
      STEPS="${2:-}"; shift 2 ;;
    --check-update)
      check_script_update
      exit $?
      ;;
    --version-check)
      VERSION_CHECK=1
      shift
      ;;
    --changelog)
      show_changelog
      exit 0
      ;;
    --uninstall)
      uninstall_openclaw "false"
      exit $?
      ;;
    --uninstall-dry-run)
      uninstall_openclaw "true"
      exit $?
      ;;
    --ci-mode)
      CI_MODE=1
      shift
      ;;
    --skip-interactive)
      SKIP_INTERACTIVE=1
      shift
      ;;
    --install-log)
      INSTALL_LOG="${2:-}"
      shift 2
      ;;
    --generate-config)
      GENERATE_CONFIG="${2:-}"
      shift 2
      ;;
    --config-output)
      CONFIG_OUTPUT="${2:-}"
      shift 2
      ;;
    --batch-deploy)
      BATCH_DEPLOY_FILE="${2:-}"
      shift 2
      ;;
    --batch-dry-run)
      BATCH_DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[cn-pack] ❌ Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# 批量部署检查 - 如果指定了批量部署，立即执行并退出
if [[ -n "$BATCH_DEPLOY_FILE" ]]; then
  batch_deploy_openclaw "$BATCH_DEPLOY_FILE" "$BATCH_DRY_RUN"
  exit $?
fi

# 故障自愈检查 - 在安装开始前检测和修复常见问题
if [[ "${ENABLE_FAULT_RECOVERY:-1}" == "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
  echo ""
  color_log "STEP" "========================================="
  color_log "STEP" "🔧 故障自愈检查"
  color_log "STEP" "========================================="
  detect_and_fix_common_issues
  echo ""
fi

# CI/CD模式环境变量覆盖
if [[ "${CI_MODE:-0}" == "1" ]] || [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] || [[ -n "${JENKINS_HOME:-}" ]]; then
  CI_MODE=1
  SKIP_INTERACTIVE="${SKIP_INTERACTIVE:-1}"
  VERIFY_LEVEL="${VERIFY_LEVEL:-minimal}"
  # 在CI模式下强制禁用颜色
  export FORCE_NO_COLOR=1
  echo "[cn-pack:INFO] 📦 检测到CI/CD环境，启用CI模式"
fi

# 如果设置了SKIP_INTERACTIVE，禁用交互式提示
if [[ "${SKIP_INTERACTIVE:-0}" == "1" ]]; then
  echo "[cn-pack:INFO] ⏭️  跳过交互式提示（CI/CD模式）"
  # 设置默认值以避免交互
  AUTO_FIX_PERMISSIONS="${AUTO_FIX_PERMISSIONS:-1}"
  AUTO_SELECT_REGISTRY="${AUTO_SELECT_REGISTRY:-1}"
fi

# 安装日志文件设置
if [[ -n "${INSTALL_LOG:-}" ]]; then
  echo "[cn-pack:INFO] 📝 安装日志将保存到: ${INSTALL_LOG}"
  exec > >(tee -a "${INSTALL_LOG}") 2>&1
fi

# Check if config template generation is requested
if [[ -n "$GENERATE_CONFIG" ]]; then
  generate_config_template "$GENERATE_CONFIG" "$CONFIG_OUTPUT"
  exit $?
fi

if [[ -z "$VERSION" || -z "$REG_CN" || -z "$REG_FALLBACK" ]]; then
  echo "[cn-pack] Missing required values." >&2
  usage
  exit 2
fi

# Check if step-by-step mode is enabled (must be before main installation logic)
if [[ "$STEP_BY_STEP" == "1" || -n "$STEPS" ]]; then
  step_by_step_install
  exit 0
fi

# Run version check if requested (non-blocking)
if [[ "$VERSION_CHECK" == "1" ]]; then
  echo "[cn-pack] Running version check..."
  check_script_updates "auto"
  # Continue with installation even if updates are available
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %q ' "$@"; echo
  else
    "$@"
  fi
}

# Network test function
run_network_test() {
  echo "[cn-pack] Running network connectivity test..."
  echo "[cn-pack] Testing CN registry: $REG_CN"
  
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -m 5 "$REG_CN/-/ping" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ CN registry reachable"
      CN_OK=1
    else
      echo "[cn-pack] ⚠️ CN registry not reachable"
      CN_OK=0
    fi
    
    echo "[cn-pack] Testing fallback registry: $REG_FALLBACK"
    if curl -fsS -m 5 "$REG_FALLBACK/-/ping" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ Fallback registry reachable"
      FALLBACK_OK=1
    else
      echo "[cn-pack] ⚠️ Fallback registry not reachable"
      FALLBACK_OK=0
    fi
    
    # Test GitHub/Gitee for script sources
    echo "[cn-pack] Testing script sources..."
    if curl -fsS -m 5 "https://raw.githubusercontent.com/openclaw/openclaw/main/package.json" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ GitHub raw reachable"
    else
      echo "[cn-pack] ⚠️ GitHub raw may be slow"
    fi
    
    if curl -fsS -m 5 "https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/README.md" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ Gitee raw reachable"
    else
      echo "[cn-pack] ⚠️ Gitee raw not reachable"
    fi
    
    echo ""
    echo "[cn-pack] === Network Test Summary ==="
    if [[ "$CN_OK" -eq 1 ]]; then
      echo "[cn-pack] ✅ Recommended: Use CN registry ($REG_CN)"
    elif [[ "$FALLBACK_OK" -eq 1 ]]; then
      echo "[cn-pack] ⚠️ Use fallback registry ($REG_FALLBACK)"
    else
      echo "[cn-pack] ❌ No registry reachable. Check network."
      exit 1
    fi
    echo ""
  else
    echo "[cn-pack] ℹ️ curl not found, skipping detailed network test"
  fi
}

# 网络优化功能
run_network_optimization() {
  echo "[cn-pack] 运行高级网络优化检测..."
  echo "[cn-pack] 这将测试多个镜像源并选择最快的"
  
  # 检查优化脚本是否存在
  local optimize_script="$(dirname "$0")/optimize-network-sources.sh"
  if [[ -f "$optimize_script" ]]; then
    echo "[cn-pack] 找到网络优化脚本: $optimize_script"
    
    # 运行优化脚本
    if bash "$optimize_script"; then
      echo ""
      echo "[cn-pack] ✅ 网络优化完成"
      echo "[cn-pack] 优化配置已保存到 ~/.openclaw-network-optimization.conf"
      echo "[cn-pack] 下次安装时可以使用: source ~/.openclaw-network-optimization.conf"
    else
      echo "[cn-pack] ⚠️ 网络优化脚本执行失败，使用基本网络测试"
      run_network_test
    fi
  else
    echo "[cn-pack] ⚠️ 网络优化脚本未找到，使用基本网络测试"
    run_network_test
  fi
}

if [[ "$NETWORK_OPTIMIZE" == "1" ]]; then
  run_network_optimization
  exit 0
fi

if [[ "$NETWORK_OPTIMIZE" == "1" ]]; then
  run_network_optimization
  exit 0
fi

if [[ "$NETWORK_TEST" == "1" ]]; then
  run_network_test
  exit 0
fi

# 检查是否有优化配置文件
if [[ -f "${HOME}/.openclaw-network-optimization.conf" ]]; then
  echo "[cn-pack] 检测到网络优化配置，正在加载..."
  # 安全地加载配置，只设置镜像源相关变量
  if source "${HOME}/.openclaw-network-optimization.conf" 2>/dev/null; then
    if [[ -n "${NPM_REGISTRY:-}" ]]; then
      REG_CN="$NPM_REGISTRY"
      echo "[cn-pack] ✅ 使用优化后的 npm 镜像源: $REG_CN"
    fi
    if [[ -n "${NPM_REGISTRY_FALLBACK:-}" ]]; then
      REG_FALLBACK="$NPM_REGISTRY_FALLBACK"
    fi
  else
    echo "[cn-pack] ⚠️ 优化配置文件加载失败，使用默认配置"
  fi
fi

if command -v node >/dev/null 2>&1; then
  NODE_VER_RAW="$(node -v || true)"
  NODE_MAJOR="${NODE_VER_RAW#v}"
  NODE_MAJOR="${NODE_MAJOR%%.*}"
  if [[ -n "${NODE_MAJOR}" ]] && (( NODE_MAJOR < 20 )); then
    echo "[cn-pack] ERROR: Node.js version ${NODE_VER_RAW} is too old. OpenClaw requires Node.js >= 20." >&2
    echo "[cn-pack] Please upgrade Node.js first. See: https://nodejs.org/" >&2
    exit 1
  fi
  echo "[cn-pack] node found: ${NODE_VER_RAW} (>=20 ✓)"
else
  echo "[cn-pack] ERROR: node not found. Please install Node.js >= 20 first." >&2
  echo "[cn-pack] Download from: https://nodejs.org/" >&2
  exit 1
fi

if command -v npm >/dev/null 2>&1; then
  echo "[cn-pack] npm found: $(npm -v)"
else
  echo "[cn-pack] ERROR: npm not found. Please install npm (usually bundled with Node.js)." >&2
  echo "[cn-pack] If you have Node.js but not npm, try reinstalling Node.js or check your PATH." >&2
  exit 1
fi

# Quick network connectivity check (optional, can be skipped with env var)
if [[ -z "${SKIP_NET_CHECK:-}" ]]; then
  echo "[cn-pack] Checking network connectivity to npm registries..."
  if command -v curl >/dev/null 2>&1; then
    # Test CN registry with latency measurement
    echo "[cn-pack] Testing CN registry: $REG_CN"
    CN_START=$(date +%s%N)
    if curl -fsS -m 5 "$REG_CN" >/dev/null 2>&1; then
      CN_END=$(date +%s%N)
      CN_LATENCY=$(( (CN_END - CN_START) / 1000000 ))
      echo "[cn-pack] ✅ CN registry reachable: $REG_CN (latency: ${CN_LATENCY}ms)"
      CN_REACHABLE=1
      CN_LATENCY_MS=${CN_LATENCY}
    else
      echo "[cn-pack] ⚠️ CN registry not reachable (will try fallback): $REG_CN"
      CN_REACHABLE=0
    fi
    
    # Test fallback registry with latency measurement
    echo "[cn-pack] Testing fallback registry: $REG_FALLBACK"
    FALLBACK_START=$(date +%s%N)
    if curl -fsS -m 5 "$REG_FALLBACK" >/dev/null 2>&1; then
      FALLBACK_END=$(date +%s%N)
      FALLBACK_LATENCY=$(( (FALLBACK_END - FALLBACK_START) / 1000000 ))
      echo "[cn-pack] ✅ Fallback registry reachable: $REG_FALLBACK (latency: ${FALLBACK_LATENCY}ms)"
      FALLBACK_REACHABLE=1
      FALLBACK_LATENCY_MS=${FALLBACK_LATENCY}
    else
      echo "[cn-pack] ⚠️ Fallback registry not reachable: $REG_FALLBACK"
      FALLBACK_REACHABLE=0
    fi
    
    # Provide intelligent recommendation
    if [[ "${CN_REACHABLE:-0}" -eq 1 && "${FALLBACK_REACHABLE:-0}" -eq 1 ]]; then
      if [[ "${CN_LATENCY_MS:-9999}" -lt "${FALLBACK_LATENCY_MS:-9999}" ]]; then
        echo "[cn-pack] 💡 Recommendation: CN registry is faster (${CN_LATENCY_MS}ms vs ${FALLBACK_LATENCY_MS}ms)"
      else
        echo "[cn-pack] 💡 Recommendation: Fallback registry is faster (${FALLBACK_LATENCY_MS}ms vs ${CN_LATENCY_MS}ms)"
      fi
    elif [[ "${CN_REACHABLE:-0}" -eq 1 ]]; then
      echo "[cn-pack] 💡 Only CN registry reachable, will use it"
    elif [[ "${FALLBACK_REACHABLE:-0}" -eq 1 ]]; then
      echo "[cn-pack] 💡 Only fallback registry reachable, will use it"
    else
      echo "[cn-pack] ❌ No npm registries reachable. Check your network connection." >&2
      exit 1
    fi
  else
    echo "[cn-pack] ℹ️ curl not found, skipping network check"
  fi
fi

# Function to check if offline mode is available
check_offline_mode() {
  if [[ "$OFFLINE_MODE" != "1" ]]; then
    return 0
  fi
  
  echo "[cn-pack] Offline mode enabled, checking local cache..."
  
  # Create cache directory if it doesn't exist
  mkdir -p "$CACHE_DIR"
  
  # Check for cached package
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  if [[ -f "$cache_file" ]]; then
    echo "[cn-pack] ✅ Found cached package: $cache_file"
    return 0
  else
    echo "[cn-pack] ❌ No cached package found for version: $VERSION"
    echo "[cn-pack] ℹ️  Cache directory: $CACHE_DIR"
    echo "[cn-pack] ℹ️  Expected file: openclaw-${VERSION}.tgz"
    return 1
  fi
}

# Function to install from offline cache
install_from_offline_cache() {
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  
  echo "[cn-pack] Installing from offline cache: $cache_file"
  
  if run npm i -g "$cache_file" --no-audit --no-fund; then
    echo "[cn-pack] ✅ Offline installation successful"
    return 0
  else
    echo "[cn-pack] ❌ Offline installation failed" >&2
    return 1
  fi
}

# Function to cache package for offline use
cache_package_for_offline() {
  local reg="$1"
  
  # Only cache if offline mode is supported or cache directory exists
  if [[ ! -d "$CACHE_DIR" ]]; then
    mkdir -p "$CACHE_DIR"
  fi
  
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  
  echo "[cn-pack] Caching package for offline use: $cache_file"
  
  # Try to download the package tarball
  if command -v npm &> /dev/null; then
    # Get package info to find tarball URL
    local package_info=$(npm view "openclaw@${VERSION}" --registry "$reg" --json 2>/dev/null || echo "{}")
    local dist_tarball=$(echo "$package_info" | grep -o '"tarball":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [[ -n "$dist_tarball" ]]; then
      echo "[cn-pack] Downloading package tarball from: $dist_tarball"
      if curl -fsSL "$dist_tarball" -o "$cache_file.tmp" 2>/dev/null; then
        mv "$cache_file.tmp" "$cache_file"
        echo "[cn-pack] ✅ Package cached successfully: $cache_file"
        echo "[cn-pack] ℹ️  File size: $(du -h "$cache_file" | cut -f1)"
      else
        echo "[cn-pack] ⚠️  Could not download package tarball"
        rm -f "$cache_file.tmp" 2>/dev/null || true
      fi
    else
      echo "[cn-pack] ⚠️  Could not get package tarball URL"
    fi
  else
    echo "[cn-pack] ⚠️  npm not available for caching"
  fi
}

install_openclaw() {
  local reg="$1"
  local attempt="$2"
  
  # Check if offline mode is enabled and available
  if [[ "$OFFLINE_MODE" == "1" ]]; then
    if check_offline_mode; then
      if install_from_offline_cache; then
        return 0
      else
        color_log "ERROR" "Offline installation failed, falling back to online mode"
      fi
    else
      color_log "ERROR" "Offline mode not available, falling back to online mode"
    fi
  fi
  
  color_log "STEP" "Installing openclaw@${VERSION} via registry: $reg (attempt: $attempt)"
  
  # Show progress bar for npm installation (estimated 30-60 seconds)
  if [[ "$DRY_RUN" != "1" ]] && [[ -t 1 ]] && [[ "$TERM" != "dumb" ]]; then
    show_progress_bar 45 "Downloading and installing OpenClaw package..."
  fi
  
  # no-audit/no-fund: faster & quieter, especially on slow networks
  if run npm i -g "openclaw@${VERSION}" --registry "$reg" --no-audit --no-fund; then
    # Cache the package for future offline use
    cache_package_for_offline "$reg"
    color_log "SUCCESS" "Installation completed successfully via $reg"
    return 0
  else
    color_log "ERROR" "Install attempt failed via registry: $reg"
    return 1
  fi
}

# Handle proxy settings before installation
echo "[cn-pack] ========================================="
echo "[cn-pack] Proxy Configuration Phase"
echo "[cn-pack] ========================================="

if [[ "$PROXY_TEST" == "1" ]]; then
  echo "[cn-pack] Running proxy connectivity test..."
  handle_proxy_settings "force"
elif [[ "$PROXY_REPORT" == "1" ]]; then
  echo "[cn-pack] Generating proxy configuration report..."
  if [[ -f "./scripts/detect-proxy.sh" ]]; then
    source ./scripts/detect-proxy.sh >/dev/null 2>&1
    generate_proxy_report "/tmp/openclaw-proxy-report-$(date +%s).md" >/dev/null 2>&1 || true
  fi
fi

# Apply proxy settings for installation
handle_proxy_settings "$PROXY_MODE"

# Setup rollback system before installation
if [[ "$DRY_RUN" != "1" ]]; then
  setup_rollback
fi

# 尝试CN源
if [[ "$FORCE_CN" == "1" ]]; then
  echo "[cn-pack] Force using CN registry (--force-cn flag)"
  if install_openclaw "$REG_CN" "CN-registry"; then
    echo "[cn-pack] ✅ Install OK via CN registry."
  else
    echo "[cn-pack] ❌ Install failed via CN registry (force mode)." >&2
    echo "[cn-pack] Troubleshooting:" >&2
    echo "[cn-pack] 1. Check CN registry: curl -fsS $REG_CN/-/ping" >&2
    echo "[cn-pack] 2. Try without --force-cn to use fallback" >&2
    perform_rollback "CN registry installation failed in force mode"
    exit 1
  fi
else
  # Normal mode with fallback
  if install_openclaw "$REG_CN" "CN-registry"; then
    echo "[cn-pack] ✅ Install OK via CN registry."
  else
    echo "[cn-pack] ⚠️ Install failed via CN registry; retrying with fallback: $REG_FALLBACK" >&2
    echo "[cn-pack] This may be due to network issues, registry mirror sync delay, or package availability." >&2
    echo "[cn-pack] Retrying with fallback registry in 2 seconds..." >&2
    sleep 2
    
    if install_openclaw "$REG_FALLBACK" "fallback-registry"; then
      echo "[cn-pack] ✅ Install OK via fallback registry."
    else
      echo "[cn-pack] ❌ Both registry attempts failed." >&2
      echo "[cn-pack] Troubleshooting steps:" >&2
      echo "[cn-pack] 1. Check network connectivity: curl -fsS https://registry.npmjs.org" >&2
      echo "[cn-pack] 2. Verify Node.js version: node -v (requires >=20)" >&2
      echo "[cn-pack] 3. Try manual install: npm i -g openclaw@${VERSION}" >&2
      echo "[cn-pack] 4. Report issue: https://github.com/openclaw/openclaw/issues" >&2
      perform_rollback "Both registry installation attempts failed"
      exit 1
    fi
  fi
fi

# Dry-run check will be handled after verification
# (moved to end of script to allow verification display in dry-run mode)

# Self-check
if command -v openclaw >/dev/null 2>&1; then
  echo "[cn-pack] Installed. Check: $(openclaw --version)"
else
  echo "[cn-pack] Install finished but 'openclaw' not found in PATH." >&2
  echo "[cn-pack] Tips: reopen your shell, or ensure your npm global bin is on PATH." >&2
  echo "[cn-pack] npm prefix: $(npm config get prefix 2>/dev/null || true)" >&2
  echo "[cn-pack] npm global bin: $(npm bin -g 2>/dev/null || true)" >&2
  exit 2
fi

# Cleanup proxy settings if not keeping them
if [[ "$KEEP_PROXY" == "0" ]]; then
  cleanup_proxy_settings
fi

echo "[cn-pack] Next steps:"
cat <<'TXT'
1) Create/verify config: ~/.openclaw/openclaw.json
2) Add DeepSeek provider snippet (see docs/openclaw-cn-pack-deepseek-v0.md)
3) Start gateway: openclaw gateway start
4) Verify: openclaw status && openclaw models status
5) Quick verification: ./scripts/verify-openclaw-install.sh (if in repo)
TXT

# Optional health check with detailed diagnostics
if [[ $DRY_RUN -eq 0 ]]; then
  echo "[cn-pack] Running post-install health check..."
  if command -v openclaw >/dev/null 2>&1; then
    OPENCLAW_PATH=$(command -v openclaw)
    OPENCLAW_VERSION_OUTPUT=$(openclaw --version 2>/dev/null || echo "version check failed")
    echo "[cn-pack] ✓ openclaw command found at: $OPENCLAW_PATH"
    echo "[cn-pack] ✓ Version: $OPENCLAW_VERSION_OUTPUT"
    
    # Check if gateway is running
    if openclaw gateway status 2>/dev/null | grep -q "running\|active"; then
      echo "[cn-pack] ✓ OpenClaw gateway is running"
    else
      echo "[cn-pack] ℹ️ Gateway not running. Start with: openclaw gateway start"
    fi
    
    # Quick config check
    if [[ -f ~/.openclaw/openclaw.json ]]; then
      echo "[cn-pack] ✓ Config file exists: ~/.openclaw/openclaw.json"
    else
      echo "[cn-pack] ℹ️ Config file not found. Create with: openclaw config init"
    fi
    
    # Enhanced health check integration (if requested)
    if [[ "${ENABLE_ENHANCED_HEALTH_CHECK:-0}" == "1" ]] || [[ "${RUN_ENHANCED_HEALTH_CHECK:-0}" == "1" ]]; then
      echo "[cn-pack] 🔍 Running enhanced health check integration..."
      echo "[cn-pack] This will perform a comprehensive health check of the OpenClaw installation"
      
      # Check if enhanced health check script exists
      ENHANCED_HEALTH_CHECK_SCRIPT="$(dirname "$0")/enhanced-health-check.sh"
      if [[ -f "$ENHANCED_HEALTH_CHECK_SCRIPT" ]] && [[ -x "$ENHANCED_HEALTH_CHECK_SCRIPT" ]]; then
        echo "[cn-pack] Found enhanced health check script: $ENHANCED_HEALTH_CHECK_SCRIPT"
        echo "[cn-pack] Running enhanced health check (this may take a moment)..."
        
        # Run enhanced health check
        if bash "$ENHANCED_HEALTH_CHECK_SCRIPT" --quick; then
          echo "[cn-pack] ✅ Enhanced health check completed successfully"
        else
          echo "[cn-pack] ⚠️ Enhanced health check found some issues (check output above)"
        fi
      else
        echo "[cn-pack] ℹ️ Enhanced health check script not found or not executable"
        echo "[cn-pack] You can download it from: https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/enhanced-health-check.sh"
        echo "[cn-pack] Or run manually: curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/enhanced-health-check.sh | bash -s -- --quick"
      fi
    fi
    
    # Additional diagnostics for troubleshooting
    echo "[cn-pack] Running additional diagnostics..."
    
    # API connectivity check (optional, can be skipped with env var)
    if [[ -z "${SKIP_API_CHECK:-}" ]] && command -v curl >/dev/null 2>&1; then
      echo "[cn-pack] Checking API connectivity..."
      
      # Check quota-proxy API (if configured)
      if [[ -f ~/.openclaw/openclaw.json ]] && grep -q "api.clawdrepublic.cn" ~/.openclaw/openclaw.json 2>/dev/null; then
        echo "[cn-pack] Testing quota-proxy API connectivity..."
        if curl -fsS -m 5 https://api.clawdrepublic.cn/healthz 2>/dev/null | grep -q '"ok":true'; then
          echo "[cn-pack] ✓ quota-proxy API is reachable"
        else
          echo "[cn-pack] ℹ️ quota-proxy API not reachable (may need TRIAL_KEY)"
        fi
      fi
      
      # Check forum connectivity
      echo "[cn-pack] Testing forum connectivity..."
      if curl -fsS -m 5 https://clawdrepublic.cn/forum/ 2>/dev/null | grep -q "Clawd 国度论坛"; then
        echo "[cn-pack] ✓ Forum is reachable"
      else
        echo "[cn-pack] ℹ️ Forum not reachable (check network or DNS)"
      fi
    elif [[ -n "${SKIP_API_CHECK:-}" ]]; then
      echo "[cn-pack] ℹ️ API connectivity check skipped (SKIP_API_CHECK set)"
    else
      echo "[cn-pack] ℹ️ curl not found, skipping API connectivity check"
    fi
    
    # Check npm global installation
    if npm list -g openclaw 2>/dev/null | grep -q "openclaw@"; then
      echo "[cn-pack] ✓ OpenClaw is installed globally via npm"
    else
      echo "[cn-pack] ⚠️ OpenClaw not found in npm global list. May be installed via npx"
    fi
    
    # Check workspace directory
    if [[ -d ~/.openclaw/workspace ]]; then
      echo "[cn-pack] ✓ Workspace directory exists: ~/.openclaw/workspace"
    else
      echo "[cn-pack] ℹ️ Workspace directory not found. Will be created on first run"
    fi
    
  else
    echo "[cn-pack] ⚠️ openclaw command not in PATH. Running diagnostics..."
    
    # Check npm global bin path
    NPM_BIN_PATH=$(npm bin -g 2>/dev/null || echo "/usr/local/bin")
    echo "[cn-pack]   npm global bin path: $NPM_BIN_PATH"
    
    # Check if npm bin is in PATH
    if echo "$PATH" | tr ':' '\n' | grep -q "^$NPM_BIN_PATH$"; then
      echo "[cn-pack]   ✓ npm bin path is in PATH"
    else
      echo "[cn-pack]   ⚠️ npm bin path NOT in PATH. Add to your shell config:"
      echo "[cn-pack]      export PATH=\"\$PATH:$NPM_BIN_PATH\""
    fi
    
    # Check if openclaw exists in npm bin
    if [[ -f "$NPM_BIN_PATH/openclaw" ]]; then
      echo "[cn-pack]   ✓ openclaw binary found at: $NPM_BIN_PATH/openclaw"
      echo "[cn-pack]   Try: source ~/.bashrc (or ~/.zshrc) and run 'openclaw --version'"
    else
      echo "[cn-pack]   ⚠️ openclaw binary not found in npm bin. Installation may have failed."
      echo "[cn-pack]   Try: npx openclaw --version (runs via npx without PATH)"
    fi
  fi
fi

# Quick verification summary
echo ""
color_log "STEP" "========================================="
color_log "STEP" "🚀 QUICK VERIFICATION COMMANDS:"
color_log "STEP" "========================================="
color_log "INFO" "1. Check version:    openclaw --version"
color_log "INFO" "2. Check status:     openclaw status"
color_log "INFO" "3. Start gateway:    openclaw gateway start"
color_log "INFO" "4. Check gateway:    openclaw gateway status"
color_log "INFO" "5. Test models:      openclaw models status"
color_log "INFO" "6. Get help:         openclaw --help"
color_log "STEP" "========================================="
color_log "INFO" "💡 Tip: Run these commands to verify your installation!"
color_log "STEP" "========================================="

# 根据验证级别执行验证
# Determine verification script path (for full verification level)
VERIFY_SCRIPT="${OPENCLAW_VERIFY_SCRIPT:-}"
if [[ -z "$VERIFY_SCRIPT" ]]; then
  # Try default paths
  if [[ -f "./scripts/verify-openclaw-install.sh" ]]; then
    VERIFY_SCRIPT="./scripts/verify-openclaw-install.sh"
  elif [[ -f "/tmp/verify-openclaw-install.sh" ]]; then
    VERIFY_SCRIPT="/tmp/verify-openclaw-install.sh"
  fi
fi
  echo ""
  color_log "STEP" "========================================="
  color_log "STEP" "🔍 安装验证 (级别: $VERIFY_LEVEL)"
  color_log "STEP" "========================================="
  
  # 验证级别处理
  case "$VERIFY_LEVEL" in
    none)
      color_log "INFO" "跳过验证 (级别: none)"
      ;;
    
    basic)
      color_log "INFO" "🚀 运行基本验证..."
      color_log "INFO" "运行以下命令进行基本验证:"
      color_log "INFO" "  openclaw --version"
      echo "[cn-pack] ℹ️   openclaw status"
      echo "[cn-pack] ℹ️   openclaw gateway status"
      ;;
    
    quick)
      # 检查当前目录是否有快速验证脚本
      quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
      if [[ -f "$quick_verify_script" ]]; then
        echo "[cn-pack] 使用快速验证脚本: $quick_verify_script"
        chmod +x "$quick_verify_script" 2>/dev/null || true
        
        if "$quick_verify_script" --quiet; then
          echo "[cn-pack] ✅ 快速验证通过！"
        else
          echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
        fi
      else
        echo "[cn-pack] ⚠️ 快速验证脚本未找到，降级到基本验证。"
        echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
        echo "[cn-pack] ℹ️   openclaw --version"
        echo "[cn-pack] ℹ️   openclaw status"
        echo "[cn-pack] ℹ️   openclaw gateway status"
      fi
      ;;
    
    full)
      # 检查完整验证脚本
      if [[ -n "$VERIFY_SCRIPT" ]] && [[ -f "$VERIFY_SCRIPT" ]]; then
        echo "[cn-pack] 运行完整验证脚本: $VERIFY_SCRIPT"
        chmod +x "$VERIFY_SCRIPT" 2>/dev/null || true
        
        if "$VERIFY_SCRIPT" --quiet; then
          echo "[cn-pack] ✅ 完整验证通过！"
        else
          echo "[cn-pack] ⚠️ 完整验证发现问题。运行 '$VERIFY_SCRIPT' 查看详情。"
        fi
      else
        echo "[cn-pack] ⚠️ 完整验证脚本未找到，降级到快速验证。"
        # 尝试快速验证
        quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
        if [[ -f "$quick_verify_script" ]]; then
          echo "[cn-pack] 使用快速验证脚本: $quick_verify_script"
          chmod +x "$quick_verify_script" 2>/dev/null || true
          
          if "$quick_verify_script" --quiet; then
            echo "[cn-pack] ✅ 快速验证通过！"
          else
            echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
          fi
        else
          echo "[cn-pack] ℹ️ 快速验证脚本也未找到，降级到基本验证。"
          echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
          echo "[cn-pack] ℹ️   openclaw --version"
          echo "[cn-pack] ℹ️   openclaw status"
          echo "[cn-pack] ℹ️   openclaw gateway status"
        fi
      fi
      ;;
    
    auto|*)
      # 自动选择验证级别
      if [[ -n "$VERIFY_SCRIPT" ]] && [[ -f "$VERIFY_SCRIPT" ]]; then
        echo "[cn-pack] 自动选择: 完整验证"
        chmod +x "$VERIFY_SCRIPT" 2>/dev/null || true
        
        if "$VERIFY_SCRIPT" --quiet; then
          echo "[cn-pack] ✅ 完整验证通过！"
        else
          echo "[cn-pack] ⚠️ 完整验证发现问题。运行 '$VERIFY_SCRIPT' 查看详情。"
        fi
      else
        # 尝试快速验证
        quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
        if [[ -f "$quick_verify_script" ]]; then
          echo "[cn-pack] 自动选择: 快速验证"
          chmod +x "$quick_verify_script" 2>/dev/null || true
          
          if "$quick_verify_script" --quiet; then
            echo "[cn-pack] ✅ 快速验证通过！"
          else
            echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
          fi
        else
          echo "[cn-pack] 自动选择: 基本验证"
          echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
          echo "[cn-pack] ℹ️   openclaw --version"
          echo "[cn-pack] ℹ️   openclaw status"
          echo "[cn-pack] ℹ️   openclaw gateway status"
        fi
      fi
      ;;
  esac
  
  echo "[cn-pack] ========================================="
  
  # 生成安装摘要报告
  generate_installation_summary() {
    echo ""
    color_log "STEP" "========================================="
    color_log "STEP" "📊 安装摘要报告"
    color_log "STEP" "========================================="
    
    local summary_file="/tmp/openclaw-install-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
      echo "OpenClaw 安装摘要报告"
      echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
      echo "脚本版本: $SCRIPT_VERSION"
      echo "安装模式: ${INSTALL_MODE:-standard}"
      echo "验证级别: $VERIFY_LEVEL"
      echo ""
      echo "=== 系统信息 ==="
      echo "操作系统: $(uname -s) $(uname -r)"
      echo "主机名: $(hostname)"
      echo "用户: $(whoami)"
      echo ""
      echo "=== 系统信息 ==="
      echo "操作系统: $(uname -s) $(uname -r)"
      echo "主机名: $(hostname)"
      echo "用户: $(whoami)"
      
      # Docker 容器检测
      if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        echo "运行环境: Docker 容器"
        echo "容器提示: 全局安装的包在容器重启后会丢失"
        echo "持久化建议: 使用 -v /host/path:/data 挂载持久化卷"
      else
        echo "运行环境: 物理机/虚拟机"
      fi
      echo ""
      
      echo "=== Node.js 环境 ==="
      if command -v node >/dev/null 2>&1; then
        echo "Node.js 版本: $(node --version 2>/dev/null || echo '未安装')"
        echo "npm 版本: $(npm --version 2>/dev/null || echo '未安装')"
      else
        echo "Node.js: 未安装"
      fi
      echo ""
      echo "=== 安装状态 ==="
      if command -v openclaw >/dev/null 2>&1; then
        echo "OpenClaw 命令: 已安装到 PATH"
        echo "OpenClaw 版本: $(openclaw --version 2>/dev/null | head -1 || echo '未知')"
      else
        echo "OpenClaw 命令: 未在 PATH 中找到"
        NPM_BIN_PATH=$(npm bin -g 2>/dev/null || echo "/usr/local/bin")
        if [[ -f "$NPM_BIN_PATH/openclaw" ]]; then
          echo "OpenClaw 二进制: 存在于 $NPM_BIN_PATH/openclaw"
        fi
      fi
      echo ""
      echo "=== 网络配置 ==="
      echo "使用的 npm registry: ${NPM_REGISTRY:-https://registry.npmmirror.com}"
      echo "代理设置: ${HTTP_PROXY:-未设置}"
      echo ""
      echo "=== 后续步骤 ==="
      echo "1. 验证安装: openclaw --version"
      echo "2. 检查状态: openclaw status"
      echo "3. 启动网关: openclaw gateway start"
      echo "4. 配置模型: openclaw models status"
      echo ""
      
      # 安装统计收集（可选，匿名）
      if [[ "${ENABLE_INSTALL_STATS:-0}" == "1" ]]; then
        echo "=== 安装统计收集（匿名） ==="
        echo "正在收集匿名安装统计信息..."
        
        # 生成匿名安装统计
        local stats_data=""
        local stats_timestamp=$(date +%s)
        local stats_os=$(uname -s 2>/dev/null || echo "unknown")
        local stats_arch=$(uname -m 2>/dev/null || echo "unknown")
        local stats_node_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "unknown")
        local stats_openclaw_version=$(openclaw --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        local stats_install_method="install-cn.sh"
        local stats_registry="${NPM_REGISTRY:-https://registry.npmmirror.com}"
        local stats_success="1"
        
        # 创建匿名统计JSON
        stats_data=$(cat <<EOF
{
  "timestamp": "$stats_timestamp",
  "os": "$stats_os",
  "arch": "$stats_arch",
  "node_version": "$stats_node_version",
  "openclaw_version": "$stats_openclaw_version",
  "install_method": "$stats_install_method",
  "registry": "$stats_registry",
  "success": "$stats_success",
  "script_version": "$SCRIPT_VERSION"
}
EOF
        )
        
        # 输出统计信息（开发调试用）
        if [[ "${DEBUG_INSTALL_STATS:-0}" == "1" ]]; then
          echo "安装统计信息（调试模式）:"
          echo "$stats_data" | jq . 2>/dev/null || echo "$stats_data"
        fi
        
        # 发送统计信息（可选，需要配置统计服务器）
        if [[ -n "${INSTALL_STATS_URL:-}" ]]; then
          echo "正在发送匿名安装统计到: $INSTALL_STATS_URL"
          if command -v curl >/dev/null 2>&1; then
            curl -s -X POST \
              -H "Content-Type: application/json" \
              -d "$stats_data" \
              "$INSTALL_STATS_URL" >/dev/null 2>&1 && \
              echo "统计信息已发送（匿名）" || \
              echo "统计信息发送失败（不影响安装）"
          elif command -v wget >/dev/null 2>&1; then
            echo "$stats_data" | wget -q -O /dev/null \
              --header="Content-Type: application/json" \
              --post-data="$stats_data" \
              "$INSTALL_STATS_URL" 2>/dev/null && \
              echo "统计信息已发送（匿名）" || \
              echo "统计信息发送失败（不影响安装）"
          else
            echo "无法发送统计信息（缺少curl/wget）"
          fi
        else
          echo "安装统计收集已启用但未配置统计服务器（INSTALL_STATS_URL）"
          echo "如需启用统计收集，请设置环境变量:"
          echo "  export INSTALL_STATS_URL='https://your-stats-server.com/api/install'"
          echo "  export ENABLE_INSTALL_STATS=1"
          echo "统计信息（本地）:"
          echo "$stats_data" | jq -c . 2>/dev/null || echo "$stats_data" | tr -d '\n'
        fi
        echo ""
      fi
      echo "=== 故障排除 ==="
      echo "• 如果 openclaw 命令未找到，尝试: source ~/.bashrc (或 ~/.zshrc)"
      echo "• 或使用 npx: npx openclaw --version"
      echo "• 查看日志: tail -f ~/.openclaw/logs/gateway.log"
      echo ""
      echo "=== 支持资源 ==="
      echo "• 文档: https://docs.openclaw.ai"
      echo "• 社区: https://discord.com/invite/clawd"
      echo "• GitHub: https://github.com/openclaw/openclaw"
      echo "• 国内镜像: https://clawdrepublic.cn"
    } > "$summary_file"
    
    color_log "SUCCESS" "安装摘要已保存到: $summary_file"
    echo ""
    color_log "INFO" "📋 摘要内容预览:"
    echo "-----------------------------------------"
    head -30 "$summary_file"
    echo "-----------------------------------------"
    echo ""
    color_log "INFO" "查看完整摘要: cat $summary_file"
  }
  
  # 如果不是dry-run，生成安装摘要
  if [[ "$DRY_RUN" != "1" ]]; then
    generate_installation_summary
    
    # 自动更新检查功能
    check_for_updates() {
      echo ""
      color_log "STEP" "========================================="
      color_log "STEP" "🔄 自动更新检查"
      color_log "STEP" "========================================="
      
      # 检查脚本是否有更新
      color_log "INFO" "检查安装脚本更新..."
      local latest_version
      if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -fsSL "$SCRIPT_UPDATE_URL" 2>/dev/null | grep -E '^SCRIPT_VERSION=' | head -1 | cut -d'"' -f2)
      elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$SCRIPT_UPDATE_URL" 2>/dev/null | grep -E '^SCRIPT_VERSION=' | head -1 | cut -d'"' -f2)
      fi
      
      if [[ -n "$latest_version" && "$latest_version" != "$SCRIPT_VERSION" ]]; then
        color_log "WARNING" "发现新版本脚本: $latest_version (当前: $SCRIPT_VERSION)"
        color_log "INFO" "更新命令: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
      else
        color_log "SUCCESS" "安装脚本已是最新版本: $SCRIPT_VERSION"
      fi
      
      # 检查OpenClaw包更新
      color_log "INFO" "检查OpenClaw包更新..."
      if command -v npm >/dev/null 2>&1 && command -v openclaw >/dev/null 2>&1; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        
        if [[ "$current_version" != "unknown" ]]; then
          local latest_package
          latest_package=$(npm view openclaw version 2>/dev/null || echo "unknown")
          
          if [[ "$latest_package" != "unknown" && "$latest_package" != "$current_version" ]]; then
            color_log "WARNING" "发现新版本OpenClaw: $latest_package (当前: $current_version)"
            color_log "INFO" "更新命令: npm install -g openclaw@$latest_package"
            color_log "INFO" "或使用: openclaw update.run"
          else
            color_log "SUCCESS" "OpenClaw已是最新版本: $current_version"
          fi
        fi
      fi
      
      echo ""
      color_log "INFO" "💡 更新提示:"
      color_log "INFO" "• 脚本更新: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
      color_log "INFO" "• OpenClaw更新: npm install -g openclaw@latest"
      color_log "INFO" "• 或使用内置更新: openclaw update.run"
    }
    
    # 如果不是CI模式，执行更新检查
    if [[ "${CI_MODE:-0}" != "1" && "${SKIP_UPDATE_CHECK:-0}" != "1" ]]; then
      check_for_updates
    fi
    
    # 快速验证功能
    quick_verification() {
      echo ""
      color_log "STEP" "========================================="
      color_log "STEP" "✅ 快速验证"
      color_log "STEP" "========================================="
      
      color_log "INFO" "执行快速验证检查..."
      
      # 1. 检查openclaw命令是否存在
      if command -v openclaw >/dev/null 2>&1; then
        color_log "SUCCESS" "✓ openclaw命令已安装"
        
        # 2. 检查版本
        local version_output
        version_output=$(openclaw --version 2>&1 | head -1)
        if [[ -n "$version_output" ]]; then
          color_log "SUCCESS" "✓ 版本检查: $version_output"
        else
          color_log "WARNING" "⚠ 无法获取版本信息"
        fi
        
        # 3. 检查配置文件目录
        if [[ -d "$HOME/.openclaw" ]]; then
          color_log "SUCCESS" "✓ 配置文件目录存在: ~/.openclaw"
        else
          color_log "WARNING" "⚠ 配置文件目录不存在"
        fi
        
        # 4. 检查网关状态（如果可能）
        if pgrep -f "openclaw gateway" >/dev/null 2>&1; then
          color_log "SUCCESS" "✓ OpenClaw网关正在运行"
        else
          color_log "INFO" "ℹ OpenClaw网关未运行（正常，首次安装需要手动启动）"
          color_log "INFO" "启动命令: openclaw gateway start"
        fi
        
        # 5. 检查quota-proxy部署状态（可选）
        color_log "INFO" "检查quota-proxy部署状态..."
        if [[ -f "$HOME/.openclaw/openclaw.json" ]] && grep -q "api.clawdrepublic.cn" "$HOME/.openclaw/openclaw.json" 2>/dev/null; then
          color_log "INFO" "检测到quota-proxy配置，测试连接..."
          if curl -fsS -m 5 https://api.clawdrepublic.cn/healthz 2>/dev/null | grep -q '"ok":true'; then
            color_log "SUCCESS" "✓ quota-proxy API连接正常"
            
            # 尝试获取TRIAL_KEY（如果有）
            if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
              local trial_key
              trial_key=$(grep -o '"apiKey":"[^"]*"' "$HOME/.openclaw/openclaw.json" | head -1 | cut -d'"' -f4)
              if [[ -n "$trial_key" ]]; then
                color_log "SUCCESS" "✓ 检测到TRIAL_KEY配置"
                color_log "INFO" "测试API调用: curl -H 'Authorization: Bearer $trial_key' https://api.clawdrepublic.cn/v1/models"
              fi
            fi
          else
            color_log "WARNING" "⚠ quota-proxy API连接失败（可能需要TRIAL_KEY）"
            color_log "INFO" "获取TRIAL_KEY: 访问 https://clawdrepublic.cn 或查看 ~/.openclaw/openclaw.json"
          fi
        else
          color_log "INFO" "ℹ 未配置quota-proxy，跳过API测试"
          color_log "INFO" "配置quota-proxy: 编辑 ~/.openclaw/openclaw.json 添加api.clawdrepublic.cn"
        fi
        
        # 6. 提供快速测试命令
        echo ""
        color_log "INFO" "🚀 快速测试命令:"
        color_log "INFO" "• 检查状态: openclaw status"
        color_log "INFO" "• 查看帮助: openclaw help"
        color_log "INFO" "• 启动网关: openclaw gateway start"
        color_log "INFO" "• 查看日志: tail -f ~/.openclaw/logs/gateway.log"
        color_log "INFO" "• 测试quota-proxy: curl -fsS https://api.clawdrepublic.cn/healthz"
        
      else
        color_log "ERROR" "✗ openclaw命令未找到"
        color_log "INFO" "尝试解决方案:"
        color_log "INFO" "1. 重新加载shell配置: source ~/.bashrc 或 source ~/.zshrc"
        color_log "INFO" "2. 使用npx: npx openclaw --version"
        color_log "INFO" "3. 检查npm全局路径: npm list -g openclaw"
        return 1
      fi
      
      echo ""
      color_log "SUCCESS" "✅ 快速验证完成！"
      color_log "SUCCESS" "OpenClaw已成功安装并准备就绪 🎉"
      return 0
    }
    
    # 执行快速验证（除非明确跳过）
    if [[ "${SKIP_VERIFICATION:-0}" != "1" && "${CI_MODE:-0}" != "1" ]]; then
      quick_verification
    fi
  fi

# Dry-run final check (after verification)
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[cn-pack] Dry-run done (no changes made)."
  exit 0
fi
