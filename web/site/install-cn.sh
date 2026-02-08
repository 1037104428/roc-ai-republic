#!/usr/bin/env bash
set -euo pipefail

# Public-facing one-liner installer for China mainland.
# Used by: https://clawdrepublic.cn/install-cn.sh

NPM_REGISTRY_DEFAULT="https://registry.npmmirror.com"

if ! command -v npm >/dev/null 2>&1; then
  echo "[clawd] npm not found. Please install Node.js >= 20 first." >&2
  exit 1
fi

REG="${NPM_REGISTRY:-$NPM_REGISTRY_DEFAULT}"

echo "[clawd] Using npm registry: $REG"
npm config set registry "$REG" >/dev/null
npm i -g openclaw@latest

echo "[clawd] Installed: $(openclaw --version 2>/dev/null || true)"
echo "[clawd] Next: openclaw onboard"
