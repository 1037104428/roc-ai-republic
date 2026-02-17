#!/usr/bin/env bash
set -euo pipefail

TZ_REGION="${TZ_REGION:-Asia/Shanghai}"
REPO_DIR="${REPO_DIR:-/home/kai/.openclaw/workspace/roc-ai-republic}"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
PROGRESS_LOG="${PROGRESS_LOG:-/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md}"
WINDOW_MINUTES="${WINDOW_MINUTES:-15}"
STRICT_REMOTE=0
SHOW_HELP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window-minutes)
      WINDOW_MINUTES="${2:-}"
      shift 2
      ;;
    --server-file)
      SERVER_FILE="${2:-}"
      shift 2
      ;;
    --strict-remote)
      STRICT_REMOTE=1
      shift
      ;;
    -h|--help)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "[ERROR] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$SHOW_HELP" == "1" ]]; then
  cat <<'EOF'
用法:
  ./scripts/cron-check-quota-proxy.sh [--window-minutes N] [--server-file PATH] [--strict-remote]

参数:
  --window-minutes N  覆盖落地窗口分钟数（默认 15，可由 WINDOW_MINUTES 环境变量设置）
  --server-file PATH  覆盖服务器目标文件路径（默认 /tmp/server.txt，可由 SERVER_FILE 环境变量设置）
  --strict-remote     远程检查失败时立即以退出码 3 失败（缺失 server 文件/不可解析/SSH 或 healthz 失败）
  -h, --help          显示帮助
EOF
  exit 0
fi

if ! [[ "$WINDOW_MINUTES" =~ ^[0-9]+$ ]] || [[ "$WINDOW_MINUTES" -le 0 ]]; then
  echo "[ERROR] WINDOW_MINUTES 必须是正整数，当前: $WINDOW_MINUTES" >&2
  exit 1
fi

now_epoch=$(TZ="$TZ_REGION" date +%s)
now_str=$(TZ="$TZ_REGION" date '+%F %T %Z')

echo "[$now_str] === ROC quota-proxy rolling check ==="

echo "\n[1/4] git log -n 10"
git -C "$REPO_DIR" log -n 10 --pretty=format:'%h %ad %s' --date=iso || true

echo "\n\n[2/4] server compose+healthz"
remote_ok=1
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
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'cd /opt/roc/quota-proxy && docker compose ps'; then
      remote_ok=0
    fi
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'curl -fsS http://127.0.0.1:8787/healthz'; then
      remote_ok=0
    fi
  else
    echo "WARN: server file exists but no parsable host: $SERVER_FILE"
    remote_ok=0
  fi
else
  echo "WARN: $SERVER_FILE missing, skip remote checks"
  echo "hint: cd $REPO_DIR && ./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for <host>"
  remote_ok=0
fi

if (( STRICT_REMOTE == 1 && remote_ok == 0 )); then
  echo "remote_check=FAIL (strict mode)"
  exit 3
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
