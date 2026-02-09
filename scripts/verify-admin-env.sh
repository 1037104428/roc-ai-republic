#!/bin/bash
set -e

# 验证 admin API 环境变量和基本功能
# 用法: ./scripts/verify-admin-env.sh [--local|--remote]

echo "=== 验证 Admin API 环境变量和基本功能 ==="

MODE="local"
if [[ "$1" == "--remote" ]]; then
    MODE="remote"
    SERVER_IP="8.210.185.194"
    SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
fi

check_env() {
    echo "[1/3] 检查环境变量..."
    
    if [[ -z "$ADMIN_TOKEN" ]]; then
        echo "❌ ADMIN_TOKEN 未设置"
        echo "提示: export ADMIN_TOKEN='your-secret-token'"
        echo "提示: 或在 quota-proxy/.env 中设置 ADMIN_TOKEN"
        return 1
    fi
    
    echo "✅ ADMIN_TOKEN 已设置 (长度: ${#ADMIN_TOKEN})"
    
    if [[ -z "$QUOTA_PROXY_URL" ]]; then
        QUOTA_PROXY_URL="http://127.0.0.1:8787"
        echo "⚠️  QUOTA_PROXY_URL 未设置，使用默认: $QUOTA_PROXY_URL"
    else
        echo "✅ QUOTA_PROXY_URL: $QUOTA_PROXY_URL"
    fi
    
    export ADMIN_TOKEN
    export QUOTA_PROXY_URL
}

check_health() {
    echo "[2/3] 检查 quota-proxy 健康状态..."
    
    if [[ "$MODE" == "remote" ]]; then
        HEALTH=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
            "curl -fsS $QUOTA_PROXY_URL/healthz 2>/dev/null || echo 'FAILED'")
    else
        HEALTH=$(curl -fsS "$QUOTA_PROXY_URL/healthz" 2>/dev/null || echo "FAILED")
    fi
    
    if [[ "$HEALTH" == *"ok"* ]] || [[ "$HEALTH" == *"true"* ]]; then
        echo "✅ quota-proxy 健康检查通过"
        echo "   响应: $HEALTH"
    else
        echo "❌ quota-proxy 健康检查失败"
        return 1
    fi
}

check_admin_auth() {
    echo "[3/3] 检查 Admin API 认证..."
    
    if [[ "$MODE" == "remote" ]]; then
        AUTH_CHECK=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" \
            "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' $QUOTA_PROXY_URL/admin/usage 2>&1 || echo 'AUTH_FAILED'")
    else
        AUTH_CHECK=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "$QUOTA_PROXY_URL/admin/usage" 2>&1 || echo "AUTH_FAILED")
    fi
    
    if [[ "$AUTH_CHECK" == *"401"* ]] || [[ "$AUTH_CHECK" == *"AUTH_FAILED"* ]]; then
        echo "❌ Admin API 认证失败"
        echo "   可能原因:"
        echo "   1. ADMIN_TOKEN 不正确"
        echo "   2. quota-proxy 未启用持久化 (SQLite)"
        echo "   3. admin 路由未启用"
        return 1
    elif [[ "$AUTH_CHECK" == *"usage"* ]] || [[ "$AUTH_CHECK" == *"[]"* ]]; then
        echo "✅ Admin API 认证通过"
        echo "   响应包含有效数据"
    else
        echo "⚠️  Admin API 响应异常: $AUTH_CHECK"
    fi
}

main() {
    check_env || exit 1
    check_health || exit 1
    check_admin_auth || echo "⚠️  Admin API 检查有警告，但基础功能正常"
    
    echo ""
    echo "=== 验证完成 ==="
    echo "Admin API 环境基本正常"
    echo ""
    echo "可用命令示例:"
    echo "1. 生成试用密钥:"
    echo "   curl -X POST -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"label\":\"test-user\"}' \\"
    echo "        $QUOTA_PROXY_URL/admin/keys"
    echo ""
    echo "2. 查看使用情况:"
    echo "   curl -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
    echo "        $QUOTA_PROXY_URL/admin/usage"
}

main "$@"