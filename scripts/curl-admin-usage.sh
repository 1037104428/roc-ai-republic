#!/usr/bin/env bash
set -euo pipefail

# curl-admin-usage.sh
# Helper for fetching usage via quota-proxy admin endpoint.
#
# Auth env vars (either works):
#   - CLAWD_ADMIN_TOKEN (preferred)
#   - ADMIN_TOKEN       (legacy)
#
# Examples:
#   CLAWD_ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
#     bash scripts/curl-admin-usage.sh --day "$(date +%F)" --limit 50 --pretty

BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"

DAY=""
KEY=""
LIMIT=""
BASE_URL_ARG=""
PRETTY=0
MASK=0

usage() {
  cat <<'EOF'
Usage:
  CLAWD_ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-usage.sh \
    [--day YYYY-MM-DD] [--key KEY] [--limit N] [--pretty] [--mask]

  # Or pass baseUrl explicitly (overrides BASE_URL env)
  CLAWD_ADMIN_TOKEN=... bash scripts/curl-admin-usage.sh --base-url http://127.0.0.1:8787 --pretty

  # Legacy env var name also supported
  ADMIN_TOKEN=... BASE_URL=http://127.0.0.1:8787 bash scripts/curl-admin-usage.sh --pretty

Notes:
  - GET /admin/usage requires persistence enabled (SQLITE_PATH).
  - BASE_URL defaults to http://127.0.0.1:8787
  - --base-url overrides BASE_URL env
  - --pretty formats JSON (python -m json.tool).
  - --mask redacts key-like fields before printing (safe for sharing logs).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --day)
      DAY="${2:-}"; shift 2;;
    --key)
      KEY="${2:-}"; shift 2;;
    --limit)
      LIMIT="${2:-}"; shift 2;;
    --base-url)
      BASE_URL_ARG="${2:-}"; shift 2;;
    --pretty)
      PRETTY=1; shift;;
    --mask)
      MASK=1; shift;;
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

qs=()
if [[ -n "$DAY" ]]; then
  qs+=("day=$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote(${DAY!r}))
PY
)")
fi
if [[ -n "$KEY" ]]; then
  qs+=("key=$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote(${KEY!r}))
PY
)")
fi
if [[ -n "$LIMIT" ]]; then
  qs+=("limit=$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote(${LIMIT!r}))
PY
)")
fi

q=""
if [[ ${#qs[@]} -gt 0 ]]; then
  q="?$(IFS='&'; echo "${qs[*]}")"
fi

if [[ -n "$BASE_URL_ARG" ]]; then
  BASE_URL="$BASE_URL_ARG"
fi

url="${BASE_URL%/}/admin/usage${q}"

out=$(curl -fsS "$url" \
  -H "Authorization: Bearer ${TOKEN}")

# Optional redaction for log sharing.
if [[ "$MASK" == "1" ]]; then
  out=$(python3 - <<'PY'
import json, sys
s = sys.stdin.read()
try:
  data = json.loads(s)
except Exception:
  print(s)
  raise SystemExit(0)

def mask_key(v: str) -> str:
  if not isinstance(v, str):
    return v
  if len(v) <= 10:
    return "***"
  return v[:6] + "…" + v[-4:]

def walk(x):
  if isinstance(x, dict):
    out = {}
    for k, v in x.items():
      if k in ("key", "api_key", "trial_key") and isinstance(v, str):
        out[k] = mask_key(v)
      else:
        out[k] = walk(v)
    return out
  if isinstance(x, list):
    return [walk(i) for i in x]
  return x

print(json.dumps(walk(data), ensure_ascii=False))
PY
<<<"$out")
fi

if [[ "$PRETTY" == "1" ]]; then
  python3 -m json.tool <<<"$out"
else
  printf '%s\n' "$out"
fi
