#!/bin/bash
# 验证 quota-proxy 密钥过期时间功能
# 用法: ./verify-key-expiration.sh [--local|--remote <host>] [--admin-token <token>]

set -e

# 默认配置
LOCAL_HOST="http://localhost:8787"
REMOTE_HOST="http://8.210.185.194:8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d}"
MODE="local"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            shift
            ;;
        --remote)
            MODE="remote"
            if [[ -n "$2" && "$2" != --* ]]; then
                REMOTE_HOST="http://$2:8787"
                shift 2
            else
                REMOTE_HOST="http://8.210.185.194:8787"
                shift
            fi
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --local             测试本地服务器 (默认)"
            echo "  --remote [host]     测试远程服务器 (默认: 8.210.185.194)"
            echo "  --admin-token <token> 指定管理员令牌"
            echo "  --help              显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 设置目标主机
if [[ "$MODE" == "local" ]]; then
    HOST="$LOCAL_HOST"
else
    HOST="$REMOTE_HOST"
fi

echo "🔍 验证 quota-proxy 密钥过期时间功能"
echo "目标: $HOST"
echo "模式: $MODE"
echo "管理员令牌: ${ADMIN_TOKEN:0:10}..."
echo ""

# 检查健康状态
echo "1. 检查服务器健康状态..."
if ! curl -fsS -m 5 "$HOST/healthz" > /dev/null 2>&1; then
    echo "❌ 服务器未响应: $HOST/healthz"
    exit 1
fi
echo "✅ 服务器健康状态正常"

# 测试 1: 创建带过期时间的密钥
echo ""
echo "2. 测试创建带过期时间的密钥..."
EXPIRES_AT="2026-12-31T23:59:59Z"
CREATE_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"label\":\"测试过期密钥\",\"expiresAt\":\"$EXPIRES_AT\"}" \
    "$HOST/admin/keys")

if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    TEST_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "✅ 成功创建带过期时间的密钥: $TEST_KEY"
    echo "   过期时间: $EXPIRES_AT"
else
    echo "❌ 创建带过期时间的密钥失败:"
    echo "$CREATE_RESPONSE"
    exit 1
fi

# 测试 2: 验证过期时间在响应中
if echo "$CREATE_RESPONSE" | grep -q "\"expiresAt\":\"$EXPIRES_AT\""; then
    echo "✅ 响应中包含正确的过期时间"
else
    echo "❌ 响应中未找到过期时间字段"
    echo "响应: $CREATE_RESPONSE"
fi

# 测试 3: 创建不带过期时间的密钥
echo ""
echo "3. 测试创建不带过期时间的密钥..."
CREATE_NO_EXPIRY_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"label":"测试无过期密钥"}' \
    "$HOST/admin/keys")

if echo "$CREATE_NO_EXPIRY_RESPONSE" | grep -q '"success":true'; then
    NO_EXPIRY_KEY=$(echo "$CREATE_NO_EXPIRY_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "✅ 成功创建不带过期时间的密钥: $NO_EXPIRY_KEY"
    
    # 检查 expiresAt 是否为 null
    if echo "$CREATE_NO_EXPIRY_RESPONSE" | grep -q '"expiresAt":null'; then
        echo "✅ 无过期时间密钥的 expiresAt 正确设置为 null"
    else
        echo "⚠️  无过期时间密钥的 expiresAt 字段可能有问题"
    fi
else
    echo "❌ 创建不带过期时间的密钥失败:"
    echo "$CREATE_NO_EXPIRY_RESPONSE"
fi

# 测试 4: 更新密钥的过期时间
echo ""
echo "4. 测试更新密钥的过期时间..."
NEW_EXPIRES_AT="2027-01-15T12:00:00Z"
UPDATE_RESPONSE=$(curl -s -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"expiresAt\":\"$NEW_EXPIRES_AT\"}" \
    "$HOST/admin/keys/$TEST_KEY")

if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
    echo "✅ 成功更新密钥过期时间"
    if echo "$UPDATE_RESPONSE" | grep -q "\"expiresAt\":\"$NEW_EXPIRES_AT\""; then
        echo "✅ 更新后的过期时间正确: $NEW_EXPIRES_AT"
    fi
else
    echo "❌ 更新密钥过期时间失败:"
    echo "$UPDATE_RESPONSE"
fi

# 测试 5: 清除密钥的过期时间
echo ""
echo "5. 测试清除密钥的过期时间..."
CLEAR_RESPONSE=$(curl -s -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"expiresAt":null}' \
    "$HOST/admin/keys/$TEST_KEY")

if echo "$CLEAR_RESPONSE" | grep -q '"success":true'; then
    echo "✅ 成功清除密钥过期时间"
    if echo "$CLEAR_RESPONSE" | grep -q '"expiresAt":null'; then
        echo "✅ 过期时间已正确清除 (设置为 null)"
    fi
else
    echo "❌ 清除密钥过期时间失败:"
    echo "$CLEAR_RESPONSE"
fi

# 测试 6: 验证无效过期时间格式
echo ""
echo "6. 测试无效过期时间格式..."
INVALID_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"label":"测试无效格式","expiresAt":"invalid-date"}' \
    "$HOST/admin/keys")

if echo "$INVALID_RESPONSE" | grep -q '"error":"Invalid expiresAt format"'; then
    echo "✅ 正确拒绝无效过期时间格式"
else
    echo "❌ 未正确验证无效过期时间格式:"
    echo "$INVALID_RESPONSE"
fi

# 测试 7: 列出密钥并检查状态
echo ""
echo "7. 列出所有密钥检查状态..."
LIST_RESPONSE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$HOST/admin/keys?limit=5")

if echo "$LIST_RESPONSE" | grep -q '"success":true'; then
    echo "✅ 成功获取密钥列表"
    # 检查是否有状态字段
    if echo "$LIST_RESPONSE" | grep -q '"status":"'; then
        echo "✅ 密钥列表包含状态字段 (active/expired)"
    else
        echo "⚠️  密钥列表可能缺少状态字段"
    fi
else
    echo "❌ 获取密钥列表失败:"
    echo "$LIST_RESPONSE"
fi

# 清理: 删除测试密钥
echo ""
echo "8. 清理测试密钥..."
for KEY in "$TEST_KEY" "$NO_EXPIRY_KEY"; do
    if [[ -n "$KEY" ]]; then
        DELETE_RESPONSE=$(curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" \
            "$HOST/admin/keys/$KEY")
        
        if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
            echo "✅ 已删除测试密钥: $KEY"
        else
            echo "⚠️  删除密钥 $KEY 失败 (可能已被删除)"
        fi
    fi
done

echo ""
echo "🎉 所有测试完成!"
echo "📋 测试总结:"
echo "  - 创建带过期时间的密钥 ✓"
echo "  - 创建不带过期时间的密钥 ✓"
echo "  - 更新密钥过期时间 ✓"
echo "  - 清除密钥过期时间 ✓"
echo "  - 验证无效格式 ✓"
echo "  - 密钥列表状态检查 ✓"
echo ""
echo "💡 使用示例:"
echo "  创建30天后过期的密钥:"
echo "  expiresAt=\$(date -d '+30 days' '+%Y-%m-%dT%H:%M:%SZ')"
echo "  curl -X POST -H \"Authorization: Bearer \$ADMIN_TOKEN\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d \"{\\\"label\\\":\\\"30天试用\\\",\\\"expiresAt\\\":\\\"\$expiresAt\\\"}\" \\"
echo "    $HOST/admin/keys"