#!/usr/bin/env bash
set -euo pipefail

# Proxy detection for OpenClaw CN installer
# Detects system proxy settings and adapts installation accordingly

SCRIPT_VERSION="2026.02.11.01"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[proxy-detect]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[proxy-detect] ✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[proxy-detect] ⚠${NC} $1"
}

log_error() {
  echo -e "${RED}[proxy-detect] ✗${NC} $1"
}

# Function to detect proxy settings
detect_proxy_settings() {
  local proxy_env_vars=("HTTP_PROXY" "HTTPS_PROXY" "http_proxy" "https_proxy" "ALL_PROXY" "all_proxy")
  local detected_proxies=()
  local proxy_type="none"
  
  log_info "Detecting proxy settings..."
  
  # Check environment variables
  for var in "${proxy_env_vars[@]}"; do
    if [[ -n "${!var:-}" ]]; then
      local proxy_value="${!var}"
      detected_proxies+=("$var=$proxy_value")
      
      # Determine proxy type
      if [[ "$proxy_value" =~ ^http:// ]]; then
        proxy_type="http"
      elif [[ "$proxy_value" =~ ^https:// ]]; then
        proxy_type="https"
      elif [[ "$proxy_value" =~ ^socks ]]; then
        proxy_type="socks"
      fi
    fi
  done
  
  # Check system proxy settings (Linux)
  if [[ -f "/etc/environment" ]]; then
    local system_proxy=$(grep -i proxy /etc/environment | head -5)
    if [[ -n "$system_proxy" ]]; then
      detected_proxies+=("system:/etc/environment")
      proxy_type="system"
    fi
  fi
  
  # Check apt proxy settings
  if [[ -f "/etc/apt/apt.conf.d/proxy.conf" ]]; then
    detected_proxies+=("apt:/etc/apt/apt.conf.d/proxy.conf")
    proxy_type="apt"
  fi
  
  # Check npm proxy settings
  local npm_proxy=$(npm config get proxy 2>/dev/null || true)
  local npm_https_proxy=$(npm config get https-proxy 2>/dev/null || true)
  
  if [[ "$npm_proxy" != "null" && -n "$npm_proxy" ]]; then
    detected_proxies+=("npm:proxy=$npm_proxy")
    proxy_type="npm"
  fi
  
  if [[ "$npm_https_proxy" != "null" && -n "$npm_https_proxy" ]]; then
    detected_proxies+=("npm:https-proxy=$npm_https_proxy")
    proxy_type="npm"
  fi
  
  # Output results
  if [[ ${#detected_proxies[@]} -eq 0 ]]; then
    log_success "No proxy settings detected"
    echo "PROXY_DETECTED=false"
    echo "PROXY_TYPE=none"
    echo "PROXY_COUNT=0"
    return 0
  else
    log_warning "Detected ${#detected_proxies[@]} proxy configuration(s):"
    for proxy in "${detected_proxies[@]}"; do
      echo "  - $proxy"
    done
    
    echo "PROXY_DETECTED=true"
    echo "PROXY_TYPE=$proxy_type"
    echo "PROXY_COUNT=${#detected_proxies[@]}"
    
    # Export proxy variables for use
    for var in "${proxy_env_vars[@]}"; do
      if [[ -n "${!var:-}" ]]; then
        echo "PROXY_${var}=${!var}"
      fi
    done
    
    return 0
  fi
}

# Function to test proxy connectivity
test_proxy_connectivity() {
  local test_url="${1:-https://registry.npmmirror.com}"
  local timeout="${2:-10}"
  
  log_info "Testing proxy connectivity to $test_url..."
  
  # Try with curl using detected proxies
  local curl_cmd="curl"
  local curl_opts=("--silent" "--max-time" "$timeout" "--head" "--fail")
  
  # Add proxy if HTTP_PROXY is set
  if [[ -n "${HTTP_PROXY:-}" ]]; then
    curl_opts+=("--proxy" "$HTTP_PROXY")
  elif [[ -n "${http_proxy:-}" ]]; then
    curl_opts+=("--proxy" "$http_proxy")
  fi
  
  if curl "${curl_opts[@]}" "$test_url" >/dev/null 2>&1; then
    log_success "Proxy connectivity test passed"
    echo "PROXY_TEST_RESULT=success"
    echo "PROXY_TEST_URL=$test_url"
    return 0
  else
    log_error "Proxy connectivity test failed"
    echo "PROXY_TEST_RESULT=failed"
    echo "PROXY_TEST_URL=$test_url"
    return 1
  fi
}

# Function to configure npm with proxy
configure_npm_proxy() {
  local proxy_url="${1:-}"
  local https_proxy_url="${2:-$proxy_url}"
  
  if [[ -z "$proxy_url" ]]; then
    log_info "No proxy URL provided, skipping npm proxy configuration"
    return 0
  fi
  
  log_info "Configuring npm proxy settings..."
  
  # Set npm proxy
  if npm config set proxy "$proxy_url" >/dev/null 2>&1; then
    log_success "Set npm proxy: $proxy_url"
  else
    log_error "Failed to set npm proxy"
    return 1
  fi
  
  # Set npm https-proxy
  if npm config set https-proxy "$https_proxy_url" >/dev/null 2>&1; then
    log_success "Set npm https-proxy: $https_proxy_url"
  else
    log_error "Failed to set npm https-proxy"
    return 1
  fi
  
  # Verify configuration
  local current_proxy=$(npm config get proxy)
  local current_https_proxy=$(npm config get https-proxy)
  
  if [[ "$current_proxy" == "$proxy_url" && "$current_https_proxy" == "$https_proxy_url" ]]; then
    log_success "npm proxy configuration verified"
    echo "NPM_PROXY_CONFIGURED=true"
    echo "NPM_PROXY_URL=$proxy_url"
    echo "NPM_HTTPS_PROXY_URL=$https_proxy_url"
    return 0
  else
    log_error "npm proxy configuration verification failed"
    echo "NPM_PROXY_CONFIGURED=false"
    return 1
  fi
}

# Function to clear npm proxy settings
clear_npm_proxy() {
  log_info "Clearing npm proxy settings..."
  
  npm config delete proxy >/dev/null 2>&1 || true
  npm config delete https-proxy >/dev/null 2>&1 || true
  
  log_success "npm proxy settings cleared"
  echo "NPM_PROXY_CLEARED=true"
  return 0
}

# Function to generate proxy configuration report
generate_proxy_report() {
  local report_file="${1:-/tmp/openclaw-proxy-report-$(date +%s).txt}"
  
  log_info "Generating proxy configuration report: $report_file"
  
  cat > "$report_file" << EOF
# OpenClaw Proxy Configuration Report
# Generated: $(date)
# Script version: $SCRIPT_VERSION

## System Information
- Hostname: $(hostname 2>/dev/null || echo "unknown")
- OS: $(uname -s) $(uname -r)
- User: $(whoami)

## Detected Proxy Settings

### Environment Variables
EOF
  
  # Environment variables
  local proxy_vars=("HTTP_PROXY" "HTTPS_PROXY" "http_proxy" "https_proxy" "ALL_PROXY" "all_proxy")
  for var in "${proxy_vars[@]}"; do
    if [[ -n "${!var:-}" ]]; then
      echo "- $var=${!var}" >> "$report_file"
    fi
  done
  
  # System files
  cat >> "$report_file" << EOF

### System Configuration Files
EOF
  
  if [[ -f "/etc/environment" ]]; then
    echo "- /etc/environment:" >> "$report_file"
    grep -i proxy /etc/environment 2>/dev/null | sed 's/^/  /' >> "$report_file" || true
  fi
  
  if [[ -f "/etc/apt/apt.conf.d/proxy.conf" ]]; then
    echo "- /etc/apt/apt.conf.d/proxy.conf:" >> "$report_file"
    cat /etc/apt/apt.conf.d/proxy.conf 2>/dev/null | sed 's/^/  /' >> "$report_file" || true
  fi
  
  # npm configuration
  cat >> "$report_file" << EOF

### npm Configuration
EOF
  
  local npm_proxy=$(npm config get proxy 2>/dev/null || echo "not set")
  local npm_https_proxy=$(npm config get https-proxy 2>/dev/null || echo "not set")
  
  echo "- proxy: $npm_proxy" >> "$report_file"
  echo "- https-proxy: $npm_https_proxy" >> "$report_file"
  
  # Connectivity test results
  cat >> "$report_file" << EOF

## Connectivity Test Results
EOF
  
  # Test common registries
  local test_urls=("https://registry.npmmirror.com" "https://registry.npmjs.org" "https://github.com")
  
  for url in "${test_urls[@]}"; do
    echo -n "Testing $url..." >> "$report_file"
    if curl --silent --max-time 5 --head --fail "$url" >/dev/null 2>&1; then
      echo " ✓ accessible" >> "$report_file"
    else
      echo " ✗ not accessible" >> "$report_file"
    fi
  done
  
  cat >> "$report_file" << EOF

## Recommendations

1. If proxies are detected but connectivity tests fail:
   - Verify proxy server is running
   - Check proxy authentication if required
   - Test with: curl --proxy <proxy_url> https://registry.npmmirror.com

2. If no proxies are detected but network access is limited:
   - Consider setting HTTP_PROXY/HTTPS_PROXY environment variables
   - Or use: npm config set proxy <proxy_url>

3. For China mainland users:
   - Recommended registry: https://registry.npmmirror.com
   - No proxy needed for domestic access

EOF
  
  log_success "Proxy report generated: $report_file"
  echo "PROXY_REPORT_FILE=$report_file"
  return 0
}

# Main function
main() {
  local action="${1:-detect}"
  
  case "$action" in
    detect)
      detect_proxy_settings
      ;;
    test)
      test_proxy_connectivity "${2:-https://registry.npmmirror.com}" "${3:-10}"
      ;;
    configure)
      configure_npm_proxy "${2:-}" "${3:-}"
      ;;
    clear)
      clear_npm_proxy
      ;;
    report)
      generate_proxy_report "${2:-}"
      ;;
    help|--help|-h)
      cat << EOF
Usage: $0 [action] [options]

Actions:
  detect                    Detect proxy settings (default)
  test [url] [timeout]      Test proxy connectivity
  configure [proxy] [https] Configure npm proxy settings
  clear                     Clear npm proxy settings
  report [file]             Generate proxy configuration report
  help                      Show this help message

Examples:
  $0 detect
  $0 test https://registry.npmmirror.com 5
  $0 configure http://proxy.example.com:8080
  $0 report /tmp/proxy-report.txt

Environment variables:
  HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy
EOF
      ;;
    *)
      log_error "Unknown action: $action"
      echo "Usage: $0 [detect|test|configure|clear|report|help]"
      return 1
      ;;
  esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi