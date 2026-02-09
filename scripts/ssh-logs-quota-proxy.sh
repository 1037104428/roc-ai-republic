#!/usr/bin/env bash
set -euo pipefail

# Fetch remote logs for ROC quota-proxy via SSH.
# Default host is read from /tmp/server.txt (format: ip:<addr>).

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ssh-logs-quota-proxy.sh [--host <root@ip|ip>] [--path <remote-path>] [--tail <n>] [--since <duration>]

Defaults:
  --host : from /tmp/server.txt (expects: ip:<addr>)
  --path : /opt/roc/quota-proxy
  --tail : 200

Notes:
  --since is passed to `docker compose logs --since ...` (supported by recent Docker Compose).
  Use values like: 10m | 1h | 24h

Examples:
  ./scripts/ssh-logs-quota-proxy.sh
  ./scripts/ssh-logs-quota-proxy.sh --tail 500
  ./scripts/ssh-logs-quota-proxy.sh --since 10m
  ./scripts/ssh-logs-quota-proxy.sh --host 8.210.185.194 --since 30m
USAGE
}

HOST=""
REMOTE_PATH="/opt/roc/quota-proxy"
TAIL="200"
SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2;;
    --path) REMOTE_PATH="${2:-}"; shift 2;;
    --tail) TAIL="${2:-}"; shift 2;;
    --since) SINCE="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "${HOST}" ]]; then
  if [[ -f /tmp/server.txt ]]; then
    ip=$(awk '
      BEGIN{ip=""}
      /^[[:space:]]*ip[[:space:]]*[:=]/{
        line=$0
        sub(/^[[:space:]]*ip[[:space:]]*[:=][[:space:]]*/,"",line)
        gsub(/[[:space:]]+/,"",line)
        ip=line
      }
      END{print ip}
    ' /tmp/server.txt | tr -d '\r')

    if [[ -n "${ip}" ]]; then
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

# Build docker compose logs command (avoid complex quoting on remote side)
remote_cmd=("cd" "${REMOTE_PATH}" "&&" "docker" "compose" "logs" "--no-color" "--tail" "${TAIL}")
if [[ -n "${SINCE}" ]]; then
  remote_cmd+=("--since" "${SINCE}")
fi

ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "${HOST}" \
  "${remote_cmd[*]}"
