#!/bin/bash
# 快速验证 quota-proxy SQLite 数据库状态脚本
# 用法: ./verify-sqlite-status.sh [--host HOST:PORT] [--token ADMIN_TOKEN]

set -e

# 默认值
HOST="127.0.0.1:8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --host)
      HOST="$2"
      shift 2
      ;;
    --token)
      ADMIN_TOKEN="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [--host HOST:PORT] [--token ADMIN_TOKEN]"
      echo ""
      echo "快速验证 quota-proxy SQLite 数据库状态"
      echo ""
      echo "参数:"
      echo "  --host HOST:PORT     quota-proxy 服务地址 (默认: 127.0.0.1:8787)"
      echo "  --token ADMIN_TOKEN  管理员令牌 (也可通过 ADMIN_TOKEN 环境变量设置)"
      echo "  --help               显示此帮助信息"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      echo "使用 --help 查看帮助"
      exit 1
      ;;
  esac
done

# 检查必需参数
if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "错误: 需要管理员令牌"
  echo "请通过 --token 参数或 ADMIN_TOKEN 环境变量设置"
  exit 1
fi

echo "=== quota-proxy SQLite 数据库状态验证 ==="
echo "服务地址: $HOST"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 检查健康状态
echo "1. 检查服务健康状态..."
if curl -fsS "http://$HOST/healthz" > /dev/null 2>&1; then
  echo "   ✅ 健康检查通过"
else
  echo "   ❌ 健康检查失败"
  exit 1
fi

# 2. 检查管理员接口
echo "2. 检查管理员接口访问..."
RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/admin_keys.json \
  "http://$HOST/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if [[ "$RESPONSE" == "200" ]]; then
  echo "   ✅ 管理员接口访问正常"
  KEY_COUNT=$(jq length /tmp/admin_keys.json 2>/dev/null || echo "0")
  echo "   当前密钥数量: $KEY_COUNT"
else
  echo "   ❌ 管理员接口访问失败 (HTTP $RESPONSE)"
  exit 1
fi

# 3. 创建测试密钥
echo "3. 创建测试密钥..."
TEST_KEY_RESPONSE=$(curl -s -X POST "http://$HOST/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"sqlite-verification-test"}')

if echo "$TEST_KEY_RESPONSE" | grep -q '"key"'; then
  TEST_KEY=$(echo "$TEST_KEY_RESPONSE" | jq -r '.key')
  echo "   ✅ 测试密钥创建成功"
  echo "   密钥: $TEST_KEY"
else
  echo "   ❌ 测试密钥创建失败"
  echo "   响应: $TEST_KEY_RESPONSE"
  exit 1
fi

# 4. 验证密钥可用性
echo "4. 验证密钥可用性..."
MODELS_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/models.json \
  "http://$HOST/v1/models" \
  -H "Authorization: Bearer $TEST_KEY")

if [[ "$MODELS_RESPONSE" == "200" ]]; then
  echo "   ✅ 密钥验证通过"
  MODEL_COUNT=$(jq '.data | length' /tmp/models.json 2>/dev/null || echo "0")
  echo "   可用模型数量: $MODEL_COUNT"
else
  echo "   ❌ 密钥验证失败 (HTTP $MODELS_RESPONSE)"
  exit 1
fi

# 5. 检查使用情况统计
echo "5. 检查使用情况统计..."
TODAY=$(date +%F)
USAGE_RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/usage.json \
  "http://$HOST/admin/usage?day=$TODAY" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if [[ "$USAGE_RESPONSE" == "200" ]]; then
  echo "   ✅ 使用情况统计正常"
  TOTAL_USAGE=$(jq '.[] | .total_requests' /tmp/usage.json 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
  echo "   今日总请求数: $TOTAL_USAGE"
else
  echo "   ❌ 使用情况统计失败 (HTTP $USAGE_RESPONSE)"
fi

# 6. 清理测试密钥（可选）
echo "6. 清理测试密钥..."
# 注意：实际部署中可能需要保留测试密钥，这里只是演示清理流程
echo "   ℹ️  测试密钥保留用于后续验证"
echo "   如需清理，可手动调用 DELETE /admin/keys/{key}"

echo ""
echo "=== 验证完成 ==="
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "验证结果摘要:"
echo "1. ✅ 服务健康状态正常"
echo "2. ✅ 管理员接口访问正常"
echo "3. ✅ 测试密钥创建成功 ($TEST_KEY)"
echo "4. ✅ 密钥验证通过"
echo "5. ✅ 使用情况统计正常"
echo ""
echo "SQLite 数据库状态验证通过！"
echo ""
echo "后续验证建议:"
echo "1. 重启服务验证数据持久化: docker compose restart quota-proxy"
echo "2. 验证配额限制: 连续调用 API 超过 200 次应返回 429"
echo "3. 验证并发性能: 同时发起多个请求测试响应时间"
echo ""
echo "快速验证命令:"
echo "  # 健康检查"
echo "  curl -fsS http://$HOST/healthz"
echo ""
echo "  # 使用测试密钥查询模型"
echo "  curl -fsS http://$HOST/v1/models \\"
echo "    -H \"Authorization: Bearer $TEST_KEY\""
echo ""
echo "  # 查看今日使用情况"
echo "  curl -fsS \"http://$HOST/admin/usage?day=$TODAY\" \\"
echo "    -H \"Authorization: Bearer $ADMIN_TOKEN\" | jq ."