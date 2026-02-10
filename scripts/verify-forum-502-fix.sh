#!/usr/bin/env bash
set -euo pipefail

# 论坛 502 修复验证脚本
# 验证 forum.clawdrepublic.cn 是否可访问

usage() {
  cat <<'TXT'
论坛 502 修复验证脚本

验证 forum.clawdrepublic.cn 是否可访问

选项：
  --timeout <秒>     超时时间（默认：5）
  --verbose          详细输出
  --json             JSON 格式输出
  --help             显示帮助
TXT
}

TIMEOUT=5
VERBOSE=0
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="${2:-5}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --json) JSON_OUTPUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知选项: $1"; usage; exit 1 ;;
  esac
done

FORUM_URL="http://forum.clawdrepublic.cn/"
START_TIME=$(date +%s.%N)

# 测试论坛访问
if [[ $VERBOSE -eq 1 ]]; then
  echo "测试论坛访问: $FORUM_URL (超时: ${TIMEOUT}s)"
fi

HTTP_CODE=0
RESPONSE_TIME=0
ERROR_MSG=""

if OUTPUT=$(curl -fsS -w "%{http_code}" -o /dev/null --max-time "$TIMEOUT" "$FORUM_URL" 2>&1); then
  HTTP_CODE=$(echo "$OUTPUT" | tail -n1)
  RESPONSE_TIME=$(echo "$OUTPUT" | grep -o 'time_total: [0-9.]*' | cut -d' ' -f2 || echo "0")
  if [[ -z "$RESPONSE_TIME" ]]; then
    RESPONSE_TIME=0
  fi
else
  ERROR_MSG="$OUTPUT"
  HTTP_CODE=000
fi

END_TIME=$(date +%s.%N)
TOTAL_TIME=$(echo "$END_TIME - $START_TIME" | bc)

# 判断结果
if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]] || [[ "$HTTP_CODE" =~ ^3[0-9][0-9]$ ]]; then
  STATUS="ok"
  MESSAGE="论坛可访问 (HTTP $HTTP_CODE)"
else
  STATUS="error"
  MESSAGE="论坛不可访问 (HTTP $HTTP_CODE)"
  if [[ -n "$ERROR_MSG" ]]; then
    MESSAGE="$MESSAGE: $ERROR_MSG"
  fi
fi

# 输出结果
if [[ $JSON_OUTPUT -eq 1 ]]; then
  cat <<JSON
{
  "status": "$STATUS",
  "message": "$MESSAGE",
  "http_code": $HTTP_CODE,
  "response_time": $RESPONSE_TIME,
  "check_time": $TOTAL_TIME,
  "url": "$FORUM_URL",
  "timestamp": "$(date -Iseconds)"
}
JSON
else
  if [[ $VERBOSE -eq 1 ]]; then
    echo "论坛验证结果:"
    echo "  状态: $STATUS"
    echo "  消息: $MESSAGE"
    echo "  HTTP 状态码: $HTTP_CODE"
    echo "  响应时间: ${RESPONSE_TIME}s"
    echo "  检查耗时: ${TOTAL_TIME}s"
    echo "  时间戳: $(date -Iseconds)"
  else
    if [[ "$STATUS" == "ok" ]]; then
      echo "✅ $MESSAGE"
    else
      echo "❌ $MESSAGE"
    fi
  fi
fi

# 返回状态码
if [[ "$STATUS" == "ok" ]]; then
  exit 0
else
  exit 1
fi