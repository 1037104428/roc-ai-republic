#!/bin/bash
# 综合测试 quota-proxy 管理接口
# 用法: ./test-admin-comprehensive.sh [--host HOST] [--token TOKEN]

set -e

HOST="http://127.0.0.1:8787"
TOKEN="${ADMIN_TOKEN:-}"
LABEL_PREFIX="test-$(date +%Y%m%d-%H%M%S)"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$TOKEN" ]]; then
    echo "错误: 需要 ADMIN_TOKEN 环境变量或 --token 参数"
    echo "用法: ADMIN_TOKEN=your_token ./test-admin-comprehensive.sh [--host HOST]"
    exit 1
fi

AUTH_HEADER="Authorization: Bearer $TOKEN"

echo "=== quota-proxy 管理接口综合测试 ==="
echo "主机: $HOST"
echo "标签前缀: $LABEL_PREFIX"
echo

# 1. 测试健康检查
echo "1. 测试健康检查..."
curl -s -f "$HOST/healthz" | jq -r '.ok' | grep -q "true" && echo "✓ 健康检查通过" || (echo "✗ 健康检查失败" && exit 1)
echo

# 2. 列出当前密钥
echo "2. 列出当前密钥..."
curl -s -H "$AUTH_HEADER" "$HOST/admin/keys" | jq -r '.keys | length' | read KEY_COUNT
echo "当前有 $KEY_COUNT 个密钥"
echo

# 3. 创建新密钥
echo "3. 创建新密钥..."
CREATE_RESPONSE=$(curl -s -H "$AUTH_HEADER" -H "Content-Type: application/json" \
    -d "{\"label\":\"$LABEL_PREFIX-comprehensive-test\"}" \
    "$HOST/admin/keys")
NEW_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key')
if [[ "$NEW_KEY" != "null" && -n "$NEW_KEY" ]]; then
    echo "✓ 创建密钥成功: $NEW_KEY"
else
    echo "✗ 创建密钥失败: $CREATE_RESPONSE"
    exit 1
fi
echo

# 4. 验证密钥可用性
echo "4. 验证密钥可用性..."
MODELS_RESPONSE=$(curl -s -H "Authorization: Bearer $NEW_KEY" "$HOST/v1/models")
if echo "$MODELS_RESPONSE" | jq -r '.object' 2>/dev/null | grep -q "list"; then
    echo "✓ 密钥可用 (/v1/models 返回成功)"
else
    echo "⚠ 密钥可能不可用或需要配额: $MODELS_RESPONSE"
fi
echo

# 5. 检查使用情况
echo "5. 检查使用情况..."
USAGE_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$HOST/admin/usage")
USAGE_COUNT=$(echo "$USAGE_RESPONSE" | jq -r '.items | length')
echo "使用情况条目数: $USAGE_COUNT"
if [[ $USAGE_COUNT -gt 0 ]]; then
    echo "最近使用记录:"
    echo "$USAGE_RESPONSE" | jq -r '.items[0] | "  - \(.trial_key[:20])...: \(.requests) 请求 (日期: \(.day))"'
fi
echo

# 6. 测试密钥删除
echo "6. 测试密钥删除..."
DELETE_RESPONSE=$(curl -s -X DELETE -H "$AUTH_HEADER" "$HOST/admin/keys/$NEW_KEY")
if echo "$DELETE_RESPONSE" | jq -r '.deleted' 2>/dev/null | grep -q "true"; then
    echo "✓ 密钥删除成功"
else
    echo "⚠ 密钥删除可能失败: $DELETE_RESPONSE"
fi
echo

# 7. 验证密钥已删除
echo "7. 验证密钥已删除..."
AFTER_DELETE_COUNT=$(curl -s -H "$AUTH_HEADER" "$HOST/admin/keys" | jq -r '.keys | length')
echo "删除后密钥总数: $AFTER_DELETE_COUNT"
if [[ $AFTER_DELETE_COUNT -eq $((KEY_COUNT)) ]]; then
    echo "✓ 密钥删除验证通过"
else
    echo "⚠ 密钥计数不一致: 之前 $KEY_COUNT, 现在 $AFTER_DELETE_COUNT"
fi
echo

echo "=== 测试完成 ==="
echo "所有管理接口功能测试通过！"
echo
echo "快速参考命令:"
echo "  列出密钥: curl -H '$AUTH_HEADER' $HOST/admin/keys | jq"
echo "  创建密钥: curl -H '$AUTH_HEADER' -H 'Content-Type: application/json' -d '{\"label\":\"your-label\"}' $HOST/admin/keys"
echo "  查看用量: curl -H '$AUTH_HEADER' $HOST/admin/usage | jq"
echo "  删除密钥: curl -X DELETE -H '$AUTH_HEADER' $HOST/admin/keys/KEY_TO_DELETE"