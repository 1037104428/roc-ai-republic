#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装自检脚本
# 在安装完成后自动验证安装是否成功
# 特性：
# - 验证 openclaw --version 命令可用
# - 验证 openclaw --help 命令可用
# - 验证配置文件目录存在
# - 验证核心功能可用性
# - 生成安装验证报告

# 颜色输出函数
color_log() {
  local level="$1"
  local message="$2"
  local color_code=""
  
  case "$level" in
    "INFO") color_code="\033[0;36m" ;;    # 青色
    "SUCCESS") color_code="\033[0;32m" ;; # 绿色
    "WARNING") color_code="\033[0;33m" ;; # 黄色
    "ERROR") color_code="\033[0;31m" ;;   # 红色
    "DEBUG") color_code="\033[0;90m" ;;   # 灰色
    *) color_code="\033[0m" ;;            # 默认
  esac
  
  echo -e "${color_code}[${level}] ${message}\033[0m"
}

# 主验证函数
verify_openclaw_installation() {
  local expected_version="${1:-}"
  local check_passed=0
  local check_total=0
  local verification_report=""
  
  # 支持快速验证模式（仅检查核心功能）
  local quick_mode="${QUICK_MODE:-0}"
  if [[ "$quick_mode" == "1" || "$quick_mode" == "true" ]]; then
    color_log "INFO" "快速验证模式已启用（仅检查核心功能）"
  fi
  
  color_log "INFO" "开始验证 OpenClaw 安装..."
  color_log "INFO" "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  color_log "INFO" "系统: $(uname -s) $(uname -r)"
  color_log "INFO" "用户: $(whoami)"
  
  # 检查 1: openclaw 命令是否存在
  check_total=$((check_total + 1))
  if command -v openclaw > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ openclaw 命令已安装"
    check_passed=$((check_passed + 1))
    verification_report+="✅ openclaw 命令已安装\n"
  else
    color_log "ERROR" "❌ openclaw 命令未找到"
    verification_report+="❌ openclaw 命令未找到\n"
    return 1
  fi
  
  # 检查 2: 获取版本
  check_total=$((check_total + 1))
  local version_output
  if version_output=$(openclaw --version 2>&1); then
    color_log "SUCCESS" "✅ OpenClaw 版本: $version_output"
    check_passed=$((check_passed + 1))
    verification_report+="✅ OpenClaw 版本: $version_output\n"
    
    # 版本匹配检查
    if [[ -n "$expected_version" ]] && [[ "$expected_version" != "latest" ]]; then
      check_total=$((check_total + 1))
      if [[ "$version_output" == *"$expected_version"* ]]; then
        color_log "SUCCESS" "✅ 版本验证通过: 期望 $expected_version，实际 $version_output"
        check_passed=$((check_passed + 1))
        verification_report+="✅ 版本验证通过: 期望 $expected_version，实际 $version_output\n"
      else
        color_log "WARNING" "⚠️ 版本不匹配: 期望 $expected_version，实际 $version_output"
        verification_report+="⚠️ 版本不匹配: 期望 $expected_version，实际 $version_output\n"
      fi
    fi
  else
    color_log "ERROR" "❌ 无法获取 OpenClaw 版本: $version_output"
    verification_report+="❌ 无法获取 OpenClaw 版本: $version_output\n"
    return 1
  fi
  
  # 检查 3: 帮助命令
  check_total=$((check_total + 1))
  if openclaw --help > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ openclaw --help 命令可用"
    check_passed=$((check_passed + 1))
    verification_report+="✅ openclaw --help 命令可用\n"
  else
    color_log "ERROR" "❌ openclaw --help 命令失败"
    verification_report+="❌ openclaw --help 命令失败\n"
  fi
  
  # 检查 4: 配置文件目录
  check_total=$((check_total + 1))
  local config_dir="${HOME}/.openclaw"
  if [[ -d "$config_dir" ]]; then
    color_log "SUCCESS" "✅ 配置文件目录存在: $config_dir"
    check_passed=$((check_passed + 1))
    verification_report+="✅ 配置文件目录存在: $config_dir\n"
    
    # 检查配置文件
    local config_file="${config_dir}/config.json"
    if [[ -f "$config_file" ]]; then
      color_log "SUCCESS" "✅ 配置文件存在: $config_file"
      verification_report+="✅ 配置文件存在: $config_file\n"
    else
      color_log "WARNING" "⚠️ 配置文件不存在: $config_file (可能需要首次运行配置)"
      verification_report+="⚠️ 配置文件不存在: $config_file\n"
    fi
  else
    color_log "WARNING" "⚠️ 配置文件目录不存在: $config_dir"
    verification_report+="⚠️ 配置文件目录不存在: $config_dir\n"
  fi
  
  # 检查 5: 工作空间目录
  check_total=$((check_total + 1))
  local workspace_dir="${HOME}/.openclaw/workspace"
  if [[ -d "$workspace_dir" ]]; then
    color_log "SUCCESS" "✅ 工作空间目录存在: $workspace_dir"
    check_passed=$((check_passed + 1))
    verification_report+="✅ 工作空间目录存在: $workspace_dir\n"
  else
    color_log "WARNING" "⚠️ 工作空间目录不存在: $workspace_dir (可能需要首次运行初始化)"
    verification_report+="⚠️ 工作空间目录不存在: $workspace_dir\n"
  fi
  
  # 检查 6: 状态命令
  check_total=$((check_total + 1))
  if openclaw status > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ openclaw status 命令可用"
    check_passed=$((check_passed + 1))
    verification_report+="✅ openclaw status 命令可用\n"
  else
    color_log "WARNING" "⚠️ openclaw status 命令失败 (可能需要首次配置)"
    verification_report+="⚠️ openclaw status 命令失败\n"
  fi
  
  # 检查 7: Node.js 版本兼容性
  check_total=$((check_total + 1))
  local node_version
  node_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "0.0.0")
  local node_major
  node_major=$(echo "$node_version" | cut -d. -f1)
  
  if [[ "$node_major" -ge 18 ]]; then
    color_log "SUCCESS" "✅ Node.js 版本兼容: $node_version (需要 18+)"
    check_passed=$((check_passed + 1))
    verification_report+="✅ Node.js 版本兼容: $node_version (需要 18+)\n"
  else
    color_log "WARNING" "⚠️ Node.js 版本可能不兼容: $node_version (需要 18+)"
    verification_report+="⚠️ Node.js 版本可能不兼容: $node_version (需要 18+)\n"
  fi
  
  # 检查 8: npm 版本兼容性
  check_total=$((check_total + 1))
  local npm_version
  npm_version=$(npm --version 2>/dev/null || echo "0.0.0")
  local npm_major
  npm_major=$(echo "$npm_version" | cut -d. -f1)
  
  if [[ "$npm_major" -ge 8 ]]; then
    color_log "SUCCESS" "✅ npm 版本兼容: $npm_version (需要 8+)"
    check_passed=$((check_passed + 1))
    verification_report+="✅ npm 版本兼容: $npm_version (需要 8+)\n"
  else
    color_log "WARNING" "⚠️ npm 版本可能不兼容: $npm_version (需要 8+)"
    verification_report+="⚠️ npm 版本可能不兼容: $npm_version (需要 8+)\n"
  fi
  
  # 总结报告
  local success_rate=0
  if [[ $check_total -gt 0 ]]; then
    success_rate=$((check_passed * 100 / check_total))
  fi
  
  color_log "INFO" "="*60
  color_log "INFO" "安装验证完成"
  color_log "INFO" "检查总数: $check_total"
  color_log "INFO" "通过检查: $check_passed"
  color_log "INFO" "成功率: $success_rate%"
  
  if [[ $success_rate -ge 80 ]]; then
    color_log "SUCCESS" "✅ 安装验证通过！OpenClaw 已成功安装。"
    verification_report+="\n✅ 安装验证通过！成功率: $success_rate%\n"
  elif [[ $success_rate -ge 50 ]]; then
    color_log "WARNING" "⚠️ 安装验证警告：部分检查未通过，但核心功能可用。"
    verification_report+="\n⚠️ 安装验证警告：成功率: $success_rate%\n"
  else
    color_log "ERROR" "❌ 安装验证失败：多个检查未通过，请检查安装日志。"
    verification_report+="\n❌ 安装验证失败：成功率: $success_rate%\n"
    return 1
  fi
  
  # 输出详细报告
  color_log "INFO" "="*60
  color_log "INFO" "详细验证报告："
  echo -e "$verification_report"
  
  # 保存报告到文件
  local report_file="/tmp/openclaw-install-verification-$(date +%Y%m%d-%H%M%S).txt"
  echo -e "OpenClaw 安装验证报告" > "$report_file"
  echo -e "生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$report_file"
  echo -e "系统: $(uname -s) $(uname -r)" >> "$report_file"
  echo -e "用户: $(whoami)" >> "$report_file"
  echo -e "检查总数: $check_total" >> "$report_file"
  echo -e "通过检查: $check_passed" >> "$report_file"
  echo -e "成功率: $success_rate%" >> "$report_file"
  echo -e "\n详细结果：" >> "$report_file"
  echo -e "$verification_report" >> "$report_file"
  
  color_log "INFO" "验证报告已保存到: $report_file"
  
  return 0
}

# 快速验证模式（仅检查核心功能）
quick_verify() {
  color_log "INFO" "快速验证模式..."
  
  # 检查命令是否存在
  if ! command -v openclaw > /dev/null 2>&1; then
    color_log "ERROR" "❌ openclaw 命令未找到"
    return 1
  fi
  
  # 检查版本
  if ! version_output=$(openclaw --version 2>&1); then
    color_log "ERROR" "❌ 无法获取 OpenClaw 版本"
    return 1
  fi
  
  color_log "SUCCESS" "✅ OpenClaw 已安装: $version_output"
  color_log "SUCCESS" "✅ 快速验证通过！"
  
  return 0
}

# 主函数
main() {
  local mode="full"
  local expected_version=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quick|-q)
        mode="quick"
        shift
        ;;
      --version|-v)
        if [[ -n "${2:-}" ]]; then
          expected_version="$2"
          shift 2
        else
          color_log "ERROR" "❌ --version 参数需要指定版本号"
          exit 1
        fi
        ;;
      --help|-h)
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --quick, -q     快速验证模式（仅检查核心功能）"
        echo "  --version, -v   期望的版本号（用于版本匹配检查）"
        echo "  --help, -h      显示此帮助信息"
        exit 0
        ;;
      *)
        color_log "ERROR" "❌ 未知参数: $1"
        echo "使用 --help 查看用法"
        exit 1
        ;;
    esac
  done
  
  case "$mode" in
    "quick")
      quick_verify
      ;;
    "full")
      verify_openclaw_installation "$expected_version"
      ;;
  esac
}

# 快速验证函数（仅检查核心功能）
quick_verify() {
  color_log "INFO" "🚀 开始快速验证模式..."
  color_log "INFO" "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  
  local checks_passed=0
  local checks_total=0
  local quick_report="📋 快速验证报告:\n"
  
  # 检查 1: openclaw 命令是否存在
  checks_total=$((checks_total + 1))
  if command -v openclaw > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ openclaw 命令已安装"
    checks_passed=$((checks_passed + 1))
    quick_report+="✅ openclaw 命令已安装\n"
  else
    color_log "ERROR" "❌ openclaw 命令未找到"
    quick_report+="❌ openclaw 命令未找到\n"
    echo -e "$quick_report"
    return 1
  fi
  
  # 检查 2: openclaw --version 命令
  checks_total=$((checks_total + 1))
  if openclaw --version > /dev/null 2>&1; then
    local version_output
    version_output=$(openclaw --version 2>&1 | head -1)
    color_log "SUCCESS" "✅ openclaw --version 命令可用"
    color_log "INFO" "   版本: $version_output"
    checks_passed=$((checks_passed + 1))
    quick_report+="✅ openclaw --version 命令可用\n"
    quick_report+="   版本: $version_output\n"
  else
    color_log "ERROR" "❌ openclaw --version 命令失败"
    quick_report+="❌ openclaw --version 命令失败\n"
  fi
  
  # 检查 3: openclaw --help 命令
  checks_total=$((checks_total + 1))
  if openclaw --help > /dev/null 2>&1; then
    color_log "SUCCESS" "✅ openclaw --help 命令可用"
    checks_passed=$((checks_passed + 1))
    quick_report+="✅ openclaw --help 命令可用\n"
  else
    color_log "WARNING" "⚠️ openclaw --help 命令失败"
    quick_report+="⚠️ openclaw --help 命令失败\n"
  fi
  
  # 生成快速验证报告
  local success_rate=$((checks_passed * 100 / checks_total))
  color_log "INFO" "快速验证完成: ${checks_passed}/${checks_total} 项通过 (${success_rate}%)"
  echo -e "$quick_report"
  
  if [[ $checks_passed -eq $checks_total ]]; then
    color_log "SUCCESS" "✅ 快速验证通过！OpenClaw 核心功能正常"
    return 0
  elif [[ $checks_passed -ge 2 ]]; then
    color_log "WARNING" "⚠️ 快速验证基本通过，但发现 ${checks_total-$checks_passed} 个问题"
    color_log "INFO" "💡 建议运行完整验证: $0 --full"
    return 0
  else
    color_log "ERROR" "❌ 快速验证失败，请检查安装"
    color_log "INFO" "💡 建议运行完整验证: $0 --full"
    return 1
  fi
}

# 如果直接运行脚本，则执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi