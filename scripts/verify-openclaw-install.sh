#!/usr/bin/env bash
set -euo pipefail

# Verify OpenClaw CLI install sanity (no gateway required)
# Usage:
#   ./scripts/verify-openclaw-install.sh

fail() {
  echo "[verify-openclaw-install] ERROR: $*" >&2
  exit 1
}

info() {
  echo "[verify-openclaw-install] $*"
}

info "node: $(command -v node || echo MISSING)"
info "npm:  $(command -v npm || echo MISSING)"

if command -v node >/dev/null 2>&1; then
  info "node -v: $(node -v || true)"
fi
if command -v npm >/dev/null 2>&1; then
  info "npm  -v: $(npm -v || true)"
  # npm v10 removed `npm bin` command. Use prefix -g and derive bin path.
  NPM_PREFIX_G="$(npm prefix -g 2>/dev/null || npm config get prefix 2>/dev/null || true)"
  info "npm prefix (-g): ${NPM_PREFIX_G}"
  if [[ -n "${NPM_PREFIX_G}" ]]; then
    info "npm global bin (derived): ${NPM_PREFIX_G%/}/bin"
  fi
fi

echo
info "openclaw: $(command -v openclaw || echo MISSING)"

if ! command -v openclaw >/dev/null 2>&1; then
  cat >&2 <<'TXT'
[verify-openclaw-install] 'openclaw' not found in PATH.

Tips:
- Reopen your shell (PATH may not refresh in old shells)
- Ensure your npm global bin directory is on PATH
- If you installed with sudo, try: sudo env "PATH=$PATH" openclaw --version

If you are in mainland CN, consider:
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
TXT
  exit 2
fi

# Keep output minimal but verifiable
OPENCLAW_VER="$(openclaw --version 2>/dev/null || true)"
if [[ -z "$OPENCLAW_VER" ]]; then
  fail "openclaw exists but --version returned empty"
fi
info "openclaw --version: $OPENCLAW_VER"

cat <<'TXT'

Next checks (optional):
  openclaw status
  openclaw models status
TXT
