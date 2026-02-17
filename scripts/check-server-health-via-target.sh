#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="${1:-/tmp/server.txt}"
SERVER="${ROC_SERVER:-}"

if [[ -z "$SERVER" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "[ERROR] 目标文件不存在: $TARGET_FILE，且未设置 ROC_SERVER" >&2
    echo "可选 1: echo '1.2.3.4' > $TARGET_FILE" >&2
    echo "可选 2: ROC_SERVER=1.2.3.4 ./scripts/check-server-health-via-target.sh" >&2
    exit 1
  fi

  SERVER="$(tr -d '[:space:]' < "$TARGET_FILE")"
  if [[ -z "$SERVER" ]]; then
    echo "[ERROR] 目标文件为空: $TARGET_FILE" >&2
    exit 1
  fi
fi

echo "[INFO] 检查服务器: $SERVER"
ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER" '
  set -e
  cd /opt/roc/quota-proxy
  docker compose ps
  echo "---HEALTHZ---"
  curl -fsS http://127.0.0.1:8787/healthz
'
