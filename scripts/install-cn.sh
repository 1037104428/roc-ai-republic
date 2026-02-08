#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN quick install
# Goals:
# - Prefer a mainland-friendly npm registry (npmmirror)
# - Fallback to npmjs if install fails
# - Do NOT permanently change user's npm registry config
# - Self-check: openclaw --version

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"

if command -v npm >/dev/null 2>&1; then
  echo "[cn-pack] npm found: $(npm -v)"
else
  echo "[cn-pack] npm not found. Please install Node.js >= 20 first." >&2
  exit 1
fi

REG_CN="${NPM_REGISTRY:-$NPM_REGISTRY_CN_DEFAULT}"
REG_FALLBACK="${NPM_REGISTRY_FALLBACK:-$NPM_REGISTRY_FALLBACK_DEFAULT}"

install_openclaw() {
  local reg="$1"
  echo "[cn-pack] Installing via registry: $reg"
  npm i -g openclaw@latest --registry "$reg"
}

if install_openclaw "$REG_CN"; then
  echo "[cn-pack] Install OK via CN registry."
else
  echo "[cn-pack] Install failed via CN registry; retrying with fallback: $REG_FALLBACK" >&2
  install_openclaw "$REG_FALLBACK"
fi

# Self-check
if command -v openclaw >/dev/null 2>&1; then
  echo "[cn-pack] Installed. Check: $(openclaw --version)"
else
  echo "[cn-pack] Install finished but 'openclaw' not found in PATH." >&2
  echo "[cn-pack] Tips: reopen your shell, or ensure your npm global bin is on PATH." >&2
  echo "[cn-pack] npm prefix: $(npm config get prefix 2>/dev/null || true)" >&2
  exit 2
fi

echo "[cn-pack] Next steps:"
cat <<'TXT'
1) Create/verify config: ~/.openclaw/openclaw.json
2) Add DeepSeek provider snippet (see docs/openclaw-cn-pack-deepseek-v0.md)
3) Start gateway: openclaw gateway start
4) Verify: openclaw status && openclaw models status
TXT
