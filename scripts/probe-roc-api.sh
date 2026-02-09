#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
probe-roc-api.sh

Quick probe for ROC public API gateway.

Usage:
  BASE_URL=https://api.clawdrepublic.cn ./scripts/probe-roc-api.sh

Checks:
  - GET /healthz
  - GET /v1/models

Exit code:
  - 0 on success
  - non-zero on failure
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

BASE_URL="${BASE_URL:-https://api.clawdrepublic.cn}"
BASE_URL="${BASE_URL%/}"

curl_common=(--fail --show-error --silent --max-time 10)

printf -- 'BASE_URL=%s\n' "$BASE_URL"

printf -- '\n== /healthz ==\n'
curl "${curl_common[@]}" "$BASE_URL/healthz" | sed -n '1,5p'

printf -- '\n== /v1/models (head) ==\n'
# Avoid huge output in cron; just show the first few lines.
curl "${curl_common[@]}" "$BASE_URL/v1/models" | sed -n '1,40p'

printf -- '\nOK\n'
