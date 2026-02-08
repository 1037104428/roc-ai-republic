#!/bin/bash
set -euo pipefail

# 检查论坛初始化状态脚本
# 用于验证论坛是否已正确初始化并运行

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/_common.sh"

usage() {
    cat <<EOF
检查论坛初始化状态脚本

用法: $0 [选项]

选项:
  --help          显示此帮助信息
  --url URL       论坛URL (默认: http://127.0.0.1:8081)
  --timeout SEC   超时时间(秒) (默认: 10)

示例:
  $0
  $0 --url http://localhost:8081 --timeout 15

检查项目:
  1. 论坛HTTP可访问性
  2. 论坛标题是否正确
  3. 论坛是否显示登录/注册链接
  4. 论坛是否有置顶帖（如果已初始化）
EOF
    exit 0
}

# 默认参数
FORUM_URL="http://127.0.0.1:8081"
TIMEOUT=10

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) usage ;;
        --url) FORUM_URL="$2"; shift ;;
        --timeout) TIMEOUT="$2"; shift ;;
        *) echo "未知选项: $1" >&2; exit 1 ;;
    esac
    shift
done

echo "🔍 检查论坛初始化状态"
echo "论坛URL: $FORUM_URL"
echo "超时: ${TIMEOUT}秒"
echo

# 检查HTTP可访问性
echo "1. 检查HTTP可访问性..."
if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" >/dev/null 2>&1; then
    echo "   ✅ 论坛可访问"
else
    echo "   ❌ 论坛不可访问"
    exit 1
fi

# 获取页面内容检查标题
echo "2. 检查论坛标题..."
PAGE_CONTENT=$(curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" 2>/dev/null || true)
if echo "$PAGE_CONTENT" | grep -q "<title>Clawd 国度</title>"; then
    echo "   ✅ 论坛标题正确"
else
    echo "   ⚠️  论坛标题可能不正确或页面内容异常"
    # 尝试提取实际标题
    ACTUAL_TITLE=$(echo "$PAGE_CONTENT" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || true)
    if [ -n "$ACTUAL_TITLE" ]; then
        echo "   实际标题: $ACTUAL_TITLE"
    fi
fi

# 检查是否有登录/注册链接（表示论坛基本功能正常）
echo "3. 检查论坛基本功能..."
if echo "$PAGE_CONTENT" | grep -q -E '(登录|注册|Sign in|Register)'; then
    echo "   ✅ 论坛显示登录/注册链接"
else
    echo "   ⚠️  未找到登录/注册链接，论坛可能未完全初始化"
fi

# 检查是否有置顶帖（如果已初始化）
echo "4. 检查置顶帖..."
if echo "$PAGE_CONTENT" | grep -q -E '(置顶|置顶帖|Sticky|Pinned)'; then
    echo "   ✅ 论坛有置顶帖"
else
    echo "   ℹ️  未检测到置顶帖，可能需要初始化置顶帖"
    echo "   参考文档: docs/posts/论坛MVP_信息架构与置顶帖模板.md"
fi

# 检查论坛API状态（Flarum特有）
echo "5. 检查论坛API..."
API_RESPONSE=$(curl -fsS --max-time "$TIMEOUT" "$FORUM_URL/api" 2>/dev/null || true)
if [ -n "$API_RESPONSE" ]; then
    if echo "$API_RESPONSE" | grep -q '"data"'; then
        echo "   ✅ 论坛API响应正常"
    else
        echo "   ℹ️  论坛API可访问但响应格式可能异常"
    fi
else
    echo "   ℹ️  论坛API不可访问（可能是正常情况，取决于配置）"
fi

echo
echo "📋 论坛初始化状态检查完成"
echo "建议:"
echo "  1. 如果论坛未完全初始化，请运行论坛初始化脚本"
echo "  2. 确保已创建必要的置顶帖（欢迎帖、规则帖、FAQ等）"
echo "  3. 验证论坛管理员账号可正常登录"
echo
echo "相关文档:"
echo "  - docs/posts/论坛MVP_信息架构与置顶帖模板.md"
echo "  - docs/ops-forum-deployment.md (如果存在)"

exit 0