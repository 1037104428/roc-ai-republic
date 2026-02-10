#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 网络源优化脚本
# 自动检测最佳镜像源并推荐优化配置
# 目标：为国内用户提供最快的安装体验

# 支持的镜像源列表（按优先级排序）
MIRROR_SOURCES=(
  "https://registry.npmmirror.com"
  "https://mirrors.cloud.tencent.com/npm/"
  "https://registry.npm.taobao.org"
  "https://registry.npmjs.org"
)

# GitHub/Gitee 镜像源
GITHUB_MIRRORS=(
  "https://raw.githubusercontent.com"
  "https://ghproxy.com/https://raw.githubusercontent.com"
  "https://raw.fastgit.org"
)

GITEE_MIRRORS=(
  "https://gitee.com"
  "https://mirror.ghproxy.com/https://gitee.com"
)

# 测试超时（秒）
TEST_TIMEOUT=5

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[网络优化]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[网络优化] ✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[网络优化] ⚠️${NC} $1"
}

log_error() {
  echo -e "${RED}[网络优化] ❌${NC} $1"
}

# 检查命令是否存在
check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "需要 $1 命令，但未找到"
    return 1
  fi
  return 0
}

# 测试URL可达性
test_url() {
  local url="$1"
  local timeout="$2"
  
  if curl -fsS -m "$timeout" "$url" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# 测试npm镜像源
test_npm_mirrors() {
  log_info "测试 npm 镜像源..."
  
  local best_mirror=""
  local best_time=9999
  
  for mirror in "${MIRROR_SOURCES[@]}"; do
    log_info "测试: $mirror"
    
    # 测试ping端点
    local start_time
    start_time=$(date +%s%3N)
    
    if test_url "$mirror/-/ping" "$TEST_TIMEOUT"; then
      local end_time
      end_time=$(date +%s%3N)
      local response_time=$((end_time - start_time))
      
      log_success "可达 (${response_time}ms)"
      
      if [[ $response_time -lt $best_time ]]; then
        best_time=$response_time
        best_mirror="$mirror"
      fi
    else
      log_warning "不可达"
    fi
  done
  
  if [[ -n "$best_mirror" ]]; then
    echo "$best_mirror"
    return 0
  else
    return 1
  fi
}

# 测试GitHub镜像源
test_github_mirrors() {
  log_info "测试 GitHub 镜像源..."
  
  local best_mirror=""
  local best_time=9999
  
  for mirror in "${GITHUB_MIRRORS[@]}"; do
    log_info "测试: $mirror"
    
    # 测试OpenClaw仓库的package.json
    local test_url="$mirror/openclaw/openclaw/main/package.json"
    local start_time
    start_time=$(date +%s%3N)
    
    if test_url "$test_url" "$TEST_TIMEOUT"; then
      local end_time
      end_time=$(date +%s%3N)
      local response_time=$((end_time - start_time))
      
      log_success "可达 (${response_time}ms)"
      
      if [[ $response_time -lt $best_time ]]; then
        best_time=$response_time
        best_mirror="$mirror"
      fi
    else
      log_warning "不可达"
    fi
  done
  
  if [[ -n "$best_mirror" ]]; then
    echo "$best_mirror"
    return 0
  else
    return 1
  fi
}

# 测试Gitee镜像源
test_gitee_mirrors() {
  log_info "测试 Gitee 镜像源..."
  
  local best_mirror=""
  local best_time=9999
  
  for mirror in "${GITEE_MIRRORS[@]}"; do
    log_info "测试: $mirror"
    
    # 测试roc-ai-republic仓库的README
    local test_url="$mirror/junkaiWang324/roc-ai-republic/raw/main/README.md"
    local start_time
    start_time=$(date +%s%3N)
    
    if test_url "$test_url" "$TEST_TIMEOUT"; then
      local end_time
      end_time=$(date +%s%3N)
      local response_time=$((end_time - start_time))
      
      log_success "可达 (${response_time}ms)"
      
      if [[ $response_time -lt $best_time ]]; then
        best_time=$response_time
        best_mirror="$mirror"
      fi
    else
      log_warning "不可达"
    fi
  done
  
  if [[ -n "$best_mirror" ]]; then
    echo "$best_mirror"
    return 0
  else
    return 1
  fi
}

# 生成优化配置
generate_optimization_config() {
  local npm_mirror="$1"
  local github_mirror="$2"
  local gitee_mirror="$3"
  
  cat <<EOF

# ============================================
# 🚀 OpenClaw CN 网络优化配置
# ============================================
# 基于实时网络测试生成的最佳配置
# 复制以下环境变量到安装命令前使用

# 最佳 npm 镜像源
export NPM_REGISTRY="$npm_mirror"
export NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"

# 最佳 GitHub 镜像源（用于脚本下载）
export GITHUB_MIRROR="$github_mirror"

# 最佳 Gitee 镜像源
export GITEE_MIRROR="$gitee_mirror"

# 安装命令示例（使用优化配置）：
# NPM_REGISTRY="$npm_mirror" \\
# GITHUB_MIRROR="$github_mirror" \\
# curl -fsSL "\${GITHUB_MIRROR}/openclaw/openclaw/main/scripts/install.sh" | bash

# 或者使用 install-cn.sh（已内置优化）：
# curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

EOF
  
  # 生成具体的安装命令
  cat <<EOF
# 📦 一键安装命令（复制并执行）：
NPM_REGISTRY="$npm_mirror" \\
GITHUB_MIRROR="$github_mirror" \\
bash -c '\$(curl -fsSL "\${GITHUB_MIRROR}/openclaw/openclaw/main/scripts/install.sh")'

# 或者使用国内优化版本：
curl -fsSL https://clawdrepublic.cn/install-cn.sh | \\
  NPM_REGISTRY="$npm_mirror" \\
  NPM_REGISTRY_FALLBACK="https://registry.npmjs.org" \\
  bash
EOF
}

# 主函数
main() {
  log_info "开始 OpenClaw CN 网络源优化检测"
  log_info "======================================"
  
  # 检查必要命令
  if ! check_command "curl"; then
    log_error "需要 curl 命令，请先安装: sudo apt-get install curl 或 sudo yum install curl"
    exit 1
  fi
  
  # 测试各镜像源
  local npm_best
  local github_best
  local gitee_best
  
  log_info ""
  npm_best=$(test_npm_mirrors)
  if [[ $? -eq 0 ]]; then
    log_success "最佳 npm 镜像源: $npm_best"
  else
    log_error "未找到可用的 npm 镜像源"
    npm_best="https://registry.npmjs.org"
  fi
  
  log_info ""
  github_best=$(test_github_mirrors)
  if [[ $? -eq 0 ]]; then
    log_success "最佳 GitHub 镜像源: $github_best"
  else
    log_error "未找到可用的 GitHub 镜像源"
    github_best="https://raw.githubusercontent.com"
  fi
  
  log_info ""
  gitee_best=$(test_gitee_mirrors)
  if [[ $? -eq 0 ]]; then
    log_success "最佳 Gitee 镜像源: $gitee_best"
  else
    log_warning "未找到可用的 Gitee 镜像源"
    gitee_best="https://gitee.com"
  fi
  
  log_info ""
  log_info "======================================"
  log_success "网络优化检测完成"
  
  # 生成优化配置
  generate_optimization_config "$npm_best" "$github_best" "$gitee_best"
  
  # 保存配置到文件
  local config_file="${HOME}/.openclaw-network-optimization.conf"
  cat > "$config_file" <<EOF
# OpenClaw CN 网络优化配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
NPM_REGISTRY="$npm_best"
NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"
GITHUB_MIRROR="$github_best"
GITEE_MIRROR="$gitee_best"
EOF
  
  log_success "配置已保存到: $config_file"
  log_info "使用方式: source $config_file"
}

# 运行模式判断
case "${1:-}" in
  "--help"|"-h")
    cat <<'EOF'
OpenClaw CN 网络源优化脚本

用法:
  ./optimize-network-sources.sh          # 运行完整优化检测
  ./optimize-network-sources.sh --help   # 显示帮助

功能:
  1. 自动测试多个 npm 镜像源（npmmirror、腾讯云、淘宝、npmjs）
  2. 测试 GitHub 镜像源（raw.githubusercontent、ghproxy、fastgit）
  3. 测试 Gitee 镜像源
  4. 基于响应时间推荐最佳镜像源
  5. 生成优化配置和环境变量
  6. 保存配置到 ~/.openclaw-network-optimization.conf

集成到 install-cn.sh:
  在安装前运行此脚本获取最佳配置，或直接在 install-cn.sh 中调用。

环境变量:
  脚本会输出最佳的环境变量配置，可直接复制使用。

EOF
    exit 0
    ;;
  *)
    main
    ;;
esac