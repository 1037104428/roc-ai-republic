#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  verify-trial-key.sh [--base-url URL] [--key TRIAL_KEY] [--chat]

Defaults:
  --base-url https://api.clawdrepublic.cn
  --key      from $CLAWD_TRIAL_KEY (or $TRIAL_KEY)

What it does:
  1) GET  /healthz
  2) GET  /v1/models   (should succeed; usually does not call upstream)
  3) POST /v1/chat/completions (only if --chat; will consume quota)

Examples:
  export CLAWD_TRIAL_KEY='trial_xxx'
  ./scripts/verify-trial-key.sh

  ./scripts/verify-trial-key.sh --base-url https://api.clawdrepublic.cn --chat
EOF
}

BASE_URL="https://api.clawdrepublic.cn"
KEY="${CLAWD_TRIAL_KEY:-${TRIAL_KEY:-}}"
DO_CHAT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    --key) KEY="$2"; shift 2 ;;
    --chat) DO_CHAT=1; shift ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$KEY" ]]; then
  echo "Missing trial key. Provide --key or set CLAWD_TRIAL_KEY." >&2
  exit 2
fi

healthz() {
  curl -fsS -m 5 "$BASE_URL/healthz" >/dev/null
}

models() {
  curl -fsS -m 10 "$BASE_URL/v1/models" \
    -H "Authorization: Bearer $KEY" >/dev/null
}

chat() {
  curl -fsS -m 30 "$BASE_URL/v1/chat/completions" \
    -H "Authorization: Bearer $KEY" \
    -H 'content-type: application/json' \
    -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好"}]}' >/dev/null
}

echo "[1/3] healthz..." >&2
healthz

echo "[2/3] models..." >&2
models

if [[ "$DO_CHAT" -eq 1 ]]; then
  echo "[3/3] chat.completions (--chat)..." >&2
  chat
else
  echo "[3/3] chat.completions skipped (use --chat to run)" >&2
fi

echo "OK" >&2
