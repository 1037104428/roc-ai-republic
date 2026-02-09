#!/usr/bin/env bash
set -euo pipefail

# Show remote `docker compose ps` for quota-proxy.
# - Reads host from /tmp/server.txt (via ssh-run-roc-key.sh)
# - Intended for quick human check / pasteable evidence in progress logs

REMOTE_DIR_DEFAULT="/opt/roc/quota-proxy"
REMOTE_DIR="${REMOTE_DIR:-$REMOTE_DIR_DEFAULT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ssh-compose-ps-quota-proxy.sh [--dir /opt/roc/quota-proxy]

Env:
  REMOTE_DIR   Remote dir containing docker-compose.yml (default: /opt/roc/quota-proxy)

Notes:
  - Host is parsed from /tmp/server.txt by scripts/ssh-run-roc-key.sh
  - Requires non-interactive SSH (key auth).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--dir" ]]; then
  REMOTE_DIR="${2:-}"
  shift 2 || true
fi

"$SCRIPT_DIR/ssh-run-roc-key.sh" "cd '$REMOTE_DIR' && docker compose ps"
