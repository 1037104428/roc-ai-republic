#!/usr/bin/env bash
set -euo pipefail

# probe-roc-all.sh
# One-shot probe for ROC public endpoints + quota-proxy on server pointed by /tmp/server.txt.
#
# Usage:
#   ./scripts/probe-roc-all.sh
#   ./scripts/probe-roc-all.sh --json
#
# Optional env:
#   SERVER_TXT=/tmp/server.txt
#   HOME_URL=https://clawdrepublic.cn
#   API_HEALTHZ_URL=https://api.clawdrepublic.cn/healthz

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_TXT="${SERVER_TXT:-/tmp/server.txt}"
HOME_URL="${HOME_URL:-https://clawdrepublic.cn}"
API_HEALTHZ_URL="${API_HEALTHZ_URL:-https://api.clawdrepublic.cn/healthz}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"; }

die() { echo "ERROR: $*" >&2; exit 1; }

MODE="pretty"
if [[ "${1:-}" == "--json" ]]; then
  MODE="json"
  shift
fi
if [[ "$#" -ne 0 ]]; then
  die "unknown args: $*"
fi

cd "$ROOT_DIR"

if [[ "$MODE" == "json" ]]; then
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"

  home_ok=0
  api_ok=0
  server_ok=0

  if curl -fsS -m 10 "$HOME_URL" >/dev/null; then home_ok=1; fi

  if curl -fsS -m 10 "$API_HEALTHZ_URL" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then api_ok=1; fi

  if [[ -f "$SERVER_TXT" ]]; then
    if [[ ! -x ./scripts/ssh-run-server-txt.sh ]]; then
      server_ok=0
    else
      if ./scripts/ssh-run-server-txt.sh "curl -fsS -m 5 http://127.0.0.1:8787/healthz" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
        server_ok=1
      fi
    fi
  else
    # server optional; treat as OK if not configured
    server_ok=1
  fi

  printf '{"ts":"%s","home_ok":%s,"api_ok":%s,"server_ok":%s}\n' \
    "$ts" \
    "$([[ $home_ok -eq 1 ]] && echo true || echo false)" \
    "$([[ $api_ok -eq 1 ]] && echo true || echo false)" \
    "$([[ $server_ok -eq 1 ]] && echo true || echo false)"
  exit 0
fi

log "probe: public endpoints"
./scripts/verify-roc-public.sh

if [[ ! -f "$SERVER_TXT" ]]; then
  log "skip: server probe (missing $SERVER_TXT)"
  exit 0
fi

if [[ ! -x ./scripts/ssh-run-server-txt.sh ]]; then
  die "missing ./scripts/ssh-run-server-txt.sh"
fi

log "probe: quota-proxy compose ps (server from $SERVER_TXT)"
./scripts/ssh-run-server-txt.sh "cd /opt/roc/quota-proxy && docker compose ps"

log "probe: quota-proxy healthz (localhost on server)"
./scripts/ssh-run-server-txt.sh "curl -fsS -m 5 http://127.0.0.1:8787/healthz"

log "OK"
