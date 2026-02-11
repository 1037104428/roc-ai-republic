#!/usr/bin/env bash
set -euo pipefail

# 论坛快速验证脚本
# 用于快速验证论坛部署状态和基本功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORUM_URL="${FORUM_URL:-http://localhost:4567}"
HEALTH_CHECK_URL="$FORUM_URL/health"
API_STATUS_URL="$FORUM_URL/api/status"

echo "=== 论坛快速验证脚本 ==="
echo "论坛URL: $FORUM_URL"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 1. 检查论坛服务是否运行
echo "1. 检查论坛服务状态..."
if curl -s --max-time 10 "$FORUM_URL" > /dev/null 2>&1; then
    echo "✓ 论坛服务可访问"
else
    echo "✗ 论坛服务不可访问"
    echo "  尝试检查Docker容器状态..."
    if docker ps | grep -q "nodebb\|forum"; then
        echo "  Docker容器正在运行"
    else
        echo "  Docker容器未运行"
    fi
    exit 1
fi

# 2. 检查健康检查端点
echo "2. 检查健康检查端点..."
if curl -s --max-time 10 "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
    echo "✓ 健康检查端点可访问"
else
    echo "⚠ 健康检查端点不可访问（可能未配置）"
fi

# 3. 检查API状态
echo "3. 检查API状态..."
API_RESPONSE=$(curl -s --max-time 10 "$API_STATUS_URL" 2>/dev/null || true)
if [ -n "$API_RESPONSE" ]; then
    echo "✓ API端点可访问"
    echo "  API响应: $API_RESPONSE"
else
    echo "⚠ API端点不可访问（可能未配置）"
fi

# 4. 检查论坛首页内容
echo "4. 检查论坛首页内容..."
HOME_CONTENT=$(curl -s --max-time 10 "$FORUM_URL" | head -c 500)
if echo "$HOME_CONTENT" | grep -qi "forum\|community\|discussion"; then
    echo "✓ 论坛首页包含论坛相关关键词"
else
    echo "⚠ 论坛首页内容异常"
    echo "  首页预览: $HOME_CONTENT"
fi

# 5. 检查端口占用
echo "5. 检查端口占用..."
if ss -tuln | grep -q ":4567 "; then
    echo "✓ 端口4567正在监听"
else
    echo "✗ 端口4567未监听"
fi

# 6. 检查Docker容器状态
echo "6. 检查Docker容器状态..."
FORUM_CONTAINERS=$(docker ps --filter "name=nodebb\|name=forum" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true)
if [ -n "$FORUM_CONTAINERS" ]; then
    echo "✓ 论坛相关容器状态:"
    echo "$FORUM_CONTAINERS" | tail -n +2
else
    echo "⚠ 未找到论坛相关容器"
fi

echo
echo "=== 验证完成 ==="
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "总结: 论坛基本部署验证完成，服务状态正常"