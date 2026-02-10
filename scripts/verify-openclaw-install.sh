#!/usr/bin/env bash
set -euo pipefail

# OpenClaw installation verification script
# This script verifies that OpenClaw is properly installed and functional
# Usage: ./scripts/verify-openclaw-install.sh [--detailed] [--quiet]

DETAILED=0
QUIET=0
VERBOSE=0

usage() {
  cat <<'TXT'
OpenClaw Installation Verification Script

Verifies that OpenClaw is properly installed and functional.

Options:
  --detailed    Run detailed diagnostics (network, API, config checks)
  --quiet       Only output errors and final summary
  --verbose     Show all diagnostic information
  -h, --help    Show this help message

Examples:
  ./scripts/verify-openclaw-install.sh
  ./scripts/verify-openclaw-install.sh --detailed
  ./scripts/verify-openclaw-install.sh --quiet
TXT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --detailed)
      DETAILED=1; shift ;;
    --quiet)
      QUIET=1; shift ;;
    --verbose)
      VERBOSE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

log() {
  if [[ "$QUIET" == "0" ]]; then
    echo "$@"
  fi
}

log_error() {
  echo "❌ $@" >&2
}

log_success() {
  if [[ "$QUIET" == "0" ]]; then
    echo "✅ $@"
  fi
}

log_info() {
  if [[ "$VERBOSE" == "1" ]] || [[ "$DETAILED" == "1" ]]; then
    echo "ℹ️  $@"
  fi
}

log_header() {
  if [[ "$QUIET" == "0" ]]; then
    echo ""
    echo "=== $@ ==="
  fi
}

# Initialize results
PASSED=0
FAILED=0
WARNINGS=0

check() {
  local name="$1"
  shift
  
  if "$@" >/dev/null 2>&1; then
    log_success "$name"
    ((PASSED++))
    return 0
  else
    log_error "$name"
    ((FAILED++))
    return 1
  fi
}

warn() {
  local name="$1"
  shift
  
  if "$@" >/dev/null 2>&1; then
    log_success "$name"
    ((PASSED++))
    return 0
  else
    log_info "$name (warning)"
    ((WARNINGS++))
    return 1
  fi
}

# Start verification
log_header "OpenClaw Installation Verification"
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log ""

# 1. Basic command checks
log_header "1. Basic Command Checks"

check "openclaw command exists" command -v openclaw

if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_PATH=$(command -v openclaw)
  log_info "OpenClaw path: $OPENCLAW_PATH"
  
  check "openclaw --version works" openclaw --version
  
  VERSION_OUTPUT=$(openclaw --version 2>/dev/null || echo "unknown")
  log_info "Version: $VERSION_OUTPUT"
  
  # Check if it's a recent version
  if echo "$VERSION_OUTPUT" | grep -q "openclaw"; then
    log_success "Valid OpenClaw version detected"
    ((PASSED++))
  else
    log_error "Invalid version output: $VERSION_OUTPUT"
    ((FAILED++))
  fi
fi

# 2. Gateway status
log_header "2. Gateway Status"

if command -v openclaw >/dev/null 2>&1; then
  if openclaw gateway status 2>/dev/null | grep -q "running\|active"; then
    log_success "Gateway is running"
    ((PASSED++))
  else
    warn "Gateway is not running (expected after fresh install)"
  fi
fi

# 3. Configuration
log_header "3. Configuration"

if [[ -f ~/.openclaw/openclaw.json ]]; then
  log_success "Config file exists: ~/.openclaw/openclaw.json"
  ((PASSED++))
  
  # Check config syntax
  if command -v jq >/dev/null 2>&1; then
    if jq empty ~/.openclaw/openclaw.json 2>/dev/null; then
      log_success "Config file has valid JSON syntax"
      ((PASSED++))
    else
      log_error "Config file has invalid JSON syntax"
      ((FAILED++))
    fi
  else
    log_info "jq not installed, skipping JSON syntax check"
  fi
else
  warn "Config file not found (expected after first run)"
fi

# 4. Workspace
log_header "4. Workspace"

if [[ -d ~/.openclaw/workspace ]]; then
  log_success "Workspace directory exists"
  ((PASSED++))
  
  # Check for important workspace files
  if [[ -f ~/.openclaw/workspace/AGENTS.md ]]; then
    log_success "AGENTS.md exists in workspace"
    ((PASSED++))
  else
    log_info "AGENTS.md not found (will be created)"
  fi
else
  warn "Workspace directory not found (will be created on first run)"
fi

# 5. Detailed diagnostics (optional)
if [[ "$DETAILED" == "1" ]]; then
  log_header "5. Detailed Diagnostics"
  
  # Check npm installation
  if command -v npm >/dev/null 2>&1; then
    log_info "npm version: $(npm -v)"
    
    if npm list -g openclaw 2>/dev/null | grep -q "openclaw@"; then
      log_success "OpenClaw is installed globally via npm"
      ((PASSED++))
    else
      log_info "OpenClaw not in npm global list (may be via npx)"
    fi
  fi
  
  # Check Node.js version
  if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v)
    log_info "Node.js version: $NODE_VERSION"
    
    # Extract major version
    NODE_MAJOR="${NODE_VERSION#v}"
    NODE_MAJOR="${NODE_MAJOR%%.*}"
    
    if [[ -n "$NODE_MAJOR" ]] && (( NODE_MAJOR >= 20 )); then
      log_success "Node.js >= 20 (required)"
      ((PASSED++))
    else
      log_error "Node.js version too old (requires >= 20)"
      ((FAILED++))
    fi
  fi
  
  # Network connectivity checks
  if command -v curl >/dev/null 2>&1; then
    log_info "Checking network connectivity..."
    
    # Check npm registries
    if curl -fsS -m 5 "https://registry.npmmirror.com/-/ping" >/dev/null 2>&1; then
      log_success "CN npm registry reachable"
      ((PASSED++))
    else
      log_info "CN npm registry not reachable"
    fi
    
    if curl -fsS -m 5 "https://registry.npmjs.org/-/ping" >/dev/null 2>&1; then
      log_success "npmjs registry reachable"
      ((PASSED++))
    else
      log_info "npmjs registry not reachable"
    fi
    
    # Check quota-proxy API (if configured)
    if [[ -f ~/.openclaw/openclaw.json ]] && grep -q "api.clawdrepublic.cn" ~/.openclaw/openclaw.json 2>/dev/null; then
      log_info "Checking quota-proxy API..."
      if curl -fsS -m 5 "https://api.clawdrepublic.cn/healthz" 2>/dev/null | grep -q '"ok":true'; then
        log_success "quota-proxy API reachable"
        ((PASSED++))
      else
        log_info "quota-proxy API not reachable (may need TRIAL_KEY)"
      fi
    fi
  else
    log_info "curl not available, skipping network checks"
  fi
  
  # Check PATH
  log_info "PATH analysis:"
  echo "$PATH" | tr ':' '\n' | grep -E "(npm|node|bin)" | while read -r path; do
    if [[ -d "$path" ]]; then
      log_info "  $path"
    fi
  done
fi

# Summary
log_header "Verification Summary"
log "Passed: $PASSED"
log "Failed: $FAILED"
log "Warnings: $WARNINGS"

if [[ "$FAILED" -eq 0 ]]; then
  if [[ "$WARNINGS" -eq 0 ]]; then
    log_success "✅ All checks passed! OpenClaw is properly installed."
    exit 0
  else
    log_success "✅ Core installation is functional (with $WARNINGS warnings)."
    exit 0
  fi
else
  log_error "❌ Installation verification failed ($FAILED errors)."
  
  # Provide troubleshooting tips
  if [[ "$QUIET" == "0" ]]; then
    echo ""
    echo "Troubleshooting tips:"
    echo "1. If 'openclaw' command not found:"
    echo "   - Check npm global bin path: npm bin -g"
    echo "   - Add to PATH: export PATH=\"\$PATH:\$(npm bin -g)\""
    echo "   - Restart your shell"
    echo ""
    echo "2. If gateway not running:"
    echo "   - Start it: openclaw gateway start"
    echo "   - Check logs: openclaw gateway logs"
    echo ""
    echo "3. If config file missing:"
    echo "   - Initialize config: openclaw config init"
    echo ""
    echo "4. For network issues:"
    echo "   - Run: ./scripts/install-cn.sh --network-test"
    echo "   - Check firewall/proxy settings"
  fi
  
  exit 1
fi