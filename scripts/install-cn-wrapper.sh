#!/usr/bin/env bash
set -euo pipefail

# Wrapper script that provides the best installation experience
# Uses enhanced installer if available, falls back to basic installer

SCRIPT_URL="https://clawdrepublic.cn/install-cn.sh"
ENHANCED_SCRIPT_URL="https://clawdrepublic.cn/install-cn-enhanced.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[installer]${NC} $*"; }
log_success() { echo -e "${GREEN}[installer] ✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}[installer] ⚠${NC} $*"; }
log_error() { echo -e "${RED}[installer] ✗${NC} $*" >&2; }

# Check if we have curl or wget
check_network_tool() {
  if command -v curl >/dev/null 2>&1; then
    echo "curl"
  elif command -v wget >/dev/null 2>&1; then
    echo "wget"
  else
    echo "none"
  fi
}

# Download script
download_script() {
  local url="$1"
  local tool="$2"
  
  case "$tool" in
    curl)
      curl -fsSL "$url"
      ;;
    wget)
      wget -qO- "$url"
      ;;
    *)
      log_error "No network tool available (curl or wget)"
      return 1
      ;;
  esac
}

# Try enhanced installer first, fallback to basic
main() {
  log "OpenClaw Installer Wrapper"
  log "Checking for enhanced installer..."
  
  local tool=$(check_network_tool)
  if [[ "$tool" == "none" ]]; then
    log_error "Please install curl or wget first:"
    log "  Ubuntu/Debian: sudo apt install curl"
    log "  CentOS/RHEL: sudo yum install curl"
    log "  macOS: brew install curl"
    exit 1
  fi
  
  # Try enhanced installer
  log "Trying enhanced installer..."
  if download_script "$ENHANCED_SCRIPT_URL" "$tool" | bash -s -- "$@"; then
    log_success "Enhanced installer completed successfully"
    exit 0
  else
    log_warn "Enhanced installer failed or not available"
    log "Falling back to basic installer..."
    
    if download_script "$SCRIPT_URL" "$tool" | bash -s -- "$@"; then
      log_success "Basic installer completed successfully"
      exit 0
    else
      log_error "Both installers failed"
      log "Manual installation steps:"
      log "1. Install Node.js >=20: https://nodejs.org/"
      log "2. Install OpenClaw: npm i -g openclaw"
      log "3. Verify: openclaw --version"
      exit 1
    fi
  fi
}

# Pass all arguments to the installer
main "$@"