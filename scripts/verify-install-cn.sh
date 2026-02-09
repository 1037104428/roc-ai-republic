#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN installer verification script
# Tests the install-cn.sh script functionality

usage() {
  cat <<'TXT'
[cn-pack] OpenClaw CN installer verification script

Usage:
  ./verify-install-cn.sh [options]

Options:
  --dry-run              Test with --dry-run flag
  --help                 Show this help
  --version <ver>        Test specific version (default: latest)
  --no-cleanup           Keep test directory after test

Examples:
  ./verify-install-cn.sh --dry-run
  ./verify-install-cn.sh --version 0.3.12
TXT
}

DRY_RUN=0
VERSION="latest"
NO_CLEANUP=0

# Use mktemp for safety (avoid collisions)
TEST_DIR="$(mktemp -d -t openclaw-cn-install-test-XXXXXXXX)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1; shift ;;
    --version)
      VERSION="${2:-}"; shift 2 ;;
    --no-cleanup)
      NO_CLEANUP=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[cn-pack] Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

cleanup() {
  if [[ "$NO_CLEANUP" == "0" ]]; then
    echo "[cn-pack] Cleaning up test directory: $TEST_DIR"
    # Guard against accidental deletion of non-/tmp paths
    case "$TEST_DIR" in
      /tmp/openclaw-cn-install-test-*) rm -rf "$TEST_DIR" 2>/dev/null || true ;;
      *) echo "[cn-pack] Refuse to cleanup unexpected TEST_DIR: $TEST_DIR" >&2 ;;
    esac
  else
    echo "[cn-pack] Test directory kept: $TEST_DIR"
  fi
}

trap cleanup EXIT

echo "[cn-pack] Starting OpenClaw CN installer verification"
echo "[cn-pack] Test directory: $TEST_DIR"

# Copy install script to test directory
if [[ ! -f scripts/install-cn.sh ]]; then
  echo "[cn-pack] ❌ Missing scripts/install-cn.sh (run from repo root)" >&2
  exit 2
fi
cp scripts/install-cn.sh "$TEST_DIR/"

# Test 1: Help output
echo "[cn-pack] Test 1: Help output"
if ! "$TEST_DIR/install-cn.sh" --help 2>&1 | grep -q "OpenClaw CN installer"; then
  echo "[cn-pack] ❌ Test 1 failed: Help output not as expected"
  exit 1
fi
echo "[cn-pack] ✅ Test 1 passed: Help output OK"

# Test 2: Dry run
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[cn-pack] Test 2: Dry run mode"
  set +e
  DRY_OUT=$("$TEST_DIR/install-cn.sh" --dry-run --version "$VERSION" 2>&1)
  DRY_RC=$?
  set -e
  DRY_RUN_COUNT=$(printf "%s" "$DRY_OUT" | grep -c "\[dry-run\]" || true)
  if [[ "$DRY_RUN_COUNT" -eq 0 || "$DRY_RC" -ne 0 ]]; then
    echo "[cn-pack] ❌ Test 2 failed: dry-run expected markers and exit 0 (markers=$DRY_RUN_COUNT rc=$DRY_RC)"
    printf "%s\n" "$DRY_OUT" | tail -n 50
    exit 1
  fi
  echo "[cn-pack] ✅ Test 2 passed: Dry run OK (found $DRY_RUN_COUNT [dry-run] markers, rc=$DRY_RC)"
fi

# Test 3: Script syntax check
echo "[cn-pack] Test 3: Script syntax check"
if ! bash -n "$TEST_DIR/install-cn.sh"; then
  echo "[cn-pack] ❌ Test 3 failed: Script has syntax errors"
  exit 1
fi
echo "[cn-pack] ✅ Test 3 passed: Script syntax OK"

# Test 4: Required commands check
echo "[cn-pack] Test 4: Required commands check"
if ! grep -q "command -v npm" "$TEST_DIR/install-cn.sh"; then
  echo "[cn-pack] ❌ Test 4 failed: npm command check missing"
  exit 1
fi
echo "[cn-pack] ✅ Test 4 passed: Required commands check present"

# Test 5: Self-check section
echo "[cn-pack] Test 5: Self-check section"
if ! grep -q "openclaw --version" "$TEST_DIR/install-cn.sh"; then
  echo "[cn-pack] ❌ Test 5 failed: Self-check missing"
  exit 1
fi
echo "[cn-pack] ✅ Test 5 passed: Self-check present"

echo "[cn-pack] ✅ All verification tests passed!"
echo "[cn-pack] Install script is ready for use."
echo ""
echo "[cn-pack] Quick usage reminder:"
echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version $VERSION"
echo "  NPM_REGISTRY=https://registry.npmmirror.com OPENCLAW_VERSION=latest bash install-cn.sh"