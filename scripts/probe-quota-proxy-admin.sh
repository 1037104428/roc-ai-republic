#!/usr/bin/env bash
set -euo pipefail

# Probe quota-proxy admin endpoints safely.
# Default target assumes SSH port-forward: server 127.0.0.1:8787 -> local 127.0.0.1:8788
#
# Usage:
#   ./scripts/probe-quota-proxy-admin.sh
#   BASE_URL=http://127.0.0.1:8788 CLAWD_ADMIN_TOKEN=... ./scripts/probe-quota-proxy-admin.sh
#
# Notes:
# - This script will NOT create keys.
# - It only verifies:
#   1) /healthz is OK
#   2) /admin/usage rejects requests without token (401/403 expected)
#   3) /admin/usage succeeds with token (if provided)

BASE_URL=${BASE_URL:-http://127.0.0.1:8788}
TOKEN=${CLAWD_ADMIN_TOKEN:-${ADMIN_TOKEN:-}}

curl_bin=${CURL_BIN:-curl}

fail() { echo "probe-quota-proxy-admin: ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }
need "$curl_bin"

say() { printf '%s\n' "$*"; }

say "BASE_URL=${BASE_URL}"

say "[1/3] healthz"
code=$("$curl_bin" -sS -m 8 -o /dev/null -w '%{http_code}' "${BASE_URL}/healthz" || true)
if [[ "$code" == "200" ]]; then
  say "healthz: OK"
elif [[ "$code" == "000" ]]; then
  fail "cannot reach ${BASE_URL}. If you're using SSH port-forward, run: ./scripts/ssh-portforward-quota-proxy-admin.sh"
else
  fail "healthz unexpected HTTP ${code}"
fi

say "[2/3] admin usage should be protected (no token)"
code=$(
  "$curl_bin" -sS -m 8 -o /dev/null -w '%{http_code}' \
    "${BASE_URL}/admin/usage?limit=1" || true
)
case "$code" in
  401|403) say "admin(no token): OK (HTTP $code)" ;;
  200) fail "admin(no token) unexpectedly succeeded (HTTP 200). admin endpoint may be exposed!" ;;
  000) fail "admin(no token) request failed (HTTP 000). is port-forward running?" ;;
  *) say "admin(no token): WARN (HTTP $code)" ;;
esac

say "[3/3] admin usage with token (optional)"
if [[ -z "$TOKEN" ]]; then
  say "admin(with token): SKIP (set CLAWD_ADMIN_TOKEN or ADMIN_TOKEN)"
  exit 0
fi

"$curl_bin" -fsS -m 8 \
  -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/admin/usage?limit=1" >/dev/null
say "admin(with token): OK"
