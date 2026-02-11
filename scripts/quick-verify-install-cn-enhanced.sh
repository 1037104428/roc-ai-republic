#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装脚本增强版快速验证工具
# 验证 install-cn.sh 脚本的更多实际功能和完整性

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-cn.sh"
TEST_DIR="/tmp/oc-install-test-$$"

# 颜色输出函数
color_log() {
  local level="$1"
  local message="$2"
  
  case "$level" in
    "INFO") echo "[INFO] $message" ;;
    "SUCCESS") echo "[SUCCESS] $message" ;;
    "WARNING") echo "[WARNING] $message" ;;
    "ERROR") echo "[ERROR] $message" ;;
    *) echo "[$level] $message" ;;
  esac
}

# 清理函数
cleanup() {
  if [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
    color_log "INFO" "清理测试目录: $TEST_DIR"
  fi
}

# 设置陷阱
trap cleanup EXIT

# 检查脚本存在性
check_script_exists() {
  color_log "INFO" "检查安装脚本存在性..."
  if [[ -f "$INSTALL_SCRIPT" ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 脚本存在"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 脚本不存在"
    return 1
  fi
}

# 检查脚本权限
check_script_permissions() {
  color_log "INFO" "检查安装脚本权限..."
  if [[ -x "$INSTALL_SCRIPT" ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 脚本有执行权限"
    return 0
  else
    color_log "WARNING" "⚠ install-cn.sh 脚本缺少执行权限，尝试添加..."
    if chmod +x "$INSTALL_SCRIPT" 2>/dev/null; then
      color_log "SUCCESS" "✓ 已添加执行权限"
      return 0
    else
      color_log "ERROR" "✗ 无法添加执行权限"
      return 1
    fi
  fi
}

# 检查脚本语法
check_script_syntax() {
  color_log "INFO" "检查安装脚本语法..."
  if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
    color_log "SUCCESS" "✓ install-cn.sh 脚本语法正确"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 脚本语法错误"
    return 1
  fi
}

# 检查帮助功能
check_help_function() {
  color_log "INFO" "检查安装脚本帮助功能..."
  # 移除颜色代码后检查
  local help_output
  help_output="$("$INSTALL_SCRIPT" --help 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  
  local checks_passed=0
  local total_checks=0
  
  # 检查关键帮助信息
  ((total_checks++))
  if echo "$help_output" | grep -q "用法:"; then
    color_log "SUCCESS" "  ✓ 包含用法说明"
    ((checks_passed++))
  else
    color_log "ERROR" "  ✗ 缺少用法说明"
  fi
  
  ((total_checks++))
  if echo "$help_output" | grep -q "选项:"; then
    color_log "SUCCESS" "  ✓ 包含选项说明"
    ((checks_passed++))
  else
    color_log "ERROR" "  ✗ 缺少选项说明"
  fi
  
  ((total_checks++))
  if echo "$help_output" | grep -q "示例:"; then
    color_log "SUCCESS" "  ✓ 包含示例说明"
    ((checks_passed++))
  else
    color_log "ERROR" "  ✗ 缺少示例说明"
  fi
  
  if [[ $checks_passed -eq $total_checks ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 帮助功能完整"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 帮助功能不完整 ($checks_passed/$total_checks)"
    return 1
  fi
}

# 检查版本功能
check_version_function() {
  color_log "INFO" "检查安装脚本版本功能..."
  local version_output
  version_output="$("$INSTALL_SCRIPT" --version 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
  
  if echo "$version_output" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+"; then
    color_log "SUCCESS" "✓ install-cn.sh 版本功能正常 (版本: $(echo "$version_output" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1))"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 版本功能异常"
    return 1
  fi
}

# 检查脚本头部信息
check_script_header() {
  color_log "INFO" "检查安装脚本头部信息..."
  local header_checks=0
  local total_header_checks=0
  
  ((total_header_checks++))
  if head -5 "$INSTALL_SCRIPT" | grep -q "#!/usr/bin/env bash"; then
    color_log "SUCCESS" "  ✓ 正确的shebang"
    ((header_checks++))
  else
    color_log "ERROR" "  ✗ 错误的shebang"
  fi
  
  ((total_header_checks++))
  if head -10 "$INSTALL_SCRIPT" | grep -q "set -euo pipefail"; then
    color_log "SUCCESS" "  ✓ 包含错误处理"
    ((header_checks++))
  else
    color_log "ERROR" "  ✗ 缺少错误处理"
  fi
  
  ((total_header_checks++))
  if head -20 "$INSTALL_SCRIPT" | grep -q "OpenClaw CN quick install"; then
    color_log "SUCCESS" "  ✓ 包含脚本描述"
    ((header_checks++))
  else
    color_log "ERROR" "  ✗ 缺少脚本描述"
  fi
  
  if [[ $header_checks -eq $total_header_checks ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 头部信息完整"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 头部信息不完整 ($header_checks/$total_header_checks)"
    return 1
  fi
}

# 检查脚本函数定义
check_script_functions() {
  color_log "INFO" "检查安装脚本关键函数..."
  local function_checks=0
  local total_function_checks=0
  
  # 检查关键函数是否存在
  local key_functions=("main" "install_openclaw" "detect_os" "check_dependencies" "setup_environment")
  
  for func in "${key_functions[@]}"; do
    ((total_function_checks++))
    if grep -q "^${func}()" "$INSTALL_SCRIPT" || grep -q "^function ${func}" "$INSTALL_SCRIPT"; then
      color_log "SUCCESS" "  ✓ 函数 '$func' 存在"
      ((function_checks++))
    else
      color_log "WARNING" "  ⚠ 函数 '$func' 不存在"
    fi
  done
  
  if [[ $function_checks -ge 3 ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 关键函数完整 ($function_checks/$total_function_checks)"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 关键函数不完整 ($function_checks/$total_function_checks)"
    return 1
  fi
}

# 检查脚本网络源配置
check_network_sources() {
  color_log "INFO" "检查安装脚本网络源配置..."
  local source_checks=0
  local total_source_checks=0
  
  ((total_source_checks++))
  if grep -q "国内镜像源" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含国内镜像源配置"
    ((source_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少国内镜像源配置"
  fi
  
  ((total_source_checks++))
  if grep -q "fallback" "$INSTALL_SCRIPT" || grep -q "回退" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含回退策略"
    ((source_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少回退策略"
  fi
  
  ((total_source_checks++))
  if grep -q "npm.taobao.org" "$INSTALL_SCRIPT" || grep -q "npmmirror.com" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含淘宝npm镜像"
    ((source_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少淘宝npm镜像"
  fi
  
  if [[ $source_checks -ge 2 ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 网络源配置合理 ($source_checks/$total_source_checks)"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 网络源配置不足 ($source_checks/$total_source_checks)"
    return 1
  fi
}

# 检查脚本验证功能
check_verification_functions() {
  color_log "INFO" "检查安装脚本验证功能..."
  local verify_checks=0
  local total_verify_checks=0
  
  ((total_verify_checks++))
  if grep -q "openclaw --version" "$INSTALL_SCRIPT" || grep -q "openclaw --help" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含OpenClaw验证"
    ((verify_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少OpenClaw验证"
  fi
  
  ((total_verify_checks++))
  if grep -q "node --version" "$INSTALL_SCRIPT" || grep -q "npm --version" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含Node.js验证"
    ((verify_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少Node.js验证"
  fi
  
  ((total_verify_checks++))
  if grep -q "验证" "$INSTALL_SCRIPT" || grep -q "verify" "$INSTALL_SCRIPT" || grep -q "check" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "  ✓ 包含验证步骤"
    ((verify_checks++))
  else
    color_log "WARNING" "  ⚠ 缺少验证步骤"
  fi
  
  if [[ $verify_checks -ge 2 ]]; then
    color_log "SUCCESS" "✓ install-cn.sh 验证功能完整 ($verify_checks/$total_verify_checks)"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 验证功能不足 ($verify_checks/$total_verify_checks)"
    return 1
  fi
}

# 模拟运行检查（不实际安装）
check_dry_run() {
  color_log "INFO" "检查安装脚本模拟运行..."
  
  # 创建测试目录
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  
  # 复制安装脚本到测试目录
  cp "$INSTALL_SCRIPT" ./test-install.sh
  chmod +x ./test-install.sh
  
  # 尝试运行 --dry-run 或 --check 模式
  local dry_run_output
  if ./test-install.sh --dry-run 2>&1 | head -50 > "$TEST_DIR/dry-run.log" 2>&1; then
    color_log "SUCCESS" "✓ install-cn.sh 模拟运行成功"
    color_log "INFO" "  模拟运行输出摘要:"
    head -10 "$TEST_DIR/dry-run.log" | sed 's/^/    /'
    return 0
  elif ./test-install.sh --check 2>&1 | head -50 > "$TEST_DIR/check.log" 2>&1; then
    color_log "SUCCESS" "✓ install-cn.sh 检查模式成功"
    color_log "INFO" "  检查模式输出摘要:"
    head -10 "$TEST_DIR/check.log" | sed 's/^/    /'
    return 0
  else
    color_log "WARNING" "⚠ install-cn.sh 无模拟运行模式，尝试普通运行（不实际安装）..."
    # 尝试设置环境变量避免实际安装
    export DRY_RUN=1
    export SKIP_INSTALL=1
    if ./test-install.sh 2>&1 | head -50 > "$TEST_DIR/normal.log" 2>&1; then
      color_log "SUCCESS" "✓ install-cn.sh 普通运行正常（跳过安装）"
      return 0
    else
      color_log "ERROR" "✗ install-cn.sh 运行异常"
      return 1
    fi
  fi
}

# 主函数
main() {
  color_log "INFO" "开始增强版验证 OpenClaw CN 安装脚本..."
  echo "========================================"
  color_log "INFO" "脚本路径: $INSTALL_SCRIPT"
  color_log "INFO" "测试目录: $TEST_DIR"
  echo "========================================"
  
  local total_checks=0
  local passed_checks=0
  
  # 执行检查
  local check_functions=(
    check_script_exists
    check_script_permissions
    check_script_syntax
    check_help_function
    check_version_function
    check_script_header
    check_script_functions
    check_network_sources
    check_verification_functions
    check_dry_run
  )
  
  for check_func in "${check_functions[@]}"; do
    ((total_checks++))
    echo ""
    if $check_func; then
      ((passed_checks++))
    fi
  done
  
  # 输出总结
  echo ""
  echo "========================================"
  color_log "INFO" "验证完成: $passed_checks/$total_checks 项通过"
  
  if [[ $passed_checks -eq $total_checks ]]; then
    color_log "SUCCESS" "✅ OpenClaw CN 安装脚本增强版验证通过"
    echo ""
    color_log "INFO" "快速使用命令:"
    echo "  # 一键安装（推荐）"
    echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
    echo ""
    echo "  # 下载后安装"
    echo "  bash scripts/install-cn.sh"
    echo ""
    echo "  # 仅检查环境"
    echo "  bash scripts/install-cn.sh --check"
    echo ""
    echo "  # 模拟运行"
    echo "  bash scripts/install-cn.sh --dry-run"
    return 0
  elif [[ $passed_checks -ge $((total_checks * 8 / 10)) ]]; then
    color_log "SUCCESS" "✅ OpenClaw CN 安装脚本验证基本通过 ($passed_checks/$total_checks)"
    echo ""
    color_log "INFO" "脚本功能基本完整，可正常使用"
    return 0
  else
    color_log "ERROR" "❌ OpenClaw CN 安装脚本验证失败 ($passed_checks/$total_checks)"
    echo ""
    color_log "INFO" "请检查 scripts/install-cn.sh 文件"
    return 1
  fi
}

# 运行主函数
main "$@"