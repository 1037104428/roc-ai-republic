#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN quick install (v0)
# - Prefer npm from domestic registry (npmmirror)
# - Then run basic onboarding hints

NPM_REGISTRY_DEFAULT="https://registry.npmmirror.com"

if command -v npm >/dev/null 2>&1; then
  echo "[cn-pack] npm found: $(npm -v)"
else
  echo "[cn-pack] npm not found. Please install Node.js >= 20 first." >&2
  exit 1
fi

REG="${NPM_REGISTRY:-$NPM_REGISTRY_DEFAULT}"

echo "[cn-pack] Using npm registry: $REG"

npm config set registry "$REG" >/dev/null

# Install OpenClaw globally
npm i -g openclaw@latest

echo "[cn-pack] Installed. Check: openclaw --version"

echo "[cn-pack] Next steps:"
cat <<'TXT'
1) Create/verify config: ~/.openclaw/openclaw.json
2) Add DeepSeek provider snippet (see docs/openclaw-cn-pack-deepseek-v0.md)
3) Start gateway: openclaw gateway start
TXT
