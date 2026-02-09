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

install_openclaw() {
  local reg="$1"
  echo "[cn-pack] Installing openclaw@${VERSION} via registry: $reg"
  # no-audit/no-fund: faster & quieter, especially on slow networks
  run npm i -g "openclaw@${VERSION}" --registry "$reg" --no-audit --no-fund
}

if install_openclaw "$REG_CN"; then
  echo "[cn-pack] Install OK via CN registry."
else
  echo "[cn-pack] Install failed via CN registry; retrying with fallback: $REG_FALLBACK" >&2
  install_openclaw "$REG_FALLBACK"
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
