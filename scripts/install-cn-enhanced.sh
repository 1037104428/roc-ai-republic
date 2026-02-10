#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN enhanced installer
# Enhanced features:
# 1. Auto-detect and install missing dependencies (curl, wget)
# 2. Better network diagnostics with multiple fallback sources
# 3. Platform-specific installation guidance
# 4. Comprehensive post-install verification
# 5. Troubleshooting guide with actionable steps

NPM_REGISTRY_CN_DEFAULT="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK_DEFAULT="https://registry.npmjs.org"
OPENCLAW_VERSION_DEFAULT="latest"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[cn-pack]${NC} $*"; }
log_success() { echo -e "${GREEN}[cn-pack] ✓${NC} $*"; }
log_warn() { echo -e "${YELLOW}[cn-pack] ⚠${NC} $*"; }
log_error() { echo -e "${RED}[cn-pack] ✗${NC} $*" >&2; }

usage() {
  cat <<'TXT'
[cn-pack] OpenClaw CN enhanced installer

Features:
• Auto-installs missing dependencies (curl/wget)
• Multi-fallback network strategy
• Platform detection & guidance
• Comprehensive post-install verification
• Built-in troubleshooting guide

Options:
  --version <ver>          Install a specific OpenClaw version (default: latest)
  --registry-cn <url>      CN npm registry (default: https://registry.npmmirror.com)
  --registry-fallback <u>  Fallback npm registry (default: https://registry.npmjs.org)
  --network-test           Run network connectivity test before install
  --force-cn               Force using CN registry (skip fallback)
  --dry-run                Print commands without executing
  --install-deps           Auto-install missing dependencies (curl/wget)
  --skip-deps              Skip dependency checks
  -h, --help               Show help

Env vars (equivalent):
  OPENCLAW_VERSION, NPM_REGISTRY, NPM_REGISTRY_FALLBACK
TXT
}

DRY_RUN=0
NETWORK_TEST=0
FORCE_CN=0
INSTALL_DEPS=0
SKIP_DEPS=0
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
    --network-test)
      NETWORK_TEST=1; shift ;;
    --force-cn)
      FORCE_CN=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --install-deps)
      INSTALL_DEPS=1; shift ;;
    --skip-deps)
      SKIP_DEPS=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      log_error "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$REG_CN" || -z "$REG_FALLBACK" ]]; then
  log_error "Missing required values."
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

# Detect platform
detect_platform() {
  local os="unknown"
  local pkg_manager="unknown"
  
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    os="${ID:-unknown}"
  elif [[ "$(uname)" == "Darwin" ]]; then
    os="macos"
  elif [[ "$(uname)" == "Linux" ]]; then
    os="linux"
  fi
  
  case "$os" in
    ubuntu|debian|linuxmint)
      pkg_manager="apt"
      ;;
    centos|rhel|fedora|rocky|almalinux)
      pkg_manager="yum"
      ;;
    arch|manjaro)
      pkg_manager="pacman"
      ;;
    macos)
      pkg_manager="brew"
      ;;
    *)
      pkg_manager="unknown"
      ;;
  esac
  
  echo "$os:$pkg_manager"
}

# Check and install dependencies
check_dependencies() {
  local missing_deps=()
  
  # Check for curl or wget
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing_deps+=("curl_or_wget")
  fi
  
  # Check for Node.js
  if ! command -v node >/dev/null 2>&1; then
    missing_deps+=("nodejs")
  fi
  
  # Check for npm
  if ! command -v npm >/dev/null 2>&1; then
    missing_deps+=("npm")
  fi
  
  if [[ ${#missing_deps[@]} -eq 0 ]]; then
    return 0
  fi
  
  log_warn "Missing dependencies: ${missing_deps[*]}"
  
  if [[ "$INSTALL_DEPS" == "1" ]]; then
    log_info "Attempting to install missing dependencies..."
    local platform_info=$(detect_platform)
    local os="${platform_info%%:*}"
    local pkg_manager="${platform_info##*:}"
    
    for dep in "${missing_deps[@]}"; do
      case "$dep" in
        curl_or_wget)
          log_info "Installing curl..."
          case "$pkg_manager" in
            apt) run sudo apt update && run sudo apt install -y curl ;;
            yum) run sudo yum install -y curl ;;
            pacman) run sudo pacman -Sy --noconfirm curl ;;
            brew) run brew install curl ;;
            *)
              log_error "Unknown package manager: $pkg_manager"
              log_info "Please install curl manually:"
              log_info "  Ubuntu/Debian: sudo apt install curl"
              log_info "  CentOS/RHEL: sudo yum install curl"
              log_info "  macOS: brew install curl"
              return 1
              ;;
          esac
          ;;
        nodejs)
          log_info "Installing Node.js..."
          case "$pkg_manager" in
            apt)
              run curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
              run sudo apt install -y nodejs
              ;;
            yum)
              run curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
              run sudo yum install -y nodejs
              ;;
            pacman)
              run sudo pacman -Sy --noconfirm nodejs
              ;;
            brew)
              run brew install node@20
              ;;
            *)
              log_error "Unknown package manager: $pkg_manager"
              log_info "Please install Node.js >=20 manually from: https://nodejs.org/"
              return 1
              ;;
          esac
          ;;
        npm)
          # npm usually comes with Node.js
          log_info "npm should be installed with Node.js. If missing, try reinstalling Node.js."
          ;;
      esac
    done
    
    # Verify installations
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
      log_success "Network tool installed"
    else
      log_error "Failed to install network tool"
      return 1
    fi
    
    if command -v node >/dev/null 2>&1; then
      log_success "Node.js installed: $(node -v)"
    else
      log_error "Failed to install Node.js"
      return 1
    fi
    
    if command -v npm >/dev/null 2>&1; then
      log_success "npm installed: $(npm -v)"
    else
      log_warn "npm not found. Some Node.js installations don't include npm."
    fi
    
    return 0
  else
    log_info "To auto-install dependencies, run with: --install-deps"
    log_info "Or install manually:"
    for dep in "${missing_deps[@]}"; do
      case "$dep" in
        curl_or_wget) log_info "  • curl or wget (for downloading)" ;;
        nodejs) log_info "  • Node.js >=20 (from https://nodejs.org/)" ;;
        npm) log_info "  • npm (usually bundled with Node.js)" ;;
      esac
    done
    return 1
  fi
}

# Enhanced network test
run_network_test() {
  log_info "Running comprehensive network diagnostics..."
  
  local test_urls=(
    "$REG_CN/-/ping"
    "$REG_FALLBACK/-/ping"
    "https://raw.githubusercontent.com/openclaw/openclaw/main/package.json"
    "https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/README.md"
    "https://clawdrepublic.cn/"
    "https://api.clawdrepublic.cn/healthz"
  )
  
  local test_names=(
    "CN npm registry"
    "Fallback npm registry"
    "GitHub raw (package info)"
    "Gitee raw (mirror)"
    "Clawd Republic website"
    "API health endpoint"
  )
  
  local results=()
  
  for i in "${!test_urls[@]}"; do
    local url="${test_urls[$i]}"
    local name="${test_names[$i]}"
    
    if curl -fsS -m 5 "$url" >/dev/null 2>&1; then
      results+=("✅ $name: Reachable")
    else
      results+=("⚠️  $name: Unreachable")
    fi
  done
  
  log_info "=== Network Diagnostic Results ==="
  for result in "${results[@]}"; do
    echo "  $result"
  done
  
  # Summary and recommendations
  log_info "=== Recommendations ==="
  if echo "${results[0]}" | grep -q "✅"; then
    log_success "CN registry is reachable - recommended for fastest install"
  elif echo "${results[1]}" | grep -q "✅"; then
    log_warn "CN registry unreachable, but fallback is available - install will work"
  else
    log_error "No npm registries reachable. Check your network connection."
    return 1
  fi
}

# Main installation function
install_openclaw() {
  local reg="$1"
  local attempt="$2"
  log_info "Installing openclaw@${VERSION} via registry: $reg (attempt: $attempt)"
  
  # Additional npm flags for better experience
  local npm_flags="--registry $reg --no-audit --no-fund --loglevel=error"
  
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] npm i -g openclaw@${VERSION} $npm_flags"
    return 0
  fi
  
  if npm i -g "openclaw@${VERSION}" $npm_flags; then
    return 0
  else
    log_error "Install attempt failed via registry: $reg"
    return 1
  fi
}

# Post-install verification
verify_installation() {
  log_info "Verifying installation..."
  
  if ! command -v openclaw >/dev/null 2>&1; then
    log_error "'openclaw' command not found in PATH"
    log_info "Troubleshooting steps:"
    log_info "1. Check npm global bin path: $(npm bin -g 2>/dev/null || echo 'unknown')"
    log_info "2. Add npm global bin to PATH:"
    log_info "   echo 'export PATH=\"\$PATH:\$(npm bin -g)\"' >> ~/.bashrc"
    log_info "3. Restart your shell or run: source ~/.bashrc"
    return 1
  fi
  
  local version_output
  if version_output=$(openclaw --version 2>&1); then
    log_success "OpenClaw installed: $version_output"
    return 0
  else
    log_error "Failed to get OpenClaw version"
    log_info "Output: $version_output"
    return 1
  fi
}

# Show troubleshooting guide
show_troubleshooting() {
  cat <<'TXT'

=== Troubleshooting Guide ===

Common issues and solutions:

1. "node: command not found"
   • Install Node.js >=20 from https://nodejs.org/
   • Or use: --install-deps (auto-install)

2. "npm: command not found"
   • Usually comes with Node.js. Reinstall Node.js.
   • On some systems: sudo apt install npm

3. Network timeouts
   • Try: --network-test to diagnose
   • Use: --force-cn to force CN registry
   • Or: --registry-cn <alternative-cn-registry>

4. Permission errors
   • Use: sudo npm i -g openclaw (not recommended)
   • Better: Fix npm permissions: https://docs.npmjs.com/resolving-eacces-permissions-errors

5. "openclaw: command not found" after install
   • Check: npm bin -g (add to PATH if needed)
   • Restart your terminal

6. Still having issues?
   • Report: https://github.com/openclaw/openclaw/issues
   • Forum: https://clawdrepublic.cn/forum/
TXT
}

# Main execution
main() {
  log_info "OpenClaw CN Enhanced Installer v1.0"
  log_info "Version: $VERSION | CN Registry: $REG_CN"
  
  # Check dependencies
  if [[ "$SKIP_DEPS" == "0" ]]; then
    if ! check_dependencies; then
      log_error "Dependency check failed"
      show_troubleshooting
      exit 1
    fi
  fi
  
  # Network test if requested
  if [[ "$NETWORK_TEST" == "1" ]]; then
    run_network_test
    exit 0
  fi
  
  # Installation
  if [[ "$FORCE_CN" == "1" ]]; then
    log_info "Force using CN registry (--force-cn flag)"
    if install_openclaw "$REG_CN" "CN-registry"; then
      log_success "Install successful via CN registry"
    else
      log_error "Install failed via CN registry (force mode)"
      show_troubleshooting
      exit 1
    fi
  else
    # Normal mode with fallback
    if install_openclaw "$REG_CN" "CN-registry"; then
      log_success "Install successful via CN registry"
    else
      log_warn "CN registry failed, trying fallback: $REG_FALLBACK"
      sleep 2
      
      if install_openclaw "$REG_FALLBACK" "fallback-registry"; then
        log_success "Install successful via fallback registry"
      else
        log_error "Both registry attempts failed"
        show_troubleshooting
        exit 1
      fi
    fi
  fi
  
  # Verification
  if verify_installation; then
    log_success "=== Installation Complete ==="
    cat <<'TXT'
Next steps:
1. Configure OpenClaw: ~/.openclaw/openclaw.json
2. Add DeepSeek provider (see docs)
3. Start: openclaw gateway start
4. Verify: openclaw status
5. Get TRIAL_KEY: https://clawdrepublic.cn/forum/

For help: https://clawdrepublic.cn/forum/c/help
TXT
  else
    log_warn "Installation may have issues"
    show_troubleshooting
    exit 1
  fi
}

main "$@"