#!/usr/bin/env bash
set -euo pipefail

# Deploy static site files to ROC server.
#
# Source: ./web/site/
# Dest:   /opt/roc/web/ (default)
# Server: /tmp/server.txt contains `ip:<addr>` or `ip=<addr>`
# Auth:   SSH key (no password)
#
# Examples:
#   ./scripts/deploy-web-site.sh
#   ./scripts/deploy-web-site.sh --dry-run
#   REMOTE_DIR=/opt/roc/web/site ./scripts/deploy-web-site.sh
#   ./scripts/deploy-web-site.sh --remote-dir /opt/roc/web/site

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/sync-web-site-assets.sh" >/dev/null

SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_DIR="${REMOTE_DIR:-/opt/roc/web}"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: deploy-web-site.sh [--remote-dir DIR] [--dry-run]

Options:
  --remote-dir DIR  Remote directory to copy site files into (default: /opt/roc/web)
  --dry-run         Print what would happen, do not SSH/SCP

Env:
  SERVER_FILE   default: /tmp/server.txt
  SSH_KEY       default: ~/.ssh/id_ed25519_roc_server
  REMOTE_USER   default: root
  REMOTE_DIR    default: /opt/roc/web
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote-dir)
      REMOTE_DIR="${2:-}"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[ERR] unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$REMOTE_DIR" ]]; then
  echo "[ERR] --remote-dir cannot be empty" >&2
  exit 2
fi

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

echo "[deploy] src=$SRC_DIR"
echo "[deploy] remote=$remote dir=$REMOTE_DIR"

echo "[deploy] files: $(find "$SRC_DIR" -maxdepth 1 -type f | wc -l)" 

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] would: ssh mkdir -p '$REMOTE_DIR'"
  echo "[dry-run] would: scp '$SRC_DIR/*' -> '$remote:$REMOTE_DIR/'"
  exit 0
fi

# Backup index.html if exists
ssh "${SSH_OPTS[@]}" "$remote" "set -e; mkdir -p '$REMOTE_DIR'; if [[ -f '$REMOTE_DIR/index.html' ]]; then cp '$REMOTE_DIR/index.html' '$REMOTE_DIR/index.html.bak.$(date +%s)'; fi"

# Copy files
scp "${SSH_OPTS[@]}" -r "$SRC_DIR/"* "$remote:$REMOTE_DIR/"

# Basic verification
ssh "${SSH_OPTS[@]}" "$remote" "set -e; ls -la '$REMOTE_DIR' | head; echo '---'; sed -n '1,20p' '$REMOTE_DIR/index.html'"

echo "[deploy] OK"
