#!/usr/bin/env bash
set -euo pipefail

# ROC / OpenClaw CN Pack - one-shot probe
# Usage:
#   bash scripts/probe.sh [--no-ssh]
#   bash scripts/probe.sh --help
# Optional env:
#   WEB_URL=https://clawdrepublic.cn
#   API_URL=https://api.clawdrepublic.cn
#   FORUM_PATH=/forum/
#   SSH_HOST=root@8.210.185.194
#   SSH_KEY=~/.ssh/id_ed25519_roc_server

NO_SSH=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
One-shot probe for ROC (site/api/forum/server).

Usage:
  bash scripts/probe.sh [--no-ssh]

Options:
  --no-ssh   Skip server checks via ssh (useful for contributors without access).

Env overrides:
  WEB_URL, API_URL, FORUM_PATH, SSH_HOST, SSH_KEY
EOF
  exit 0
fi
if [[ "${1:-}" == "--no-ssh" ]]; then
  NO_SSH=1
  shift || true
fi
if [[ $# -gt 0 ]]; then
  echo "Unknown args: $*" >&2
  echo "Try: bash scripts/probe.sh --help" >&2
  exit 2
fi

WEB_URL="${WEB_URL:-https://clawdrepublic.cn}"
API_URL="${API_URL:-https://api.clawdrepublic.cn}"
FORUM_PATH="${FORUM_PATH:-/forum/}"
SSH_HOST="${SSH_HOST:-root@8.210.185.194}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"

curl_flags=( -fsS -m 8 )
ssh_flags=( -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 )

log() { printf -- '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "web:  ${WEB_URL}/"
curl "${curl_flags[@]}" "${WEB_URL}/" >/dev/null

log "api:  ${API_URL}/healthz"
curl "${curl_flags[@]}" "${API_URL}/healthz" | sed -n '1,3p'

log "api:  ${API_URL}/v1/models (optional; should return JSON)"
if ! curl "${curl_flags[@]}" "${API_URL}/v1/models" | head -c 200; then
  log "warn: /v1/models not available (ok for older deployments)"
fi
printf -- '\n'

log "forum: ${WEB_URL}${FORUM_PATH}"
# Prefer status-code probe (stable). Optionally print a short hint from HTML title.
forum_tmp="$(mktemp -t roc_forum_probe.XXXXXX.html)"
code="$(curl -m 8 -sS -o "$forum_tmp" -w '%{http_code}' "${WEB_URL}${FORUM_PATH}" || true)"
if [[ "$code" == "200" || "$code" == "302" ]]; then
  title="$(grep -i -m1 -o '<title>[^<]*' "$forum_tmp" 2>/dev/null | sed 's/<title>//' || true)"
  [[ -n "$title" ]] && log "forum: OK (title: $title)" || log "forum: OK"
else
  log "forum: FAIL (http $code)"
  rm -f "$forum_tmp" || true
  exit 1
fi
rm -f "$forum_tmp" || true

if [[ "$NO_SSH" == "1" ]]; then
  log "server: skipped (--no-ssh)"
  log "OK"
  exit 0
fi

log "server: quota-proxy healthz via ssh (${SSH_HOST})"
ssh "${ssh_flags[@]}" "$SSH_HOST" 'curl -fsS -m 5 http://127.0.0.1:8787/healthz'

log "server: docker compose ps (/opt/roc/quota-proxy)"
ssh "${ssh_flags[@]}" "$SSH_HOST" 'cd /opt/roc/quota-proxy && docker compose ps'

log "OK"
