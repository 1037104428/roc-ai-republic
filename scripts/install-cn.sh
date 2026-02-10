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

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"
OPENCLAW_VERSION_DEFAULT="latest"

usage() {
  cat <<'TXT'
[cn-pack] OpenClaw CN installer

Options:
  --version <ver>          Install a specific OpenClaw version (default: latest)
  --registry-cn <url>      CN npm registry (default: https://registry.npmmirror.com)
  --registry-fallback <u>  Fallback npm registry (default: https://registry.npmjs.org)
  --network-test           Run network connectivity test before install
  --network-optimize       Run advanced network optimization (detect best mirrors)
  --force-cn               Force using CN registry (skip fallback)
  --dry-run                Print commands without executing
  -h, --help               Show help

Env vars (equivalent):
  OPENCLAW_VERSION, NPM_REGISTRY, NPM_REGISTRY_FALLBACK, OPENCLAW_VERIFY_SCRIPT
TXT
}

DRY_RUN=0
NETWORK_TEST=0
NETWORK_OPTIMIZE=0
FORCE_CN=0
VERSION="${OPENCLAW_VERSION:-$OPENCLAW_VERSION_DEFAULT}"
REG_CN="${NPM_REGISTRY:-$NPM_REGISTRY_CN_DEFAULT}"
REG_FALLBACK="${NPM_REGISTRY_FALLBACK:-$NPM_REGISTRY_FALLBACK_DEFAULT}"

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
    --network-optimize)
      NETWORK_OPTIMIZE=1; shift ;;
    --force-cn)
      FORCE_CN=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[cn-pack] Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$REG_CN" || -z "$REG_FALLBACK" ]]; then
  echo "[cn-pack] Missing required values." >&2
  usage
  exit 2
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
    if curl -fsS -m 5 "$REG_CN" >/dev/null 2>&1; then
      echo "[cn-pack] ✅ CN registry reachable: $REG_CN"
    else
      echo "[cn-pack] ⚠️ CN registry not reachable (will try fallback): $REG_CN"
    fi
  else
    echo "[cn-pack] ℹ️ curl not found, skipping network check"
  fi
fi

install_openclaw() {
  local reg="$1"
  local attempt="$2"
  echo "[cn-pack] Installing openclaw@${VERSION} via registry: $reg (attempt: $attempt)"
  # no-audit/no-fund: faster & quieter, especially on slow networks
  if run npm i -g "openclaw@${VERSION}" --registry "$reg" --no-audit --no-fund; then
    return 0
  else
    echo "[cn-pack] Install attempt failed via registry: $reg" >&2
    return 1
  fi
}

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

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[cn-pack] Dry-run done (no changes made)."
  exit 0
fi

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

# Auto-run verification if verification script is available
if [[ $DRY_RUN -eq 0 ]]; then
  # Determine verification script path
  VERIFY_SCRIPT="${OPENCLAW_VERIFY_SCRIPT:-}"
  if [[ -z "$VERIFY_SCRIPT" ]]; then
    # Try default paths
    if [[ -f "./scripts/verify-openclaw-install.sh" ]]; then
      VERIFY_SCRIPT="./scripts/verify-openclaw-install.sh"
    elif [[ -f "/tmp/verify-openclaw-install.sh" ]]; then
      VERIFY_SCRIPT="/tmp/verify-openclaw-install.sh"
    fi
  fi
  
  if [[ -n "$VERIFY_SCRIPT" ]] && [[ -f "$VERIFY_SCRIPT" ]]; then
    echo ""
    echo "[cn-pack] Running automatic installation verification using: $VERIFY_SCRIPT"
    echo "[cn-pack] ========================================="
    
    # Make verification script executable
    chmod +x "$VERIFY_SCRIPT" 2>/dev/null || true
    
    # Run verification with quiet mode for clean output
    if "$VERIFY_SCRIPT" --quiet; then
      echo "[cn-pack] ✅ Installation verified successfully!"
    else
      echo "[cn-pack] ⚠️ Verification found issues. Run '$VERIFY_SCRIPT' for details."
    fi
    
    echo "[cn-pack] ========================================="
  else
    echo ""
    echo "[cn-pack] ℹ️ Verification script not found. Skipping automatic verification."
    echo "[cn-pack] ℹ️ To enable verification, set OPENCLAW_VERIFY_SCRIPT=/path/to/verify-openclaw-install.sh"
    echo "[cn-pack] ℹ️ Or download the verification script:"
    echo "[cn-pack] ℹ️   curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-openclaw-install.sh -o /tmp/verify-openclaw-install.sh"
  fi
fi
