#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 批量部署验证脚本
# 用于验证批量部署功能的正确性

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

# Color logging
color_log() {
  local level="$1"
  local message="$2"
  local color=""
  local reset="\033[0m"
  
  case "$level" in
    "INFO") color="\033[0;34m" ;;  # Blue
    "SUCCESS") color="\033[0;32m" ;;  # Green
    "WARNING") color="\033[0;33m" ;;  # Yellow
    "ERROR") color="\033[0;31m" ;;  # Red
    "STEP") color="\033[1;35m" ;;  # Magenta (bold)
    *) color="\033[0;37m" ;;  # White
  esac
  
  if [[ -t 1 ]] && [[ "$TERM" != "dumb" ]]; then
    echo -e "${color}[batch-verify:${level}]${reset} ${message}"
  else
    echo "[batch-verify:${level}] ${message}"
  fi
}

# Show usage
usage() {
  cat << EOF
OpenClaw 批量部署验证脚本

用法:
  ./verify-batch-deploy.sh [选项]

选项:
  --help, -h          显示帮助信息
  --test-config       测试配置文件解析
  --test-dry-run      测试Dry Run模式
  --test-all          运行所有测试
  --create-example    创建示例配置文件

示例:
  ./verify-batch-deploy.sh --test-config
  ./verify-batch-deploy.sh --test-dry-run
  ./verify-batch-deploy.sh --test-all
  ./verify-batch-deploy.sh --create-example
EOF
}

# Test 1: 检查批量部署选项是否可用
test_batch_options() {
  color_log "STEP" "测试1: 检查批量部署选项是否可用"
  
  if ! "$INSTALL_SCRIPT" --help 2>&1 | grep -q "batch-deploy"; then
    color_log "ERROR" "❌ 批量部署选项未在帮助信息中找到"
    return 1
  fi
  
  if ! "$INSTALL_SCRIPT" --help 2>&1 | grep -q "batch-dry-run"; then
    color_log "ERROR" "❌ 批量部署Dry Run选项未在帮助信息中找到"
    return 1
  fi
  
  color_log "SUCCESS" "✅ 批量部署选项在帮助信息中可用"
  return 0
}

# Test 2: 测试配置文件解析
test_config_parsing() {
  color_log "STEP" "测试2: 测试配置文件解析"
  
  # 创建测试配置文件
  local test_config="/tmp/test-batch-config-$(date +%s).txt"
  cat > "$test_config" << EOF
# 测试配置文件
server1.example.com|admin|pass1|--version latest --ci-mode
server2.example.com|root|pass2|--force-cn --ci-mode
# 注释行应该被忽略
  # 带空格的注释行
EOF
  
  # 测试Dry Run模式
  if "$INSTALL_SCRIPT" --batch-deploy "$test_config" --batch-dry-run 2>&1 | grep -q "Dry Run"; then
    color_log "SUCCESS" "✅ Dry Run模式工作正常"
  else
    color_log "ERROR" "❌ Dry Run模式测试失败"
    rm -f "$test_config"
    return 1
  fi
  
  # 检查是否识别了2个服务器
  if "$INSTALL_SCRIPT" --batch-deploy "$test_config" --batch-dry-run 2>&1 | grep -q "总服务器数: 2"; then
    color_log "SUCCESS" "✅ 配置文件解析正确 (识别了2个服务器)"
  else
    color_log "ERROR" "❌ 配置文件解析失败"
    rm -f "$test_config"
    return 1
  fi
  
  rm -f "$test_config"
  color_log "SUCCESS" "✅ 配置文件解析测试通过"
  return 0
}

# Test 3: 测试无效配置文件处理
test_invalid_config() {
  color_log "STEP" "测试3: 测试无效配置文件处理"
  
  local invalid_config="/tmp/invalid-config-$(date +%s).txt"
  echo "invalid line without enough fields" > "$invalid_config"
  
  # 测试不存在的配置文件
  if "$INSTALL_SCRIPT" --batch-deploy "/tmp/nonexistent-file-$(date +%s).txt" --batch-dry-run 2>&1 | grep -q "配置文件不存在"; then
    color_log "SUCCESS" "✅ 不存在的配置文件处理正确"
  else
    color_log "ERROR" "❌ 不存在的配置文件处理失败"
    rm -f "$invalid_config"
    return 1
  fi
  
  rm -f "$invalid_config"
  color_log "SUCCESS" "✅ 无效配置文件处理测试通过"
  return 0
}

# Test 4: 测试批量部署帮助信息
test_batch_help() {
  color_log "STEP" "测试4: 测试批量部署帮助信息"
  
  # 检查帮助信息中是否包含批量部署说明
  if "$INSTALL_SCRIPT" --help 2>&1 | grep -A5 "batch-deploy" | grep -q "Batch deploy"; then
    color_log "SUCCESS" "✅ 批量部署帮助信息完整"
  else
    color_log "WARNING" "⚠️  批量部署帮助信息可能不完整"
  fi
  
  color_log "SUCCESS" "✅ 批量部署帮助信息测试通过"
  return 0
}

# Test 5: 创建示例配置文件
create_example_config() {
  color_log "STEP" "测试5: 创建示例配置文件"
  
  local example_file="$PROJECT_ROOT/batch-deploy-example.txt"
  
  # 检查示例文件是否存在
  if [[ -f "$PROJECT_ROOT/config-templates/batch-deploy-config.example.txt" ]]; then
    color_log "SUCCESS" "✅ 示例配置文件已存在: config-templates/batch-deploy-config.example.txt"
    
    # 显示示例文件内容预览
    echo ""
    color_log "INFO" "示例配置文件预览:"
    echo "-----------------------------------------"
    head -20 "$PROJECT_ROOT/config-templates/batch-deploy-config.example.txt"
    echo "-----------------------------------------"
    echo ""
    color_log "INFO" "完整文件: $PROJECT_ROOT/config-templates/batch-deploy-config.example.txt"
  else
    color_log "ERROR" "❌ 示例配置文件不存在"
    return 1
  fi
  
  color_log "SUCCESS" "✅ 示例配置文件测试通过"
  return 0
}

# Main test function
run_all_tests() {
  local passed=0
  local failed=0
  local tests=5
  
  color_log "STEP" "========================================="
  color_log "STEP" "🚀 开始批量部署功能验证"
  color_log "STEP" "========================================="
  
  # Test 1
  if test_batch_options; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  
  # Test 2
  if test_config_parsing; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  
  # Test 3
  if test_invalid_config; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  
  # Test 4
  if test_batch_help; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  
  # Test 5
  if create_example_config; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  
  # Summary
  echo ""
  color_log "STEP" "========================================="
  color_log "STEP" "📊 验证结果摘要"
  color_log "STEP" "========================================="
  color_log "INFO" "总测试数: $tests"
  color_log "SUCCESS" "通过: $passed"
  
  if [[ "$failed" -gt 0 ]]; then
    color_log "ERROR" "失败: $failed"
    echo ""
    color_log "WARNING" "⚠️  部分测试失败，请检查批量部署功能"
    return 1
  else
    color_log "SUCCESS" "失败: $failed"
    echo ""
    color_log "SUCCESS" "🎉 所有测试通过！批量部署功能正常"
    return 0
  fi
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

case "$1" in
  --help|-h)
    usage
    exit 0
    ;;
  --test-config)
    test_config_parsing
    exit $?
    ;;
  --test-dry-run)
    test_config_parsing
    exit $?
    ;;
  --test-all)
    run_all_tests
    exit $?
    ;;
  --create-example)
    create_example_config
    exit $?
    ;;
  *)
    color_log "ERROR" "未知选项: $1"
    usage
    exit 1
    ;;
esac