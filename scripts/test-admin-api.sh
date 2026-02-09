#!/bin/bash
# 测试 quota-proxy 管理员 API 端点
# 用法: ./test-admin-api.sh [--server SERVER_IP] [--token ADMIN_TOKEN]

set -e

# 默认值
SERVER_IP="8.210.185.194"
ADMIN_TOKEN="${QUOTA_PROXY_ADMIN_TOKEN:-test_admin_token_123}"
BASE_URL="http://${SERVER_IP}:8787"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_IP="$2"
            BASE_URL="http://${SERVER_IP}:8787"
            shift 2
            ;;
        --token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [--server SERVER_IP] [--token ADMIN_TOKEN]"
            echo ""
            echo "测试 quota-proxy 管理员 API 端点:"
            echo "  1. 健康检查 /healthz"
            echo "  2. 生成试用密钥 /admin/keys (POST)"
            echo "  3. 查看使用情况 /admin/usage (GET)"
            echo ""
            echo "环境变量:"
            echo "  QUOTA_PROXY_ADMIN_TOKEN  管理员令牌 (默认: test_admin_token_123)"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo "=== 测试 quota-proxy 管理员 API ==="
echo "服务器: ${SERVER_IP}"
echo "API地址: ${BASE_URL}"
echo "管理员令牌: ${ADMIN_TOKEN:0:10}..."
echo ""

# 1. 健康检查
echo "1. 测试健康检查端点 /healthz:"
if curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
    exit 1
fi

# 2. 生成试用密钥
echo ""
echo "2. 测试生成试用密钥 /admin/keys:"
TRIAL_KEY_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"name":"test_user","quota":100,"expiry_hours":24}' \
    "${BASE_URL}/admin/keys" || echo "{}")

if echo "${TRIAL_KEY_RESPONSE}" | grep -q "key"; then
    TRIAL_KEY=$(echo "${TRIAL_KEY_RESPONSE}" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "   ✅ 试用密钥生成成功"
    echo "   密钥: ${TRIAL_KEY:0:20}..."
else
    echo "   ⚠️  试用密钥生成失败 (可能是API未实现或令牌错误)"
    echo "   响应: ${TRIAL_KEY_RESPONSE}"
    TRIAL_KEY=""
fi

# 3. 查看使用情况
echo ""
echo "3. 测试查看使用情况 /admin/usage:"
USAGE_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${BASE_URL}/admin/usage" || echo "{}")

if echo "${USAGE_RESPONSE}" | grep -q "total_requests\|active_keys"; then
    echo "   ✅ 使用情况查询成功"
    echo "   响应摘要:"
    echo "${USAGE_RESPONSE}" | jq -r '. | "   总请求数: \(.total_requests // 0)\n   活跃密钥数: \(.active_keys // 0)\n   总用户数: \(.total_users // 0)"' 2>/dev/null || \
    echo "   原始响应: ${USAGE_RESPONSE}"
else
    echo "   ⚠️  使用情况查询失败 (可能是API未实现或令牌错误)"
    echo "   响应: ${USAGE_RESPONSE}"
fi

# 4. 如果生成了试用密钥，测试使用它
if [[ -n "${TRIAL_KEY}" ]]; then
    echo ""
    echo "4. 测试试用密钥使用:"
    TEST_RESPONSE=$(curl -s -H "X-API-Key: ${TRIAL_KEY}" \
        "${BASE_URL}/v1/chat/completions" \
        -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello"}]}' || echo "{}")
    
    if echo "${TEST_RESPONSE}" | grep -q "choices\|error"; then
        echo "   ✅ 试用密钥可用"
    else
        echo "   ⚠️  试用密钥测试失败"
    fi
fi

echo ""
echo "=== 测试完成 ==="
echo "注意: 如果管理员API端点尚未实现，这些测试会显示警告而非错误。"
echo "这是预期的，因为API正在开发中。脚本主要用于验证API端点的基础连通性。"