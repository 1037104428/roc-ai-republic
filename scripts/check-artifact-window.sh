#!/usr/bin/env bash
set -euo pipefail

MINUTES=15
JSON=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/check-artifact-window.sh [--minutes N] [--json]

Notes:
  - Default window is 15 minutes.
  - --json emits a machine-readable summary (no noisy logs).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --minutes)
      MINUTES=${2:?missing minutes}
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TS="$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z')"

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# --- repo window check ---
repo_line=""
repo_ok=0
if repo_line=$(git log --since="${MINUTES} minutes ago" -1 --pretty=format:'%h %ad %s' --date=iso 2>/dev/null) && [[ -n "$repo_line" ]]; then
  repo_ok=1
fi

# --- server quota-proxy probe ---
server_status="skip"
server_host=""
if [[ -f /tmp/server.txt ]]; then
  server_host=$(sed -n 's/^ip://p' /tmp/server.txt | head -n 1 | tr -d ' \t\r\n')
  if [[ -n "$server_host" ]] && need_cmd ssh; then
    if ssh -o BatchMode=yes -o ConnectTimeout=8 "root@${server_host}" \
      'cd /opt/roc/quota-proxy && docker compose ps >/dev/null && curl -fsS http://127.0.0.1:8787/healthz >/dev/null' \
      >/dev/null 2>&1; then
      server_status="ok"
    else
      server_status="fail"
    fi
  else
    server_status="skip"
  fi
fi

# --- public API gateway probe ---
BASE_URL_DEFAULT="https://api.clawdrepublic.cn"
BASE_URL="${BASE_URL:-$BASE_URL_DEFAULT}"
api_status="skip"
if need_cmd curl; then
  if curl -fsS "${BASE_URL%/}/healthz" >/dev/null 2>&1 \
    && curl -fsS "${BASE_URL%/}/v1/models" >/dev/null 2>&1; then
    api_status="ok"
  else
    api_status="fail"
  fi
fi

# --- local admin probe (optional; expects SSH port-forward) ---
ADMIN_BASE_URL_DEFAULT="http://127.0.0.1:8788"
ADMIN_BASE_URL="${ADMIN_BASE_URL:-$ADMIN_BASE_URL_DEFAULT}"
admin_status="skip"
if need_cmd curl; then
  code=$(curl -sS -m 2 -o /dev/null -w '%{http_code}' "${ADMIN_BASE_URL%/}/healthz" 2>/dev/null || true)
  if [[ "$code" == "200" ]]; then
    admin_status="ok"
  elif [[ "$code" == "000" ]]; then
    admin_status="skip" # probably no port-forward
  else
    admin_status="fail"
  fi
fi

if [[ "$JSON" == "1" ]]; then
  TS="$TS" MINUTES="$MINUTES" \
  REPO_OK="$repo_ok" REPO_LINE="$repo_line" \
  SERVER_STATUS="$server_status" SERVER_HOST="$server_host" \
  API_STATUS="$api_status" API_BASE_URL="$BASE_URL" \
  ADMIN_STATUS="$admin_status" ADMIN_BASE_URL="$ADMIN_BASE_URL" \
  python3 - <<'PY'
import json, os

def b(v: str) -> bool:
  return v.strip() in ("1","true","True","yes","ok")

obj = {
  "ts": os.environ.get("TS",""),
  "minutes": int(os.environ.get("MINUTES","15")),
  "repo": {
    "ok": b(os.environ.get("REPO_OK","0")),
    "last": os.environ.get("REPO_LINE", ""),
  },
  "server": {
    "status": os.environ.get("SERVER_STATUS","skip"),
    "host": os.environ.get("SERVER_HOST",""),
  },
  "api": {
    "status": os.environ.get("API_STATUS","skip"),
    "baseUrl": os.environ.get("API_BASE_URL",""),
  },
  "admin": {
    "status": os.environ.get("ADMIN_STATUS","skip"),
    "baseUrl": os.environ.get("ADMIN_BASE_URL",""),
  },
}
print(json.dumps(obj, ensure_ascii=False))
PY
  exit 0
fi

echo "[${TS}] check-artifact-window: last ${MINUTES} minutes"

if [[ "$repo_ok" == "1" ]]; then
  echo "repo: OK (has commit in window)"
  printf '  %s\n\n' "$repo_line"
else
  echo "repo: WARN (no commit in window)"
fi

if [[ -f /tmp/server.txt ]]; then
  echo "server: probing quota-proxy (compose ps + /healthz)"
  if need_cmd ssh; then
    ./scripts/ssh-healthz-quota-proxy.sh
  else
    echo "server: SKIP (ssh not available)"
  fi
else
  echo "server: SKIP (/tmp/server.txt not found)"
fi

echo

echo "api: probing ${BASE_URL}"
if need_cmd curl; then
  ./scripts/probe-roc-api.sh
else
  echo "api: SKIP (curl not available)"
fi

echo

echo "admin: probing ${ADMIN_BASE_URL} (optional; expects SSH port-forward)"
if [[ "$admin_status" == "ok" ]]; then
  ./scripts/probe-quota-proxy-admin.sh
elif [[ "$admin_status" == "skip" ]]; then
  echo "admin: SKIP (no local port-forward detected; run ./scripts/ssh-portforward-quota-proxy-admin.sh)"
else
  echo "admin: WARN (healthz not OK; try running ./scripts/probe-quota-proxy-admin.sh for details)"
fi
