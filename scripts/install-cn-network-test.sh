#!/usr/bin/env bash
set -euo pipefail

# Network connectivity test for CN installer
# Tests npm registry reachability and helps choose the best registry

NPM_REGISTRY_CN="https://registry.npmmirror.com"
NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"
GITHUB_RAW="https://raw.githubusercontent.com"
GITEE_RAW="https://gitee.com"

test_url() {
  local url="$1"
  local timeout="${2:-5}"
  
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time "$timeout" "$url" >/dev/null 2>&1 && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout="$timeout" --tries=1 -O /dev/null "$url" >/dev/null 2>&1 && return 0
  fi
  return 1
}

test_npm_registry() {
  local registry="$1"
  echo -n "Testing npm registry: $registry ... "
  
  # Test registry ping endpoint
  if test_url "$registry/-/ping" 3; then
    echo "✓ OK"
    return 0
  else
    echo "✗ FAILED"
    return 1
  fi
}

test_github_gitee() {
  echo -n "Testing GitHub raw ... "
  if test_url "$GITHUB_RAW/openclaw/openclaw/main/package.json" 5; then
    echo "✓ OK"
    GITHUB_OK=1
  else
    echo "✗ SLOW/FAILED"
    GITHUB_OK=0
  fi
  
  echo -n "Testing Gitee raw ... "
  if test_url "$GITEE_RAW/junkaiWang324/roc-ai-republic/raw/main/README.md" 5; then
    echo "✓ OK"
    GITEE_OK=1
  else
    echo "✗ SLOW/FAILED"
    GITEE_OK=0
  fi
}

recommend_registry() {
  echo ""
  echo "=== Network Test Results ==="
  
  if test_npm_registry "$NPM_REGISTRY_CN"; then
    echo "✅ Recommended: Use CN registry ($NPM_REGISTRY_CN)"
    echo "   Command: NPM_REGISTRY=$NPM_REGISTRY_CN bash install-cn.sh"
    return 0
  fi
  
  if test_npm_registry "$NPM_REGISTRY_FALLBACK"; then
    echo "⚠️  CN registry unavailable, using fallback ($NPM_REGISTRY_FALLBACK)"
    echo "   Command: NPM_REGISTRY=$NPM_REGISTRY_FALLBACK bash install-cn.sh"
    return 1
  fi
  
  echo "❌ No npm registry reachable. Check network connectivity."
  return 2
}

main() {
  echo "OpenClaw CN Installer - Network Connectivity Test"
  echo "=================================================="
  
  # Check for curl/wget
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "Error: Need curl or wget for network tests"
    echo "Installing curl is recommended:"
    echo "  Ubuntu/Debian: sudo apt install curl"
    echo "  CentOS/RHEL: sudo yum install curl"
    echo "  macOS: brew install curl"
    exit 1
  fi
  
  test_github_gitee
  recommend_registry
  
  echo ""
  echo "=== Installation Tips ==="
  if [[ "$GITHUB_OK" -eq 0 && "$GITEE_OK" -eq 1 ]]; then
    echo "• GitHub may be slow, using Gitee mirror for docs/scripts"
    echo "• Example: curl -fsSL https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/install-cn.sh | bash"
  fi
  
  if [[ "$GITHUB_OK" -eq 1 && "$GITEE_OK" -eq 1 ]]; then
    echo "• Both GitHub and Gitee accessible"
    echo "• Default script: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
  fi
  
  echo ""
  echo "For manual install with specific registry:"
  echo "  NPM_REGISTRY=https://registry.npmmirror.com npm install -g openclaw"
  echo "  or"
  echo "  NPM_REGISTRY=https://registry.npmjs.org npm install -g openclaw"
}

main "$@"