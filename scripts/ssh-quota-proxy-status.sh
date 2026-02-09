#!/usr/bin/env bash
set -euo pipefail

# Combined remote status check for ROC quota-proxy.
# Wraps:
#   - ssh-healthz-quota-proxy.sh --json (compose_up_count + healthz_ok)
#   - ssh-audit-quota-proxy-exposure.sh --json (port binding exposure risk)
# and prints a single summary (human-readable by default; JSON with --json).

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/ssh-quota-proxy-status.sh [--host <root@ip|ip>] [--json]

Defaults:
  --host : from $CLAWD_SERVER_HOST, else /tmp/server.txt (expects: ip:<addr>)

Checks (remote):
  - docker compose ps (via ssh-healthz)
  - /healthz (127.0.0.1:8787)
  - port binding exposure risk (expect 127.0.0.1:8787->8787)

Output:
  - default: human-readable summary + compose ps + healthz
  - --json : single-line JSON (good for cron/CI)

Examples:
  ./scripts/ssh-quota-proxy-status.sh
  ./scripts/ssh-quota-proxy-status.sh --host 8.210.185.194
  ./scripts/ssh-quota-proxy-status.sh --json | python3 -m json.tool
USAGE
}

HOST=""
AS_JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2;;
    --json) AS_JSON=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

# Prefer explicit env override (useful for cron/CI runners without /tmp/server.txt).
if [[ -z "${HOST}" && -n "${CLAWD_SERVER_HOST:-}" ]]; then
  HOST="${CLAWD_SERVER_HOST}"
fi

# Reuse the host parsing behavior from ssh-healthz-quota-proxy.sh.
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

if [[ ${AS_JSON} -eq 0 ]]; then
  echo "== quota-proxy remote status =="
  echo "host=${HOST}"
  echo

  # 1) Exposure audit (human)
  ./scripts/ssh-audit-quota-proxy-exposure.sh || true
  echo

  # 2) Healthz + compose (human)
  ./scripts/ssh-healthz-quota-proxy.sh --host "${HOST#root@}"
  exit 0
fi

# JSON mode
healthz_json=$(./scripts/ssh-healthz-quota-proxy.sh --host "${HOST#root@}" --json)

# ssh-audit exits non-zero if exposed; keep JSON anyway
set +e
exposure_json=$(CLAWD_SERVER_HOST="${HOST#root@}" ./scripts/ssh-audit-quota-proxy-exposure.sh --json 2>/dev/null)
exposure_rc=$?
set -e

compose_ok=$(printf '%s' "$healthz_json" | grep -o '"compose_ok":[0-9]\+' | head -n1 | cut -d: -f2 || echo 0)
healthz_ok=$(printf '%s' "$healthz_json" | grep -o '"healthz_ok":[0-9]\+' | head -n1 | cut -d: -f2 || echo 0)

exposure_ok=false
if printf '%s' "$exposure_json" | grep -q '"ok":true'; then
  exposure_ok=true
fi

overall_ok=0
if [[ "${compose_ok}" == "1" && "${healthz_ok}" == "1" && "${exposure_ok}" == "true" && ${exposure_rc} -eq 0 ]]; then
  overall_ok=1
fi

ts=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z')

# Single-line JSON, nested objects.
json=$(printf '{"ts":"%s","host":"%s","healthz":%s,"exposure":%s,"overall_ok":%s}\n' \
  "$ts" \
  "${HOST}" \
  "$healthz_json" \
  "${exposure_json:-{}}" \
  "$overall_ok")

# Defensive: in rare shells/TTYs we observed an extra '}' being inserted before overall_ok.
# Normalize if that happens so downstream parsers (python -m json.tool) don't fail.
json=$(printf '%s' "$json" | sed 's/}},"overall_ok"/},"overall_ok"/')

printf '%s\n' "$json"

exit $([[ $overall_ok -eq 1 ]] && echo 0 || echo 5)
