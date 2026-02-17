#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="/tmp/server.txt"
SERVER="${ROC_SERVER:-}"
PRINT_ONLY=0
CHECK_ONLY=0

usage() {
  cat <<'EOF'
用法:
  ./scripts/prepare-server-target.sh --server <ip-or-host> [--file /tmp/server.txt]
  ./scripts/prepare-server-target.sh --print [--file /tmp/server.txt]
  ./scripts/prepare-server-target.sh --check [--file /tmp/server.txt]

说明:
  - 默认写入 /tmp/server.txt，供 check-server-health-via-target.sh 读取
  - --print 仅打印当前解析到的目标，不写文件
  - --check 仅校验目标文件是否存在且可解析（适合部署前自检）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER="${2:-}"
      shift 2
      ;;
    --file)
      TARGET_FILE="${2:-}"
      shift 2
      ;;
    --print)
      PRINT_ONLY=1
      shift
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] 未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$PRINT_ONLY" == "1" && "$CHECK_ONLY" == "1" ]]; then
  echo "[ERROR] --print 与 --check 不能同时使用" >&2
  exit 1
fi

extract_target() {
  local file="$1"
  sed -nE '
    s/\r$//;
    s/#.*$//;
    /^[[:space:]]*$/d;
    s/^[[:space:]]*(ip|host|server)[[:space:]]*[:=][[:space:]]*([^[:space:]]+).*/\2/ip; p;
    t done;
    s/^[[:space:]]*([^[:space:]]+).*/\1/p;
    :done
  ' "$file" | head -n1
}

if [[ "$PRINT_ONLY" == "1" || "$CHECK_ONLY" == "1" ]]; then
  if [[ ! -f "$TARGET_FILE" ]]; then
    echo "[ERROR] 目标文件不存在: $TARGET_FILE" >&2
    exit 1
  fi
  CURRENT="$(extract_target "$TARGET_FILE")"
  if [[ -z "$CURRENT" ]]; then
    echo "[ERROR] 目标文件不可解析: $TARGET_FILE" >&2
    exit 1
  fi

  if [[ "$PRINT_ONLY" == "1" ]]; then
    echo "$CURRENT"
  else
    echo "[OK] 目标文件可解析: $TARGET_FILE"
    echo "[OK] 解析目标: $CURRENT"
  fi
  exit 0
fi

if [[ -z "$SERVER" ]]; then
  echo "[ERROR] 缺少 --server 参数（或设置 ROC_SERVER）" >&2
  usage >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_FILE")"
printf 'host=%s\n' "$SERVER" > "$TARGET_FILE"

PARSED="$(extract_target "$TARGET_FILE")"
if [[ "$PARSED" != "$SERVER" ]]; then
  echo "[ERROR] 写入后解析不一致: expected=$SERVER actual=${PARSED:-<empty>}" >&2
  exit 1
fi

echo "[OK] 已写入目标文件: $TARGET_FILE"
echo "[OK] 解析目标: $PARSED"
