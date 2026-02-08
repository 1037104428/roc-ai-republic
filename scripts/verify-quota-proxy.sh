#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash scripts/verify-quota-proxy.sh [--base-url http://127.0.0.1:8787] [--day YYYY-MM-DD]
# Env:
#   BASE_URL=...  (preferred over positional args)
#   DAY=...

_base_url_arg=""
_day_arg=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      _base_url_arg="${2:-}"; shift 2 ;;
    --day)
      _day_arg="${2:-}"; shift 2 ;;
    -h|--help)
      echo "usage: $0 [--base-url URL] [--day YYYY-MM-DD]"; exit 0 ;;
    *)
      # Backward-compat: allow old positional BASE_URL as first arg
      if [[ -z "${_base_url_arg}" ]]; then
        _base_url_arg="$1"; shift ;
      else
        echo "unknown arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

BASE_URL="${BASE_URL:-${_base_url_arg:-http://127.0.0.1:8787}}"
DAY="${DAY:-${_day_arg:-$(date +%F)}}"

# Optional:
# - ADMIN_TOKEN=...            # to call /admin/*
# - ISSUE_KEY=1                # also POST /admin/keys (requires persistence enabled)
# - TRIAL_LABEL="forum-user:alice"  # label for issued key

say() { printf '%s\n' "$*"; }

say "[verify] baseUrl=${BASE_URL} day=${DAY}"

say "[1/4] GET /healthz"
curl -fsS "${BASE_URL}/healthz" | sed -e 's/^/[healthz] /'

say "[2/4] GET /admin/usage (expects 401 if ADMIN_TOKEN not set)"
if [[ -z "${ADMIN_TOKEN:-}" ]]; then
  code=$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}/admin/usage?day=${DAY}")
  if [[ "$code" != "401" ]]; then
    say "[fail] expected 401 without ADMIN_TOKEN, got ${code}"
    exit 1
  fi
  say "[ok] got 401 as expected (set ADMIN_TOKEN to test authenticated path)"
else
  curl -fsS "${BASE_URL}/admin/usage?day=${DAY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | sed -e 's/^/[usage] /'
fi

say "[3/4] (optional) POST /admin/keys (ISSUE_KEY=1)"
if [[ -n "${ADMIN_TOKEN:-}" && "${ISSUE_KEY:-0}" == "1" ]]; then
  label="${TRIAL_LABEL:-forum-user:demo}"
  say "[issue] label=${label}"

  resp=$(curl -fsS -X POST "${BASE_URL}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H 'content-type: application/json' \
    -d "{\"label\":\"${label}\"}")
  echo "$resp" | sed -e 's/^/[issued] /'

  trial_key=$(echo "$resp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("key",""))')

  if [[ -z "$trial_key" ]]; then
    say "[warn] could not parse issued key from response (no .key)"
  else
    say "[ok] issued trial_key=${trial_key}"
    say "[hint] user-side verify: curl -fsS ${BASE_URL%/}/v1/models -H 'Authorization: Bearer ${trial_key}'"
  fi
else
  say "[skip] set ADMIN_TOKEN + ISSUE_KEY=1 to issue a key (requires persistence enabled)"
fi

say "[4/4] docker compose ps (best-effort, only if in deploy dir)"
if [[ -f docker-compose.yml || -f compose.yml ]]; then
  docker compose ps
else
  say "[skip] no compose file in current dir; run from quota-proxy deploy dir to include compose status"
fi

say "[done]"
