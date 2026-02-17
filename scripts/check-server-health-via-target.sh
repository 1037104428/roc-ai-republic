#!/usr/bin/env bash
set -euo pipefail

PRINT_TARGET_ONLY=0
if [[ "${1:-}" == "--print-target" ]]; then
  PRINT_TARGET_ONLY=1
  shift
fi

TARGET_FILE="${1:-${ROC_SERVER_FILE:-/tmp/server.txt}}"
SERVER="${ROC_SERVER:-}"
SSH_USER="${ROC_SSH_USER:-root}"
SSH_PORT="${ROC_SSH_PORT:-22}"
SSH_CONNECT_TIMEOUT="${ROC_SSH_CONNECT_TIMEOUT:-8}"
HEALTHZ_URL="${ROC_HEALTHZ_URL:-http://127.0.0.1:8787/healthz}"

if [[ -z "$SERVER" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "[ERROR] 目标文件不存在: $TARGET_FILE，且未设置 ROC_SERVER" >&2
    echo "可选 1: echo '1.2.3.4' > $TARGET_FILE" >&2
    echo "可选 2: ROC_SERVER=1.2.3.4 ./scripts/check-server-health-via-target.sh" >&2
    echo "可选 3: ROC_SERVER_FILE=/path/to/server.txt ./scripts/check-server-health-via-target.sh" >&2
    exit 1
  fi

  SERVER="$(sed -nE '
    s/\r$//;
    s/#.*$//;
    /^[[:space:]]*$/d;
    s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\2/ip; p;
    t done;
    s/^[[:space:]]*([^[:space:]]+).*/\1/p;
    :done
  ' "$TARGET_FILE" | head -n1)"
  if [[ -z "$SERVER" ]]; then
    echo "[ERROR] 目标文件不可解析: $TARGET_FILE" >&2
    echo "支持格式示例: '1.2.3.4' 或 'ip:1.2.3.4' 或 'host=example.com'" >&2
    exit 1
  fi
fi

echo "[INFO] 检查服务器: $SERVER"
echo "[INFO] SSH: ${SSH_USER}@${SERVER}:${SSH_PORT} (ConnectTimeout=${SSH_CONNECT_TIMEOUT}s)"
echo "[INFO] Healthz: ${HEALTHZ_URL}"

if [[ "$PRINT_TARGET_ONLY" == "1" ]]; then
  echo "[INFO] --print-target 已启用，仅输出解析结果，不执行 SSH 检查"
  exit 0
fi

ssh \
  -o BatchMode=yes \
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
  -p "${SSH_PORT}" \
  "${SSH_USER}@${SERVER}" "
  set -e
  cd /opt/roc/quota-proxy
  docker compose ps
  echo '---HEALTHZ---'
  curl -fsS '${HEALTHZ_URL}'
"
