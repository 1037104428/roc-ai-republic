#!/usr/bin/env bash
set -euo pipefail

PRINT_TARGET_ONLY=0
PRINT_SERVER_ONLY=0
PRINT_REMOTE_CMD_ONLY=0
PRINT_SSH_CMD_ONLY=0
PRINT_HEALTHZ_CMD_ONLY=0
PRINT_COMPOSE_CMD_ONLY=0
PRINT_CHECK_CMD_ONLY=0
DRY_RUN=0
HEALTHZ_ONLY=0
COMPOSE_ONLY=0
SHOW_HELP=0
SET_SERVER_ARG=""
SSH_USER_ARG=""
SSH_PORT_ARG=""
SSH_CONNECT_TIMEOUT_ARG=""
HEALTHZ_TIMEOUT_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-target)
      PRINT_TARGET_ONLY=1
      shift
      ;;
    --print-server)
      PRINT_SERVER_ONLY=1
      shift
      ;;
    --print-remote-cmd)
      PRINT_REMOTE_CMD_ONLY=1
      shift
      ;;
    --print-ssh-cmd)
      PRINT_SSH_CMD_ONLY=1
      shift
      ;;
    --print-healthz-cmd)
      PRINT_HEALTHZ_CMD_ONLY=1
      shift
      ;;
    --print-compose-cmd)
      PRINT_COMPOSE_CMD_ONLY=1
      shift
      ;;
    --print-check-cmd)
      PRINT_CHECK_CMD_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --healthz-only)
      HEALTHZ_ONLY=1
      shift
      ;;
    --compose-only)
      COMPOSE_ONLY=1
      shift
      ;;
    --ssh-user)
      SSH_USER_ARG="${2:-}"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT_ARG="${2:-}"
      shift 2
      ;;
    --connect-timeout)
      SSH_CONNECT_TIMEOUT_ARG="${2:-}"
      shift 2
      ;;
    --healthz-timeout)
      HEALTHZ_TIMEOUT_ARG="${2:-}"
      shift 2
      ;;
    --set-server)
      SET_SERVER_ARG="${2:-}"
      shift 2
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
  ./scripts/check-server-health-via-target.sh [--print-target|--print-server] [--print-remote-cmd|--print-ssh-cmd|--print-healthz-cmd|--print-compose-cmd|--print-check-cmd] [--set-server HOST] [--dry-run] [--healthz-only|--compose-only] [--ssh-user USER] [--ssh-port PORT] [--connect-timeout SEC] [--healthz-timeout SEC] [TARGET_FILE]

参数:
  TARGET_FILE              可选，服务器目标文件路径（默认 /tmp/server.txt）
  --print-target           打印带 [INFO] 前缀的服务器目标信息，不执行 SSH
  --print-server           仅输出解析出的服务器地址（纯文本，无前缀）
  --print-remote-cmd       仅打印远端执行片段（可复制到 ssh ... "<cmd>"）
  --print-ssh-cmd          仅打印完整 SSH 命令（纯文本，便于命令替换/日志采集）
  --print-healthz-cmd      仅打印 healthz curl 命令（可直接用于现有 SSH/监控）
  --print-compose-cmd      仅打印 compose ps 命令（便于复用到现有 SSH/监控）
  --print-check-cmd        仅打印 compose+healthz 合并命令（便于一次性巡检）
  --set-server HOST        将 HOST 写入 TARGET_FILE（默认 /tmp/server.txt）后退出
  --dry-run                仅打印将执行的 SSH 命令，不实际连接
  --healthz-only           仅执行 healthz curl（跳过 docker compose ps）
  --compose-only           仅执行 docker compose ps（跳过 healthz curl）
  --ssh-user USER          覆盖 SSH 用户（等价 ROC_SSH_USER）
  --ssh-port PORT          覆盖 SSH 端口（等价 ROC_SSH_PORT）
  --connect-timeout SEC    覆盖 SSH 连接超时秒数（等价 ROC_SSH_CONNECT_TIMEOUT）
  --healthz-timeout SEC    覆盖 healthz 超时秒数（等价 ROC_HEALTHZ_TIMEOUT）
  -h, --help               显示帮助

环境变量:
  ROC_SERVER               直接指定服务器地址（优先于 TARGET_FILE）
  ROC_SERVER_FILE          默认目标文件路径（默认 /tmp/server.txt）
  ROC_SSH_USER             SSH 用户（默认 root）
  ROC_SSH_PORT             SSH 端口（默认 22）
  ROC_SSH_CONNECT_TIMEOUT  SSH 连接超时秒数（默认 8）
  ROC_SSH_STRICT_HOST_KEY_CHECKING  SSH StrictHostKeyChecking（默认 accept-new）
  ROC_SSH_IDENTITY_FILE    SSH 私钥文件路径（可选，例如 ~/.ssh/id_ed25519）
  ROC_REMOTE_DIR           远端目录（默认 /opt/roc/quota-proxy）
  ROC_DOCKER_COMPOSE_CMD   远端 compose 命令（默认 'docker compose'）
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
SSH_IDENTITY_FILE="${ROC_SSH_IDENTITY_FILE:-}"
HEALTHZ_URL="${ROC_HEALTHZ_URL:-http://127.0.0.1:8787/healthz}"
HEALTHZ_TIMEOUT="${ROC_HEALTHZ_TIMEOUT:-6}"
REMOTE_DIR="${ROC_REMOTE_DIR:-/opt/roc/quota-proxy}"
DOCKER_COMPOSE_CMD="${ROC_DOCKER_COMPOSE_CMD:-docker compose}"

if [[ -n "${SSH_USER_ARG}" ]]; then SSH_USER="${SSH_USER_ARG}"; fi
if [[ -n "${SSH_PORT_ARG}" ]]; then SSH_PORT="${SSH_PORT_ARG}"; fi
if [[ -n "${SSH_CONNECT_TIMEOUT_ARG}" ]]; then SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT_ARG}"; fi
if [[ -n "${HEALTHZ_TIMEOUT_ARG}" ]]; then HEALTHZ_TIMEOUT="${HEALTHZ_TIMEOUT_ARG}"; fi

if [[ -n "${SET_SERVER_ARG}" ]]; then
  mkdir -p "$(dirname "$TARGET_FILE")"
  printf "%s\n" "${SET_SERVER_ARG}" > "$TARGET_FILE"
  echo "[INFO] 已写入服务器目标: $TARGET_FILE -> ${SET_SERVER_ARG}"
  exit 0
fi

if [[ -z "$SERVER" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "[ERROR] 目标文件不存在: $TARGET_FILE，且未设置 ROC_SERVER" >&2
    echo "可选 1: echo '1.2.3.4' > $TARGET_FILE" >&2
    echo "可选 2: ROC_SERVER=1.2.3.4 ./scripts/check-server-health-via-target.sh" >&2
    echo "可选 3: ROC_SERVER_FILE=/path/to/server.txt ./scripts/check-server-health-via-target.sh" >&2
    if [[ "$TARGET_FILE" == "/tmp/server.txt" ]]; then
      echo "可选 4: ./scripts/prepare-server-target.sh --server 1.2.3.4 && ./scripts/check-server-health-via-target.sh" >&2
    fi
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

if [[ "$PRINT_SERVER_ONLY" == "1" ]]; then
  printf "%s\n" "$SERVER"
  exit 0
fi

if [[ "$HEALTHZ_ONLY" == "1" && "$COMPOSE_ONLY" == "1" ]]; then
  echo "[ERROR] --healthz-only 与 --compose-only 不能同时使用" >&2
  exit 1
fi

if [[ "$PRINT_SSH_CMD_ONLY" != "1" && "$PRINT_HEALTHZ_CMD_ONLY" != "1" && "$PRINT_COMPOSE_CMD_ONLY" != "1" && "$PRINT_CHECK_CMD_ONLY" != "1" ]]; then
  echo "[INFO] 检查服务器: $SERVER"
  echo "[INFO] SSH: ${SSH_USER}@${SERVER}:${SSH_PORT} (ConnectTimeout=${SSH_CONNECT_TIMEOUT}s, StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING})"
  if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
    echo "[INFO] SSH IdentityFile: ${SSH_IDENTITY_FILE}"
  fi
  echo "[INFO] Healthz: ${HEALTHZ_URL} (timeout=${HEALTHZ_TIMEOUT}s)"
  echo "[INFO] RemoteDir: ${REMOTE_DIR}"
  echo "[INFO] ComposeCmd: ${DOCKER_COMPOSE_CMD}"
  if [[ "$HEALTHZ_ONLY" == "1" ]]; then
    echo "[INFO] Mode: healthz-only（跳过 compose ps）"
  fi
  if [[ "$COMPOSE_ONLY" == "1" ]]; then
    echo "[INFO] Mode: compose-only（跳过 healthz curl）"
  fi
fi

if [[ "$PRINT_TARGET_ONLY" == "1" ]]; then
  echo "[INFO] --print-target 已启用，仅输出解析结果，不执行 SSH 检查"
  exit 0
fi

if [[ "$HEALTHZ_ONLY" == "1" ]]; then
  REMOTE_CMD="set -e; cd '${REMOTE_DIR}'; echo '---HEALTHZ---'; curl -fsS --max-time '${HEALTHZ_TIMEOUT}' '${HEALTHZ_URL}'"
elif [[ "$COMPOSE_ONLY" == "1" ]]; then
  REMOTE_CMD="set -e; cd '${REMOTE_DIR}'; ${DOCKER_COMPOSE_CMD} ps"
else
  REMOTE_CMD="set -e; cd '${REMOTE_DIR}'; ${DOCKER_COMPOSE_CMD} ps; echo '---HEALTHZ---'; curl -fsS --max-time '${HEALTHZ_TIMEOUT}' '${HEALTHZ_URL}'"
fi

SSH_IDENTITY_ARGS=()
if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
  SSH_IDENTITY_ARGS+=("-i" "${SSH_IDENTITY_FILE}")
fi

if [[ "$PRINT_REMOTE_CMD_ONLY" == "1" ]]; then
  echo "[INFO] --print-remote-cmd 已启用，仅输出远端命令片段"
  printf "%s\n" "${REMOTE_CMD}"
  exit 0
fi

if [[ "$PRINT_HEALTHZ_CMD_ONLY" == "1" ]]; then
  printf "curl -fsS --max-time %q %q\n" "${HEALTHZ_TIMEOUT}" "${HEALTHZ_URL}"
  exit 0
fi

if [[ "$PRINT_COMPOSE_CMD_ONLY" == "1" ]]; then
  printf "%s ps\n" "${DOCKER_COMPOSE_CMD}"
  exit 0
fi

if [[ "$PRINT_CHECK_CMD_ONLY" == "1" ]]; then
  printf "%s ps && curl -fsS --max-time %q %q\n" "${DOCKER_COMPOSE_CMD}" "${HEALTHZ_TIMEOUT}" "${HEALTHZ_URL}"
  exit 0
fi

if [[ "$PRINT_SSH_CMD_ONLY" == "1" ]]; then
  if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=%s -o ConnectTimeout=%s -p %s -i %q %s@%s %q\n" \
      "${SSH_STRICT_HOST_KEY_CHECKING}" "${SSH_CONNECT_TIMEOUT}" "${SSH_PORT}" "${SSH_IDENTITY_FILE}" "${SSH_USER}" "${SERVER}" "${REMOTE_CMD}"
  else
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=%s -o ConnectTimeout=%s -p %s %s@%s %q\n" \
      "${SSH_STRICT_HOST_KEY_CHECKING}" "${SSH_CONNECT_TIMEOUT}" "${SSH_PORT}" "${SSH_USER}" "${SERVER}" "${REMOTE_CMD}"
  fi
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[INFO] --dry-run 已启用，仅输出将执行的 SSH 命令"
  if [[ -n "${SSH_IDENTITY_FILE}" ]]; then
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=%s -o ConnectTimeout=%s -p %s -i %q %s@%s %q\n" \
      "${SSH_STRICT_HOST_KEY_CHECKING}" "${SSH_CONNECT_TIMEOUT}" "${SSH_PORT}" "${SSH_IDENTITY_FILE}" "${SSH_USER}" "${SERVER}" "${REMOTE_CMD}"
  else
    printf "ssh -o BatchMode=yes -o StrictHostKeyChecking=%s -o ConnectTimeout=%s -p %s %s@%s %q\n" \
      "${SSH_STRICT_HOST_KEY_CHECKING}" "${SSH_CONNECT_TIMEOUT}" "${SSH_PORT}" "${SSH_USER}" "${SERVER}" "${REMOTE_CMD}"
  fi
  exit 0
fi

ssh \
  -o BatchMode=yes \
  -o StrictHostKeyChecking="${SSH_STRICT_HOST_KEY_CHECKING}" \
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
  -p "${SSH_PORT}" \
  "${SSH_IDENTITY_ARGS[@]}" \
  "${SSH_USER}@${SERVER}" "${REMOTE_CMD}"
