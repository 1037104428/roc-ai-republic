#!/usr/bin/env bash
set -euo pipefail

# curl-admin-create-key.sh
# Helper for creating a trial key via quota-proxy admin endpoint.
#
# Auth env vars (either works):
#   - CLAWD_ADMIN_TOKEN (preferred)
#   - ADMIN_TOKEN       (legacy)
#
# Examples:
#   CLAWD_ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-create-key.sh --label 'forum-user:alice' --pretty

BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"

LABEL=""
PRETTY=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  CLAWD_ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-create-key.sh \
    [--label TEXT] [--pretty] [--dry-run]

  # Legacy env var name also supported
  ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-create-key.sh --pretty

Notes:
  - POST /admin/keys requires persistence enabled (SQLITE_PATH).
  - BASE_URL defaults to http://127.0.0.1:8787
  - --pretty formats JSON (python -m json.tool).
  - --dry-run prints the curl command + JSON body without sending the request.
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
    --dry-run)
      DRY_RUN=1; shift;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2;;
  esac
done

TOKEN="${CLAWD_ADMIN_TOKEN:-${ADMIN_TOKEN:-}}"
if [[ -z "$TOKEN" ]]; then
  echo "CLAWD_ADMIN_TOKEN (preferred) or ADMIN_TOKEN (legacy) is required" >&2
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

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<EOF
# dry-run (no request sent)
URL=${url}
BODY=${body}

curl -fsS -X POST "${url}" \
  -H "Authorization: Bearer \${CLAWD_ADMIN_TOKEN:-\${ADMIN_TOKEN}}" \
  -H 'content-type: application/json' \
  -d '${body}'
EOF
  exit 0
fi

out=$(curl -fsS -X POST "$url" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'content-type: application/json' \
  -d "$body")

if [[ "$PRETTY" == "1" ]]; then
  python3 -m json.tool <<<"$out"
else
  printf '%s\n' "$out"
fi
