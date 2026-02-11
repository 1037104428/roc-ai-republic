#!/bin/bash

# Test script for version comparison function
# This script tests the compare_versions function from install-cn.sh

# Don't use set -e for testing script

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Copy the compare_versions function from install-cn.sh
compare_versions() {
  local version1="$1"
  local version2="$2"
  
  # Remove non-numeric prefixes and split by dots
  local v1_clean="${version1//[^0-9.]/}"
  local v2_clean="${version2//[^0-9.]/}"
  
  # Split into arrays
  IFS='.' read -ra v1_parts <<< "$v1_clean"
  IFS='.' read -ra v2_parts <<< "$v2_clean"
  
  # Compare each part
  local max_parts=$(( ${#v1_parts[@]} > ${#v2_parts[@]} ? ${#v1_parts[@]} : ${#v2_parts[@]} ))
  
  for (( i=0; i<max_parts; i++ )); do
    local v1_part="${v1_parts[i]:-0}"
    local v2_part="${v2_parts[i]:-0}"
    
    if (( v1_part > v2_part )); then
      return 1  # version1 > version2
    elif (( v1_part < v2_part )); then
      return 2  # version1 < version2
    fi
  done
  
  return 0  # versions are equal
}

# Test cases
test_version_comparison() {
    # Use array of arrays for test cases
    local test_cases=(
        "2026.02.11.1638 2026.02.11.1638 0"
        "2026.02.11.1638 2026.02.11.1637 1"
        "2026.02.11.1637 2026.02.11.1638 2"
        "2026.02.11 2026.02.11.0 0"
        "2026.02.11.1 2026.02.11 1"
        "2026.02 2026.02.0.0 0"
        "2026.02.01 2026.02.1 0"
        "2026.02.11.1638 2026.02.11.1639 2"
        "2026.02.11.1639 2026.02.11.1638 1"
        "1.0.0 1.0.0 0"
        "1.0.1 1.0.0 1"
        "1.0.0 1.0.1 2"
        "2.0.0 1.9.9 1"
        "1.9.9 2.0.0 2"
    )
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    log_info "Testing version comparison function..."
    
    for test_case in "${test_cases[@]}"; do
        IFS=' ' read -r v1 v2 expected <<< "$test_case"
        total_tests=$((total_tests + 1))
        
        compare_versions "$v1" "$v2"
        local result=$?
        
        if [[ $result -eq $expected ]]; then
            log_success "PASS: compare_versions('$v1', '$v2') = $result (expected: $expected)"
            passed_tests=$((passed_tests + 1))
        else
            log_error "FAIL: compare_versions('$v1', '$v2') = $result (expected: $expected)"
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    echo ""
    log_info "Test Summary:"
    log_info "  Total tests: $total_tests"
    if [[ $passed_tests -eq $total_tests ]]; then
        log_success "  Passed: $passed_tests"
    else
        log_warning "  Passed: $passed_tests"
    fi
    if [[ $failed_tests -gt 0 ]]; then
        log_error "  Failed: $failed_tests"
    fi
    
    return $failed_tests
}

# Show help information
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Test the version comparison function from install-cn.sh"
    echo ""
    echo "Options:"
    echo "  --help     Show this help message"
    echo "  --version  Show script version"
    echo ""
    echo "Description:"
    echo "  This script tests the compare_versions() function used in install-cn.sh"
    echo "  to ensure it correctly compares semantic version numbers."
    echo ""
    echo "Examples:"
    echo "  $0              # Run all tests"
    echo "  $0 --help       # Show this help"
}

# Show version
show_version() {
    echo "test-version-comparison.sh v1.0.0"
    echo "Test script for version comparison function"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting version comparison tests..."
    echo ""
    
    test_version_comparison
    local test_result=$?
    
    echo ""
    if [[ $test_result -eq 0 ]]; then
        log_success "All tests passed! Version comparison function is working correctly."
    else
        log_error "Some tests failed. Please check the version comparison function."
        exit 1
    fi
}

# Run main function
main "$@"