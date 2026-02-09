#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装完整验证脚本
# 验证 install-cn.sh 的所有关键功能：
# 1. 网络连通性测试
# 2. 国内源可达性
# 3. 回退策略
# 4. 安装后自检
# 5. 版本验证

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 测试网络连通性
test_network_connectivity() {
  log_info "测试网络连通性..."
  
  local cn_registry="https://registry.npmmirror.com"
  local fallback_registry="https://registry.npmjs.org"
  local quota_proxy="https://clawdrepublic.cn/healthz"
  local landing_page="https://clawdrepublic.cn/"
  
  local all_ok=1
  
  # 测试国内镜像
  if curl -fsS -m 10 "$cn_registry/-/ping" >/dev/null 2>&1; then
    log_success "国内镜像可达: $cn_registry"
  else
    log_warn "国内镜像不可达: $cn_registry"
    all_ok=0
  fi
  
  # 测试回退镜像
  if curl -fsS -m 10 "$fallback_registry/-/ping" >/dev/null 2>&1; then
    log_success "回退镜像可达: $fallback_registry"
  else
    log_error "回退镜像不可达: $fallback_registry"
    all_ok=0
  fi
  
  # 测试 quota-proxy 健康检查
  if curl -fsS -m 10 "$quota_proxy" >/dev/null 2>&1; then
    log_success "quota-proxy 健康检查正常: $quota_proxy"
  else
    log_warn "quota-proxy 健康检查失败: $quota_proxy"
    all_ok=0
  fi
  
  # 测试 landing page
  local landing_content
  landing_content="$(curl -s -m 10 "$landing_page" 2>/dev/null || echo "")"
  if echo "$landing_content" | grep -q "中华AI共和国\|OpenClaw"; then
    log_success "Landing page 内容正常: $landing_page"
  else
    log_warn "Landing page 内容异常: $landing_page"
    all_ok=0
  fi
  
  return $all_ok
}

# 测试 install-cn.sh 脚本语法
test_script_syntax() {
  log_info "测试 install-cn.sh 脚本语法..."
  
  local script_path="$REPO_ROOT/scripts/install-cn.sh"
  
  if [[ ! -f "$script_path" ]]; then
    log_error "脚本不存在: $script_path"
    return 1
  fi
  
  # 检查 shebang
  if head -1 "$script_path" | grep -q "^#!/usr/bin/env bash"; then
    log_success "Shebang 正确"
  else
    log_error "Shebang 不正确"
    return 1
  fi
  
  # 检查语法
  if bash -n "$script_path"; then
    log_success "脚本语法正确"
  else
    log_error "脚本语法错误"
    return 1
  fi
  
  # 测试 --dry-run 选项
  if "$script_path" --dry-run --help 2>&1 | grep -q "OpenClaw CN installer"; then
    log_success "--dry-run 选项工作正常"
  else
    log_error "--dry-run 选项异常"
    return 1
  fi
  
  # 测试 --network-test 选项
  local network_test_output
  network_test_output="$("$script_path" --dry-run --network-test 2>&1 || true)"
  if echo "$network_test_output" | grep -q "Running network connectivity test\|network connectivity test"; then
    log_success "--network-test 选项工作正常"
  else
    log_error "--network-test 选项异常"
    return 1
  fi
  
  return 0
}

# 测试安装脚本的核心功能
test_install_functionality() {
  log_info "测试安装脚本核心功能..."
  
  local script_path="$REPO_ROOT/scripts/install-cn.sh"
  local test_dir
  test_dir="$(mktemp -d)"
  
  trap 'rm -rf "$test_dir"' EXIT
  
  cd "$test_dir"
  
  # 创建模拟环境
  cat > package.json << 'EOF'
{
  "name": "test-openclaw-install",
  "version": "1.0.0"
}
EOF
  
  # 测试 --dry-run 输出包含关键命令
  local dry_run_output
  dry_run_output="$("$script_path" --dry-run --version latest 2>&1)"
  
  local checks_passed=0
  local total_checks=4
  
  # 检查是否包含 npm install
  if echo "$dry_run_output" | grep -q "npm install"; then
    log_success "输出包含 npm install 命令"
    ((checks_passed++))
  else
    log_warn "输出缺少 npm install 命令"
  fi
  
  # 检查是否包含 openclaw --version
  if echo "$dry_run_output" | grep -q "openclaw --version"; then
    log_success "输出包含 openclaw --version 自检"
    ((checks_passed++))
  else
    log_warn "输出缺少 openclaw --version 自检"
  fi
  
  # 检查是否包含 registry 配置
  if echo "$dry_run_output" | grep -q "registry.npmmirror.com"; then
    log_success "输出包含国内镜像配置"
    ((checks_passed++))
  else
    log_warn "输出缺少国内镜像配置"
  fi
  
  # 检查是否包含错误处理
  if echo "$dry_run_output" | grep -q "set -euo pipefail"; then
    log_success "脚本包含严格的错误处理"
    ((checks_passed++))
  else
    log_warn "脚本缺少严格的错误处理"
  fi
  
  if [[ $checks_passed -eq $total_checks ]]; then
    log_success "所有核心功能检查通过 ($checks_passed/$total_checks)"
    return 0
  else
    log_warn "部分功能检查未通过 ($checks_passed/$total_checks)"
    return 1
  fi
}

# 测试文档完整性
test_documentation() {
  log_info "测试文档完整性..."
  
  local docs=(
    "$REPO_ROOT/docs/install-cn-guide.md"
    "$REPO_ROOT/docs/install-cn-network-guide.md"
    "$REPO_ROOT/docs/install-cn-troubleshooting.md"
  )
  
  local all_ok=1
  
  for doc in "${docs[@]}"; do
    if [[ -f "$doc" ]]; then
      # 检查文档是否包含关键章节
      local doc_name="$(basename "$doc")"
      
      if grep -q "## " "$doc"; then
        log_success "文档 $doc_name 包含章节结构"
      else
        log_warn "文档 $doc_name 缺少章节结构"
        all_ok=0
      fi
      
      # 检查是否包含代码示例
      if grep -q '```' "$doc"; then
        log_success "文档 $doc_name 包含代码示例"
      else
        log_warn "文档 $doc_name 缺少代码示例"
        all_ok=0
      fi
    else
      log_error "文档不存在: $doc"
      all_ok=0
    fi
  done
  
  # 检查 README 中的安装说明
  if [[ -f "$REPO_ROOT/README.md" ]]; then
    if grep -q "install-cn.sh" "$REPO_ROOT/README.md"; then
      log_success "README 包含 install-cn.sh 引用"
    else
      log_warn "README 缺少 install-cn.sh 引用"
      all_ok=0
    fi
  fi
  
  return $all_ok
}

# 生成验证报告
generate_report() {
  local network_ok=$1
  local syntax_ok=$2
  local functionality_ok=$3
  local docs_ok=$4
  
  log_info "="
  log_info "验证报告"
  log_info "="
  
  echo "网络连通性测试: $( [[ $network_ok -eq 0 ]] && echo "✅ 通过" || echo "❌ 失败" )"
  echo "脚本语法测试: $( [[ $syntax_ok -eq 0 ]] && echo "✅ 通过" || echo "❌ 失败" )"
  echo "核心功能测试: $( [[ $functionality_ok -eq 0 ]] && echo "✅ 通过" || echo "❌ 失败" )"
  echo "文档完整性测试: $( [[ $docs_ok -eq 0 ]] && echo "✅ 通过" || echo "❌ 失败" )"
  
  local total_tests=4
  local passed_tests=0
  
  [[ $network_ok -eq 0 ]] && ((passed_tests++))
  [[ $syntax_ok -eq 0 ]] && ((passed_tests++))
  [[ $functionality_ok -eq 0 ]] && ((passed_tests++))
  [[ $docs_ok -eq 0 ]] && ((passed_tests++))
  
  echo ""
  echo "总计: $passed_tests/$total_tests 项测试通过"
  
  if [[ $passed_tests -eq $total_tests ]]; then
    log_success "🎉 所有验证测试通过！install-cn.sh 准备就绪。"
    return 0
  else
    log_error "⚠️  部分验证测试失败，请检查问题。"
    return 1
  fi
}

main() {
  log_info "开始 OpenClaw CN 安装脚本完整验证"
  log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  log_info "="
  
  # 运行所有测试
  test_network_connectivity
  local network_result=$?
  
  test_script_syntax
  local syntax_result=$?
  
  test_install_functionality
  local functionality_result=$?
  
  test_documentation
  local docs_result=$?
  
  echo ""
  generate_report $network_result $syntax_result $functionality_result $docs_result
  local final_result=$?
  
  log_info "="
  log_info "验证完成"
  
  exit $final_result
}

# 如果直接运行则执行 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi