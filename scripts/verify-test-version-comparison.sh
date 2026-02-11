#!/bin/bash

# Verification script for test-version-comparison.sh
# This script verifies that the version comparison test script works correctly

set -e

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

# Test functions
test_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log_success "File exists: $file"
        return 0
    else
        log_error "File not found: $file"
        return 1
    fi
}

test_file_executable() {
    local file="$1"
    if [[ -x "$file" ]]; then
        log_success "File is executable: $file"
        return 0
    else
        log_warning "File is not executable: $file"
        return 1
    fi
}

test_syntax_check() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        log_success "Syntax check passed: $file"
        return 0
    else
        log_error "Syntax check failed: $file"
        return 1
    fi
}

test_help_function() {
    local file="$1"
    if grep -q "help\|usage\|--help" "$file"; then
        log_success "Help/usage information found in: $file"
        return 0
    else
        log_warning "No help/usage information found in: $file"
        return 1
    fi
}

test_script_runs() {
    local file="$1"
    if "$file" --help 2>&1 | grep -q "test-version-comparison"; then
        log_success "Script runs and shows help: $file"
        return 0
    else
        # Try running without arguments
        if timeout 5 "$file" 2>&1 | grep -q "Starting version comparison tests"; then
            log_success "Script runs successfully: $file"
            return 0
        else
            log_error "Script failed to run: $file"
            return 1
        fi
    fi
}

test_version_comparison_function() {
    local file="$1"
    if grep -q "compare_versions()" "$file"; then
        log_success "compare_versions function found in: $file"
        return 0
    else
        log_error "compare_versions function not found in: $file"
        return 1
    fi
}

test_test_cases() {
    local file="$1"
    local test_case_count=$(grep -c '"2026\.' "$file" || echo "0")
    if [[ $test_case_count -ge 5 ]]; then
        log_success "Found $test_case_count test cases in: $file"
        return 0
    else
        log_warning "Only found $test_case_count test cases in: $file (expected at least 5)"
        return 1
    fi
}

# Main verification function
verify_test_version_comparison_script() {
    local script_path="scripts/test-version-comparison.sh"
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    log_info "Verifying test-version-comparison.sh script..."
    echo ""
    
    # Run all tests
    local tests=(
        "test_file_exists $script_path"
        "test_file_executable $script_path"
        "test_syntax_check $script_path"
        "test_help_function $script_path"
        "test_version_comparison_function $script_path"
        "test_test_cases $script_path"
        "test_script_runs $script_path"
    )
    
    for test_command in "${tests[@]}"; do
        total_tests=$((total_tests + 1))
        if eval "$test_command"; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # Summary
    echo ""
    log_info "Verification Summary:"
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

# Main execution
main() {
    log_info "Starting verification of test-version-comparison.sh..."
    echo ""
    
    verify_test_version_comparison_script
    local verify_result=$?
    
    echo ""
    if [[ $verify_result -eq 0 ]]; then
        log_success "All verifications passed! test-version-comparison.sh is ready for use."
    else
        log_error "Some verifications failed. Please check the test-version-comparison.sh script."
        exit 1
    fi
}

# Run main function
main "$@"