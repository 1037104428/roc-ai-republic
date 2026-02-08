#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
quota-proxy-admin.sh - helper for quota-proxy admin endpoints

Usage:
  quota-proxy-admin.sh [--host URL] [--admin-token TOKEN|--admin-token-env ENV] <command> [args]

Options:
  --host URL             Admin base URL (default: http://127.0.0.1:8787)
  --admin-token TOKEN    Admin token value (preferred: keep out of shell history)
  --admin-token-env ENV  Read admin token from env var name (default: ADMIN_TOKEN)
  -h, --help             Show help

Commands:
  keys-create --label TEXT   Create/issue a new TRIAL_KEY with a label
  keys-list                 List issued keys
  usage [--day YYYY-MM-DD] [--key TRIAL_KEY]
                           Query usage aggregated by day

Examples:
  export ADMIN_TOKEN='***'
  ./scripts/quota-proxy-admin.sh keys-create --label 'forum-user:alice'
  ./scripts/quota-proxy-admin.sh usage --day "$(date +%F)"

Notes:
  - quota-proxy must be started with SQLITE_PATH + ADMIN_TOKEN enabled.
  - This script does not require jq; it will pretty-print if jq is installed.
EOF
}

HOST="http://127.0.0.1:8787"
ADMIN_TOKEN_ENV="ADMIN_TOKEN"
ADMIN_TOKEN_VALUE=""

# parse global flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"; shift 2 ;;
    --admin-token)
      ADMIN_TOKEN_VALUE="$2"; shift 2 ;;
    --admin-token-env)
      ADMIN_TOKEN_ENV="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    keys-create|keys-list|usage)
      break ;;
    *)
      echo "Unknown option/command: $1" >&2
      usage
      exit 2
      ;;
  esac
done

CMD="${1:-}"; shift || true

if [[ -z "$CMD" ]]; then
  usage
  exit 2
fi

if [[ -z "$ADMIN_TOKEN_VALUE" ]]; then
  # shellcheck disable=SC2154
  ADMIN_TOKEN_VALUE="${!ADMIN_TOKEN_ENV:-}"
fi

if [[ -z "$ADMIN_TOKEN_VALUE" ]]; then
  echo "Missing admin token. Provide --admin-token or export ${ADMIN_TOKEN_ENV}." >&2
  exit 2
fi

curl_json() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}"

  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer ${ADMIN_TOKEN_VALUE}" \
      -H 'content-type: application/json' \
      -d "$data"
  else
    curl -fsS -X "$method" "$url" \
      -H "Authorization: Bearer ${ADMIN_TOKEN_VALUE}"
  fi
}

pretty() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    cat
  fi
}

case "$CMD" in
  keys-create)
    LABEL=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label)
          LABEL="$2"; shift 2 ;;
        -h|--help)
          usage; exit 0 ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 2
          ;;
      esac
    done
    if [[ -z "$LABEL" ]]; then
      echo "keys-create requires --label" >&2
      exit 2
    fi
    curl_json POST "${HOST%/}/admin/keys" "{\"label\":\"${LABEL//"/\\\"}\"}" | pretty
    ;;

  keys-list)
    curl_json GET "${HOST%/}/admin/keys" | pretty
    ;;

  usage)
    DAY=""
    KEY=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --day)
          DAY="$2"; shift 2 ;;
        --key)
          KEY="$2"; shift 2 ;;
        -h|--help)
          usage; exit 0 ;;
        *)
          echo "Unknown arg: $1" >&2
          usage
          exit 2
          ;;
      esac
    done
    if [[ -z "$DAY" ]]; then
      DAY="$(date +%F)"
    fi
    QS="day=${DAY}"
    if [[ -n "$KEY" ]]; then
      QS="${QS}&key=${KEY}"
    fi
    curl_json GET "${HOST%/}/admin/usage?${QS}" | pretty
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 2
    ;;
esac
