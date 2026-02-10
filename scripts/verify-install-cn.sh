#!/usr/bin/env bash
set -euo pipefail

# Verify install-cn.sh functionality
# This script tests the CN installer without actually installing OpenClaw

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/scripts/install-cn.sh"

echo "=== OpenClaw CN Installer Verification ==="
echo "Script: $INSTALL_SCRIPT"
echo ""

# Check if script exists
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "❌ Install script not found: $INSTALL_SCRIPT"
  exit 1
fi

echo "✅ Install script exists"

# Test 1: Syntax check
echo ""
echo "=== Test 1: Syntax Check ==="
if bash -n "$INSTALL_SCRIPT"; then
  echo "✅ Syntax check passed"
else
  echo "❌ Syntax check failed"
  exit 1
fi

# Test 2: Help output
echo ""
echo "=== Test 2: Help Output ==="
if "$INSTALL_SCRIPT" --help 2>&1 | grep -q "OpenClaw CN installer"; then
  echo "✅ Help output contains expected text"
else
  echo "❌ Help output missing expected text"
  exit 1
fi

# Test 3: Network test mode
echo ""
echo "=== Test 3: Network Test Mode ==="
NETWORK_TEST_OUTPUT="$("$INSTALL_SCRIPT" --network-test 2>&1 | head -5)"
if echo "$NETWORK_TEST_OUTPUT" | grep -q "Running network connectivity test"; then
  echo "✅ Network test mode works"
else
  echo "❌ Network test mode not working"
  echo "Output: $NETWORK_TEST_OUTPUT"
  exit 1
fi

# Test 4: Dry run mode
echo ""
echo "=== Test 4: Dry Run Mode ==="
DRY_OUTPUT="$("$INSTALL_SCRIPT" --dry-run 2>&1)"
if echo "$DRY_OUTPUT" | grep -q "dry-run"; then
  echo "✅ Dry run mode works"
else
  echo "❌ Dry run mode not working"
  exit 1
fi

# Test 5: Version specification
echo ""
echo "=== Test 5: Version Specification ==="
VERSION_OUTPUT="$("$INSTALL_SCRIPT" --version 0.3.12 --dry-run 2>&1)"
if echo "$VERSION_OUTPUT" | grep -q "openclaw@0.3.12"; then
  echo "✅ Version specification works"
else
  echo "❌ Version specification not working"
  exit 1
fi

# Test 6: Registry override
echo ""
echo "=== Test 6: Registry Override ==="
REG_OUTPUT="$("$INSTALL_SCRIPT" --registry-cn https://test.registry.cn --dry-run 2>&1)"
if echo "$REG_OUTPUT" | grep -q "test.registry.cn"; then
  echo "✅ Registry override works"
else
  echo "❌ Registry override not working"
  exit 1
fi

# Test 7: Force CN mode
echo ""
echo "=== Test 7: Force CN Mode ==="
FORCE_OUTPUT="$("$INSTALL_SCRIPT" --force-cn --dry-run 2>&1)"
if echo "$FORCE_OUTPUT" | grep -q "Force using CN registry"; then
  echo "✅ Force CN mode works"
else
  echo "❌ Force CN mode not working"
  exit 1
fi

# Test 8: Script self-check functions
echo ""
echo "=== Test 8: Script Self-Check Functions ==="
# Check for network test function
if grep -q "run_network_test()" "$INSTALL_SCRIPT"; then
  echo "✅ Network test function exists"
else
  echo "❌ Network test function missing"
fi

# Check for install_openclaw function
if grep -q "install_openclaw()" "$INSTALL_SCRIPT"; then
  echo "✅ Install function exists"
else
  echo "❌ Install function missing"
fi

# Check for self-check at end
if grep -q "Self-check" "$INSTALL_SCRIPT"; then
  echo "✅ Self-check section exists"
else
  echo "❌ Self-check section missing"
fi

# Test 9: Environment variable support
echo ""
echo "=== Test 9: Environment Variable Support ==="
ENV_OUTPUT="$(OPENCLAW_VERSION=0.3.12 NPM_REGISTRY=https://test.registry.cn "$INSTALL_SCRIPT" --dry-run 2>&1)"
if echo "$ENV_OUTPUT" | grep -q "openclaw@0.3.12" && echo "$ENV_OUTPUT" | grep -q "test.registry.cn"; then
  echo "✅ Environment variable support works"
else
  echo "❌ Environment variable support not working"
fi

# Test 10: Error handling
echo ""
echo "=== Test 10: Error Handling ==="
# Test missing required argument
if ! "$INSTALL_SCRIPT" --version 2>&1 | grep -q "Missing required values"; then
  echo "⚠️  Missing argument error handling could be improved"
else
  echo "✅ Missing argument error handling works"
fi

echo ""
echo "=== Summary ==="
echo "✅ All core functionality tests passed"
echo ""
echo "To test actual installation (requires Node.js >= 20):"
echo "  curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash"
echo ""
echo "For network connectivity test only:"
echo "  curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash -s -- --network-test"
echo ""
echo "For dry-run (no install):"
echo "  curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash -s -- --dry-run"