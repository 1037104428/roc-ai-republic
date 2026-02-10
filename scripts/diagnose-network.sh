#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 网络诊断工具
# 帮助用户快速诊断网络连接问题，提供详细的故障排除建议

NPM_REGISTRY_CN="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"
GITHUB_RAW="https://raw.githubusercontent.com"
GITEE_RAW="https://gitee.com"
QUOTA_PROXY_API="https://api.clawdrepublic.cn"
FORUM_URL="https://clawdrepublic.cn/forum/"

usage() {
  cat <<'TXT'
OpenClaw CN 网络诊断工具

用法:
  ./diagnose-network.sh [选项]

选项:
  --all            运行所有网络测试（默认）
  --npm            只测试 npm 注册表
  --github         只测试 GitHub/Gitee
  --api            只测试 API 服务
  --dns            只测试 DNS 解析
  --verbose        显示详细输出
  --help           显示帮助信息

环境变量:
  HTTP_PROXY, HTTPS_PROXY  设置代理服务器
  NO_PROXY                 设置不代理的地址

示例:
  ./diagnose-network.sh --all
  ./diagnose-network.sh --npm --verbose
  HTTP_PROXY=http://proxy:8080 ./diagnose-network.sh
TXT
}

VERBOSE=0
TEST_NPM=0
TEST_GITHUB=0
TEST_API=0
TEST_DNS=0
TEST_ALL=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      TEST_ALL=1; shift ;;
    --npm)
      TEST_NPM=1; TEST_ALL=0; shift ;;
    --github)
      TEST_GITHUB=1; TEST_ALL=0; shift ;;
    --api)
      TEST_API=1; TEST_ALL=0; shift ;;
    --dns)
      TEST_DNS=1; TEST_ALL=0; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$TEST_ALL" -eq 1 ]]; then
  TEST_NPM=1
  TEST_GITHUB=1
  TEST_API=1
  TEST_DNS=1
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_warning "命令 '$1' 未安装"
    return 1
  fi
  return 0
}

test_curl() {
  local url="$1"
  local name="$2"
  local timeout="${3:-5}"
  
  if [[ "$VERBOSE" -eq 1 ]]; then
    log_info "测试 $name: $url (超时: ${timeout}s)"
  fi
  
  if curl -fsS -m "$timeout" "$url" >/dev/null 2>&1; then
    log_success "$name 可达"
    return 0
  else
    log_error "$name 不可达"
    return 1
  fi
}

test_dns() {
  local host="$1"
  local name="$2"
  
  if [[ "$VERBOSE" -eq 1 ]]; then
    log_info "DNS 解析 $name: $host"
  fi
  
  if check_command dig; then
    if dig +short "$host" >/dev/null 2>&1; then
      log_success "$name DNS 解析成功"
      return 0
    else
      log_error "$name DNS 解析失败"
      return 1
    fi
  elif check_command nslookup; then
    if nslookup "$host" >/dev/null 2>&1; then
      log_success "$name DNS 解析成功"
      return 0
    else
      log_error "$name DNS 解析失败"
      return 1
    fi
  else
    log_warning "DNS 解析工具未安装 (dig/nslookup)"
    return 2
  fi
}

test_ping() {
  local host="$1"
  local name="$2"
  
  if [[ "$VERBOSE" -eq 1 ]]; then
    log_info "Ping 测试 $name: $host"
  fi
  
  if check_command ping; then
    if ping -c 2 -W 2 "$host" >/dev/null 2>&1; then
      log_success "$name Ping 成功"
      return 0
    else
      log_warning "$name Ping 失败 (可能被防火墙阻止)"
      return 1
    fi
  else
    log_warning "ping 命令未安装"
    return 2
  fi
}

test_npm_registry() {
  log_info "=== 测试 npm 注册表 ==="
  
  local cn_ok=0
  local fallback_ok=0
  
  # 测试国内镜像
  if test_curl "$NPM_REGISTRY_CN/-/ping" "npm 国内镜像"; then
    cn_ok=1
  fi
  
  # 测试国际镜像
  if test_curl "$NPM_REGISTRY_FALLBACK/-/ping" "npm 国际镜像"; then
    fallback_ok=1
  fi
  
  echo ""
  log_info "npm 注册表测试结果:"
  if [[ "$cn_ok" -eq 1 ]]; then
    log_success "✅ 推荐使用国内镜像: $NPM_REGISTRY_CN"
  elif [[ "$fallback_ok" -eq 1 ]]; then
    log_warning "⚠️  国内镜像不可用，使用国际镜像: $NPM_REGISTRY_FALLBACK"
  else
    log_error "❌ 所有 npm 注册表都不可用"
    return 1
  fi
  
  return 0
}

test_github_gitee() {
  log_info "=== 测试代码仓库 ==="
  
  local github_ok=0
  local gitee_ok=0
  
  # 测试 GitHub
  if test_curl "$GITHUB_RAW/openclaw/openclaw/main/package.json" "GitHub Raw"; then
    github_ok=1
  fi
  
  # 测试 Gitee
  if test_curl "$GITEE_RAW/junkaiWang324/roc-ai-republic/raw/main/README.md" "Gitee Raw"; then
    gitee_ok=1
  fi
  
  echo ""
  log_info "代码仓库测试结果:"
  if [[ "$github_ok" -eq 1 ]]; then
    log_success "✅ GitHub 可达"
  else
    log_warning "⚠️  GitHub 可能较慢或被限制"
  fi
  
  if [[ "$gitee_ok" -eq 1 ]]; then
    log_success "✅ Gitee 可达"
  else
    log_warning "⚠️  Gitee 不可达"
  fi
  
  return 0
}

test_api_services() {
  log_info "=== 测试 API 服务 ==="
  
  local api_ok=0
  local forum_ok=0
  
  # 测试 quota-proxy API
  if test_curl "$QUOTA_PROXY_API/healthz" "quota-proxy API"; then
    api_ok=1
  fi
  
  # 测试论坛
  if test_curl "$FORUM_URL" "论坛页面"; then
    forum_ok=1
  fi
  
  echo ""
  log_info "API 服务测试结果:"
  if [[ "$api_ok" -eq 1 ]]; then
    log_success "✅ quota-proxy API 可达"
  else
    log_warning "⚠️  quota-proxy API 不可达 (可能需要 TRIAL_KEY)"
  fi
  
  if [[ "$forum_ok" -eq 1 ]]; then
    log_success "✅ 论坛页面可达"
  else
    log_warning "⚠️  论坛页面不可达"
  fi
  
  return 0
}

test_dns_resolution() {
  log_info "=== 测试 DNS 解析 ==="
  
  local hosts=(
    "registry.npmmirror.com:npm 国内镜像"
    "registry.npmjs.org:npm 国际镜像"
    "raw.githubusercontent.com:GitHub Raw"
    "gitee.com:Gitee"
    "api.clawdrepublic.cn:quota-proxy API"
    "clawdrepublic.cn:论坛"
  )
  
  local all_ok=1
  
  for host_pair in "${hosts[@]}"; do
    IFS=':' read -r host name <<< "$host_pair"
    if ! test_dns "$host" "$name"; then
      all_ok=0
    fi
  done
  
  echo ""
  if [[ "$all_ok" -eq 1 ]]; then
    log_success "✅ 所有 DNS 解析正常"
  else
    log_warning "⚠️  部分 DNS 解析失败"
  fi
  
  return 0
}

show_network_info() {
  log_info "=== 网络信息 ==="
  
  # 显示 IP 地址
  if check_command ip; then
    log_info "IP 地址:"
    ip addr show | grep -E "inet (192\.168|10\.|172\.)" | head -5 || true
  elif check_command ifconfig; then
    log_info "IP 地址:"
    ifconfig | grep -E "inet (192\.168|10\.|172\.)" | head -5 || true
  fi
  
  # 显示代理设置
  log_info "代理设置:"
  [[ -n "$HTTP_PROXY" ]] && echo "  HTTP_PROXY: $HTTP_PROXY"
  [[ -n "$HTTPS_PROXY" ]] && echo "  HTTPS_PROXY: $HTTPS_PROXY"
  [[ -n "$NO_PROXY" ]] && echo "  NO_PROXY: $NO_PROXY"
  
  # 显示 DNS 服务器
  if [[ -f /etc/resolv.conf ]]; then
    log_info "DNS 服务器:"
    grep -E "^nameserver" /etc/resolv.conf | head -3 || true
  fi
  
  echo ""
}

show_troubleshooting() {
  log_info "=== 故障排除建议 ==="
  
  cat <<'TXT'
如果遇到网络连接问题:

1. 检查网络连接:
   - 确保设备已连接到互联网
   - 尝试访问其他网站确认网络正常

2. 检查代理设置:
   - 如果使用代理，确保代理服务器正常工作
   - 尝试临时禁用代理: unset HTTP_PROXY HTTPS_PROXY

3. 检查 DNS 解析:
   - 尝试使用公共 DNS: 114.114.114.114 或 8.8.8.8
   - 修改 /etc/resolv.conf 或网络设置

4. 检查防火墙:
   - 确保防火墙未阻止出站连接
   - 检查企业网络策略

5. 特定服务问题:
   - npm 安装失败: 尝试 --registry-fallback 选项
   - GitHub 访问慢: 使用 Gitee 镜像
   - API 不可用: 检查 TRIAL_KEY 配置

6. 使用备用方案:
   - 手动下载安装包
   - 使用离线安装方式
   - 联系技术支持

更多帮助:
   - 查看文档: docs/install-cn-strategy.md
   - 论坛求助: https://clawdrepublic.cn/forum/
   - GitHub Issues: https://github.com/openclaw/openclaw/issues
TXT
}

main() {
  echo "========================================="
  echo "    OpenClaw CN 网络诊断工具"
  echo "========================================="
  echo ""
  
  # 检查必要命令
  if ! check_command curl; then
    log_error "curl 命令未安装，无法进行网络测试"
    log_info "安装 curl:"
    echo "  Ubuntu/Debian: sudo apt install curl"
    echo "  CentOS/RHEL: sudo yum install curl"
    echo "  macOS: brew install curl"
    exit 1
  fi
  
  show_network_info
  
  local exit_code=0
  
  # 运行测试
  if [[ "$TEST_DNS" -eq 1 ]]; then
    test_dns_resolution || exit_code=1
  fi
  
  if [[ "$TEST_NPM" -eq 1 ]]; then
    test_npm_registry || exit_code=1
  fi
  
  if [[ "$TEST_GITHUB" -eq 1 ]]; then
    test_github_gitee || exit_code=1
  fi
  
  if [[ "$TEST_API" -eq 1 ]]; then
    test_api_services || exit_code=1
  fi
  
  echo ""
  log_info "=== 测试完成 ==="
  
  if [[ "$exit_code" -eq 0 ]]; then
    log_success "✅ 所有网络测试通过"
  else
    log_warning "⚠️  部分网络测试失败"
    show_troubleshooting
  fi
  
  echo ""
  log_info "快速修复命令:"
  echo "  1. 使用代理: export HTTP_PROXY=http://proxy:8080"
  echo "  2. 使用备用 npm 源: npm config set registry $NPM_REGISTRY_FALLBACK"
  echo "  3. 使用离线安装: 下载 openclaw.tgz 后运行 npm i -g openclaw.tgz"
  
  exit "$exit_code"
}

main "$@"