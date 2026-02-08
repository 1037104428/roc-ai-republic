#!/usr/bin/env bash
set -euo pipefail

# Run a command on the root server described by /tmp/server.txt (ip only) using SSH key.
#
# Usage:
#   ./scripts/ssh-run-roc-key.sh "cd /opt/roc/quota-proxy && docker compose ps"
#
# server.txt formats accepted:
#   ip:8.210.185.194
#   ip: 8.210.185.194
#   ip=8.210.185.194

if [[ ${1:-} == "" ]]; then
  echo "usage: $0 <remote-shell-command>" >&2
  exit 2
fi

if grep -qE '^password:' /tmp/server.txt 2>/dev/null; then
  echo "warn: /tmp/server.txt contains password:. Prefer key-only auth; keep only ip:..., and chmod 600 /tmp/server.txt" >&2
fi

ip=$(awk '
  BEGIN{ip=""}
  # Preferred: ip:1.2.3.4 (or ip=...)
  /^[[:space:]]*ip[[:space:]]*[:=]/{
    line=$0
    sub(/^[[:space:]]*ip[[:space:]]*[:=][[:space:]]*/,"",line)
    gsub(/[[:space:]]+/,"",line)
    ip=line
  }
  # Fallback: a bare IPv4 on its own line
  ip=="" && $0 ~ /^[[:space:]]*([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]]*$/ {
    line=$0
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",line)
    ip=line
  }
  END{print ip}
' /tmp/server.txt)
if [[ -z ${ip} ]]; then
  echo "error: /tmp/server.txt missing ip. expected: ip:1.2.3.4 (or ip=1.2.3.4)" >&2
  exit 2
fi

key=${ROC_SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}

ssh \
  -i "$key" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=8 \
  root@"$ip" \
  "$1"
