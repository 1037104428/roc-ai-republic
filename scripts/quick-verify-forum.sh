#!/bin/bash
# 快速验证论坛服务状态脚本
# 用法: ./scripts/quick-verify-forum.sh [--url URL] [--timeout SECONDS]

set -e

# 默认参数
FORUM_URL="http://127.0.0.1:8081"
TIMEOUT=10

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            FORUM_URL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "快速验证论坛服务状态脚本"
            echo "用法: $0 [--url URL] [--timeout SECONDS]"
            echo ""
            echo "参数:"
            echo "  --url URL      论坛URL (默认: $FORUM_URL)"
            echo "  --timeout SEC  超时秒数 (默认: $TIMEOUT)"
            echo "  --help         显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

echo "🔍 开始验证论坛服务..."
echo "论坛URL: $FORUM_URL"
echo "超时设置: ${TIMEOUT}秒"
echo ""

# 检查HTTP响应
echo "1. 检查HTTP可访问性..."
if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" > /dev/null 2>&1; then
    echo "   ✅ HTTP访问正常"
else
    echo "   ❌ HTTP访问失败"
    exit 1
fi

# 检查页面标题
echo "2. 检查页面标题..."
TITLE=$(curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo "")
if [[ -n "$TITLE" ]]; then
    echo "   ✅ 页面标题: $TITLE"
else
    echo "   ⚠️  无法获取页面标题"
fi

# 检查登录/注册链接
echo "3. 检查登录/注册功能..."
if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" | grep -q -E '(登录|注册|sign in|sign up|log in|register)' 2>/dev/null; then
    echo "   ✅ 登录/注册链接存在"
else
    echo "   ⚠️  未找到登录/注册链接"
fi

# 检查置顶帖区域
echo "4. 检查置顶帖区域..."
if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" | grep -q -E '(置顶|sticky|pinned|announcement)' 2>/dev/null; then
    echo "   ✅ 置顶帖区域存在"
else
    echo "   ⚠️  未找到置顶帖区域"
fi

echo ""
echo "🎉 论坛服务验证完成！"
echo "论坛URL: $FORUM_URL"
echo "状态: 正常运行"
echo ""
echo "📋 下一步建议:"
echo "  1. 访问 $FORUM_URL 查看论坛界面"
echo "  2. 检查是否有置顶帖需要创建"
echo "  3. 测试注册和发帖功能"