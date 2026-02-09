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
  --dry-run                Print commands without executing
  -h, --help               Show help

Env vars (equivalent):
  OPENCLAW_VERSION, NPM_REGISTRY, NPM_REGISTRY_FALLBACK
TXT
}

DRY_RUN=0
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
