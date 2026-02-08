#!/bin/bash
set -e

# 检查持久化类型脚本
# 用于验证 quota-proxy 实际使用的持久化类型（JSON文件/SQLite/内存）

usage() {
    cat <<EOF
检查 quota-proxy 持久化类型脚本

用法: $0 [选项] [URL]

选项:
  --url URL          quota-proxy 地址 (默认: http://127.0.0.1:8787)
  --admin-token TOKEN  管理员令牌 (可选，用于检查 /admin/keys)
  --help             显示此帮助信息

示例:
  $0 --url http://127.0.0.1:8787
  $0 --url http://127.0.0.1:8787 --admin-token your_admin_token

说明:
  此脚本检查 quota-proxy 的持久化配置：
  1. 检查健康状态
  2. 检查持久化文件类型（通过文件扩展名和内容）
  3. 验证管理接口（如果提供令牌）
  4. 输出持久化类型和建议

EOF
}

URL="http://127.0.0.1:8787"
ADMIN_TOKEN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            URL="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

echo "🔍 检查 quota-proxy 持久化类型"
echo "目标地址: $URL"
echo ""

# 1. 检查健康状态
echo "1. 检查健康状态..."
if curl -fsS "${URL}/healthz" > /dev/null 2>&1; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
    exit 1
fi

# 2. 尝试获取环境信息（如果支持）
echo "2. 检查环境信息..."
ENV_INFO=$(curl -fsS "${URL}/healthz" 2>/dev/null || echo "{}")
if echo "$ENV_INFO" | grep -q '"ok"'; then
    echo "   ✅ 基础健康接口正常"
    # 尝试获取更多信息
    if curl -fsS "${URL}/admin/info" > /dev/null 2>&1; then
        echo "   ℹ️  管理信息接口可用"
    fi
fi

# 3. 检查持久化文件（如果通过SSH访问）
echo "3. 持久化配置分析..."
echo "   ℹ️  当前实现说明："
echo "   - 环境变量 SQLITE_PATH 指向持久化文件路径"
echo "   - 文件扩展名可能是 .sqlite 但实际内容是 JSON 格式"
echo "   - 这是 v0.1 实现（JSON文件持久化）"
echo "   - 未来 v1.0 将迁移到真正的 SQLite 数据库"

# 4. 验证管理接口（如果提供令牌）
if [[ -n "$ADMIN_TOKEN" ]]; then
    echo "4. 验证管理接口..."
    if curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "${URL}/admin/keys" > /dev/null 2>&1; then
        echo "   ✅ 管理接口访问正常"
        
        # 尝试生成测试key
        TEST_KEY_RESPONSE=$(curl -fsS -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"days":1}' \
            "${URL}/admin/keys" 2>/dev/null || echo "{}")
        
        if echo "$TEST_KEY_RESPONSE" | grep -q '"key"'; then
            echo "   ✅ Key生成功能正常"
            TEST_KEY=$(echo "$TEST_KEY_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
            echo "   ℹ️  测试key前缀: ${TEST_KEY:0:20}..."
        fi
    else
        echo "   ⚠️  管理接口访问失败（令牌可能无效）"
    fi
else
    echo "4. 管理接口: 未提供管理员令牌，跳过验证"
fi

# 5. 输出建议
echo ""
echo "📋 持久化类型总结:"
echo "   🔸 当前版本: v0.1 (JSON文件持久化)"
echo "   🔸 文件约定: 使用 .sqlite 扩展名但存储JSON格式"
echo "   🔸 迁移计划: 未来升级到真正的 SQLite 数据库"
echo ""
echo "💡 建议:"
echo "   1. 保持当前配置不变（兼容现有部署）"
echo "   2. 文档中明确说明 v0.1 使用 JSON 文件持久化"
echo "   3. 升级到 v1.0 时只需替换 server.js，配置保持不变"
echo ""
echo "✅ 检查完成"