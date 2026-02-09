#!/usr/bin/env bash
set -euo pipefail

# Quick verification of quota-proxy database health
# Usage: bash scripts/verify-quota-db-health.sh [--remote]

REMOTE=0
if [[ "${1:-}" == "--remote" ]]; then
  REMOTE=1
  shift
fi

if [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--remote]" >&2
  echo "  --remote: Check remote server (requires SSH access)" >&2
  exit 2
fi

log() { printf -- '[%s] %s\n' "$(date '+%F %T')" "$*"; }

if [[ $REMOTE -eq 1 ]]; then
  # Read server IP from /tmp/server.txt
  SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
  if [[ ! -f "$SERVER_FILE" ]]; then
    log "ERROR: Server file not found: $SERVER_FILE"
    log "Create it with: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
  fi
  
  SERVER_IP=$(head -1 "$SERVER_FILE" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [[ -z "$SERVER_IP" ]]; then
    log "ERROR: Could not extract IP from $SERVER_FILE"
    exit 1
  fi
  
  SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
  SSH_FLAGS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8)
  
  log "Checking remote quota-proxy database health on $SERVER_IP..."
  ssh "${SSH_FLAGS[@]}" "root@$SERVER_IP" \
    "cd /opt/roc/quota-proxy && curl -fsS http://127.0.0.1:8787/healthz/db" | jq . 2>/dev/null || {
    log "ERROR: Failed to check remote database health"
    exit 1
  }
else
  log "Checking local quota-proxy database health (assuming localhost:8787)..."
  curl -fsS http://127.0.0.1:8787/healthz/db 2>/dev/null | jq . || {
    log "ERROR: Failed to check local database health"
    log "Make sure quota-proxy is running locally on port 8787"
    exit 1
  }
fi

log "✅ Database health check passed"