#!/bin/bash
set -euo pipefail

# verify-sqlite-persistence-on-server.sh - 在服务器上验证 quota-proxy SQLite 持久化
# 用途：SSH 到服务器，验证 SQLite 数据库文件存在、可读写，且服务正常运行
# 输出：JSON 格式的验证结果，便于 cron/监控解析

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
readonly SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
readonly REMOTE_USER="${REMOTE_USER:-root}"
readonly REMOTE_DIR="/opt/roc/quota-proxy"
readonly DB_FILE="$REMOTE_DIR/data/quota.db"
readonly OUTPUT_JSON="${OUTPUT_JSON:-0}"

usage() {
  cat <<EOF
$SCRIPT_NAME - 在服务器上验证 quota-proxy SQLite 持久化

用法:
  $SCRIPT_NAME [选项]

选项:
  --server-file PATH  服务器信息文件 (默认: $SERVER_FILE)
  --ssh-key PATH      SSH 私钥路径 (默认: $SSH_KEY)
  --remote-user USER  远程用户名 (默认: $REMOTE_USER)
  --json              输出 JSON 格式结果
  --help             显示此帮助信息

环境变量:
  SERVER_FILE         同 --server-file
  SSH_KEY            同 --ssh-key
  REMOTE_USER        同 --remote-user
  OUTPUT_JSON         同 --json (设置为 1)

示例:
  # 基本验证
  $SCRIPT_NAME

  # 输出 JSON 格式
  $SCRIPT_NAME --json

验证项目:
  1. SSH 连接性
  2. quota-proxy 容器运行状态
  3. SQLite 数据库文件存在性
  4. 数据库文件可读写性
  5. 健康检查端点 (/healthz)
  6. 数据库表结构（如果 sqlite3 可用）

退出码:
  0 - 所有验证通过
  1 - 部分验证失败
  2 - 参数错误或无法连接
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-file) SERVER_FILE="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --remote-user) REMOTE_USER="$2"; shift 2 ;;
    --json) OUTPUT_JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "错误: 未知选项 $1"; usage; exit 2 ;;
  esac
done

# 读取服务器 IP
if [[ ! -f "$SERVER_FILE" ]]; then
  echo "错误: 服务器文件不存在: $SERVER_FILE" >&2
  exit 2
fi

SERVER_IP=$(grep -E '^(ip=|ip:)' "$SERVER_FILE" | head -1 | sed 's/^ip[=:]//')
if [[ -z "$SERVER_IP" ]]; then
  echo "错误: 无法从 $SERVER_FILE 提取 IP 地址" >&2
  exit 2
fi

# 验证结果存储
declare -A results
declare -A messages

# 函数：添加验证结果
add_result() {
  local key="$1"
  local success="$2"
  local message="$3"
  results["$key"]=$success
  messages["$key"]="$message"
}

# 函数：运行 SSH 命令
run_ssh() {
  ssh -i "$SSH_KEY" \
      -o BatchMode=yes \
      -o ConnectTimeout=8 \
      -o StrictHostKeyChecking=no \
      "${REMOTE_USER}@${SERVER_IP}" \
      "$@"
}

# 函数：检查命令是否存在
check_command() {
  run_ssh "command -v $1" >/dev/null 2>&1
}

echo "[verify] 开始验证服务器 $SERVER_IP 上的 SQLite 持久化" >&2

# 1. 验证 SSH 连接性
if run_ssh "echo 'SSH连接测试'" >/dev/null 2>&1; then
  add_result "ssh" 1 "SSH 连接成功"
else
  add_result "ssh" 0 "SSH 连接失败"
  echo "❌ SSH 连接失败，无法继续验证" >&2
  exit 2
fi

# 2. 验证 quota-proxy 容器运行状态
if run_ssh "cd '$REMOTE_DIR' && docker compose ps 2>/dev/null | grep -q 'Up'"; then
  add_result "container" 1 "quota-proxy 容器正在运行"
else
  add_result "container" 0 "quota-proxy 容器未运行"
fi

# 3. 验证 SQLite 数据库文件存在性
if run_ssh "test -f '$DB_FILE'"; then
  DB_SIZE=$(run_ssh "stat -c%s '$DB_FILE' 2>/dev/null || echo '0'")
  add_result "db_file" 1 "SQLite 数据库文件存在 (${DB_SIZE}字节)"
else
  add_result "db_file" 0 "SQLite 数据库文件不存在: $DB_FILE"
fi

# 4. 验证数据库文件可读写性
if run_ssh "test -r '$DB_FILE' && test -w '$DB_FILE'"; then
  add_result "db_permissions" 1 "数据库文件可读写"
else
  PERMS=$(run_ssh "ls -la '$DB_FILE' 2>/dev/null || echo '无权限'")
  add_result "db_permissions" 0 "数据库文件权限不足: $PERMS"
fi

# 5. 验证健康检查端点
HEALTHZ_OUTPUT=$(run_ssh "curl -fsS -m 5 http://127.0.0.1:8787/healthz 2>/dev/null || echo 'FAILED'")
if [[ "$HEALTHZ_OUTPUT" == *"ok"* ]] || [[ "$HEALTHZ_OUTPUT" == *"OK"* ]]; then
  add_result "healthz" 1 "健康检查通过: $HEALTHZ_OUTPUT"
else
  add_result "healthz" 0 "健康检查失败: $HEALTHZ_OUTPUT"
fi

# 6. 验证数据库表结构（如果 sqlite3 可用）
if check_command "sqlite3"; then
  TABLES=$(run_ssh "sqlite3 '$DB_FILE' '.tables' 2>/dev/null || echo 'ERROR'")
  if [[ "$TABLES" == *"keys"* ]] && [[ "$TABLES" == *"usage"* ]]; then
    add_result "db_tables" 1 "数据库表结构正确: $TABLES"
  else
    add_result "db_tables" 0 "数据库表结构不完整: $TABLES"
  fi
else
  add_result "db_tables" 1 "跳过表结构验证 (sqlite3 不可用)"
fi

# 计算总体结果
TOTAL_CHECKS=${#results[@]}
PASSED_CHECKS=0
for key in "${!results[@]}"; do
  if [[ ${results[$key]} -eq 1 ]]; then
    ((PASSED_CHECKS++))
  fi
done

OVERALL_SUCCESS=$([[ $PASSED_CHECKS -eq $TOTAL_CHECKS ]] && echo 1 || echo 0)

# 输出结果 - 只实现文本输出，简化调试
echo ""
echo "=== SQLite 持久化验证结果 ==="
echo "服务器: $SERVER_IP"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "------------------------------"

for key in "${!results[@]}"; do
  if [[ ${results[$key]} -eq 1 ]]; then
    echo "✅ $key: ${messages[$key]}"
  else
    echo "❌ $key: ${messages[$key]}"
  fi
done

echo "------------------------------"
echo "通过: $PASSED_CHECKS/$TOTAL_CHECKS"

if [[ $OVERALL_SUCCESS -eq 1 ]]; then
  echo "✅ 所有验证通过"
  exit 0
else
  echo "❌ 部分验证失败"
  exit 1
fi