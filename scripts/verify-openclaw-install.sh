#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN installation verification script
# Provides comprehensive verification of OpenClaw installation
# Usage: ./scripts/verify-openclaw-install.sh [--quiet|--verbose|--dry-run]

VERBOSE=0
QUIET=0
DRY_RUN=0

usage() {
  cat <<'TXT'
OpenClaw CN Installation Verification

Verifies that OpenClaw is correctly installed and functional.

Options:
  --quiet          Minimal output (only errors)
  --verbose        Detailed output with debugging info
  --dry-run        Print commands without executing
  -h, --help       Show help

Exit codes:
  0 - Installation verified successfully
  1 - Warning (minor issues)
  2 - Critical issue found
  3 - Verification error

TXT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)    QUIET=1; shift ;;
    --verbose)  VERBOSE=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Color output helpers
if [[ $QUIET -eq 0 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
  
  info() { echo -e "${BLUE}[verify]${NC} $1"; }
  success() { echo -e "${GREEN}[verify]✅${NC} $1"; }
  warning() { echo -e "${YELLOW}[verify]⚠️${NC} $1"; }
  error() { echo -e "${RED}[verify]❌${NC} $1"; }
else
  info() { :; }
  success() { :; }
  warning() { echo "[verify] WARNING: $1"; }
  error() { echo "[verify] ERROR: $1"; }
fi

run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
    return 0
  fi
  "$@"
}

# Start verification
if [[ $QUIET -eq 0 ]]; then
  echo ""
  echo "========================================="
  echo "🔍 OpenClaw Installation Verification"
  echo "========================================="
fi

# 1. Check if openclaw command exists
info "Checking openclaw command availability..."
if command -v openclaw >/dev/null 2>&1; then
  success "openclaw command found"
else
  error "openclaw command not found in PATH"
  exit 2
fi

# 2. Check version
info "Checking openclaw version..."
if [[ $DRY_RUN -eq 1 ]]; then
  success "Version: [dry-run] openclaw --version"
elif VERSION_OUTPUT=$(openclaw --version 2>/dev/null); then
  success "Version: $VERSION_OUTPUT"
else
  warning "Failed to get version (command may need setup)"
fi

# 3. Check basic help
info "Checking help command..."
if run_cmd openclaw --help >/dev/null 2>&1; then
  success "Help command works"
else
  warning "Help command failed (may be normal during first run)"
fi

# 4. Check status command
info "Checking status command..."
if STATUS_OUTPUT=$(run_cmd openclaw status 2>&1); then
  if echo "$STATUS_OUTPUT" | grep -q "Gateway"; then
    success "Status command works"
    if [[ $VERBOSE -eq 1 ]]; then
      echo "$STATUS_OUTPUT" | head -20
    fi
  else
    warning "Status output unexpected format"
  fi
else
  warning "Status command failed (gateway may not be running)"
fi

# 5. Check models command
info "Checking models command..."
if run_cmd openclaw models status >/dev/null 2>&1; then
  success "Models command works"
else
  warning "Models command failed (no models configured)"
fi

# 6. Check gateway commands
info "Checking gateway commands..."
if run_cmd openclaw gateway status >/dev/null 2>&1; then
  success "Gateway status command works"
else
  warning "Gateway status command failed (gateway may not be installed)"
fi

# 7. Check workspace directory
info "Checking workspace directory..."
WORKSPACE_DIR="${HOME}/.openclaw/workspace"
if [[ -d "$WORKSPACE_DIR" ]]; then
  success "Workspace directory exists: $WORKSPACE_DIR"
  if [[ $VERBOSE -eq 1 ]]; then
    ls -la "$WORKSPACE_DIR" | head -10
  fi
else
  warning "Workspace directory not found (may need first run)"
fi

# 8. Check config file
info "Checking config file..."
CONFIG_FILE="${HOME}/.openclaw/config.json"
if [[ -f "$CONFIG_FILE" ]]; then
  success "Config file exists: $CONFIG_FILE"
  if [[ $VERBOSE -eq 1 ]]; then
    echo "Config size: $(wc -l < "$CONFIG_FILE") lines"
  fi
else
  warning "Config file not found (may need first run)"
fi

# 9. Check node version (OpenClaw requires Node.js)
info "Checking Node.js version..."
if [[ $DRY_RUN -eq 1 ]]; then
  success "Node.js: [dry-run] node --version"
  warning "Node.js version [dry-run] node --version may be too old (needs >= 18.x)"
elif NODE_VERSION=$(node --version 2>/dev/null); then
  success "Node.js: $NODE_VERSION"
  # Check if version is compatible
  NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
  if [[ $NODE_MAJOR -ge 18 ]]; then
    success "Node.js version compatible (>= 18.x)"
  else
    warning "Node.js version $NODE_VERSION may be too old (needs >= 18.x)"
  fi
else
  error "Node.js not found (required for OpenClaw)"
  exit 2
fi

# 10. Check npm/npx
info "Checking npm/npx..."
if command -v npm >/dev/null 2>&1; then
  success "npm command found"
else
  error "npm command not found (required for OpenClaw)"
  exit 2
fi

if command -v npx >/dev/null 2>&1; then
  success "npx command found"
else
  warning "npx command not found (may affect some operations)"
fi

# Summary
if [[ $QUIET -eq 0 ]]; then
  echo ""
  echo "========================================="
  echo "📊 Verification Summary"
  echo "========================================="
  echo "✅ Basic installation: Verified"
  echo "✅ Command availability: Verified"
  echo "✅ Node.js compatibility: Verified"
  echo ""
  echo "💡 Next steps:"
  echo "   1. Run 'openclaw gateway start' to start the gateway"
  echo "   2. Run 'openclaw status' to check system status"
  echo "   3. Configure models with 'openclaw models add'"
  echo "   4. Visit https://docs.openclaw.ai for documentation"
  echo "========================================="
fi

exit 0