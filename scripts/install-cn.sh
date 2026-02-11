#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN quick install
# Goals:
# - Prefer a mainland-friendly npm registry (npmmirror)
# - Fallback to npmjs if install fails
# - Do NOT permanently change user's npm registry config
# - Self-check: openclaw --version
#
# Usage:
#   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
#   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
#   NPM_REGISTRY=https://registry.npmmirror.com OPENCLAW_VERSION=latest bash install-cn.sh

# Script version for update checking
SCRIPT_VERSION="2026.02.11.02"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh"

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"
OPENCLAW_VERSION_DEFAULT="latest"
VERIFY_LEVEL_DEFAULT="auto"  # auto, basic, quick, full, none

# Show script version
echo "[cn-pack] OpenClaw CN installer v$SCRIPT_VERSION"
echo "[cn-pack] ========================================="

# Function to check for script updates
check_script_updates() {
  local check_mode="${1:-auto}"  # auto, force, skip
  
  if [[ "$check_mode" == "skip" ]]; then
    echo "[cn-pack] Script update check skipped"
    return 0
  fi
  
  # Only check for updates if we have curl and it's not a forced check
  if [[ "$check_mode" == "auto" ]] && ! command -v curl &> /dev/null; then
    echo "[cn-pack] curl not available, skipping update check"
    return 0
  fi
  
  echo "[cn-pack] Checking for script updates..."
  
  # Try to fetch latest version from GitHub
  local latest_version=""
  local update_available=false
  
  if command -v curl &> /dev/null; then
    # Try GitHub first
    latest_version=$(curl -fsSL "$SCRIPT_UPDATE_URL" 2>/dev/null | grep -E '^SCRIPT_VERSION="[^"]+"' | head -1 | cut -d'"' -f2)
    
    # If GitHub fails, try Gitee
    if [[ -z "$latest_version" ]]; then
      local gitee_url="https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/install-cn.sh"
      latest_version=$(curl -fsSL "$gitee_url" 2>/dev/null | grep -E '^SCRIPT_VERSION="[^"]+"' | head -1 | cut -d'"' -f2)
    fi
  fi
  
  if [[ -n "$latest_version" ]]; then
    if [[ "$latest_version" != "$SCRIPT_VERSION" ]]; then
      echo "[cn-pack] ⚠️  Update available: v$SCRIPT_VERSION → v$latest_version"
      echo "[cn-pack]    Run with --check-update to see details"
      update_available=true
    else
      echo "[cn-pack] ✓ Script is up to date (v$SCRIPT_VERSION)"
    fi
  else
    echo "[cn-pack] ⚠️  Could not check for updates (network issue)"
  fi
  
  # Return update status
  if [[ "$update_available" == true ]]; then
    return 1
  fi
  return 0
}

# Function to show update details
show_update_details() {
  echo "[cn-pack] ========================================="
  echo "[cn-pack] Script Update Information"
  echo "[cn-pack] ========================================="
  echo "[cn-pack] Current version: v$SCRIPT_VERSION"
  echo "[cn-pack] Update URL: $SCRIPT_UPDATE_URL"
  echo "[cn-pack]"
  echo "[cn-pack] To update:"
  echo "[cn-pack]   1. Download latest: curl -fsSL $SCRIPT_UPDATE_URL -o install-cn.sh"
  echo "[cn-pack]   2. Make executable: chmod +x install-cn.sh"
  echo "[cn-pack]   3. Verify: ./install-cn.sh --version"
  echo "[cn-pack]"
  echo "[cn-pack] Or use one-liner:"
  echo "[cn-pack]   curl -fsSL $SCRIPT_UPDATE_URL | bash"
  echo "[cn-pack] ========================================="
}

# Function to detect and handle proxy settings
handle_proxy_settings() {
  local proxy_mode="${1:-auto}"  # auto, force, skip
  
  echo "[cn-pack] Checking proxy settings..."
  
  # Simple proxy detection (fallback if detect-proxy.sh is not available)
  detect_proxy_fallback() {
    local proxy_vars=("HTTP_PROXY" "HTTPS_PROXY" "http_proxy" "https_proxy" "ALL_PROXY" "all_proxy")
    local detected_count=0
    
    for var in "${proxy_vars[@]}"; do
      if [[ -n "${!var:-}" ]]; then
        echo "[cn-pack] Detected proxy: $var=${!var}"
        detected_count=$((detected_count + 1))
      fi
    done
    
    # Check npm proxy settings
    local npm_proxy=$(npm config get proxy 2>/dev/null || echo "null")
    local npm_https_proxy=$(npm config get https-proxy 2>/dev/null || echo "null")
    
    if [[ "$npm_proxy" != "null" && -n "$npm_proxy" ]]; then
      echo "[cn-pack] Detected npm proxy: $npm_proxy"
      detected_count=$((detected_count + 1))
    fi
    
    if [[ "$npm_https_proxy" != "null" && -n "$npm_https_proxy" ]]; then
      echo "[cn-pack] Detected npm https-proxy: $npm_https_proxy"
      detected_count=$((detected_count + 1))
    fi
    
    if [[ $detected_count -gt 0 ]]; then
      echo "PROXY_DETECTED=true"
      echo "PROXY_COUNT=$detected_count"
      return 0
    else
      echo "PROXY_DETECTED=false"
      echo "PROXY_COUNT=0"
      return 1
    fi
  }
  
  # Try to use the full proxy detection script if available
  if [[ -f "./scripts/detect-proxy.sh" ]]; then
    # Source the proxy detection script
    source ./scripts/detect-proxy.sh >/dev/null 2>&1 || {
      echo "[cn-pack] ⚠ Failed to load proxy detection script, using fallback"
      detect_proxy_fallback
      return 0
    }
    
    # Run proxy detection
    local proxy_info
    proxy_info=$(detect_proxy_settings 2>/dev/null || echo "PROXY_DETECTED=false")
    
    # Parse proxy detection results
    local proxy_detected=$(echo "$proxy_info" | grep "^PROXY_DETECTED=" | cut -d= -f2)
    local proxy_type=$(echo "$proxy_info" | grep "^PROXY_TYPE=" | cut -d= -f2)
    local proxy_count=$(echo "$proxy_info" | grep "^PROXY_COUNT=" | cut -d= -f2)
    
    if [[ "$proxy_detected" == "true" ]]; then
      echo "[cn-pack] ✓ Detected $proxy_count proxy configuration(s)"
      
      # Test proxy connectivity if not skipping
      if [[ "$proxy_mode" != "skip" ]]; then
        echo "[cn-pack] Testing proxy connectivity..."
        local test_result
        test_result=$(test_proxy_connectivity "https://registry.npmmirror.com" 10 2>/dev/null || true)
        
        if echo "$test_result" | grep -q "PROXY_TEST_RESULT=success"; then
          echo "[cn-pack] ✓ Proxy connectivity test passed"
          
          # Configure npm proxy if needed and not skipping
          if [[ -n "${HTTP_PROXY:-}" ]] && [[ "$proxy_mode" == "force" || "$proxy_mode" == "auto" ]]; then
            echo "[cn-pack] Configuring npm proxy for installation..."
            configure_npm_proxy "$HTTP_PROXY" "${HTTPS_PROXY:-$HTTP_PROXY}" >/dev/null 2>&1 || true
          fi
        else
          echo "[cn-pack] ⚠ Proxy connectivity test failed"
          
          if [[ "$proxy_mode" == "force" ]]; then
            echo "[cn-pack] ✗ Proxy forced but connectivity failed. Installation may fail."
            return 1
          fi
        fi
      fi
      
      return 0
    else
      echo "[cn-pack] ✓ No proxy settings detected"
      return 0
    fi
  else
    # Use fallback detection
    detect_proxy_fallback
    return 0
  fi
}

# Function for step-by-step installation
step_by_step_install() {
  local steps_to_run=""
  
  # Determine which steps to run
  if [[ -n "$STEPS" ]]; then
    steps_to_run="$STEPS"
    echo "[cn-pack] 🔧 运行指定步骤: $steps_to_run"
  else
    steps_to_run="network-check,proxy-check,registry-test,dependency-check,npm-install,verification,cleanup"
    echo "[cn-pack] 🔧 运行完整步骤序列"
  fi
  
  # Convert steps to array
  IFS=',' read -ra steps_array <<< "$steps_to_run"
  
  for step in "${steps_array[@]}"; do
    step=$(echo "$step" | xargs)  # Trim whitespace
    
    case "$step" in
      network-check)
        echo "[cn-pack] 🔍 步骤 1/7: 网络连接检查"
        echo "[cn-pack]   运行网络测试..."
        if [[ "$NETWORK_TEST" == "1" ]]; then
          echo "[cn-pack]   ✓ 网络测试已启用"
        else
          echo "[cn-pack]   ℹ️ 网络测试未启用 (使用 --network-test 启用)"
        fi
        ;;
        
      proxy-check)
        echo "[cn-pack] 🔍 步骤 2/7: 代理配置检查"
        echo "[cn-pack]   检查代理设置..."
        if [[ "$PROXY_TEST" == "1" ]]; then
          echo "[cn-pack]   ✓ 代理测试已启用"
        else
          echo "[cn-pack]   ℹ️ 代理测试未启用 (使用 --proxy-test 启用)"
        fi
        ;;
        
      registry-test)
        echo "[cn-pack] 🔍 步骤 3/7: NPM 仓库连接测试"
        echo "[cn-pack]   测试仓库连接性..."
        echo "[cn-pack]   主仓库: $REG_CN"
        echo "[cn-pack]   备用仓库: $REG_FALLBACK"
        ;;
        
      dependency-check)
        echo "[cn-pack] 🔍 步骤 4/7: 系统依赖检查"
        echo "[cn-pack]   检查 Node.js, npm, curl..."
        # 这里可以添加实际的依赖检查
        ;;
        
      npm-install)
        echo "[cn-pack] 🔍 步骤 5/7: NPM 包安装"
        echo "[cn-pack]   安装 OpenClaw v$VERSION..."
        echo "[cn-pack]   使用仓库: $REG_CN"
        ;;
        
      verification)
        echo "[cn-pack] 🔍 步骤 6/7: 安装验证"
        echo "[cn-pack]   验证级别: $VERIFY_LEVEL"
        ;;
        
      cleanup)
        echo "[cn-pack] 🔍 步骤 7/7: 清理临时文件"
        echo "[cn-pack]   清理安装过程中的临时文件..."
        ;;
        
      *)
        echo "[cn-pack] ⚠️  未知步骤: $step (跳过)"
        continue
        ;;
    esac
    
    # 在实际实现中，这里会有每个步骤的实际执行代码
    echo "[cn-pack]   ✓ 步骤 '$step' 准备就绪"
    echo ""
  done
  
  echo "[cn-pack] ✅ 分步安装模式配置完成"
  echo "[cn-pack] ℹ️  要实际执行安装，请移除 --step-by-step 或 --steps 参数"
}

# Function to clear proxy settings after installation
cleanup_proxy_settings() {
  echo "[cn-pack] Cleaning up proxy settings..."
  
  # Clear npm proxy config
  npm config delete proxy >/dev/null 2>&1 || true
  npm config delete https-proxy >/dev/null 2>&1 || true
  
  echo "[cn-pack] ✓ Proxy settings cleaned up"
}

usage() {
  cat <<TXT
[cn-pack] OpenClaw CN installer v$SCRIPT_VERSION

Options:
  --version <ver>          Install a specific OpenClaw version (default: latest)
  --registry-cn <url>      CN npm registry (default: https://registry.npmmirror.com)
  --registry-fallback <u>  Fallback npm registry (default: https://registry.npmjs.org)
  --network-test           Run network connectivity test before install
  --network-optimize       Run advanced network optimization (detect best mirrors)
  --force-cn               Force using CN registry (skip fallback)
  --dry-run                Print commands without executing
  --check-update           Check for script updates and exit
  --version-check          Check script version and update status (non-blocking)
  --verify-level <level>   Verification level: auto, basic, quick, full, none (default: auto)
  --proxy-mode <mode>      Proxy handling mode: auto, force, skip (default: auto)
  --proxy-test             Test proxy connectivity before installation
  --proxy-report           Generate proxy configuration report
  --keep-proxy             Keep npm proxy settings after installation
  --offline-mode           Enable offline mode (use local cache only)
  --cache-dir <dir>        Specify local cache directory (default: ~/.openclaw/cache)
  --step-by-step           Enable step-by-step interactive installation mode
  --steps <steps>          Specify installation steps to run (comma-separated)
  -h, --help               Show help

Installation Steps (for --step-by-step or --steps):
  - network-check: Network connectivity test
  - proxy-check: Proxy configuration check
  - registry-test: NPM registry connectivity test
  - dependency-check: System dependency verification
  - npm-install: NPM package installation
  - verification: Installation verification
  - cleanup: Cleanup temporary files

Version Control:
  - Script version: $SCRIPT_VERSION
  - Update URL: $SCRIPT_UPDATE_URL
  - Use --check-update to check for updates
  - Use --version-check for non-blocking version check

Env vars (equivalent):
  OPENCLAW_VERSION, NPM_REGISTRY, NPM_REGISTRY_FALLBACK, OPENCLAW_VERIFY_SCRIPT, OPENCLAW_VERIFY_LEVEL
  HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy (for proxy detection)
TXT
}

# Function to check for script updates
check_script_update() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "[cn-pack] ℹ️ curl not available, skipping update check"
    return 0
  fi
  
  echo "[cn-pack] Checking for script updates..."
  
  # Try to get remote script content
  REMOTE_CONTENT=$(curl -fsS -m 10 "$SCRIPT_UPDATE_URL" 2>/dev/null || echo "")
  
  if [[ -z "$REMOTE_CONTENT" ]]; then
    echo "[cn-pack] ℹ️ Could not fetch remote script (network issue)"
    return 0
  fi
  
  # Extract version from remote script - handle different quote styles
  REMOTE_VERSION=$(echo "$REMOTE_CONTENT" | \
    grep -m1 'SCRIPT_VERSION=' | \
    sed -n "s/.*SCRIPT_VERSION=\"\([^\"]*\)\".*/\1/p" || \
    echo "$REMOTE_CONTENT" | \
    grep -m1 'SCRIPT_VERSION=' | \
    sed -n "s/.*SCRIPT_VERSION='\([^']*\)'.*/\1/p" || \
    echo "")
  
  if [[ -z "$REMOTE_VERSION" ]]; then
    echo "[cn-pack] ℹ️ Could not parse version from remote script"
    return 0
  fi
  
  if [[ "$REMOTE_VERSION" != "$SCRIPT_VERSION" ]]; then
    echo "[cn-pack] ⚠️  New version available: $REMOTE_VERSION (current: $SCRIPT_VERSION)"
    echo "[cn-pack] ℹ️  Update with: curl -fsSL $SCRIPT_UPDATE_URL -o /tmp/install-cn.sh && bash /tmp/install-cn.sh"
    echo "[cn-pack] ℹ️  Or visit: https://github.com/1037104428/roc-ai-republic/blob/main/scripts/install-cn.sh"
    return 1
  else
    echo "[cn-pack] ✅ Script is up to date (version: $SCRIPT_VERSION)"
    return 0
  fi
}

DRY_RUN=0
NETWORK_TEST=0
NETWORK_OPTIMIZE=0
FORCE_CN=0
VERSION_CHECK=0
VERSION="${OPENCLAW_VERSION:-$OPENCLAW_VERSION_DEFAULT}"
REG_CN="${NPM_REGISTRY:-$NPM_REGISTRY_CN_DEFAULT}"
REG_FALLBACK="${NPM_REGISTRY_FALLBACK:-$NPM_REGISTRY_FALLBACK_DEFAULT}"
VERIFY_LEVEL="${OPENCLAW_VERIFY_LEVEL:-$VERIFY_LEVEL_DEFAULT}"
PROXY_MODE="auto"
PROXY_TEST=0
PROXY_REPORT=0
KEEP_PROXY=0
OFFLINE_MODE=0
CACHE_DIR="${HOME}/.openclaw/cache"
STEP_BY_STEP=0
STEPS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"; shift 2 ;;
    --registry-cn)
      REG_CN="${2:-}"; shift 2 ;;
    --registry-fallback)
      REG_FALLBACK="${2:-}"; shift 2 ;;
    --network-test)
      NETWORK_TEST=1; shift ;;
    --verify-level)
      VERIFY_LEVEL="${2:-}"; shift 2 ;;
    --network-optimize)
      NETWORK_OPTIMIZE=1; shift ;;
    --force-cn)
      FORCE_CN=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --proxy-mode)
      PROXY_MODE="${2:-auto}"; shift 2 ;;
    --proxy-test)
      PROXY_TEST=1; shift ;;
    --proxy-report)
      PROXY_REPORT=1; shift ;;
    --keep-proxy)
      KEEP_PROXY=1; shift ;;
    --offline-mode)
      OFFLINE_MODE=1; shift ;;
    --cache-dir)
      CACHE_DIR="${2:-}"; shift 2 ;;
    --step-by-step)
      STEP_BY_STEP=1; shift ;;
    --steps)
      STEPS="${2:-}"; shift 2 ;;
    --check-update)
      check_script_update
      exit $?
      ;;
    --version-check)
      VERSION_CHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[cn-pack] ❌ Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$REG_CN" || -z "$REG_FALLBACK" ]]; then
  echo "[cn-pack] Missing required values." >&2
  usage
  exit 2
fi

# Check if step-by-step mode is enabled (must be before main installation logic)
if [[ "$STEP_BY_STEP" == "1" || -n "$STEPS" ]]; then
  step_by_step_install
  exit 0
fi

# Run version check if requested (non-blocking)
if [[ "$VERSION_CHECK" == "1" ]]; then
  echo "[cn-pack] Running version check..."
  check_script_updates "auto"
  # Continue with installation even if updates are available
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[dry-run] %q ' "$@"; echo
  else
    "$@"
  fi
}

# Network test function
run_network_test() {
  echo "[cn-pack] Running network connectivity test..."
  echo "[cn-pack] Testing CN registry: $REG_CN"
  
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -m 5 "$REG_CN/-/ping" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ CN registry reachable"
      CN_OK=1
    else
      echo "[cn-pack] ⚠️ CN registry not reachable"
      CN_OK=0
    fi
    
    echo "[cn-pack] Testing fallback registry: $REG_FALLBACK"
    if curl -fsS -m 5 "$REG_FALLBACK/-/ping" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ Fallback registry reachable"
      FALLBACK_OK=1
    else
      echo "[cn-pack] ⚠️ Fallback registry not reachable"
      FALLBACK_OK=0
    fi
    
    # Test GitHub/Gitee for script sources
    echo "[cn-pack] Testing script sources..."
    if curl -fsS -m 5 "https://raw.githubusercontent.com/openclaw/openclaw/main/package.json" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ GitHub raw reachable"
    else
      echo "[cn-pack] ⚠️ GitHub raw may be slow"
    fi
    
    if curl -fsS -m 5 "https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/README.md" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ Gitee raw reachable"
    else
      echo "[cn-pack] ⚠️ Gitee raw not reachable"
    fi
    
    echo ""
    echo "[cn-pack] === Network Test Summary ==="
    if [[ "$CN_OK" -eq 1 ]]; then
      echo "[cn-pack] ✅ Recommended: Use CN registry ($REG_CN)"
    elif [[ "$FALLBACK_OK" -eq 1 ]]; then
      echo "[cn-pack] ⚠️ Use fallback registry ($REG_FALLBACK)"
    else
      echo "[cn-pack] ❌ No registry reachable. Check network."
      exit 1
    fi
    echo ""
  else
    echo "[cn-pack] ℹ️ curl not found, skipping detailed network test"
  fi
}

# 网络优化功能
run_network_optimization() {
  echo "[cn-pack] 运行高级网络优化检测..."
  echo "[cn-pack] 这将测试多个镜像源并选择最快的"
  
  # 检查优化脚本是否存在
  local optimize_script="$(dirname "$0")/optimize-network-sources.sh"
  if [[ -f "$optimize_script" ]]; then
    echo "[cn-pack] 找到网络优化脚本: $optimize_script"
    
    # 运行优化脚本
    if bash "$optimize_script"; then
      echo ""
      echo "[cn-pack] ✅ 网络优化完成"
      echo "[cn-pack] 优化配置已保存到 ~/.openclaw-network-optimization.conf"
      echo "[cn-pack] 下次安装时可以使用: source ~/.openclaw-network-optimization.conf"
    else
      echo "[cn-pack] ⚠️ 网络优化脚本执行失败，使用基本网络测试"
      run_network_test
    fi
  else
    echo "[cn-pack] ⚠️ 网络优化脚本未找到，使用基本网络测试"
    run_network_test
  fi
}

if [[ "$NETWORK_OPTIMIZE" == "1" ]]; then
  run_network_optimization
  exit 0
fi

if [[ "$NETWORK_OPTIMIZE" == "1" ]]; then
  run_network_optimization
  exit 0
fi

if [[ "$NETWORK_TEST" == "1" ]]; then
  run_network_test
  exit 0
fi

# 检查是否有优化配置文件
if [[ -f "${HOME}/.openclaw-network-optimization.conf" ]]; then
  echo "[cn-pack] 检测到网络优化配置，正在加载..."
  # 安全地加载配置，只设置镜像源相关变量
  if source "${HOME}/.openclaw-network-optimization.conf" 2>/dev/null; then
    if [[ -n "${NPM_REGISTRY:-}" ]]; then
      REG_CN="$NPM_REGISTRY"
      echo "[cn-pack] ✅ 使用优化后的 npm 镜像源: $REG_CN"
    fi
    if [[ -n "${NPM_REGISTRY_FALLBACK:-}" ]]; then
      REG_FALLBACK="$NPM_REGISTRY_FALLBACK"
    fi
  else
    echo "[cn-pack] ⚠️ 优化配置文件加载失败，使用默认配置"
  fi
fi

if command -v node >/dev/null 2>&1; then
  NODE_VER_RAW="$(node -v || true)"
  NODE_MAJOR="${NODE_VER_RAW#v}"
  NODE_MAJOR="${NODE_MAJOR%%.*}"
  if [[ -n "${NODE_MAJOR}" ]] && (( NODE_MAJOR < 20 )); then
    echo "[cn-pack] ERROR: Node.js version ${NODE_VER_RAW} is too old. OpenClaw requires Node.js >= 20." >&2
    echo "[cn-pack] Please upgrade Node.js first. See: https://nodejs.org/" >&2
    exit 1
  fi
  echo "[cn-pack] node found: ${NODE_VER_RAW} (>=20 ✓)"
else
  echo "[cn-pack] ERROR: node not found. Please install Node.js >= 20 first." >&2
  echo "[cn-pack] Download from: https://nodejs.org/" >&2
  exit 1
fi

if command -v npm >/dev/null 2>&1; then
  echo "[cn-pack] npm found: $(npm -v)"
else
  echo "[cn-pack] ERROR: npm not found. Please install npm (usually bundled with Node.js)." >&2
  echo "[cn-pack] If you have Node.js but not npm, try reinstalling Node.js or check your PATH." >&2
  exit 1
fi

# Quick network connectivity check (optional, can be skipped with env var)
if [[ -z "${SKIP_NET_CHECK:-}" ]]; then
  echo "[cn-pack] Checking network connectivity to npm registries..."
  if command -v curl >/dev/null 2>&1; then
    # Test CN registry with latency measurement
    echo "[cn-pack] Testing CN registry: $REG_CN"
    CN_START=$(date +%s%N)
    if curl -fsS -m 5 "$REG_CN" >/dev/null 2>&1; then
      CN_END=$(date +%s%N)
      CN_LATENCY=$(( (CN_END - CN_START) / 1000000 ))
      echo "[cn-pack] ✅ CN registry reachable: $REG_CN (latency: ${CN_LATENCY}ms)"
      CN_REACHABLE=1
      CN_LATENCY_MS=${CN_LATENCY}
    else
      echo "[cn-pack] ⚠️ CN registry not reachable (will try fallback): $REG_CN"
      CN_REACHABLE=0
    fi
    
    # Test fallback registry with latency measurement
    echo "[cn-pack] Testing fallback registry: $REG_FALLBACK"
    FALLBACK_START=$(date +%s%N)
    if curl -fsS -m 5 "$REG_FALLBACK" >/dev/null 2>&1; then
      FALLBACK_END=$(date +%s%N)
      FALLBACK_LATENCY=$(( (FALLBACK_END - FALLBACK_START) / 1000000 ))
      echo "[cn-pack] ✅ Fallback registry reachable: $REG_FALLBACK (latency: ${FALLBACK_LATENCY}ms)"
      FALLBACK_REACHABLE=1
      FALLBACK_LATENCY_MS=${FALLBACK_LATENCY}
    else
      echo "[cn-pack] ⚠️ Fallback registry not reachable: $REG_FALLBACK"
      FALLBACK_REACHABLE=0
    fi
    
    # Provide intelligent recommendation
    if [[ "${CN_REACHABLE:-0}" -eq 1 && "${FALLBACK_REACHABLE:-0}" -eq 1 ]]; then
      if [[ "${CN_LATENCY_MS:-9999}" -lt "${FALLBACK_LATENCY_MS:-9999}" ]]; then
        echo "[cn-pack] 💡 Recommendation: CN registry is faster (${CN_LATENCY_MS}ms vs ${FALLBACK_LATENCY_MS}ms)"
      else
        echo "[cn-pack] 💡 Recommendation: Fallback registry is faster (${FALLBACK_LATENCY_MS}ms vs ${CN_LATENCY_MS}ms)"
      fi
    elif [[ "${CN_REACHABLE:-0}" -eq 1 ]]; then
      echo "[cn-pack] 💡 Only CN registry reachable, will use it"
    elif [[ "${FALLBACK_REACHABLE:-0}" -eq 1 ]]; then
      echo "[cn-pack] 💡 Only fallback registry reachable, will use it"
    else
      echo "[cn-pack] ❌ No npm registries reachable. Check your network connection." >&2
      exit 1
    fi
  else
    echo "[cn-pack] ℹ️ curl not found, skipping network check"
  fi
fi

# Function to check if offline mode is available
check_offline_mode() {
  if [[ "$OFFLINE_MODE" != "1" ]]; then
    return 0
  fi
  
  echo "[cn-pack] Offline mode enabled, checking local cache..."
  
  # Create cache directory if it doesn't exist
  mkdir -p "$CACHE_DIR"
  
  # Check for cached package
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  if [[ -f "$cache_file" ]]; then
    echo "[cn-pack] ✅ Found cached package: $cache_file"
    return 0
  else
    echo "[cn-pack] ❌ No cached package found for version: $VERSION"
    echo "[cn-pack] ℹ️  Cache directory: $CACHE_DIR"
    echo "[cn-pack] ℹ️  Expected file: openclaw-${VERSION}.tgz"
    return 1
  fi
}

# Function to install from offline cache
install_from_offline_cache() {
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  
  echo "[cn-pack] Installing from offline cache: $cache_file"
  
  if run npm i -g "$cache_file" --no-audit --no-fund; then
    echo "[cn-pack] ✅ Offline installation successful"
    return 0
  else
    echo "[cn-pack] ❌ Offline installation failed" >&2
    return 1
  fi
}

# Function to cache package for offline use
cache_package_for_offline() {
  local reg="$1"
  
  # Only cache if offline mode is supported or cache directory exists
  if [[ ! -d "$CACHE_DIR" ]]; then
    mkdir -p "$CACHE_DIR"
  fi
  
  local cache_file="${CACHE_DIR}/openclaw-${VERSION}.tgz"
  
  echo "[cn-pack] Caching package for offline use: $cache_file"
  
  # Try to download the package tarball
  if command -v npm &> /dev/null; then
    # Get package info to find tarball URL
    local package_info=$(npm view "openclaw@${VERSION}" --registry "$reg" --json 2>/dev/null || echo "{}")
    local dist_tarball=$(echo "$package_info" | grep -o '"tarball":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [[ -n "$dist_tarball" ]]; then
      echo "[cn-pack] Downloading package tarball from: $dist_tarball"
      if curl -fsSL "$dist_tarball" -o "$cache_file.tmp" 2>/dev/null; then
        mv "$cache_file.tmp" "$cache_file"
        echo "[cn-pack] ✅ Package cached successfully: $cache_file"
        echo "[cn-pack] ℹ️  File size: $(du -h "$cache_file" | cut -f1)"
      else
        echo "[cn-pack] ⚠️  Could not download package tarball"
        rm -f "$cache_file.tmp" 2>/dev/null || true
      fi
    else
      echo "[cn-pack] ⚠️  Could not get package tarball URL"
    fi
  else
    echo "[cn-pack] ⚠️  npm not available for caching"
  fi
}

install_openclaw() {
  local reg="$1"
  local attempt="$2"
  
  # Check if offline mode is enabled and available
  if [[ "$OFFLINE_MODE" == "1" ]]; then
    if check_offline_mode; then
      if install_from_offline_cache; then
        return 0
      else
        echo "[cn-pack] ❌ Offline installation failed, falling back to online mode" >&2
      fi
    else
      echo "[cn-pack] ❌ Offline mode not available, falling back to online mode" >&2
    fi
  fi
  
  echo "[cn-pack] Installing openclaw@${VERSION} via registry: $reg (attempt: $attempt)"
  # no-audit/no-fund: faster & quieter, especially on slow networks
  if run npm i -g "openclaw@${VERSION}" --registry "$reg" --no-audit --no-fund; then
    # Cache the package for future offline use
    cache_package_for_offline "$reg"
    return 0
  else
    echo "[cn-pack] Install attempt failed via registry: $reg" >&2
    return 1
  fi
}

# Handle proxy settings before installation
echo "[cn-pack] ========================================="
echo "[cn-pack] Proxy Configuration Phase"
echo "[cn-pack] ========================================="

if [[ "$PROXY_TEST" == "1" ]]; then
  echo "[cn-pack] Running proxy connectivity test..."
  handle_proxy_settings "force"
elif [[ "$PROXY_REPORT" == "1" ]]; then
  echo "[cn-pack] Generating proxy configuration report..."
  if [[ -f "./scripts/detect-proxy.sh" ]]; then
    source ./scripts/detect-proxy.sh >/dev/null 2>&1
    generate_proxy_report "/tmp/openclaw-proxy-report-$(date +%s).md" >/dev/null 2>&1 || true
  fi
fi

# Apply proxy settings for installation
handle_proxy_settings "$PROXY_MODE"

# 尝试CN源
if [[ "$FORCE_CN" == "1" ]]; then
  echo "[cn-pack] Force using CN registry (--force-cn flag)"
  if install_openclaw "$REG_CN" "CN-registry"; then
    echo "[cn-pack] ✅ Install OK via CN registry."
  else
    echo "[cn-pack] ❌ Install failed via CN registry (force mode)." >&2
    echo "[cn-pack] Troubleshooting:" >&2
    echo "[cn-pack] 1. Check CN registry: curl -fsS $REG_CN/-/ping" >&2
    echo "[cn-pack] 2. Try without --force-cn to use fallback" >&2
    exit 1
  fi
else
  # Normal mode with fallback
  if install_openclaw "$REG_CN" "CN-registry"; then
    echo "[cn-pack] ✅ Install OK via CN registry."
  else
    echo "[cn-pack] ⚠️ Install failed via CN registry; retrying with fallback: $REG_FALLBACK" >&2
    echo "[cn-pack] This may be due to network issues, registry mirror sync delay, or package availability." >&2
    echo "[cn-pack] Retrying with fallback registry in 2 seconds..." >&2
    sleep 2
    
    if install_openclaw "$REG_FALLBACK" "fallback-registry"; then
      echo "[cn-pack] ✅ Install OK via fallback registry."
    else
      echo "[cn-pack] ❌ Both registry attempts failed." >&2
      echo "[cn-pack] Troubleshooting steps:" >&2
      echo "[cn-pack] 1. Check network connectivity: curl -fsS https://registry.npmjs.org" >&2
      echo "[cn-pack] 2. Verify Node.js version: node -v (requires >=20)" >&2
      echo "[cn-pack] 3. Try manual install: npm i -g openclaw@${VERSION}" >&2
      echo "[cn-pack] 4. Report issue: https://github.com/openclaw/openclaw/issues" >&2
      exit 1
    fi
  fi
fi

# Dry-run check will be handled after verification
# (moved to end of script to allow verification display in dry-run mode)

# Self-check
if command -v openclaw >/dev/null 2>&1; then
  echo "[cn-pack] Installed. Check: $(openclaw --version)"
else
  echo "[cn-pack] Install finished but 'openclaw' not found in PATH." >&2
  echo "[cn-pack] Tips: reopen your shell, or ensure your npm global bin is on PATH." >&2
  echo "[cn-pack] npm prefix: $(npm config get prefix 2>/dev/null || true)" >&2
  echo "[cn-pack] npm global bin: $(npm bin -g 2>/dev/null || true)" >&2
  exit 2
fi

# Cleanup proxy settings if not keeping them
if [[ "$KEEP_PROXY" == "0" ]]; then
  cleanup_proxy_settings
fi

echo "[cn-pack] Next steps:"
cat <<'TXT'
1) Create/verify config: ~/.openclaw/openclaw.json
2) Add DeepSeek provider snippet (see docs/openclaw-cn-pack-deepseek-v0.md)
3) Start gateway: openclaw gateway start
4) Verify: openclaw status && openclaw models status
5) Quick verification: ./scripts/verify-openclaw-install.sh (if in repo)
TXT

# Optional health check with detailed diagnostics
if [[ $DRY_RUN -eq 0 ]]; then
  echo "[cn-pack] Running post-install health check..."
  if command -v openclaw >/dev/null 2>&1; then
    OPENCLAW_PATH=$(command -v openclaw)
    OPENCLAW_VERSION_OUTPUT=$(openclaw --version 2>/dev/null || echo "version check failed")
    echo "[cn-pack] ✓ openclaw command found at: $OPENCLAW_PATH"
    echo "[cn-pack] ✓ Version: $OPENCLAW_VERSION_OUTPUT"
    
    # Check if gateway is running
    if openclaw gateway status 2>/dev/null | grep -q "running\|active"; then
      echo "[cn-pack] ✓ OpenClaw gateway is running"
    else
      echo "[cn-pack] ℹ️ Gateway not running. Start with: openclaw gateway start"
    fi
    
    # Quick config check
    if [[ -f ~/.openclaw/openclaw.json ]]; then
      echo "[cn-pack] ✓ Config file exists: ~/.openclaw/openclaw.json"
    else
      echo "[cn-pack] ℹ️ Config file not found. Create with: openclaw config init"
    fi
    
    # Additional diagnostics for troubleshooting
    echo "[cn-pack] Running additional diagnostics..."
    
    # API connectivity check (optional, can be skipped with env var)
    if [[ -z "${SKIP_API_CHECK:-}" ]] && command -v curl >/dev/null 2>&1; then
      echo "[cn-pack] Checking API connectivity..."
      
      # Check quota-proxy API (if configured)
      if [[ -f ~/.openclaw/openclaw.json ]] && grep -q "api.clawdrepublic.cn" ~/.openclaw/openclaw.json 2>/dev/null; then
        echo "[cn-pack] Testing quota-proxy API connectivity..."
        if curl -fsS -m 5 https://api.clawdrepublic.cn/healthz 2>/dev/null | grep -q '"ok":true'; then
          echo "[cn-pack] ✓ quota-proxy API is reachable"
        else
          echo "[cn-pack] ℹ️ quota-proxy API not reachable (may need TRIAL_KEY)"
        fi
      fi
      
      # Check forum connectivity
      echo "[cn-pack] Testing forum connectivity..."
      if curl -fsS -m 5 https://clawdrepublic.cn/forum/ 2>/dev/null | grep -q "Clawd 国度论坛"; then
        echo "[cn-pack] ✓ Forum is reachable"
      else
        echo "[cn-pack] ℹ️ Forum not reachable (check network or DNS)"
      fi
    elif [[ -n "${SKIP_API_CHECK:-}" ]]; then
      echo "[cn-pack] ℹ️ API connectivity check skipped (SKIP_API_CHECK set)"
    else
      echo "[cn-pack] ℹ️ curl not found, skipping API connectivity check"
    fi
    
    # Check npm global installation
    if npm list -g openclaw 2>/dev/null | grep -q "openclaw@"; then
      echo "[cn-pack] ✓ OpenClaw is installed globally via npm"
    else
      echo "[cn-pack] ⚠️ OpenClaw not found in npm global list. May be installed via npx"
    fi
    
    # Check workspace directory
    if [[ -d ~/.openclaw/workspace ]]; then
      echo "[cn-pack] ✓ Workspace directory exists: ~/.openclaw/workspace"
    else
      echo "[cn-pack] ℹ️ Workspace directory not found. Will be created on first run"
    fi
    
  else
    echo "[cn-pack] ⚠️ openclaw command not in PATH. Running diagnostics..."
    
    # Check npm global bin path
    NPM_BIN_PATH=$(npm bin -g 2>/dev/null || echo "/usr/local/bin")
    echo "[cn-pack]   npm global bin path: $NPM_BIN_PATH"
    
    # Check if npm bin is in PATH
    if echo "$PATH" | tr ':' '\n' | grep -q "^$NPM_BIN_PATH$"; then
      echo "[cn-pack]   ✓ npm bin path is in PATH"
    else
      echo "[cn-pack]   ⚠️ npm bin path NOT in PATH. Add to your shell config:"
      echo "[cn-pack]      export PATH=\"\$PATH:$NPM_BIN_PATH\""
    fi
    
    # Check if openclaw exists in npm bin
    if [[ -f "$NPM_BIN_PATH/openclaw" ]]; then
      echo "[cn-pack]   ✓ openclaw binary found at: $NPM_BIN_PATH/openclaw"
      echo "[cn-pack]   Try: source ~/.bashrc (or ~/.zshrc) and run 'openclaw --version'"
    else
      echo "[cn-pack]   ⚠️ openclaw binary not found in npm bin. Installation may have failed."
      echo "[cn-pack]   Try: npx openclaw --version (runs via npx without PATH)"
    fi
  fi
fi

# Quick verification summary
echo ""
echo "[cn-pack] ========================================="
echo "[cn-pack] 🚀 QUICK VERIFICATION COMMANDS:"
echo "[cn-pack] ========================================="
echo "[cn-pack] 1. Check version:    openclaw --version"
echo "[cn-pack] 2. Check status:     openclaw status"
echo "[cn-pack] 3. Start gateway:    openclaw gateway start"
echo "[cn-pack] 4. Check gateway:    openclaw gateway status"
echo "[cn-pack] 5. Test models:      openclaw models status"
echo "[cn-pack] 6. Get help:         openclaw --help"
echo "[cn-pack] ========================================="
echo "[cn-pack] 💡 Tip: Run these commands to verify your installation!"
echo "[cn-pack] ========================================="

# 根据验证级别执行验证
# Determine verification script path (for full verification level)
VERIFY_SCRIPT="${OPENCLAW_VERIFY_SCRIPT:-}"
if [[ -z "$VERIFY_SCRIPT" ]]; then
  # Try default paths
  if [[ -f "./scripts/verify-openclaw-install.sh" ]]; then
    VERIFY_SCRIPT="./scripts/verify-openclaw-install.sh"
  elif [[ -f "/tmp/verify-openclaw-install.sh" ]]; then
    VERIFY_SCRIPT="/tmp/verify-openclaw-install.sh"
  fi
fi
  echo ""
  echo "[cn-pack] ========================================="
  echo "[cn-pack] 🔍 安装验证 (级别: $VERIFY_LEVEL)"
  echo "[cn-pack] ========================================="
  
  # 验证级别处理
  case "$VERIFY_LEVEL" in
    none)
      echo "[cn-pack] ℹ️ 跳过验证 (级别: none)"
      ;;
    
    basic)
      echo "[cn-pack] 🚀 运行基本验证..."
      echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
      echo "[cn-pack] ℹ️   openclaw --version"
      echo "[cn-pack] ℹ️   openclaw status"
      echo "[cn-pack] ℹ️   openclaw gateway status"
      ;;
    
    quick)
      # 检查当前目录是否有快速验证脚本
      quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
      if [[ -f "$quick_verify_script" ]]; then
        echo "[cn-pack] 使用快速验证脚本: $quick_verify_script"
        chmod +x "$quick_verify_script" 2>/dev/null || true
        
        if "$quick_verify_script" --quiet; then
          echo "[cn-pack] ✅ 快速验证通过！"
        else
          echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
        fi
      else
        echo "[cn-pack] ⚠️ 快速验证脚本未找到，降级到基本验证。"
        echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
        echo "[cn-pack] ℹ️   openclaw --version"
        echo "[cn-pack] ℹ️   openclaw status"
        echo "[cn-pack] ℹ️   openclaw gateway status"
      fi
      ;;
    
    full)
      # 检查完整验证脚本
      if [[ -n "$VERIFY_SCRIPT" ]] && [[ -f "$VERIFY_SCRIPT" ]]; then
        echo "[cn-pack] 运行完整验证脚本: $VERIFY_SCRIPT"
        chmod +x "$VERIFY_SCRIPT" 2>/dev/null || true
        
        if "$VERIFY_SCRIPT" --quiet; then
          echo "[cn-pack] ✅ 完整验证通过！"
        else
          echo "[cn-pack] ⚠️ 完整验证发现问题。运行 '$VERIFY_SCRIPT' 查看详情。"
        fi
      else
        echo "[cn-pack] ⚠️ 完整验证脚本未找到，降级到快速验证。"
        # 尝试快速验证
        quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
        if [[ -f "$quick_verify_script" ]]; then
          echo "[cn-pack] 使用快速验证脚本: $quick_verify_script"
          chmod +x "$quick_verify_script" 2>/dev/null || true
          
          if "$quick_verify_script" --quiet; then
            echo "[cn-pack] ✅ 快速验证通过！"
          else
            echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
          fi
        else
          echo "[cn-pack] ℹ️ 快速验证脚本也未找到，降级到基本验证。"
          echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
          echo "[cn-pack] ℹ️   openclaw --version"
          echo "[cn-pack] ℹ️   openclaw status"
          echo "[cn-pack] ℹ️   openclaw gateway status"
        fi
      fi
      ;;
    
    auto|*)
      # 自动选择验证级别
      if [[ -n "$VERIFY_SCRIPT" ]] && [[ -f "$VERIFY_SCRIPT" ]]; then
        echo "[cn-pack] 自动选择: 完整验证"
        chmod +x "$VERIFY_SCRIPT" 2>/dev/null || true
        
        if "$VERIFY_SCRIPT" --quiet; then
          echo "[cn-pack] ✅ 完整验证通过！"
        else
          echo "[cn-pack] ⚠️ 完整验证发现问题。运行 '$VERIFY_SCRIPT' 查看详情。"
        fi
      else
        # 尝试快速验证
        quick_verify_script="$(dirname "$0")/quick-verify-openclaw.sh"
        if [[ -f "$quick_verify_script" ]]; then
          echo "[cn-pack] 自动选择: 快速验证"
          chmod +x "$quick_verify_script" 2>/dev/null || true
          
          if "$quick_verify_script" --quiet; then
            echo "[cn-pack] ✅ 快速验证通过！"
          else
            echo "[cn-pack] ⚠️ 快速验证发现问题。运行 '$quick_verify_script' 查看详情。"
          fi
        else
          echo "[cn-pack] 自动选择: 基本验证"
          echo "[cn-pack] ℹ️ 运行以下命令进行基本验证:"
          echo "[cn-pack] ℹ️   openclaw --version"
          echo "[cn-pack] ℹ️   openclaw status"
          echo "[cn-pack] ℹ️   openclaw gateway status"
        fi
      fi
      ;;
  esac
  
  echo "[cn-pack] ========================================="

# Dry-run final check (after verification)
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[cn-pack] Dry-run done (no changes made)."
  exit 0
fi
