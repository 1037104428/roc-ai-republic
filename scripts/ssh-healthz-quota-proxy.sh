#!/usr/bin/env bash
set -euo pipefail

# Quick remote health check for ROC quota-proxy.
# Default host is read from /tmp/server.txt (format: ip:<addr>).

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ssh-healthz-quota-proxy.sh [--host <root@ip|ip>] [--path <remote-path>] [--json]

Defaults:
  --host : from /tmp/server.txt (expects: ip:<addr>)
  --path : /opt/roc/quota-proxy

Checks:
  - docker compose ps (and a minimal "is anything up" check)
  - curl -fsS http://127.0.0.1:8787/healthz

Output:
  - default: human-readable (compose ps + healthz body)
  - --json : single-line JSON summary (good for cron/CI)

Examples:
  ./scripts/ssh-healthz-quota-proxy.sh
  ./scripts/ssh-healthz-quota-proxy.sh --host 8.210.185.194
  ./scripts/ssh-healthz-quota-proxy.sh --host root@8.210.185.194 --path /opt/roc/quota-proxy
  ./scripts/ssh-healthz-quota-proxy.sh --json
USAGE
}

HOST=""
REMOTE_PATH="/opt/roc/quota-proxy"
AS_JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2;;
    --path) REMOTE_PATH="${2:-}"; shift 2;;
    --json) AS_JSON=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "${HOST}" ]]; then
  if [[ -f /tmp/server.txt ]]; then
    # Accept:
    #   ip:8.210.185.194 | ip: 8.210.185.194 | ip=8.210.185.194
    # Even if /tmp/server.txt contains extra lines.
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

if [[ ${AS_JSON} -eq 0 ]]; then
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "${HOST}" \
    "cd '${REMOTE_PATH}' && docker compose ps && echo && curl -fsS http://127.0.0.1:8787/healthz && echo"
  exit 0
fi

# JSON mode: do not require jq; keep it a single line.
# We intentionally do NOT expose full 'docker compose ps' output (too noisy);
# we only check whether any container is present and whether /healthz returns ok.
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "${HOST}" \
  "cd '${REMOTE_PATH}' \
    && up_count=\$(docker compose ps --quiet 2>/dev/null | wc -l | tr -d ' ') \
    && healthz=\$(curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null || true) \
    && healthz_compact=\$(printf '%s' \"\${healthz}\" | tr -d '[:space:]') \
    && ts=\$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z') \
    && compose_ok=0; if [ \"\${up_count}\" -gt 0 ]; then compose_ok=1; fi \
    && healthz_ok=0; if [ \"\${healthz_compact}\" = '{\"ok\":true}' ]; then healthz_ok=1; fi \
    && printf '{\"ts\":\"%s\",\"host\":\"%s\",\"remote_path\":\"%s\",\"compose_up_count\":%s,\"compose_ok\":%s,\"healthz_ok\":%s}\n' \"\${ts}\" \"${HOST}\" \"${REMOTE_PATH}\" \"\${up_count}\" \"\${compose_ok}\" \"\${healthz_ok}\""