#!/usr/bin/env bash
set -euo pipefail

# probe-roc-all.sh
# One-shot probe for ROC public endpoints + quota-proxy on server pointed by /tmp/server.txt.
#
# Usage:
#   ./scripts/probe-roc-all.sh
#   ./scripts/probe-roc-all.sh --json
#   ./scripts/probe-roc-all.sh --timeout 15
#   ./scripts/probe-roc-all.sh --json --timeout 15
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
TIMEOUT=10

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json)
      MODE="json"
      shift
      ;;
    --timeout)
      TIMEOUT="${2:-}"
      [[ -n "$TIMEOUT" ]] || die "--timeout requires a value"
      shift 2
      ;;
    *)
      die "unknown arg: $1"
      ;;
  esac
done

cd "$ROOT_DIR"

if [[ "$MODE" == "json" ]]; then
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"

  home_ok=0
  api_ok=0
  server_ok=0

  if curl -fsS -m "$TIMEOUT" "$HOME_URL" >/dev/null; then home_ok=1; fi

  if curl -fsS -m "$TIMEOUT" "$API_HEALTHZ_URL" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then api_ok=1; fi

  if [[ -f "$SERVER_TXT" ]]; then
    # Normalize /tmp/server.txt (drop password lines, unify ip format)
    if [[ -x ./scripts/sanitize-server-txt.sh ]]; then
      ./scripts/sanitize-server-txt.sh "$SERVER_TXT" >/dev/null || true
    fi

    if [[ ! -x ./scripts/ssh-run-roc-key.sh ]]; then
      server_ok=0
    else
      if ./scripts/ssh-run-roc-key.sh "curl -fsS -m $TIMEOUT http://127.0.0.1:8787/healthz" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
        server_ok=1
      fi
    fi
  else
    # server optional; treat as OK if not configured
    server_ok=1
  fi

  all_ok=0
  if [[ $home_ok -eq 1 && $api_ok -eq 1 && $server_ok -eq 1 ]]; then all_ok=1; fi

  printf '{"ts":"%s","home_ok":%s,"api_ok":%s,"server_ok":%s,"all_ok":%s}\n' \
    "$ts" \
    "$([[ $home_ok -eq 1 ]] && echo true || echo false)" \
    "$([[ $api_ok -eq 1 ]] && echo true || echo false)" \
    "$([[ $server_ok -eq 1 ]] && echo true || echo false)" \
    "$([[ $all_ok -eq 1 ]] && echo true || echo false)"

  # Exit code: 0 if all ok, 2 otherwise (useful for cron/CI)
  if [[ $all_ok -eq 1 ]]; then exit 0; else exit 2; fi
fi

log "probe: public endpoints"
./scripts/verify-roc-public.sh

if [[ ! -f "$SERVER_TXT" ]]; then
  log "skip: server probe (missing $SERVER_TXT)"
  exit 0
fi

# Normalize /tmp/server.txt (drop password lines, unify ip format)
if [[ -x ./scripts/sanitize-server-txt.sh ]]; then
  ./scripts/sanitize-server-txt.sh "$SERVER_TXT" >/dev/null || true
fi

if [[ ! -x ./scripts/ssh-run-roc-key.sh ]]; then
  die "missing ./scripts/ssh-run-roc-key.sh"
fi

log "probe: quota-proxy compose ps (server from $SERVER_TXT)"
./scripts/ssh-run-roc-key.sh "cd /opt/roc/quota-proxy && docker compose ps"

log "probe: quota-proxy healthz (localhost on server)"
./scripts/ssh-run-roc-key.sh "curl -fsS -m $TIMEOUT http://127.0.0.1:8787/healthz"

log "OK"
