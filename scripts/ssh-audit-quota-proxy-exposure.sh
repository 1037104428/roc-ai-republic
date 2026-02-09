#!/usr/bin/env bash
set -euo pipefail

MIN_BIND="127.0.0.1"

usage() {
  cat <<USAGE
Usage: ssh-audit-quota-proxy-exposure.sh [--json]

Checks quota-proxy docker compose port bindings on the server in /tmp/server.txt.
Pass criteria (default): quota-proxy is bound to 127.0.0.1 (not 0.0.0.0 / ::).

Environment:
  CLAWD_SERVER_HOST  override host (otherwise read /tmp/server.txt with format ip:<HOST>)

Outputs:
  human-readable by default; with --json prints single-line JSON.
USAGE
}

JSON=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--json" ]]; then JSON=1; shift; fi
if [[ $# -ne 0 ]]; then echo "Unexpected args: $*" >&2; usage; exit 2; fi

HOST="${CLAWD_SERVER_HOST:-}"
if [[ -z "$HOST" ]]; then
  if [[ ! -f /tmp/server.txt ]]; then
    echo "/tmp/server.txt not found" >&2
    exit 3
  fi
  HOST=$(awk -F: '/^ip:/{print $2}' /tmp/server.txt | tail -n 1)
fi
if [[ -z "$HOST" ]]; then
  echo "Could not determine host from /tmp/server.txt" >&2
  exit 4
fi

OUT=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 "root@${HOST}" 'cd /opt/roc/quota-proxy && docker compose ps')

# Heuristic parse: look for 0.0.0.0 / ::: or absence of 127.0.0.1 mapping.
EXPOSED=0
if echo "$OUT" | grep -Eq '(0\.0\.0\.0:8787|\[::\]:8787|:::8787)'; then
  EXPOSED=1
fi
BOUND_LOCAL=0
if echo "$OUT" | grep -Eq "${MIN_BIND}:8787->8787"; then
  BOUND_LOCAL=1
fi

OK=0
if [[ $EXPOSED -eq 0 && $BOUND_LOCAL -eq 1 ]]; then
  OK=1
fi

if [[ $JSON -eq 1 ]]; then
  # single-line JSON
  printf '{"host":"%s","ok":%s,"bound_local":%s,"exposed":%s}' \
    "$HOST" \
    "$([[ $OK -eq 1 ]] && echo true || echo false)" \
    "$([[ $BOUND_LOCAL -eq 1 ]] && echo true || echo false)" \
    "$([[ $EXPOSED -eq 1 ]] && echo true || echo false)"
  echo
  exit $([[ $OK -eq 1 ]] && echo 0 || echo 5)
fi

echo "host=$HOST"
echo "$OUT"
echo "---"
if [[ $OK -eq 1 ]]; then
  echo "OK: quota-proxy is bound to ${MIN_BIND}:8787 (not publicly exposed)."
  exit 0
else
  echo "WARN: quota-proxy port binding may be exposed (expected ${MIN_BIND}:8787->8787)." >&2
  exit 5
fi
