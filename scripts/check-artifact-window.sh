#!/usr/bin/env bash
set -euo pipefail

MINUTES=15
if [[ ${1:-} == "--minutes" ]]; then
  MINUTES=${2:?missing minutes}
  shift 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TS="$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z')"
echo "[${TS}] check-artifact-window: last ${MINUTES} minutes"

need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARN: missing command: $cmd" >&2
    return 1
  fi
}


# 1) repo window check
if git log --since="${MINUTES} minutes ago" -1 --pretty=format:'%h %ad %s' --date=iso | grep -q .; then
  echo "repo: OK (has commit in window)"
  git log --since="${MINUTES} minutes ago" -1 --pretty=format:'  %h %ad %s' --date=iso
  echo
else
  echo "repo: WARN (no commit in window)"
fi

# 2) server quota-proxy healthz
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

# 3) public API gateway probe (/healthz + /v1/models)
BASE_URL_DEFAULT="https://api.clawdrepublic.cn"
BASE_URL="${BASE_URL:-$BASE_URL_DEFAULT}"
echo "api: probing ${BASE_URL}"
if need_cmd curl; then
  ./scripts/probe-roc-api.sh
else
  echo "api: SKIP (curl not available)"
fi

