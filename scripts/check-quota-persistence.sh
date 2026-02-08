#!/bin/bash
set -e

# quota-proxy 持久化状态快速检查脚本
# 用法：./scripts/check-quota-persistence.sh [base_url]
# 默认 base_url: http://127.0.0.1:8787

BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

echo "🔍 检查 quota-proxy 持久化状态 (${BASE_URL})"
echo "=========================================="

# 1. 检查健康状态
echo "1. 健康检查..."
if ! curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    echo "   ❌ 服务不可达"
    exit 1
fi
echo "   ✅ 服务在线"

# 2. 检查持久化模式
echo "2. 持久化模式检测..."
if [ -z "$ADMIN_TOKEN" ]; then
    echo "   ⚠️  未设置 ADMIN_TOKEN，跳过管理接口检查"
    echo "   💡 提示：设置 ADMIN_TOKEN 环境变量可检查持久化详情"
else
    # 尝试获取用量信息（会暴露持久化模式）
    RESPONSE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "${BASE_URL}/admin/usage?day=$(date +%Y-%m-%d)" 2>/dev/null || true)
    
    if echo "$RESPONSE" | grep -q '"mode":"file"'; then
        echo "   📄 当前模式：JSON 文件持久化 (v0.1)"
    elif echo "$RESPONSE" | grep -q '"mode":"sqlite"'; then
        echo "   🗄️  当前模式：SQLite 数据库持久化"
    elif echo "$RESPONSE" | grep -q '"mode":"memory"'; then
        echo "   💾 当前模式：内存模式 (无持久化)"
    else
        echo "   ❓ 未知持久化模式"
        echo "   📋 响应预览：${RESPONSE:0:100}..."
    fi
fi

# 3. 检查环境变量提示
echo "3. 环境变量提示..."
echo "   💡 关键环境变量："
echo "   - SQLITE_PATH: 持久化文件路径（当前实现为 JSON 文件）"
echo "   - ADMIN_TOKEN: 管理接口鉴权 token"
echo "   - DAILY_REQ_LIMIT: 每日请求上限（默认 200）"

# 4. 验证脚本
echo "4. 验证脚本可用性..."
if [ -f "./scripts/test-quota-proxy-admin.sh" ]; then
    echo "   ✅ test-quota-proxy-admin.sh 可用"
else
    echo "   ⚠️  test-quota-proxy-admin.sh 不存在"
fi

if [ -f "./scripts/test-quota-proxy-admin-v2.sh" ]; then
    echo "   ✅ test-quota-proxy-admin-v2.sh 可用"
else
    echo "   ⚠️  test-quota-proxy-admin-v2.sh 不存在"
fi

echo ""
echo "📝 后续步骤："
echo "1. 如需测试管理接口，运行：ADMIN_TOKEN=xxx ./scripts/test-quota-proxy-admin.sh ${BASE_URL}"
echo "2. 如需测试持久化功能，运行：ADMIN_TOKEN=xxx ./scripts/test-quota-proxy-admin-v2.sh ${BASE_URL}"
echo "3. 查看文档：cat docs/quota-proxy-v1-admin-spec.md | head -50"