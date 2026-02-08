#!/usr/bin/env bash
set -euo pipefail

# Purpose:
# - Non-interactive server healthcheck for quota-proxy.
# - Intended for cron usage.
#
# Requirements:
# - SSH key-based auth (no password prompts).
# - /tmp/server.txt contains `ip:<server-ip>`.

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
REMOTE_DIR="${REMOTE_DIR:-/opt/roc/quota-proxy}"
REMOTE_USER="${REMOTE_USER:-root}"

if [[ ! -f "$SERVER_FILE" ]]; then
  echo "[ERR] server file missing: $SERVER_FILE" >&2
  exit 2
fi

ip_line="$(grep -E '^ip:' "$SERVER_FILE" | tail -n 1 || true)"
if [[ -z "$ip_line" ]]; then
  echo "[ERR] cannot find ip:<addr> in $SERVER_FILE" >&2
  exit 2
fi

SERVER_IP="${ip_line#ip:}"
SERVER_IP="${SERVER_IP//[[:space:]]/}"

SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

remote="$REMOTE_USER@$SERVER_IP"

cmd=$'set -euo pipefail\n'
cmd+="cd \"$REMOTE_DIR\"\n"
cmd+=$'docker compose ps\n'
cmd+=$'curl -fsS http://127.0.0.1:8787/healthz\n'

ssh "${SSH_OPTS[@]}" "$remote" "$cmd"
