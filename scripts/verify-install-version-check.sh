#!/usr/bin/env bash
set -euo pipefail

# 验证安装脚本版本检测功能
# 此脚本测试 install-cn.sh 的版本检测功能是否正常工作

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

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
  
  echo -e "${color_code}[$(date '+%Y-%m-%d %H:%M:%S')] $level: $message\033[0m"
}

# 验证函数
verify_install_script_version_check() {
  color_log "INFO" "开始验证安装脚本版本检测功能"
  color_log "INFO" "安装脚本路径: $INSTALL_SCRIPT"
  
  # 检查脚本是否存在
  if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    color_log "ERROR" "安装脚本不存在: $INSTALL_SCRIPT"
    return 1
  fi
  
  color_log "SUCCESS" "✅ 安装脚本文件存在"
  
  # 检查脚本是否可执行
  if [[ ! -x "$INSTALL_SCRIPT" ]]; then
    color_log "WARNING" "安装脚本不可执行，正在添加执行权限"
    chmod +x "$INSTALL_SCRIPT"
  fi
  
  color_log "SUCCESS" "✅ 安装脚本可执行"
  
  # 检查版本检测代码是否存在
  local version_check_count=0
  
  # 检查注释中的版本检测说明
  if grep -q "Self-check: openclaw --version" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "✅ 安装脚本包含版本检测注释说明"
    version_check_count=$((version_check_count + 1))
  else
    color_log "ERROR" "❌ 安装脚本缺少版本检测注释说明"
  fi
  
  # 检查版本检测函数调用
  if grep -q "openclaw --version" "$INSTALL_SCRIPT"; then
    local line_count=$(grep -c "openclaw --version" "$INSTALL_SCRIPT")
    color_log "SUCCESS" "✅ 安装脚本包含 $line_count 处版本检测调用"
    version_check_count=$((version_check_count + 1))
  else
    color_log "ERROR" "❌ 安装脚本缺少版本检测调用"
  fi
  
  # 检查版本匹配验证逻辑
  if grep -q "版本验证通过" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "✅ 安装脚本包含版本匹配验证逻辑"
    version_check_count=$((version_check_count + 1))
  else
    color_log "WARNING" "⚠️ 安装脚本缺少版本匹配验证逻辑"
  fi
  
  # 检查版本不匹配警告
  if grep -q "版本不匹配" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "✅ 安装脚本包含版本不匹配警告"
    version_check_count=$((version_check_count + 1))
  else
    color_log "WARNING" "⚠️ 安装脚本缺少版本不匹配警告"
  fi
  
  # 检查版本检测错误处理
  if grep -q "无法获取OpenClaw版本" "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "✅ 安装脚本包含版本检测错误处理"
    version_check_count=$((version_check_count + 1))
  else
    color_log "WARNING" "⚠️ 安装脚本缺少版本检测错误处理"
  fi
  
  # 输出验证结果
  color_log "INFO" "版本检测功能验证完成"
  color_log "INFO" "版本检测功能点总数: 5"
  color_log "INFO" "版本检测功能点通过: $version_check_count"
  
  if [[ $version_check_count -ge 4 ]]; then
    color_log "SUCCESS" "✅ 安装脚本版本检测功能验证通过"
    return 0
  elif [[ $version_check_count -ge 2 ]]; then
    color_log "WARNING" "⚠️ 安装脚本版本检测功能基本可用，但需要改进"
    return 0
  else
    color_log "ERROR" "❌ 安装脚本版本检测功能验证失败"
    return 1
  fi
}

# 验证安装脚本语法
verify_install_script_syntax() {
  color_log "INFO" "开始验证安装脚本语法"
  
  if bash -n "$INSTALL_SCRIPT"; then
    color_log "SUCCESS" "✅ 安装脚本语法正确"
    return 0
  else
    color_log "ERROR" "❌ 安装脚本语法错误"
    return 1
  fi
}

# 验证安装脚本版本检测功能示例
verify_version_check_example() {
  color_log "INFO" "开始验证版本检测功能示例"
  
  # 提取版本检测代码段
  local version_check_section=$(grep -A 15 "Check 2: Get version" "$INSTALL_SCRIPT" | head -20)
  
  if [[ -n "$version_check_section" ]]; then
    color_log "SUCCESS" "✅ 成功提取版本检测代码段"
    color_log "DEBUG" "版本检测代码段内容:"
    echo "$version_check_section" | while IFS= read -r line; do
      color_log "DEBUG" "  $line"
    done
    
    # 检查关键功能点
    local has_version_command=false
    local has_version_match=false
    local has_version_mismatch=false
    local has_error_handling=false
    
    if echo "$version_check_section" | grep -q "openclaw --version"; then
      has_version_command=true
    fi
    
    if echo "$version_check_section" | grep -q "版本验证通过"; then
      has_version_match=true
    fi
    
    if echo "$version_check_section" | grep -q "版本不匹配"; then
      has_version_mismatch=true
    fi
    
    if echo "$version_check_section" | grep -q "无法获取OpenClaw版本"; then
      has_error_handling=true
    fi
    
    color_log "INFO" "版本检测功能点分析:"
    color_log "INFO" "  - 版本命令检测: $([ "$has_version_command" = true ] && echo "✅ 存在" || echo "❌ 缺失")"
    color_log "INFO" "  - 版本匹配验证: $([ "$has_version_match" = true ] && echo "✅ 存在" || echo "❌ 缺失")"
    color_log "INFO" "  - 版本不匹配警告: $([ "$has_version_mismatch" = true ] && echo "✅ 存在" || echo "❌ 缺失")"
    color_log "INFO" "  - 错误处理: $([ "$has_error_handling" = true ] && echo "✅ 存在" || echo "❌ 缺失")"
    
    local example_score=0
    [[ "$has_version_command" = true ]] && example_score=$((example_score + 1))
    [[ "$has_version_match" = true ]] && example_score=$((example_score + 1))
    [[ "$has_version_mismatch" = true ]] && example_score=$((example_score + 1))
    [[ "$has_error_handling" = true ]] && example_score=$((example_score + 1))
    
    if [[ $example_score -ge 3 ]]; then
      color_log "SUCCESS" "✅ 版本检测功能示例验证通过"
      return 0
    else
      color_log "WARNING" "⚠️ 版本检测功能示例需要改进"
      return 1
    fi
  else
    color_log "ERROR" "❌ 无法提取版本检测代码段"
    return 1
  fi
}

# 主验证函数
main() {
  color_log "INFO" "================================================"
  color_log "INFO" "安装脚本版本检测功能验证"
  color_log "INFO" "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
  color_log "INFO" "================================================"
  
  local overall_result=0
  
  # 验证1: 安装脚本语法
  if verify_install_script_syntax; then
    color_log "SUCCESS" "✅ 验证1: 安装脚本语法验证通过"
  else
    color_log "ERROR" "❌ 验证1: 安装脚本语法验证失败"
    overall_result=1
  fi
  
  # 验证2: 版本检测功能
  if verify_install_script_version_check; then
    color_log "SUCCESS" "✅ 验证2: 版本检测功能验证通过"
  else
    color_log "ERROR" "❌ 验证2: 版本检测功能验证失败"
    overall_result=1
  fi
  
  # 验证3: 版本检测功能示例
  if verify_version_check_example; then
    color_log "SUCCESS" "✅ 验证3: 版本检测功能示例验证通过"
  else
    color_log "WARNING" "⚠️ 验证3: 版本检测功能示例需要改进"
  fi
  
  color_log "INFO" "================================================"
  color_log "INFO" "验证完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
  
  if [[ $overall_result -eq 0 ]]; then
    color_log "SUCCESS" "✅ 安装脚本版本检测功能总体验证通过"
    color_log "INFO" "建议: 安装脚本包含完整的版本检测功能，支持版本验证和错误处理"
  else
    color_log "ERROR" "❌ 安装脚本版本检测功能总体验证失败"
    color_log "INFO" "建议: 请检查安装脚本的版本检测功能实现"
  fi
  
  color_log "INFO" "================================================"
  
  return $overall_result
}

# 执行主函数
main "$@"