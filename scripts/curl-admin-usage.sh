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

usage() {
  cat <<'EOF'
Usage:
  ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-usage.sh [--day YYYY-MM-DD] [--limit N] [--key trial_xxx]

Notes:
  - Prefer --day for operational stats. Use --limit for quick debugging.
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

curl -fsS "$url" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
