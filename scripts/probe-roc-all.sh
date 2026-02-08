#!/usr/bin/env bash
set -euo pipefail

# probe-roc-all.sh
# One-shot probe for ROC public endpoints + quota-proxy on server pointed by /tmp/server.txt.
# Usage:
#   ./scripts/probe-roc-all.sh
# Optional env:
#   SERVER_TXT=/tmp/server.txt

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_TXT="${SERVER_TXT:-/tmp/server.txt}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"; }

die() { echo "ERROR: $*" >&2; exit 1; }

cd "$ROOT_DIR"

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
./scripts/ssh-run-server-txt.sh "curl -fsS http://127.0.0.1:8787/healthz"

log "OK"
