#!/usr/bin/env bash
set -euo pipefail

# curl-admin-usage.sh
# Helper for querying quota-proxy admin usage endpoint.
#
# Requirements:
#   - ADMIN_TOKEN env var
#
# Examples:
#   ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-usage.sh --day $(date +%F)
#
#   ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-usage.sh --limit 50
#
#   ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-usage.sh --day $(date +%F) --key trial_xxx

BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"

DAY=""
LIMIT=""
KEY=""
MASK=0
PRETTY=0

usage() {
  cat <<'EOF'
Usage:
  ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-usage.sh \
    [--day YYYY-MM-DD] [--limit N] [--key trial_xxx] [--pretty] [--mask]

Notes:
  - Prefer --day for operational stats. Use --limit for quick debugging.
  - --pretty formats JSON (python -m json.tool).
  - --mask obfuscates trial keys in output (safe for sharing logs).
  - BASE_URL defaults to http://127.0.0.1:8787
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --day)
      DAY="${2:-}"; shift 2;;
    --limit)
      LIMIT="${2:-}"; shift 2;;
    --key)
      KEY="${2:-}"; shift 2;;
    --mask)
      MASK=1; shift;;
    --pretty)
      PRETTY=1; shift;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2;;
  esac
done

if [[ -z "${ADMIN_TOKEN:-}" ]]; then
  echo "ADMIN_TOKEN is required" >&2
  exit 2
fi

qs=()
if [[ -n "$DAY" ]]; then qs+=("day=${DAY}"); fi
if [[ -n "$LIMIT" ]]; then qs+=("limit=${LIMIT}"); fi
if [[ -n "$KEY" ]]; then qs+=("key=${KEY}"); fi

query=""
if [[ ${#qs[@]} -gt 0 ]]; then
  query="?$(IFS='&'; echo "${qs[*]}")"
fi

url="${BASE_URL%/}/admin/usage${query}"

out=$(curl -fsS "$url" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

if [[ "$MASK" == "1" ]]; then
  out=$(python3 - <<'PY'
import json, sys

def mask_key(s: str) -> str:
    if not isinstance(s, str):
        return s
    if not s.startswith('trial_'):
        return s
    if len(s) <= 12:
        return 'trial_***'
    return s[:9] + '...' + s[-4:]

obj = json.loads(sys.stdin.read())
items = obj.get('items')
if isinstance(items, list):
    for it in items:
        if isinstance(it, dict) and 'key' in it:
            it['key'] = mask_key(it.get('key'))
print(json.dumps(obj, ensure_ascii=False))
PY
<<<"$out")
fi

if [[ "$PRETTY" == "1" ]]; then
  python3 -m json.tool <<<"$out"
else
  printf '%s\n' "$out"
fi
