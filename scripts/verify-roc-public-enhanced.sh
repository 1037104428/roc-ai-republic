#!/usr/bin/env bash
set -euo pipefail

# Enhanced ROC public endpoints verification script.
# Provides comprehensive validation of landing page and API endpoints with detailed reporting.
#
# Usage:
#   ./verify-roc-public-enhanced.sh [OPTIONS] [HOME_URL] [API_BASE_URL]
#
# Options:
#   --timeout N          Request timeout in seconds (default: 10)
#   --verbose            Enable verbose output
#   --quiet              Suppress non-error output
#   --dry-run            Show what would be checked without making requests
#   --json               Output results in JSON format
#   --check-ssl          Verify SSL certificate validity
#   --check-redirect     Follow and verify redirects
#   --check-headers      Validate response headers
#   --check-content      Validate response content
#   --help               Show this help message
#
# Examples:
#   ./verify-roc-public-enhanced.sh
#   ./verify-roc-public-enhanced.sh --timeout 5 --verbose
#   ./verify-roc-public-enhanced.sh --json --check-ssl
#   ./verify-roc-public-enhanced.sh https://clawdrepublic.cn https://api.clawdrepublic.cn
#   curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-roc-public-enhanced.sh | bash

# Default configuration
TIMEOUT="${TIMEOUT:-10}"
VERBOSE=false
QUIET=false
DRY_RUN=false
JSON_OUTPUT=false
CHECK_SSL=false
CHECK_REDIRECT=false
CHECK_HEADERS=false
CHECK_CONTENT=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
args=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --timeout)
      TIMEOUT="${2:-}"
      [[ -n "$TIMEOUT" ]] || { echo "--timeout requires a value" >&2; exit 2; }
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --check-ssl)
      CHECK_SSL=true
      shift
      ;;
    --check-redirect)
      CHECK_REDIRECT=true
      shift
      ;;
    --check-headers)
      CHECK_HEADERS=true
      shift
      ;;
    --check-content)
      CHECK_CONTENT=true
      shift
      ;;
    --help)
      cat <<EOF
Enhanced ROC Public Endpoints Verification Script

This script provides comprehensive validation of ROC public endpoints including:
- Landing page availability and response
- API health endpoint functionality
- SSL certificate validation (optional)
- Redirect behavior (optional)
- Response headers validation (optional)
- Content validation (optional)

Usage: $0 [OPTIONS] [HOME_URL] [API_BASE_URL]

Options:
  --timeout N          Request timeout in seconds (default: 10)
  --verbose            Enable verbose output
  --quiet              Suppress non-error output
  --dry-run            Show what would be checked without making requests
  --json               Output results in JSON format
  --check-ssl          Verify SSL certificate validity
  --check-redirect     Follow and verify redirects
  --check-headers      Validate response headers
  --check-content      Validate response content
  --help               Show this help message

Examples:
  $0
  $0 --timeout 5 --verbose
  $0 --json --check-ssl
  $0 https://clawdrepublic.cn https://api.clawdrepublic.cn

Environment Variables:
  TIMEOUT              Default request timeout (overridden by --timeout)

Exit Codes:
  0 - All checks passed
  1 - One or more checks failed
  2 - Invalid arguments
  3 - Network/DNS error
EOF
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

HOME_URL="${args[0]:-https://clawdrepublic.cn}"
API_BASE_URL="${args[1]:-https://api.clawdrepublic.cn}"

# Helper functions
log() {
  if [[ "$QUIET" == false ]]; then
    printf '%s\n' "$*"
  fi
}

log_verbose() {
  if [[ "$VERBOSE" == true ]]; then
    printf '%s\n' "$*"
  fi
}

log_error() {
  printf "${RED}%s${NC}\n" "$*" >&2
}

log_success() {
  if [[ "$QUIET" == false ]]; then
    printf "${GREEN}%s${NC}\n" "$*"
  fi
}

log_warning() {
  printf "${YELLOW}%s${NC}\n" "$*" >&2
}

log_info() {
  if [[ "$QUIET" == false ]]; then
    printf "${BLUE}%s${NC}\n" "$*"
  fi
}

check_url() {
  local url="$1"
  local description="$2"
  local curl_opts=()
  
  curl_opts+=("-fsS" "-m" "$TIMEOUT")
  
  if [[ "$CHECK_REDIRECT" == true ]]; then
    curl_opts+=("-L")
  fi
  
  if [[ "$CHECK_SSL" == true ]]; then
    curl_opts+=("--ssl-reqd")
  fi
  
  if [[ "$CHECK_HEADERS" == true ]]; then
    curl_opts+=("-I")
  fi
  
  log_info "[CHECK] $description: $url"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_verbose "  Would run: curl ${curl_opts[*]} \"$url\""
    return 0
  fi
  
  local response
  local exit_code=0
  
  if [[ "$CHECK_HEADERS" == true ]]; then
    response=$(curl "${curl_opts[@]}" "$url" 2>&1) || exit_code=$?
  else
    response=$(curl "${curl_opts[@]}" "$url" 2>&1) || exit_code=$?
  fi
  
  if [[ $exit_code -eq 0 ]]; then
    log_success "  ✓ PASS: $description"
    if [[ "$VERBOSE" == true ]]; then
      if [[ "$CHECK_HEADERS" == true ]]; then
        echo "$response" | head -n 20 | sed 's/^/    /'
      elif [[ "$CHECK_CONTENT" == true ]]; then
        echo "$response" | head -n 5 | sed 's/^/    /'
      fi
    fi
    return 0
  else
    log_error "  ✗ FAIL: $description (exit code: $exit_code)"
    if [[ "$VERBOSE" == true ]]; then
      echo "$response" | sed 's/^/    /'
    fi
    return 1
  fi
}

# Main verification function
verify_endpoints() {
  local errors=0
  local results=()
  
  log_info "=== ROC Public Endpoints Verification ==="
  log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  log_info "Configuration:"
  log_info "  Timeout: ${TIMEOUT}s"
  log_info "  Home URL: $HOME_URL"
  log_info "  API Base URL: $API_BASE_URL"
  log_info "  SSL Check: $CHECK_SSL"
  log_info "  Redirect Check: $CHECK_REDIRECT"
  log_info "  Headers Check: $CHECK_HEADERS"
  log_info "  Content Check: $CHECK_CONTENT"
  log_info ""
  
  # Check landing page
  if check_url "$HOME_URL" "Landing page availability"; then
    results+=("landing_page:pass")
  else
    results+=("landing_page:fail")
    errors=$((errors + 1))
  fi
  
  # Check API health endpoint
  if check_url "${API_BASE_URL}/healthz" "API health endpoint"; then
    results+=("api_health:pass")
  else
    results+=("api_health:fail")
    errors=$((errors + 1))
  fi
  
  # Additional checks if enabled
  if [[ "$CHECK_SSL" == true ]]; then
    if check_url "$HOME_URL" "SSL certificate validation"; then
      results+=("ssl_home:pass")
    else
      results+=("ssl_home:fail")
      errors=$((errors + 1))
    fi
    
    if check_url "${API_BASE_URL}/healthz" "API SSL certificate validation"; then
      results+=("ssl_api:pass")
    else
      results+=("ssl_api:fail")
      errors=$((errors + 1))
    fi
  fi
  
  # Summary
  log_info ""
  log_info "=== Verification Summary ==="
  log_info "Total checks: ${#results[@]}"
  log_info "Passed: $(printf '%s\n' "${results[@]}" | grep -c ':pass$')"
  log_info "Failed: $(printf '%s\n' "${results[@]}" | grep -c ':fail$')"
  
  if [[ $errors -eq 0 ]]; then
    log_success "✓ All checks passed!"
  else
    log_error "✗ $errors check(s) failed"
  fi
  
  # JSON output if requested
  if [[ "$JSON_OUTPUT" == true ]]; then
    cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "configuration": {
    "timeout": $TIMEOUT,
    "home_url": "$HOME_URL",
    "api_base_url": "$API_BASE_URL",
    "check_ssl": $CHECK_SSL,
    "check_redirect": $CHECK_REDIRECT,
    "check_headers": $CHECK_HEADERS,
    "check_content": $CHECK_CONTENT
  },
  "results": [
    $(printf '%s\n' "${results[@]}" | sed 's/\(.*\):\(.*\)/{"check":"\1","status":"\2"}/' | paste -sd ',')
  ],
  "summary": {
    "total": ${#results[@]},
    "passed": $(printf '%s\n' "${results[@]}" | grep -c ':pass$'),
    "failed": $(printf '%s\n' "${results[@]}" | grep -c ':fail$'),
    "success": $(if [[ $errors -eq 0 ]]; then echo "true"; else echo "false"; fi)
  }
}
EOF
  fi
  
  return $errors
}

# Main execution
main() {
  # Validate timeout
  if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -lt 1 ]] || [[ "$TIMEOUT" -gt 60 ]]; then
    log_error "Invalid timeout value: $TIMEOUT (must be 1-60)"
    exit 2
  fi
  
  # Validate URLs
  if [[ ! "$HOME_URL" =~ ^https?:// ]]; then
    log_error "Invalid home URL: $HOME_URL (must start with http:// or https://)"
    exit 2
  fi
  
  if [[ ! "$API_BASE_URL" =~ ^https?:// ]]; then
    log_error "Invalid API base URL: $API_BASE_URL (must start with http:// or https://)"
    exit 2
  fi
  
  # Run verification
  verify_endpoints
  exit $?
}

# Run main function
main "$@"