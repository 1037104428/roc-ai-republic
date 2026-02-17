#!/usr/bin/env bash
set -euo pipefail

PRINT_TARGET_ONLY=0
DRY_RUN=0
SHOW_HELP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-target)
      PRINT_TARGET_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      SHOW_HELP=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ "$SHOW_HELP" == "1" ]]; then
  cat <<'EOF'
用法:
  ./scripts/check-server-health-via-target.sh [--print-target] [--dry-run] [TARGET_FILE]

参数:
  TARGET_FILE              可选，服务器目标文件路径（默认 /tmp/server.txt）
  --print-target           仅输出解析出的服务器目标，不执行 SSH
  --dry-run                仅打印将执行的 SSH 命令，不实际连接
  -h, --help               显示帮助

环境变量:
  ROC_SERVER               直接指定服务器地址（优先于 TARGET_FILE）
  ROC_SERVER_FILE          默认目标文件路径（默认 /tmp/server.txt）
  ROC_SSH_USER             SSH 用户（默认 root）
  ROC_SSH_PORT             SSH 端口（默认 22）
  ROC_SSH_CONNECT_TIMEOUT  SSH 连接超时秒数（默认 8）
  ROC_SSH_STRICT_HOST_KEY_CHECKING  SSH StrictHostKeyChecking（默认 accept-new）
  ROC_REMOTE_DIR           远端目录（默认 /opt/roc/quota-proxy）
  ROC_HEALTHZ_URL          健康检查 URL（默认 http://127.0.0.1:8787/healthz）
  ROC_HEALTHZ_TIMEOUT      healthz curl 超时秒数（默认 6）
EOF
  exit 0
fi

TARGET_FILE="${1:-${ROC_SERVER_FILE:-/tmp/server.txt}}"
SERVER="${ROC_SERVER:-}"
SSH_USER="${ROC_SSH_USER:-root}"
SSH_PORT="${ROC_SSH_PORT:-22}"
SSH_CONNECT_TIMEOUT="${ROC_SSH_CONNECT_TIMEOUT:-8}"
SSH_STRICT_HOST_KEY_CHECKING="${ROC_SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
HEALTHZ_URL="${ROC_HEALTHZ_URL:-http://127.0.0.1:8787/healthz}"
HEALTHZ_TIMEOUT="${ROC_HEALTHZ_TIMEOUT:-6}"
REMOTE_DIR="${ROC_REMOTE_DIR:-/opt/roc/quota-proxy}"

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
echo "[INFO] SSH: ${SSH_USER}@${SERVER}:${SSH_PORT} (ConnectTimeout=${SSH_CONNECT_TIMEOUT}s, StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING})"
echo "[INFO] Healthz: ${HEALTHZ_URL} (timeout=${HEALTHZ_TIMEOUT}s)"
echo "[INFO] RemoteDir: ${REMOTE_DIR}"

if [[ "$PRINT_TARGET_ONLY" == "1" ]]; then
  echo "[INFO] --print-target 已启用，仅输出解析结果，不执行 SSH 检查"
  exit 0
fi

REMOTE_CMD="set -e; cd '${REMOTE_DIR}'; docker compose ps; echo '---HEALTHZ---'; curl -fsS --max-time '${HEALTHZ_TIMEOUT}' '${HEALTHZ_URL}'"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[INFO] --dry-run 已启用，仅输出将执行的 SSH 命令"
  printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=%s -o ConnectTimeout=%s -p %s %s@%s %q\n" \
    "${SSH_STRICT_HOST_KEY_CHECKING}" "${SSH_CONNECT_TIMEOUT}" "${SSH_PORT}" "${SSH_USER}" "${SERVER}" "${REMOTE_CMD}"
  exit 0
fi

ssh \
  -o BatchMode=yes \
  -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY_CHECKING}" \
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
  -p "${SSH_PORT}" \
  "${SSH_USER}@${SERVER}" "${REMOTE_CMD}"
