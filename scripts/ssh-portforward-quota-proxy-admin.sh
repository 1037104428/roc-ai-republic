#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ssh-portforward-quota-proxy-admin.sh [--host root@1.2.3.4] [--local-port 8788] [--remote-port 8787]

Description:
  Create an SSH local port-forward for quota-proxy admin endpoints.
  For safety, this avoids exposing admin endpoints to the public Internet.

Defaults:
  --host        read from /tmp/server.txt (format: ip:<HOST>)
  --local-port  8788
  --remote-port 8787   (quota-proxy listens on 127.0.0.1:<remote-port> on the server)

Examples:
  # Use /tmp/server.txt
  ./scripts/ssh-portforward-quota-proxy-admin.sh

  # Explicit host
  ./scripts/ssh-portforward-quota-proxy-admin.sh --host root@8.210.185.194

Then (in another terminal):
  BASE_URL=http://127.0.0.1:8788 ADMIN_TOKEN=... ./scripts/curl-admin-create-key.sh
  BASE_URL=http://127.0.0.1:8788 ADMIN_TOKEN=... ./scripts/curl-admin-usage.sh --mask

Tip:
  Keep this SSH session running while you do admin curls.
EOF
}

HOST=""
LOCAL_PORT="8788"
REMOTE_PORT="8787"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --host) HOST="${2:-}"; shift 2;;
    --local-port) LOCAL_PORT="${2:-}"; shift 2;;
    --remote-port) REMOTE_PORT="${2:-}"; shift 2;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$HOST" ]]; then
  if [[ -f /tmp/server.txt ]]; then
    HOST_IP=$(sed -n 's/^ip://p' /tmp/server.txt | head -n1 | tr -d ' \t\r')
    if [[ -n "${HOST_IP}" ]]; then
      HOST="root@${HOST_IP}"
    fi
  fi
fi

if [[ -z "$HOST" ]]; then
  echo "ERROR: missing --host and /tmp/server.txt has no ip:<HOST>" >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "ERROR: ssh not found" >&2
  exit 1
fi

echo "Forwarding: 127.0.0.1:${LOCAL_PORT} -> ${HOST} 127.0.0.1:${REMOTE_PORT}" >&2
echo "Press Ctrl+C to stop." >&2

exec ssh \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
  "$HOST"
