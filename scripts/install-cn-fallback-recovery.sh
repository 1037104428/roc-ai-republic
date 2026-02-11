#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN Install Fallback Recovery Script
# Purpose: Provide recovery mechanisms when main install-cn.sh fails
# Usage: bash install-cn-fallback-recovery.sh [--cleanup | --retry | --diagnose]

SCRIPT_VERSION="2026.02.12.0429"
SCRIPT_NAME="install-cn-fallback-recovery.sh"

# Color logging
color_log() {
  local level="$1"
  local message="$2"
  local color=""
  
  case "$level" in
    "INFO") color="\033[0;34m" ;;
    "SUCCESS") color="\033[0;32m" ;;
    "WARNING") color="\033[0;33m" ;;
    "ERROR") color="\033[0;31m" ;;
    "DEBUG") color="\033[0;90m" ;;
    *) color="\033[0m" ;;
  esac
  
  echo -e "${color}[${level}] ${message}\033[0m"
}

log_info() { color_log "INFO" "$1"; }
log_success() { color_log "SUCCESS" "$1"; }
log_warning() { color_log "WARNING" "$1"; }
log_error() { color_log "ERROR" "$1"; }

# Check if OpenClaw is already installed
check_openclaw_installed() {
  if command -v openclaw >/dev/null 2>&1; then
    log_info "OpenClaw is already installed: $(openclaw --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi
  return 1
}

# Clean up failed installation
cleanup_failed_install() {
  log_info "Starting cleanup of failed OpenClaw installation..."
  
  # Remove npm global package if exists
  if npm list -g openclaw >/dev/null 2>&1; then
    log_info "Removing global npm package..."
    npm uninstall -g openclaw || true
  fi
  
  # Remove nvm installation if exists
  if [ -d "$HOME/.nvm/versions/node" ]; then
    log_info "Checking for nvm installations..."
    find "$HOME/.nvm/versions/node" -name "openclaw" -type d 2>/dev/null | while read dir; do
      log_info "Removing: $dir"
      rm -rf "$dir" 2>/dev/null || true
    done
  fi
  
  # Remove symlinks
  for link in /usr/local/bin/openclaw /usr/bin/openclaw "$HOME/.local/bin/openclaw"; do
    if [ -L "$link" ]; then
      log_info "Removing symlink: $link"
      rm -f "$link" 2>/dev/null || true
    fi
  done
  
  # Remove config directories
  for dir in "$HOME/.openclaw" "$HOME/.config/openclaw" "/etc/openclaw"; do
    if [ -d "$dir" ]; then
      log_info "Backing up and removing config directory: $dir"
      mv "$dir" "${dir}.bak.$(date +%s)" 2>/dev/null || true
    fi
  done
  
  log_success "Cleanup completed. Ready for fresh installation."
}

# Diagnose installation issues
diagnose_issues() {
  log_info "Running installation diagnostics..."
  
  echo -e "\n=== System Information ==="
  uname -a
  echo -e "\n=== Node.js Information ==="
  command -v node >/dev/null 2>&1 && node --version || echo "Node.js not found"
  command -v npm >/dev/null 2>&1 && npm --version || echo "npm not found"
  command -v nvm >/dev/null 2>&1 && echo "nvm available" || echo "nvm not found"
  
  echo -e "\n=== Network Connectivity ==="
  for url in "https://registry.npmjs.com" "https://registry.npmmirror.com" "https://github.com" "https://gitee.com"; do
    if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
      echo "✓ $url is reachable"
    else
      echo "✗ $url is NOT reachable"
    fi
  done
  
  echo -e "\n=== Disk Space ==="
  df -h "$HOME" 2>/dev/null || df -h / 2>/dev/null
  
  echo -e "\n=== Current OpenClaw Status ==="
  if check_openclaw_installed; then
    echo "OpenClaw is already installed"
  else
    echo "OpenClaw is not installed"
  fi
  
  log_info "Diagnostics completed. Check above for potential issues."
}

# Retry installation with different strategies
retry_installation() {
  log_info "Starting retry installation with fallback strategies..."
  
  # Strategy 1: Try with npmmirror
  log_info "Strategy 1: Using npmmirror registry..."
  NPM_REGISTRY=https://registry.npmmirror.com bash -c '
    curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  ' && {
    log_success "Strategy 1 succeeded!"
    return 0
  }
  
  # Strategy 2: Try with npmjs
  log_info "Strategy 2: Using npmjs registry..."
  NPM_REGISTRY=https://registry.npmjs.com bash -c '
    curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  ' && {
    log_success "Strategy 2 succeeded!"
    return 0
  }
  
  # Strategy 3: Direct npm install
  log_info "Strategy 3: Direct npm install..."
  npm install -g openclaw && {
    log_success "Strategy 3 succeeded!"
    return 0
  }
  
  log_error "All retry strategies failed"
  return 1
}

# Main function
main() {
  local action="${1:-diagnose}"
  
  case "$action" in
    --cleanup|-c)
      cleanup_failed_install
      ;;
    --retry|-r)
      retry_installation
      ;;
    --diagnose|-d)
      diagnose_issues
      ;;
    --help|-h)
      echo "Usage: $SCRIPT_NAME [OPTION]"
      echo ""
      echo "Options:"
      echo "  --cleanup, -c    Clean up failed installation"
      echo "  --retry, -r      Retry installation with fallback strategies"
      echo "  --diagnose, -d   Diagnose installation issues (default)"
      echo "  --help, -h       Show this help message"
      echo ""
      echo "Examples:"
      echo "  $SCRIPT_NAME --cleanup   # Clean up failed installation"
      echo "  $SCRIPT_NAME --retry     # Retry installation"
      echo "  $SCRIPT_NAME             # Run diagnostics"
      ;;
    *)
      log_error "Unknown option: $action"
      echo "Use --help for usage information"
      return 1
      ;;
  esac
}

# Run main function
main "$@"
