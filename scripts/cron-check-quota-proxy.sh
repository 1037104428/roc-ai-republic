#!/usr/bin/env bash
set -euo pipefail

TZ_REGION="${TZ_REGION:-Asia/Shanghai}"
REPO_DIR="${REPO_DIR:-/home/kai/.openclaw/workspace/roc-ai-republic}"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
PROGRESS_LOG="${PROGRESS_LOG:-/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md}"
WINDOW_MINUTES="${WINDOW_MINUTES:-15}"

now_epoch=$(TZ="$TZ_REGION" date +%s)
now_str=$(TZ="$TZ_REGION" date '+%F %T %Z')

echo "[$now_str] === ROC quota-proxy rolling check ==="

echo "\n[1/4] git log -n 10"
git -C "$REPO_DIR" log -n 10 --pretty=format:'%h %ad %s' --date=iso || true

echo "\n\n[2/4] server compose+healthz"
if [[ -f "$SERVER_FILE" ]]; then
  server=$(sed -nE '
    s/\r$//;
    s/#.*$//;
    /^[[:space:]]*$/d;
    s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\2/ip; p;
    t done;
    s/^[[:space:]]*([^[:space:]]+).*/\1/p;
    :done
  ' "$SERVER_FILE" | head -n1)

  if [[ -n "${server:-}" ]]; then
    echo "server=$server"
    ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'cd /opt/roc/quota-proxy && docker compose ps' || true
    ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'curl -fsS http://127.0.0.1:8787/healthz' || true
  else
    echo "WARN: server file exists but no parsable host: $SERVER_FILE"
  fi
else
  echo "WARN: $SERVER_FILE missing, skip remote checks"
  echo "hint: cd $REPO_DIR && ./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for <host>"
fi

echo "\n[3/4] progress log tail -n 50"
tail -n 50 "$PROGRESS_LOG" || true

echo "\n[4/4] artifact-window check (${WINDOW_MINUTES}m)"
latest_ts=$(git -C "$REPO_DIR" log -n 1 --format=%ct 2>/dev/null || echo 0)
delta=$(( now_epoch - latest_ts ))
if (( latest_ts > 0 && delta <= WINDOW_MINUTES*60 )); then
  echo "artifact_window=HIT (latest commit ${delta}s ago)"
  exit 0
fi

echo "artifact_window=MISS (no commit within ${WINDOW_MINUTES} minutes)"
exit 2
