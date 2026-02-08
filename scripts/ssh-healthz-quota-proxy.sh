#!/usr/bin/env bash
set -euo pipefail

# Quick remote health check for ROC quota-proxy.
# Default host is read from /tmp/server.txt (format: ip:<addr>).

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ssh-healthz-quota-proxy.sh [--host <root@ip|ip>] [--path <remote-path>]

Defaults:
  --host : from /tmp/server.txt (expects: ip:<addr>)
  --path : /opt/roc/quota-proxy

Checks:
  - docker compose ps
  - curl -fsS http://127.0.0.1:8787/healthz

Examples:
  ./scripts/ssh-healthz-quota-proxy.sh
  ./scripts/ssh-healthz-quota-proxy.sh --host 8.210.185.194
  ./scripts/ssh-healthz-quota-proxy.sh --host root@8.210.185.194 --path /opt/roc/quota-proxy
USAGE
}

HOST=""
REMOTE_PATH="/opt/roc/quota-proxy"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2;;
    --path) REMOTE_PATH="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "${HOST}" ]]; then
  if [[ -f /tmp/server.txt ]]; then
    # expecting: ip:8.210.185.194
    ip_line="$(cat /tmp/server.txt | tr -d '\r' | tail -n 1)"
    ip="${ip_line#ip:}"
    if [[ -n "${ip}" && "${ip}" != "${ip_line}" ]]; then
      HOST="root@${ip}"
    fi
  fi
fi

if [[ -z "${HOST}" ]]; then
  echo "ERROR: missing --host and /tmp/server.txt not usable." >&2
  exit 2
fi

# allow passing raw ip
if [[ "${HOST}" != *"@"* ]]; then
  HOST="root@${HOST}"
fi

ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 "${HOST}" \
  "cd '${REMOTE_PATH}' && docker compose ps && echo && curl -fsS http://127.0.0.1:8787/healthz"
