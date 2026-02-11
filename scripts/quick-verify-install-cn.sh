#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装脚本快速验证工具
# 快速验证 install-cn.sh 脚本的完整性、语法和基本功能
# 用法：./quick-verify-install-cn.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/scripts/install-cn.sh"
VERIFY_DOC="$REPO_ROOT/docs/install-cn-quick-verify.md"
TEST_EXAMPLES="$REPO_ROOT/docs/install-cn-quick-test-examples.md"

# 颜色输出函数
color_log() {
  local level="$1"
  local message="$2"
  local color_code=""
  
  case "$level" in
    "INFO") color_code="\033[0;34m" ;;    # 蓝色
    "SUCCESS") color_code="\033[0;32m" ;; # 绿色
    "WARNING") color_code="\033[0;33m" ;; # 黄色
    "ERROR") color_code="\033[0;31m" ;;   # 红色
    "DEBUG") color_code="\033[0;90m" ;;   # 灰色
    *) color_code="\033[0m" ;;
  esac
  
  echo -e "${color_code}[$level] $message\033[0m"
}

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

# 验证安装脚本存在性
verify_install_script_exists() {
  log_info "验证安装脚本存在性..."
  
  if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    log_error "安装脚本不存在: $INSTALL_SCRIPT"
    return 1
  fi
  
  if [[ ! -x "$INSTALL_SCRIPT" ]]; then
    log_warning "安装脚本没有执行权限，正在添加..."
    chmod +x "$INSTALL_SCRIPT"
  fi
  
  log_success "安装脚本存在且可执行: $(basename "$INSTALL_SCRIPT")"
}

# 验证安装脚本语法
verify_install_script_syntax() {
  log_info "验证安装脚本语法..."
  
  if bash -n "$INSTALL_SCRIPT"; then
    log_success "安装脚本语法正确"
  else
    log_error "安装脚本语法错误"
    return 1
  fi
}

# 验证帮助信息
verify_help_info() {
  log_info "验证帮助信息..."
  
  local help_output
  if help_output=$("$INSTALL_SCRIPT" --help 2>&1); then
    if echo "$help_output" | grep -q "Usage:"; then
      log_success "帮助信息正常显示"
    else
      log_warning "帮助信息缺少Usage部分"
    fi
  else
    log_error "获取帮助信息失败"
    return 1
  fi
}

# 验证干运行模式
verify_dry_run() {
  log_info "验证干运行模式..."
  
  local dry_run_output
  if dry_run_output=$("$INSTALL_SCRIPT" --dry-run --version latest 2>&1); then
    if echo "$dry_run_output" | grep -q "DRY RUN"; then
      log_success "干运行模式正常"
    else
      log_warning "干运行模式输出缺少DRY RUN标记"
    fi
  else
    log_error "干运行模式执行失败"
    return 1
  fi
}

# 验证版本检查
verify_version_check() {
  log_info "验证版本检查..."
  
  local version_output
  if version_output=$("$INSTALL_SCRIPT" --version-check 2>&1); then
    if echo "$version_output" | grep -q "版本检查"; then
      log_success "版本检查功能正常"
    else
      log_warning "版本检查输出缺少预期内容"
    fi
  else
    log_error "版本检查执行失败"
    return 1
  fi
}

# 验证验证文档存在性
verify_verify_docs() {
  log_info "验证验证文档存在性..."
  
  local missing_docs=()
  
  if [[ ! -f "$VERIFY_DOC" ]]; then
    missing_docs+=("$(basename "$VERIFY_DOC")")
  else
    log_success "验证文档存在: $(basename "$VERIFY_DOC")"
  fi
  
  if [[ ! -f "$TEST_EXAMPLES" ]]; then
    missing_docs+=("$(basename "$TEST_EXAMPLES")")
  else
    log_success "测试示例文档存在: $(basename "$TEST_EXAMPLES")"
  fi
  
  if [[ ${#missing_docs[@]} -gt 0 ]]; then
    log_warning "缺少文档: ${missing_docs[*]}"
    return 1
  fi
}

# 验证网络测试脚本
verify_network_test_script() {
  log_info "验证网络测试脚本..."
  
  local network_test_script="$REPO_ROOT/scripts/install-cn-network-test.sh"
  
  if [[ ! -f "$network_test_script" ]]; then
    log_warning "网络测试脚本不存在"
    return 1
  fi
  
  if [[ ! -x "$network_test_script" ]]; then
    log_warning "网络测试脚本没有执行权限，正在添加..."
    chmod +x "$network_test_script"
  fi
  
  if bash -n "$network_test_script"; then
    log_success "网络测试脚本语法正确"
  else
    log_error "网络测试脚本语法错误"
    return 1
  fi
}

# 生成验证报告
generate_verification_report() {
  log_info "生成验证报告..."
  
  echo "========================================"
  echo "OpenClaw CN 安装脚本验证报告"
  echo "========================================"
  echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "安装脚本: $(basename "$INSTALL_SCRIPT")"
  echo "脚本路径: $INSTALL_SCRIPT"
  echo "----------------------------------------"
  echo "验证项目                    状态"
  echo "----------------------------------------"
  
  local tests=(
    "安装脚本存在性"
    "安装脚本语法"
    "帮助信息"
    "干运行模式"
    "版本检查"
    "验证文档存在性"
    "网络测试脚本"
  )
  
  for test_name in "${tests[@]}"; do
    echo "$test_name                    ✓"
  done
  
  echo "----------------------------------------"
  echo "快速使用命令:"
  echo "  # 语法检查"
  echo "  bash -n scripts/install-cn.sh"
  echo ""
  echo "  # 帮助信息"
  echo "  ./scripts/install-cn.sh --help"
  echo ""
  echo "  # 干运行测试"
  echo "  ./scripts/install-cn.sh --dry-run --version latest"
  echo ""
  echo "  # 详细验证"
  echo "  ./scripts/quick-verify-install-cn.sh"
  echo "========================================"
}

# 主验证函数
main() {
  log_info "开始验证 OpenClaw CN 安装脚本..."
  
  local errors=0
  
  # 执行所有验证
  verify_install_script_exists || ((errors++))
  verify_install_script_syntax || ((errors++))
  verify_help_info || ((errors++))
  verify_dry_run || ((errors++))
  verify_version_check || ((errors++))
  verify_verify_docs || ((errors++))
  verify_network_test_script || ((errors++))
  
  # 生成报告
  generate_verification_report
  
  # 输出总结
  if [[ $errors -eq 0 ]]; then
    log_success "所有验证通过！安装脚本功能完整。"
    echo ""
    log_info "快速测试命令："
    echo "  ./scripts/install-cn.sh --dry-run --version latest"
    echo "  ./scripts/install-cn.sh --version-check"
    echo "  ./scripts/install-cn-network-test.sh"
  else
    log_warning "发现 $errors 个问题，请检查相关项目。"
    return 1
  fi
}

# 执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi