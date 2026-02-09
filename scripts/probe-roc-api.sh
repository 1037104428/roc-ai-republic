#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
probe-roc-api.sh

Quick probe for ROC public API gateway.

Usage:
  BASE_URL=https://api.clawdrepublic.cn ./scripts/probe-roc-api.sh
  ./scripts/probe-roc-api.sh --json

Options:
  --json   Output a single JSON object (machine-friendly; no extra banners).

Checks:
  - GET /healthz
  - GET /v1/models

Exit code:
  - 0 on success
  - non-zero on failure
EOF
}

json_mode=0
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --json)
      json_mode=1
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      echo "Tip: use --help" >&2
      exit 2
      ;;
  esac
done

BASE_URL="${BASE_URL:-https://api.clawdrepublic.cn}"
BASE_URL="${BASE_URL%/}"

curl_common=(--fail --show-error --silent --max-time 10)

ts="$(TZ=Asia/Shanghai date '+%F %T %Z')"

healthz_body="$(curl "${curl_common[@]}" "$BASE_URL/healthz")"
models_body="$(curl "${curl_common[@]}" "$BASE_URL/v1/models")"

# Parse with python (avoid jq dependency).
healthz_ok="$(python3 - "$healthz_body" <<'PY'
import json,sys
try:
  obj=json.loads(sys.argv[1])
  print(1 if obj.get('ok') is True else 0)
except Exception:
  print(0)
PY
)"

models_count="$(python3 - "$models_body" <<'PY'
import json,sys
try:
  obj=json.loads(sys.argv[1])
  data=obj.get('data')
  print(len(data) if isinstance(data,list) else -1)
except Exception:
  print(-1)
PY
)"

models_ok=0
if [[ "$models_count" =~ ^[0-9]+$ ]] && (( models_count >= 0 )); then
  models_ok=1
fi

if (( json_mode )); then
  python3 - <<PY
import json
out={
  "ts": "${ts}",
  "base_url": "${BASE_URL}",
  "healthz_ok": int("${healthz_ok}"),
  "models_ok": int("${models_ok}"),
  "models_count": int("${models_count}"),
}
print(json.dumps(out, ensure_ascii=False))
PY
  if (( healthz_ok != 1 || models_ok != 1 )); then
    exit 1
  fi
  exit 0
fi

printf -- 'BASE_URL=%s\n' "$BASE_URL"

printf -- '\n== /healthz ==\n'
echo "$healthz_body" | sed -n '1,5p'

printf -- '\n== /v1/models (head) ==\n'
# Avoid huge output in cron; just show the first few lines.
echo "$models_body" | sed -n '1,40p'

printf -- '\nOK\n'
