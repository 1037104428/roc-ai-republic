#!/usr/bin/env bash
set -euo pipefail

# ROC / OpenClaw CN Pack - one-shot probe
# Usage:
#   bash scripts/probe.sh
# Optional env:
#   WEB_URL=https://clawdrepublic.cn
#   API_URL=https://api.clawdrepublic.cn
#   FORUM_PATH=/forum/
#   SSH_HOST=root@8.210.185.194
#   SSH_KEY=~/.ssh/id_ed25519_roc_server

WEB_URL="${WEB_URL:-https://clawdrepublic.cn}"
API_URL="${API_URL:-https://api.clawdrepublic.cn}"
FORUM_PATH="${FORUM_PATH:-/forum/}"
SSH_HOST="${SSH_HOST:-root@8.210.185.194}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"

curl_flags=( -fsS -m 8 )
ssh_flags=( -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 )

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

log "web:  ${WEB_URL}/"
curl "${curl_flags[@]}" "${WEB_URL}/" >/dev/null

log "api:  ${API_URL}/healthz"
curl "${curl_flags[@]}" "${API_URL}/healthz" | sed -n '1,3p'

log "api:  ${API_URL}/v1/models (optional; should return JSON)"
if ! curl "${curl_flags[@]}" "${API_URL}/v1/models" | head -c 200; then
  log "warn: /v1/models not available (ok for older deployments)"
fi
printf '\n'

log "forum: ${WEB_URL}${FORUM_PATH}"
# Prefer status-code probe (stable). Optionally print a short hint from HTML title.
code="$(curl -m 8 -sS -o /tmp/roc_forum_probe.html -w '%{http_code}' "${WEB_URL}${FORUM_PATH}" || true)"
if [[ "$code" == "200" || "$code" == "302" ]]; then
  title="$(grep -i -m1 -o '<title>[^<]*' /tmp/roc_forum_probe.html 2>/dev/null | sed 's/<title>//' || true)"
  [[ -n "$title" ]] && log "forum: OK (title: $title)" || log "forum: OK"
else
  log "forum: FAIL (http $code)"
  exit 1
fi

log "server: quota-proxy healthz via ssh (${SSH_HOST})"
ssh "${ssh_flags[@]}" "$SSH_HOST" 'curl -fsS -m 5 http://127.0.0.1:8787/healthz'

log "server: docker compose ps (/opt/roc/quota-proxy)"
ssh "${ssh_flags[@]}" "$SSH_HOST" 'cd /opt/roc/quota-proxy && docker compose ps'

log "OK"
