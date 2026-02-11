#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装脚本快速验证工具
# 快速验证 install-cn.sh 脚本的基本功能和完整性

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-cn.sh"

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
  if "$INSTALL_SCRIPT" --help 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "用法:"; then
    color_log "SUCCESS" "✓ install-cn.sh 帮助功能正常"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 帮助功能异常"
    return 1
  fi
}

# 检查脚本头部信息
check_script_header() {
  color_log "INFO" "检查安装脚本头部信息..."
  # 检查脚本是否包含必要的头部信息
  if head -20 "$INSTALL_SCRIPT" | grep -q "OpenClaw CN quick install"; then
    color_log "SUCCESS" "✓ install-cn.sh 头部信息完整"
    return 0
  else
    color_log "ERROR" "✗ install-cn.sh 头部信息不完整"
    return 1
  fi
}

# 主函数
main() {
  color_log "INFO" "开始验证 OpenClaw CN 安装脚本..."
  echo "========================================"
  
  local total_checks=0
  local passed_checks=0
  
  # 执行检查
  for check_func in check_script_exists check_script_permissions check_script_syntax check_help_function check_script_header; do
    ((total_checks++))
    if $check_func; then
      ((passed_checks++))
    fi
    echo ""
  done
  
  # 输出总结
  echo "========================================"
  color_log "INFO" "验证完成: $passed_checks/$total_checks 项通过"
  
  if [[ $passed_checks -eq $total_checks ]]; then
    color_log "SUCCESS" "✅ OpenClaw CN 安装脚本验证通过"
    echo ""
    color_log "INFO" "快速使用命令:"
    echo "  # 一键安装"
    echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
    echo ""
    echo "  # 下载后安装"
    echo "  bash scripts/install-cn.sh"
    return 0
  else
    color_log "ERROR" "❌ OpenClaw CN 安装脚本验证失败"
    echo ""
    color_log "INFO" "请检查 scripts/install-cn.sh 文件"
    return 1
  fi
}

# 运行主函数
main "$@"
