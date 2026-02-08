#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8787}"
DAY="${DAY:-$(date +%F)}"

say() { printf '%s\n' "$*"; }

say "[verify] baseUrl=${BASE_URL} day=${DAY}"

say "[1/3] GET /healthz"
curl -fsS "${BASE_URL}/healthz" | sed -e 's/^/[healthz] /'

say "[2/3] GET /admin/usage (expects 401 if ADMIN_TOKEN not set)"
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

say "[3/3] docker compose ps (best-effort, only if in /opt/roc/quota-proxy)"
if [[ -f docker-compose.yml || -f compose.yml ]]; then
  docker compose ps
else
  say "[skip] no compose file in current dir; run from quota-proxy deploy dir to include compose status"
fi

say "[done]"
