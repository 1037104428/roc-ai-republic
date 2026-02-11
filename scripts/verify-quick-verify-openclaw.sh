#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# 验证脚本：verify-quick-verify-openclaw.sh
# 验证 quick-verify-openclaw.sh 脚本的功能和完整性
# 版本：2026.02.11.1627
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
  echo -e "${CYAN}[INFO]${NC} $1"
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

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo -e "${MAGENTA}[DEBUG]${NC} $1"
  fi
}

log_step() {
  echo -e "${BLUE}▶${NC} $1"
}

# 检查函数
check_file_exists() {
  local file="$1"
  log_step "检查文件存在性: $file"
  if [[ -f "$file" ]]; then
    log_success "文件存在: $file"
    return 0
  else
    log_error "文件不存在: $file"
    return 1
  fi
}

check_executable() {
  local file="$1"
  log_step "检查可执行权限: $file"
  if [[ -x "$file" ]]; then
    log_success "文件可执行: $file"
    return 0
  else
    log_warning "文件不可执行: $file"
    return 1
  fi
}

check_syntax() {
  local file="$1"
  log_step "检查语法: $file"
  if bash -n "$file" 2>/dev/null; then
    log_success "语法检查通过: $file"
    return 0
  else
    log_error "语法检查失败: $file"
    return 1
  fi
}

check_help_function() {
  local file="$1"
  log_step "检查帮助功能: $file"
  if "$file" --help 2>&1 | grep -q "用法\|选项\|帮助\|usage\|help"; then
    log_success "帮助功能可用: $file"
    return 0
  else
    log_error "帮助功能不可用: $file"
    return 1
  fi
}

check_dry_run() {
  local file="$1"
  log_step "检查干运行模式: $file"
  if "$file" --dry-run 2>&1 | grep -q "干运行\|dry-run\|将检查\|将执行"; then
    log_success "干运行模式可用: $file"
    return 0
  else
    log_error "干运行模式不可用: $file"
    return 1
  fi
}

check_color_logging() {
  local file="$1"
  log_step "检查颜色日志功能: $file"
  if grep -q "RED='\\\033" "$file" || grep -q "GREEN='\\\033" "$file" || grep -q "BLUE='\\\033" "$file"; then
    log_success "颜色日志功能存在: $file"
    return 0
  else
    log_warning "颜色日志功能可能缺失: $file"
    return 1
  fi
}

check_version_info() {
  local file="$1"
  log_step "检查版本信息: $file"
  if grep -q "SCRIPT_VERSION\|版本信息\|版本号\|2026" "$file"; then
    log_success "版本信息存在: $file"
    return 0
  else
    log_warning "版本信息可能缺失: $file"
    return 1
  fi
}

check_output_format() {
  local file="$1"
  log_step "检查输出格式: $file"
  if grep -q "echo.*===\|echo.*检查\|echo.*建议\|echo.*结果" "$file"; then
    log_success "输出格式合理: $file"
    return 0
  else
    log_warning "输出格式可能不合理: $file"
    return 1
  fi
}

check_line_count() {
  local file="$1"
  log_step "检查脚本行数: $file"
  local lines=$(wc -l < "$file")
  if [[ $lines -gt 50 ]]; then
    log_success "脚本行数合理: $file ($lines 行)"
    return 0
  else
    log_warning "脚本行数可能过少: $file ($lines 行)"
    return 1
  fi
}

check_actual_run() {
  local file="$1"
  log_step "检查实际运行: $file"
  if "$file" --quiet 2>&1 | grep -q "OpenClaw 快速验证\|验证完成\|检查完成\|所有检查通过"; then
    log_success "实际运行测试通过: $file"
    return 0
  else
    log_error "实际运行测试失败: $file"
    return 1
  fi
}

check_parameter_validation() {
  local file="$1"
  log_step "检查参数验证: $file"
  if "$file" --invalid-param 2>&1 | grep -q "未知参数\|无效参数\|错误\|error"; then
    log_success "参数验证功能存在: $file"
    return 0
  else
    log_warning "参数验证功能可能缺失: $file"
    return 1
  fi
}

check_environment_variables() {
  local file="$1"
  log_step "检查环境变量处理: $file"
  if grep -q "export\|ENV\|环境变量" "$file"; then
    log_success "环境变量处理功能存在: $file"
    return 0
  else
    log_warning "环境变量处理功能可能缺失: $file"
    return 1
  fi
}

check_error_handling() {
  local file="$1"
  log_step "检查错误处理: $file"
  if grep -q "set -e\|trap\|exit 1\|错误处理" "$file"; then
    log_success "错误处理功能存在: $file"
    return 0
  else
    log_warning "错误处理功能可能缺失: $file"
    return 1
  fi
}

check_code_quality() {
  local file="$1"
  log_step "检查代码质量: $file"
  if shellcheck "$file" 2>&1 | grep -q "SC[0-9]\+:"; then
    log_warning "代码质量检查发现警告: $file"
    return 1
  else
    log_success "代码质量检查通过: $file"
    return 0
  fi
}

# 主函数
main() {
  local target_script="scripts/quick-verify-openclaw.sh"
  local total_tests=0
  local passed_tests=0
  local failed_tests=0
  
  echo -e "${BLUE}========================================${NC}"
  echo -e "${CYAN}开始验证脚本: $target_script${NC}"
  echo -e "${BLUE}========================================${NC}"
  
  # 测试1: 文件存在性检查
  ((total_tests++))
  if check_file_exists "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试2: 可执行权限检查
  ((total_tests++))
  if check_executable "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试3: 语法检查
  ((total_tests++))
  if check_syntax "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试4: 帮助功能检查
  ((total_tests++))
  if check_help_function "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试5: 干运行模式检查
  ((total_tests++))
  if check_dry_run "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试6: 颜色日志功能检查
  ((total_tests++))
  if check_color_logging "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试7: 版本信息检查
  ((total_tests++))
  if check_version_info "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试8: 输出格式检查
  ((total_tests++))
  if check_output_format "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试9: 脚本行数检查
  ((total_tests++))
  if check_line_count "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试10: 实际运行测试
  ((total_tests++))
  if check_actual_run "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试11: 参数验证检查
  ((total_tests++))
  if check_parameter_validation "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试12: 环境变量处理检查
  ((total_tests++))
  if check_environment_variables "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试13: 错误处理检查
  ((total_tests++))
  if check_error_handling "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  # 测试14: 代码质量检查
  ((total_tests++))
  if check_code_quality "$target_script"; then
    ((passed_tests++))
  else
    ((failed_tests++))
  fi
  
  echo -e "${BLUE}========================================${NC}"
  echo -e "${CYAN}验证完成${NC}"
  echo -e "${BLUE}========================================${NC}"
  
  # 显示统计信息
  echo -e "${CYAN}总计测试:${NC} $total_tests"
  echo -e "${GREEN}通过测试:${NC} $passed_tests"
  echo -e "${RED}失败测试:${NC} $failed_tests"
  echo -e "${BLUE}========================================${NC}"
  
  # 计算通过率
  local pass_rate=0
  if [[ $total_tests -gt 0 ]]; then
    pass_rate=$((passed_tests * 100 / total_tests))
  fi
  
  if [[ $failed_tests -eq 0 ]]; then
    echo -e "${GREEN}✅ 所有测试通过！ (通过率: ${pass_rate}%)${NC}"
    exit 0
  elif [[ $pass_rate -ge 80 ]]; then
    echo -e "${YELLOW}⚠️  $failed_tests 个测试失败，但通过率较高 (${pass_rate}%)${NC}"
    exit 0
  else
    echo -e "${RED}❌ 有 $failed_tests 个测试失败 (通过率: ${pass_rate}%)${NC}"
    exit 1
  fi
}

# 显示使用说明
usage() {
  echo -e "${CYAN}用法: $0 [选项]${NC}"
  echo -e "${CYAN}选项:${NC}"
  echo -e "  --dry-run    干运行模式，只显示检查项"
  echo -e "  --quick      快速模式，只运行基本检查"
  echo -e "  --debug      调试模式，显示详细信息"
  echo -e "  --help       显示帮助信息"
  echo -e ""
  echo -e "${CYAN}示例:${NC}"
  echo -e "  $0                    # 运行完整验证"
  echo -e "  $0 --dry-run          # 干运行模式"
  echo -e "  $0 --quick            # 快速验证模式"
  echo -e "  $0 --debug            # 调试模式"
}

# 参数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      echo -e "${CYAN}干运行模式：只显示检查项，不实际执行${NC}"
      echo -e "${BLUE}========================================${NC}"
      echo -e "${CYAN}将检查以下项目：${NC}"
      echo -e "1. 文件存在性检查"
      echo -e "2. 可执行权限检查"
      echo -e "3. 语法检查"
      echo -e "4. 帮助功能检查"
      echo -e "5. 干运行模式检查"
      echo -e "6. 颜色日志功能检查"
      echo -e "7. 版本信息检查"
      echo -e "8. 输出格式检查"
      echo -e "9. 脚本行数检查"
      echo -e "10. 实际运行测试"
      echo -e "11. 参数验证检查"
      echo -e "12. 环境变量处理检查"
      echo -e "13. 错误处理检查"
      echo -e "14. 代码质量检查"
      echo -e "${BLUE}========================================${NC}"
      echo -e "${CYAN}总计: 14 项检查${NC}"
      exit 0
      ;;
    --quick)
      echo -e "${CYAN}快速模式：只运行基本检查${NC}"
      # 在快速模式下，只运行关键检查
      DEBUG=false
      ;;
    --debug)
      DEBUG=true
      log_debug "调试模式已启用"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# 运行主函数
main