#!/usr/bin/env bash
set -u

# Progress log (workspace-local; used by the 24h sprint loop runner)
LOG="/home/kai/.openclaw/workspace/logs/clawd_24h_sprint_progress.log"
mkdir -p "$(dirname "$LOG")"

now_ts() { TZ=Asia/Shanghai date '+%F %T %Z'; }

append_line() {
  # 1 line max (caller responsible)
  printf '%s\n' "$1" >> "$LOG"
}

run_cmd() {
  # usage: run_cmd <label> <command...>
  local label="$1"; shift
  local out err rc
  out="$(mktemp)"; err="$(mktemp)"
  "$@" >"$out" 2>"$err"; rc=$?
  local err_sum
  err_sum="$(tr '\n' ' ' <"$err" | sed -E 's/[[:space:]]+/ /g' | cut -c1-220)"
  if [ $rc -eq 0 ]; then
    append_line "- $(now_ts) ${label}: OK"
  else
    append_line "- $(now_ts) ${label}: FAIL (code: ${rc}) (stderr: ${err_sum})"
  fi
  rm -f "$out" "$err"
  return 0
}

ts="$(now_ts)"
append_line "- ${ts} loop tick"

# 2) 线上探活
run_cmd "probe web clawdrepublic.cn" curl -fsS -m 5 https://clawdrepublic.cn/
run_cmd "probe api /healthz" curl -fsS -m 5 https://api.clawdrepublic.cn/healthz

# 3) 服务器探活
IP_FILE="/tmp/server.txt"
if [ -f "$IP_FILE" ]; then
  ip="$(awk -F"[:=]" '/^ip/{gsub(/ /, "", $2); print $2}' "$IP_FILE" | head -n1)"
else
  ip=""
fi

if [ -z "${ip}" ]; then
  append_line "- $(now_ts) probe server: SKIP (reason: missing ip in /tmp/server.txt)"
else
  run_cmd "probe server quota-proxy" ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 "root@${ip}" "cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz"
fi

# 5) 如果本轮没有更多产出，至少记录下一步（由上层 agentTurn 决定追加更具体内容）
append_line "- $(now_ts) note: if no commit this tick, record blocker/next step"
