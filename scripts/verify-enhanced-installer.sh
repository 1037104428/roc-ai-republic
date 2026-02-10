#!/usr/bin/env bash
set -euo pipefail

# Verification script for enhanced installer
# Tests syntax, dry-run, and basic functionality

log() { echo "[verify] $*"; }
log_warn() { echo "[verify] ⚠ $*"; }
log_error() { echo "[verify] ✗ $*" >&2; }

test_count=0
pass_count=0
fail_count=0

run_test() {
  local name="$1"
  local command="$2"
  
  ((test_count++))
  log "Test $test_count: $name"
  
  if eval "$command"; then
    log "  ✓ PASS"
    ((pass_count++))
  else
    log_error "  ✗ FAIL"
    ((fail_count++))
  fi
  echo
}

summary() {
  log "=== Test Summary ==="
  log "Total tests: $test_count"
  log "Passed: $pass_count"
  log "Failed: $fail_count"
  
  if [[ $fail_count -eq 0 ]]; then
    log "All tests passed! ✓"
    exit 0
  else
    log_error "Some tests failed"
    exit 1
  fi
}

main() {
  log "Verifying enhanced installer scripts..."
  
  # Test 1: Syntax check for enhanced installer
  run_test "Syntax check: install-cn-enhanced.sh" \
    "bash -n scripts/install-cn-enhanced.sh"
  
  # Test 2: Syntax check for wrapper
  run_test "Syntax check: install-cn-wrapper.sh" \
    "bash -n scripts/install-cn-wrapper.sh"
  
  # Test 3: Dry-run test for enhanced installer
  run_test "Dry-run test: enhanced installer" \
    "./scripts/install-cn-enhanced.sh --dry-run --version latest 2>&1 | grep -q 'dry-run' || (echo 'Dry-run output missing'; false)"
  
  # Test 4: Help output test
  run_test "Help output test" \
    "./scripts/install-cn-enhanced.sh --help 2>&1 | grep -q 'OpenClaw CN enhanced installer'"
  
  # Test 5: Network test mode
  run_test "Network test mode" \
    "./scripts/install-cn-enhanced.sh --network-test 2>&1 | grep -q 'Network Diagnostic Results'"
  
  # Test 6: Platform detection (should not fail)
  run_test "Platform detection function" \
    "grep -q 'detect_platform' scripts/install-cn-enhanced.sh"
  
  # Test 7: Dependency check function
  run_test "Dependency check function" \
    "grep -q 'check_dependencies' scripts/install-cn-enhanced.sh"
  
  # Test 8: Wrapper script functionality
  run_test "Wrapper script help" \
    "./scripts/install-cn-wrapper.sh 2>&1 | grep -q 'OpenClaw Installer Wrapper'"
  
  # Test 9: Verify scripts are executable
  run_test "Scripts are executable" \
    "[[ -x scripts/install-cn-enhanced.sh && -x scripts/install-cn-wrapper.sh ]]"
  
  # Test 10: Check for required shebang
  run_test "Shebang check" \
    "head -1 scripts/install-cn-enhanced.sh | grep -q '^#!/usr/bin/env bash'"
  
  summary
}

main "$@"