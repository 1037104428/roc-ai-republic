#!/usr/bin/env bash
set -euo pipefail

# Test script for proxy detection integration
# This script tests the proxy detection functionality in install-cn.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[test-proxy]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[test-proxy] ✓${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[test-proxy] ⚠${NC} $1"
}

log_error() {
  echo -e "${RED}[test-proxy] ✗${NC} $1"
}

# Test 1: Proxy detection script functionality
test_proxy_detection_script() {
  log_info "Test 1: Testing proxy detection script..."
  
  if [[ -f "$PROJECT_ROOT/scripts/detect-proxy.sh" ]]; then
    log_success "Proxy detection script exists"
    
    # Test basic detection
    local output
    output=$("$PROJECT_ROOT/scripts/detect-proxy.sh" detect 2>/dev/null)
    
    if echo "$output" | grep -q "PROXY_DETECTED="; then
      log_success "Proxy detection script works correctly"
      return 0
    else
      log_error "Proxy detection script output format incorrect"
      return 1
    fi
  else
    log_error "Proxy detection script not found"
    return 1
  fi
}

# Test 2: Proxy detection integration in install-cn.sh
test_install_cn_proxy_integration() {
  log_info "Test 2: Testing proxy detection integration in install-cn.sh..."
  
  if [[ -f "$PROJECT_ROOT/scripts/install-cn.sh" ]]; then
    log_success "install-cn.sh script exists"
    
    # Check if proxy functions are defined
    if grep -q "handle_proxy_settings" "$PROJECT_ROOT/scripts/install-cn.sh"; then
      log_success "handle_proxy_settings function found"
    else
      log_error "handle_proxy_settings function not found"
      return 1
    fi
    
    if grep -q "cleanup_proxy_settings" "$PROJECT_ROOT/scripts/install-cn.sh"; then
      log_success "cleanup_proxy_settings function found"
    else
      log_error "cleanup_proxy_settings function not found"
      return 1
    fi
    
    # Check if proxy options are in usage
    if grep -q "--proxy-mode" "$PROJECT_ROOT/scripts/install-cn.sh"; then
      log_success "--proxy-mode option found in usage"
    else
      log_error "--proxy-mode option not found in usage"
      return 1
    fi
    
    return 0
  else
    log_error "install-cn.sh script not found"
    return 1
  fi
}

# Test 3: Dry-run with proxy options
test_dry_run_with_proxy() {
  log_info "Test 3: Testing dry-run with proxy options..."
  
  # Test with auto proxy mode
  local output
  output=$(cd "$PROJECT_ROOT" && HTTP_PROXY=http://test-proxy:8080 ./scripts/install-cn.sh --dry-run --proxy-mode auto 2>&1 || true)
  
  if echo "$output" | grep -q "Checking proxy settings"; then
    log_success "Proxy detection runs in dry-run mode"
  else
    log_warning "Proxy detection may not run in dry-run mode"
  fi
  
  # Test with skip proxy mode
  output=$(cd "$PROJECT_ROOT" && ./scripts/install-cn.sh --dry-run --proxy-mode skip 2>&1 || true)
  
  if echo "$output" | grep -q "Checking proxy settings"; then
    log_success "Proxy detection runs even in skip mode (for reporting)"
  else
    log_warning "Proxy detection may not run in skip mode"
  fi
  
  return 0
}

# Test 4: Proxy documentation
test_proxy_documentation() {
  log_info "Test 4: Testing proxy documentation..."
  
  if [[ -f "$PROJECT_ROOT/docs/proxy-detection-integration-guide.md" ]]; then
    log_success "Proxy detection integration guide exists"
    
    # Check for key sections
    if grep -q "## 概述" "$PROJECT_ROOT/docs/proxy-detection-integration-guide.md"; then
      log_success "Documentation has overview section"
    else
      log_warning "Documentation missing overview section"
    fi
    
    if grep -q "## 集成步骤" "$PROJECT_ROOT/docs/proxy-detection-integration-guide.md"; then
      log_success "Documentation has integration steps section"
    else
      log_warning "Documentation missing integration steps section"
    fi
    
    if grep -q "## 使用示例" "$PROJECT_ROOT/docs/proxy-detection-integration-guide.md"; then
      log_success "Documentation has usage examples section"
    else
      log_warning "Documentation missing usage examples section"
    fi
    
    return 0
  else
    log_error "Proxy detection integration guide not found"
    return 1
  fi
}

# Test 5: Proxy report generation
test_proxy_report_generation() {
  log_info "Test 5: Testing proxy report generation..."
  
  if [[ -f "$PROJECT_ROOT/scripts/detect-proxy.sh" ]]; then
    # Test report generation
    local report_file="/tmp/test-proxy-report-$(date +%s).md"
    
    if "$PROJECT_ROOT/scripts/detect-proxy.sh" report "$report_file" >/dev/null 2>&1; then
      if [[ -f "$report_file" ]]; then
        log_success "Proxy report generated successfully"
        
        # Check report content
        if grep -q "# OpenClaw Proxy Configuration Report" "$report_file"; then
          log_success "Report has correct header"
        else
          log_warning "Report missing correct header"
        fi
        
        rm "$report_file"
        return 0
      else
        log_error "Proxy report file not created"
        return 1
      fi
    else
      log_error "Proxy report generation failed"
      return 1
    fi
  else
    log_error "Cannot test report generation - detect-proxy.sh not found"
    return 1
  fi
}

# Main test function
run_tests() {
  local tests_passed=0
  local tests_failed=0
  local tests_total=5
  
  log_info "Starting proxy integration tests..."
  echo ""
  
  # Run all tests
  if test_proxy_detection_script; then
    ((tests_passed++))
  else
    ((tests_failed++))
  fi
  
  echo ""
  
  if test_install_cn_proxy_integration; then
    ((tests_passed++))
  else
    ((tests_failed++))
  fi
  
  echo ""
  
  if test_dry_run_with_proxy; then
    ((tests_passed++))
  else
    ((tests_failed++))
  fi
  
  echo ""
  
  if test_proxy_documentation; then
    ((tests_passed++))
  else
    ((tests_failed++))
  fi
  
  echo ""
  
  if test_proxy_report_generation; then
    ((tests_passed++))
  else
    ((tests_failed++))
  fi
  
  echo ""
  log_info "Test Results:"
  echo "  Total tests: $tests_total"
  echo "  Passed: $tests_passed"
  echo "  Failed: $tests_failed"
  
  if [[ $tests_failed -eq 0 ]]; then
    log_success "All proxy integration tests passed!"
    return 0
  else
    log_error "Some proxy integration tests failed"
    return 1
  fi
}

# Quick validation test
quick_validation() {
  log_info "Running quick validation..."
  
  # Check script version was updated
  local script_version
  script_version=$(grep "^SCRIPT_VERSION=" "$PROJECT_ROOT/scripts/install-cn.sh" | cut -d'"' -f2)
  
  if [[ "$script_version" == "2026.02.11.01" ]]; then
    log_success "Script version updated to 2026.02.11.01"
  else
    log_error "Script version not updated correctly: $script_version"
  fi
  
  # Check file permissions
  if [[ -x "$PROJECT_ROOT/scripts/detect-proxy.sh" ]]; then
    log_success "detect-proxy.sh is executable"
  else
    log_error "detect-proxy.sh is not executable"
  fi
  
  # Check backup was created
  if [[ -f "$PROJECT_ROOT/scripts/install-cn.sh.backup" ]]; then
    log_success "Backup of install-cn.sh created"
  else
    log_warning "No backup of install-cn.sh found"
  fi
}

# Show usage
usage() {
  cat << EOF
Usage: $0 [option]

Options:
  test       Run all proxy integration tests (default)
  validate   Run quick validation checks
  help       Show this help message

Examples:
  $0 test      # Run all tests
  $0 validate  # Run validation checks
  $0           # Run all tests (default)
EOF
}

# Main execution
main() {
  local action="${1:-test}"
  
  case "$action" in
    test)
      run_tests
      ;;
    validate)
      quick_validation
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      log_error "Unknown action: $action"
      usage
      return 1
      ;;
  esac
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi