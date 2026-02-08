#!/usr/bin/env bash
set -euo pipefail

# Deploy static site files to ROC server.
# - Source:   ./web/site/
# - Dest:     /opt/roc/web/site/
# - Server IP: /tmp/server.txt contains `ip:<addr>` or `ip=<addr>`
# - Auth:     SSH key (no password)

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/roc/web/site}"

if [[ ! -f "$SERVER_FILE" ]]; then
  echo "[ERR] server file missing: $SERVER_FILE" >&2
  exit 2
fi

ip=$(
  awk -F"[:=]" '/^ip/{gsub(/ /, "", $2); print $2}' "$SERVER_FILE" | tail -n 1
)
if [[ -z "$ip" ]]; then
  echo "[ERR] cannot parse ip from $SERVER_FILE (expect ip:<addr> or ip=<addr>)" >&2
  exit 2
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "[ERR] ssh key missing: $SSH_KEY" >&2
  exit 2
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/web/site"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "[ERR] src dir missing: $SRC_DIR" >&2
  exit 2
fi

SSH_OPTS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

remote="$REMOTE_USER@$ip"

echo "[deploy] remote=$remote dir=$REMOTE_DIR"

# Backup index.html if exists
ssh "${SSH_OPTS[@]}" "$remote" "set -e; mkdir -p '$REMOTE_DIR'; if [[ -f '$REMOTE_DIR/index.html' ]]; then cp '$REMOTE_DIR/index.html' '$REMOTE_DIR/index.html.bak.$(date +%s)'; fi"

# Copy files
scp "${SSH_OPTS[@]}" -r "$SRC_DIR/"* "$remote:$REMOTE_DIR/"

# Basic verification
ssh "${SSH_OPTS[@]}" "$remote" "set -e; ls -la '$REMOTE_DIR'; echo '---'; sed -n '1,20p' '$REMOTE_DIR/index.html'"

echo "[deploy] OK"
