#!/usr/bin/env bash
set -euo pipefail

TZ_REGION="${TZ_REGION:-Asia/Shanghai}"
REPO_DIR="${REPO_DIR:-/home/kai/.openclaw/workspace/roc-ai-republic}"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
PROGRESS_LOG="${PROGRESS_LOG:-/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md}"
WINDOW_MINUTES="${WINDOW_MINUTES:-15}"
STRICT_REMOTE=0
PRINT_LOG_SNIPPETS=0
JSON_SUMMARY=0
JSON_ONLY=0
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
    --print-log-snippets)
      PRINT_LOG_SNIPPETS=1
      shift
      ;;
    --json-summary)
      JSON_SUMMARY=1
      shift
      ;;
    --json-only)
      JSON_SUMMARY=1
      JSON_ONLY=1
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
  ./scripts/cron-check-quota-proxy.sh [--window-minutes N] [--server-file PATH] [--strict-remote] [--print-log-snippets] [--json-summary|--json-only]

参数:
  --window-minutes N    覆盖落地窗口分钟数（默认 15，可由 WINDOW_MINUTES 环境变量设置）
  --server-file PATH    覆盖服务器目标文件路径（默认 /tmp/server.txt，可由 SERVER_FILE 环境变量设置）
  --strict-remote       远程检查失败时立即以退出码 3 失败（缺失 server 文件/不可解析/SSH 或 healthz 失败）
  --print-log-snippets  仅输出可直接粘贴到进度日志的验证命令模板（避免 shell 变量被提前展开）
  --json-summary        追加输出 JSON 摘要（ts/window_minutes/remote_ok/artifact_window），便于 cron 告警解析
  --json-only           仅输出 JSON 摘要（等价于 --json-summary + 静默文本日志）
  -h, --help            显示帮助
EOF
  exit 0
fi

if (( PRINT_LOG_SNIPPETS == 1 )); then
  cat <<EOF
验证命令模板（可直接复制到进度日志）：
- 验证：cd $REPO_DIR && ./scripts/cron-check-quota-proxy.sh --server-file $SERVER_FILE --strict-remote >/tmp/roc-cron-check.out 2>&1 || rc=\$?; echo "exit=\${rc:-0}"; tail -n 8 /tmp/roc-cron-check.out
- 服务器验证：if [ -f "$SERVER_FILE" ]; then SERVER=\$(sed -nE "s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\\2/ip; t; s/^[[:space:]]*([^[:space:]]+).*/\\1/p" "$SERVER_FILE" | head -n1); ssh -o BatchMode=yes -o ConnectTimeout=8 root@"\$SERVER" 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'; else echo '$SERVER_FILE 缺失，服务器检查未执行'; fi
- 缺失目标文件时先引导：cd $REPO_DIR && ./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for <host>
EOF
  exit 0
fi

if ! [[ "$WINDOW_MINUTES" =~ ^[0-9]+$ ]] || [[ "$WINDOW_MINUTES" -le 0 ]]; then
  echo "[ERROR] WINDOW_MINUTES 必须是正整数，当前: $WINDOW_MINUTES" >&2
  exit 1
fi

now_epoch=$(TZ="$TZ_REGION" date +%s)
now_str=$(TZ="$TZ_REGION" date '+%F %T %Z')

if (( JSON_ONLY == 0 )); then
  echo "[$now_str] === ROC quota-proxy rolling check ==="
  echo "\n[1/4] git log -n 10"
  git -C "$REPO_DIR" log -n 10 --pretty=format:'%h %ad %s' --date=iso || true
  echo "\n\n[2/4] server compose+healthz"
fi
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
    if (( JSON_ONLY == 0 )); then
      echo "server=$server"
    fi
    if (( JSON_ONLY == 1 )); then
      if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'cd /opt/roc/quota-proxy && docker compose ps' >/dev/null 2>&1; then
        remote_ok=0
      fi
      if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'curl -fsS http://127.0.0.1:8787/healthz' >/dev/null 2>&1; then
        remote_ok=0
      fi
    else
      if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'cd /opt/roc/quota-proxy && docker compose ps'; then
        remote_ok=0
      fi
      if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server" 'curl -fsS http://127.0.0.1:8787/healthz'; then
        remote_ok=0
      fi
    fi
  else
    if (( JSON_ONLY == 0 )); then
      echo "WARN: server file exists but no parsable host: $SERVER_FILE"
    fi
    remote_ok=0
  fi
else
  if (( JSON_ONLY == 0 )); then
    echo "WARN: $SERVER_FILE missing, skip remote checks"
    echo "hint: cd $REPO_DIR && ./scripts/check-server-health-via-target.sh --print-bootstrap-cmd-for <host>"
  fi
  remote_ok=0
fi

if (( STRICT_REMOTE == 1 && remote_ok == 0 )); then
  if (( JSON_ONLY == 0 )); then
    echo "remote_check=FAIL (strict mode)"
  fi
  if (( JSON_SUMMARY == 1 )); then
    printf '{"ts":"%s","window_minutes":%s,"remote_ok":false,"artifact_window":"SKIP_STRICT_REMOTE_FAIL","exit":3}\n' "$now_str" "$WINDOW_MINUTES"
  fi
  exit 3
fi

if (( JSON_ONLY == 0 )); then
  echo "\n[3/4] progress log tail -n 50"
  tail -n 50 "$PROGRESS_LOG" || true
  echo "\n[4/4] artifact-window check (${WINDOW_MINUTES}m)"
fi
latest_ts=$(git -C "$REPO_DIR" log -n 1 --format=%ct 2>/dev/null || echo 0)
delta=$(( now_epoch - latest_ts ))
if (( latest_ts > 0 && delta <= WINDOW_MINUTES*60 )); then
  if (( JSON_ONLY == 0 )); then
    echo "artifact_window=HIT (latest commit ${delta}s ago)"
  fi
  if (( JSON_SUMMARY == 1 )); then
    printf '{"ts":"%s","window_minutes":%s,"remote_ok":%s,"artifact_window":"HIT","latest_commit_age_sec":%s,"exit":0}\n' "$now_str" "$WINDOW_MINUTES" "$([[ "$remote_ok" == "1" ]] && echo true || echo false)" "$delta"
  fi
  exit 0
fi

if (( JSON_ONLY == 0 )); then
  echo "artifact_window=MISS (no commit within ${WINDOW_MINUTES} minutes)"
fi
if (( JSON_SUMMARY == 1 )); then
  printf '{"ts":"%s","window_minutes":%s,"remote_ok":%s,"artifact_window":"MISS","latest_commit_age_sec":%s,"exit":2}\n' "$now_str" "$WINDOW_MINUTES" "$([[ "$remote_ok" == "1" ]] && echo true || echo false)" "$delta"
fi
exit 2
