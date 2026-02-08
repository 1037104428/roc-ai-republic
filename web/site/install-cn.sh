#!/usr/bin/env bash
set -euo pipefail

# Public-facing one-liner installer for China mainland.
# Used by: https://clawdrepublic.cn/install-cn.sh
# Note: do NOT modify user's npm registry config globally.

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"

if ! command -v npm >/dev/null 2>&1; then
  echo "[clawd] npm not found. Please install Node.js >= 20 first." >&2
  exit 1
fi

REG_CN="${NPM_REGISTRY:-$NPM_REGISTRY_CN_DEFAULT}"
REG_FALLBACK="${NPM_REGISTRY_FALLBACK:-$NPM_REGISTRY_FALLBACK_DEFAULT}"

install_openclaw() {
  local reg="$1"
  echo "[clawd] Installing via registry: $reg"
  npm i -g openclaw@latest --registry "$reg"
}

if install_openclaw "$REG_CN"; then
  :
else
  echo "[clawd] CN registry failed; retrying with fallback: $REG_FALLBACK" >&2
  install_openclaw "$REG_FALLBACK"
fi

if command -v openclaw >/dev/null 2>&1; then
  echo "[clawd] Installed: $(openclaw --version)"
else
  echo "[clawd] Installed but 'openclaw' not found in PATH. Try reopening your shell." >&2
  echo "[clawd] npm prefix: $(npm config get prefix 2>/dev/null || true)" >&2
  exit 2
fi

echo "[clawd] Next: openclaw onboard"
