#!/usr/bin/env bash
set -euo pipefail

# curl-admin-create-key.sh
# Helper for creating a trial key via quota-proxy admin endpoint.
#
# Requirements:
#   - ADMIN_TOKEN env var
#
# Examples:
#   ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-create-key.sh --label 'forum-user:alice' --pretty

BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"

LABEL=""
PRETTY=0

usage() {
  cat <<'EOF'
Usage:
  ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-create-key.sh \
    [--label TEXT] [--pretty]

Notes:
  - POST /admin/keys requires persistence enabled (SQLITE_PATH).
  - BASE_URL defaults to http://127.0.0.1:8787
  - --pretty formats JSON (python -m json.tool).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --label)
      LABEL="${2:-}"; shift 2;;
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

body=$(python3 - <<PY
import json
label = ${LABEL!r}
# Keep the payload minimal and stable.
print(json.dumps({"label": label} if label else {}, ensure_ascii=False))
PY
)

url="${BASE_URL%/}/admin/keys"

out=$(curl -fsS -X POST "$url" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H 'content-type: application/json' \
  -d "$body")

if [[ "$PRETTY" == "1" ]]; then
  python3 -m json.tool <<<"$out"
else
  printf '%s\n' "$out"
fi
