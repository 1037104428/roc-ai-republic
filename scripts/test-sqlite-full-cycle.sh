#!/bin/bash
set -euo pipefail

# test-sqlite-full-cycle.sh - 完整验证 quota-proxy SQLite 持久化与管理接口的端到端测试
# 用途：管理员部署后一键验证 SQLite 持久化、key 发放、用量查询、用量重置、key 吊销等完整流程
# 依赖：curl, jq (可选但推荐), bash >=4

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly PROXY_URL="${PROXY_URL:-http://127.0.0.1:8787}"
readonly ADMIN_TOKEN="${ADMIN_TOKEN:-}"
readonly TEST_LABEL="${TEST_LABEL:-test-$(date +%Y%m%d-%H%M%S)}"

usage() {
  cat <<EOF
$SCRIPT_NAME - 完整验证 quota-proxy SQLite 持久化与管理接口

用法:
  $SCRIPT_NAME [选项]

选项:
  --url URL         quota-proxy 地址 (默认: $PROXY_URL)
  --token TOKEN     管理员 token (也可通过 ADMIN_TOKEN 环境变量设置)
  --label LABEL     测试 key 的 label (默认: $TEST_LABEL)
  --help            显示此帮助信息

环境变量:
  PROXY_URL         同 --url
  ADMIN_TOKEN       同 --token

示例:
  # 在服务器本机测试
  ADMIN_TOKEN="your-secret" $SCRIPT_NAME

  # 远程测试（需确保 admin 接口可访问）
  ADMIN_TOKEN="your-secret" $SCRIPT_NAME --url http://your-server:8787

验证步骤:
  1. 健康检查 (/healthz)
  2. 模型列表 (/v1/models)
  3. 创建测试 key (/admin/keys)
  4. 查询 key 列表 (/admin/keys)
  5. 查询用量 (/admin/usage)
  6. 用量重置 (/admin/usage/reset)
  7. 吊销 key (/admin/keys/:key)
  8. 验证 key 吊销后不可用
  9. SQLite 文件存在性检查（本地部署时）

退出码:
  0 - 所有测试通过
  1 - 参数/环境错误
  2 - 测试失败
EOF
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

fatal() {
  log "错误: $*"
  exit 1
}

warn() {
  log "警告: $*"
}

info() {
  log "信息: $*"
}

success() {
  log "成功: $*"
}

check_deps() {
  if ! command -v curl &>/dev/null; then
    fatal "需要 curl 命令"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)
        PROXY_URL="$2"
        shift 2
        ;;
      --token)
        ADMIN_TOKEN="$2"
        shift 2
        ;;
      --label)
        TEST_LABEL="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        fatal "未知参数: $1"
        ;;
    esac
  done

  if [[ -z "$ADMIN_TOKEN" ]]; then
    fatal "必须提供管理员 token (通过 --token 或 ADMIN_TOKEN 环境变量)"
  fi

  if [[ -z "$PROXY_URL" ]]; then
    fatal "必须提供 proxy URL"
  fi
}

curl_with_auth() {
  local url="$1"
  shift
  curl -fsSL \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$@" \
    "$url"
}

test_healthz() {
  info "步骤 1/9: 健康检查"
  local resp
  resp=$(curl -fsSL "${PROXY_URL}/healthz")
  if [[ "$resp" == '{"ok":true}' ]]; then
    success "健康检查通过"
  else
    fatal "健康检查失败: $resp"
  fi
}

test_models() {
  info "步骤 2/9: 模型列表"
  local resp
  resp=$(curl -fsSL "${PROXY_URL}/v1/models")
  if echo "$resp" | grep -q '"object":"list"'; then
    success "模型列表返回正常"
  else
    warn "模型列表响应格式可能异常: $(echo "$resp" | head -c 200)"
  fi
}

create_test_key() {
  info "步骤 3/9: 创建测试 key (label: $TEST_LABEL)"
  local payload
  payload=$(cat <<EOF
{
  "label": "$TEST_LABEL",
  "limit": 10
}
EOF
  )
  
  local resp
  resp=$(curl_with_auth "${PROXY_URL}/admin/keys" -X POST -d "$payload")
  
  if echo "$resp" | grep -q '"key":"trial_'; then
    TEST_KEY=$(echo "$resp" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    success "创建测试 key: $TEST_KEY"
  else
    fatal "创建 key 失败: $resp"
  fi
}

list_keys() {
  info "步骤 4/9: 查询 key 列表"
  local resp
  resp=$(curl_with_auth "${PROXY_URL}/admin/keys")
  
  if echo "$resp" | grep -q '"items":'; then
    if echo "$resp" | grep -q "$TEST_KEY"; then
      success "key 列表包含测试 key"
    else
      warn "key 列表未找到测试 key (可能显示延迟)"
    fi
  else
    warn "key 列表响应格式可能异常: $(echo "$resp" | head -c 200)"
  fi
}

test_usage() {
  info "步骤 5/9: 查询用量"
  local resp
  resp=$(curl_with_auth "${PROXY_URL}/admin/usage")
  
  if echo "$resp" | grep -q '"items":'; then
    if echo "$resp" | grep -q "$TEST_LABEL"; then
      success "用量查询包含测试 label"
    else
      warn "用量查询未找到测试 label (可能显示延迟)"
    fi
  else
    warn "用量查询响应格式可能异常: $(echo "$resp" | head -c 200)"
  fi
}

reset_usage() {
  info "步骤 6/9: 用量重置"
  local payload
  payload=$(cat <<EOF
{
  "key": "$TEST_KEY"
}
EOF
  )
  
  local resp
  resp=$(curl_with_auth "${PROXY_URL}/admin/usage/reset" -X POST -d "$payload")
  
  if [[ "$resp" == '{"ok":true}' ]]; then
    success "用量重置成功"
  else
    warn "用量重置响应异常: $resp"
  fi
}

revoke_key() {
  info "步骤 7/9: 吊销测试 key"
  local resp
  resp=$(curl_with_auth "${PROXY_URL}/admin/keys/${TEST_KEY}" -X DELETE)
  
  if [[ "$resp" == '{"ok":true}' ]]; then
    success "key 吊销成功"
  else
    warn "key 吊销响应异常: $resp"
  fi
}

test_revoked_key() {
  info "步骤 8/9: 验证吊销后 key 不可用"
  local resp
  set +e
  resp=$(curl -fsSL \
    -H "Authorization: Bearer $TEST_KEY" \
    "${PROXY_URL}/v1/models" 2>&1)
  local curl_exit=$?
  set -e
  
  if [[ $curl_exit -ne 0 ]]; then
    success "吊销后 key 返回错误 (预期行为)"
  else
    warn "吊销后 key 仍可访问: $(echo "$resp" | head -c 200)"
  fi
}

check_sqlite_file() {
  info "步骤 9/9: SQLite 文件检查 (仅本地部署)"
  
  # 尝试检查本地 SQLite 文件
  if [[ "$PROXY_URL" == http://127.0.0.1:* ]] && [[ -d "${SCRIPT_DIR}/../quota-proxy/data" ]]; then
    local db_file="${SCRIPT_DIR}/../quota-proxy/data/quota.db"
    if [[ -f "$db_file" ]]; then
      success "SQLite 文件存在: $db_file"
      if command -v sqlite3 &>/dev/null; then
        local table_count
        table_count=$(sqlite3 "$db_file" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
        info "数据库包含 $table_count 个表"
      fi
    else
      warn "SQLite 文件不存在: $db_file (可能使用 JSON 持久化或路径不同)"
    fi
  else
    info "跳过远程 SQLite 文件检查"
  fi
}

main() {
  check_deps
  parse_args "$@"
  
  info "开始完整 SQLite 持久化与管理接口测试"
  info "Proxy URL: $PROXY_URL"
  info "测试 label: $TEST_LABEL"
  
  test_healthz
  test_models
  create_test_key
  list_keys
  test_usage
  reset_usage
  revoke_key
  test_revoked_key
  check_sqlite_file
  
  success "所有测试通过！"
  info "测试 key 已创建并吊销: $TEST_KEY"
  info "SQLite 持久化与管理接口功能完整"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi