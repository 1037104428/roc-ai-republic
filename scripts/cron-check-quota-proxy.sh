#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_PATH_DEFAULT="/home/kai/.openclaw/workspace/roc-ai-republic"
REPO_PATH_FALLBACK="/home/kai/.openclaw/workspace"
SERVER_FILE="/tmp/server.txt"
REMOTE_DIR="/opt/roc/quota-proxy"
HEALTHZ_URL="http://127.0.0.1:8787/healthz"
SSH_TIMEOUT="8"
JSON_ONLY=0
PRINT_SERVER_CHECK_CMD=0

usage() {
  cat <<'EOF'
用法: cron-check-quota-proxy.sh [选项]

选项:
  --repo PATH         指定仓库路径（默认 /home/kai/.openclaw/workspace/roc-ai-republic；不存在时回退 /home/kai/.openclaw/workspace）
  --server-file PATH  指定 server.txt 路径（默认 /tmp/server.txt）
  --server HOST       直接指定远端主机，优先级高于 server-file
  --remote-dir PATH   远端 quota-proxy 目录（默认 /opt/roc/quota-proxy）
  --healthz-url URL   远端健康检查地址（默认 http://127.0.0.1:8787/healthz）
  --ssh-timeout SEC   SSH ConnectTimeout 秒数（默认 8）
  --json-only         仅输出 JSON 汇总
  --print-server-check-cmd  输出可直接粘贴到进度日志的服务器验证命令模板
  -h, --help          显示帮助
EOF
}

REPO_PATH="$REPO_PATH_DEFAULT"
SERVER_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_PATH="$2"; shift 2 ;;
    --server-file) SERVER_FILE="$2"; shift 2 ;;
    --server) SERVER_OVERRIDE="$2"; shift 2 ;;
    --remote-dir) REMOTE_DIR="$2"; shift 2 ;;
    --healthz-url) HEALTHZ_URL="$2"; shift 2 ;;
    --ssh-timeout) SSH_TIMEOUT="$2"; shift 2 ;;
    --json-only) JSON_ONLY=1; shift ;;
    --print-server-check-cmd) PRINT_SERVER_CHECK_CMD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 2 ;;
  esac
done

TS="$(TZ=Asia/Shanghai date '+%F %T %Z')"

if [[ "$PRINT_SERVER_CHECK_CMD" -eq 1 ]]; then
  cat <<'EOF'
if [ -f /tmp/server.txt ]; then SERVER=$(sed -nE "s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\2/ip; t; s/^[[:space:]]*([^[:space:]]+).*/\1/p" /tmp/server.txt | head -n1); ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER" 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'; else echo '/tmp/server.txt 缺失，服务器检查未执行'; fi
EOF
  exit 0
fi

if [[ ! -d "$REPO_PATH/.git" && -d "$REPO_PATH_FALLBACK/.git" ]]; then
  REPO_PATH="$REPO_PATH_FALLBACK"
fi

if [[ "$JSON_ONLY" -eq 0 ]]; then
  echo "[$TS] cron-check-quota-proxy"
fi

GIT_OK=0
GIT_LOG=""
if [[ -d "$REPO_PATH/.git" ]]; then
  GIT_LOG="$(git -C "$REPO_PATH" log --oneline -n 10 2>&1 || true)"
  [[ -n "$GIT_LOG" ]] && GIT_OK=1
else
  GIT_LOG="repo not found: $REPO_PATH"
fi

REMOTE_OK=0
REMOTE_MSG=""
SERVER="${SERVER_OVERRIDE}"
if [[ -z "$SERVER" && -f "$SERVER_FILE" ]]; then
  SERVER="$(sed -nE "s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\2/ip; t; s/^[[:space:]]*([^[:space:]]+).*/\1/p" "$SERVER_FILE" | head -n1)"
fi

if [[ -n "$SERVER" ]]; then
  if OUT=$(ssh -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" root@"$SERVER" "cd '$REMOTE_DIR' && docker compose ps && curl -fsS '$HEALTHZ_URL'" 2>&1); then
    REMOTE_OK=1
    REMOTE_MSG="$OUT"
  else
    REMOTE_MSG="$OUT"
  fi
else
  REMOTE_MSG="server missing: set --server or create $SERVER_FILE"
fi

if [[ "$JSON_ONLY" -eq 1 ]]; then
  python3 - <<PY
import json
print(json.dumps({
  "ts": "${TS}",
  "repo": "${REPO_PATH}",
  "git_ok": ${GIT_OK},
  "remote_ok": ${REMOTE_OK},
  "server": "${SERVER}",
}, ensure_ascii=False))
PY
  exit 0
fi

echo "\n== git log -n 10 =="
echo "$GIT_LOG"

echo "\n== remote check =="
echo "$REMOTE_MSG"

if [[ "$REMOTE_OK" -eq 1 ]]; then
  echo "\nRESULT: OK"
else
  echo "\nRESULT: PARTIAL (remote not reachable)"
fi
