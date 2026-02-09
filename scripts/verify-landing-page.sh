#!/usr/bin/env bash
set -euo pipefail

# Verify landing page deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_url() {
    local url="$1"
    local description="$2"
    
    log_info "Checking $description: $url"
    
    if curl -fsS -m 10 "$url" > /dev/null 2>&1; then
        log_info "  ✓ $description is accessible"
        return 0
    else
        log_error "  ✗ $description is NOT accessible"
        return 1
    fi
}

check_content() {
    local url="$1"
    local pattern="$2"
    local description="$3"
    
    log_info "Checking $description content: $url"
    
    if curl -fsS -m 10 "$url" 2>/dev/null | grep -q "$pattern"; then
        log_info "  ✓ $description contains expected content"
        return 0
    else
        log_error "  ✗ $description missing expected content: $pattern"
        return 1
    fi
}

usage() {
    cat <<EOF
Verify landing page deployment

Usage: $0 [OPTIONS]

Options:
  --help    Show this help

Checks:
  1. Main site accessibility
  2. Key pages (quickstart, quota-proxy, downloads)
  3. API gateway health
  4. Forum accessibility
  5. Install script availability
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

log_info "Starting landing page verification..."
echo

# Base URLs
BASE_URL="https://clawdrepublic.cn"
API_URL="https://api.clawdrepublic.cn"
FORUM_URL="https://clawdrepublic.cn/forum"

# Track results
PASS=0
FAIL=0

# Check main site
if check_url "$BASE_URL/" "Main site"; then
    ((PASS++))
else
    ((FAIL++))
fi

# Check key pages
for page in quickstart.html quota-proxy.html downloads.html; do
    if check_url "$BASE_URL/$page" "$page page"; then
        ((PASS++))
    else
        ((FAIL++))
    fi
done

# Check content on key pages
if check_content "$BASE_URL/quickstart.html" "CLAWD_TRIAL_KEY" "Quickstart page has TRIAL_KEY reference"; then
    ((PASS++))
else
    ((FAIL++))
fi

if check_content "$BASE_URL/quota-proxy.html" "试用密钥" "Quota-proxy page has Chinese instructions"; then
    ((PASS++))
else
    ((FAIL++))
fi

# Check API gateway
if check_url "$API_URL/healthz" "API health endpoint"; then
    ((PASS++))
else
    ((FAIL++))
fi

# Check install script
INSTALL_URL="$BASE_URL/install-cn.sh"
log_info "Checking install script: $INSTALL_URL"
if curl -fsS -m 10 "$INSTALL_URL" > /dev/null 2>&1; then
    log_info "  ✓ Install script is accessible"
    ((PASS++))
else
    log_error "  ✗ Install script is NOT accessible"
    ((FAIL++))
fi

# Summary
echo
log_info "Verification complete!"
log_info "Pass: $PASS, Fail: $FAIL"

if [[ $FAIL -eq 0 ]]; then
    log_info "✓ All checks passed! Landing page is fully operational."
    exit 0
else
    log_error "✗ Some checks failed. Review the errors above."
    exit 1
fi