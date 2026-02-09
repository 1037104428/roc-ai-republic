#!/bin/bash
set -euo pipefail

# 论坛MVP验证脚本
# 用途：验证论坛信息架构与置顶帖模板是否完整
# 作者：中华AI共和国项目推进循环
# 时间：2026-02-09

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"

echo "🔍 验证论坛MVP文档完整性..."

# 1. 检查docs/posts目录是否存在
if [ ! -d "$DOCS_DIR/posts" ]; then
    echo "❌ 错误：$DOCS_DIR/posts 目录不存在"
    exit 1
fi

echo "✅ docs/posts 目录存在"

# 2. 检查必要的模板文件（基于实际文件结构）
required_files=(
    "forum-architecture.md"
    "newbie-guide-template.md"
    "trial-key-application-template.md"
    "模板_问题求助.md"
    "模板_TRIAL_KEY_申请.md"
    "置顶_论坛导航与规则.md"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$DOCS_DIR/posts/$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "❌ 缺少以下模板文件："
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo "✅ 所有模板文件完整"

# 3. 检查文件内容非空
empty_files=()
for file in "${required_files[@]}"; do
    if [ ! -s "$DOCS_DIR/posts/$file" ]; then
        empty_files+=("$file")
    fi
done

if [ ${#empty_files[@]} -gt 0 ]; then
    echo "⚠️  以下文件内容为空："
    for file in "${empty_files[@]}"; do
        echo "  - $file"
    done
    echo "提示：请补充内容"
fi

# 4. 检查论坛信息架构文档
if ! grep -q "信息架构\|论坛" "$DOCS_DIR/posts/forum-architecture.md" 2>/dev/null; then
    echo "⚠️  forum-architecture.md 中可能缺少'信息架构'或'论坛'关键词"
fi

# 5. 检查置顶帖模板
if ! grep -q "置顶\|导航" "$DOCS_DIR/posts/置顶_论坛导航与规则.md" 2>/dev/null; then
    echo "⚠️  置顶_论坛导航与规则.md 中可能缺少'置顶'或'导航'关键词"
fi

# 6. 输出统计信息
echo ""
echo "📊 论坛MVP文档统计："
echo "  - 模板文件数量: ${#required_files[@]}"
echo "  - 总文件大小: $(du -sh "$DOCS_DIR/posts" | cut -f1)"
echo "  - 最近修改时间: $(ls -lt "$DOCS_DIR/posts/"*.md | head -1 | awk '{print $6,$7,$8}')"

# 7. 生成验证报告
echo ""
echo "📋 验证报告："
echo "  - 目录结构: ✅ 完整"
echo "  - 模板文件: ✅ 完整"
echo "  - 内容检查: $(if [ ${#empty_files[@]} -eq 0 ]; then echo "✅ 通过"; else echo "⚠️  有${#empty_files[@]}个空文件"; fi)"
echo ""
echo "🎉 论坛MVP文档验证完成！"
echo ""
echo "下一步建议："
echo "  1. 将模板部署到实际论坛"
echo "  2. 创建论坛反向代理配置（修复502问题）"
echo "  3. 在官网添加论坛入口链接"
echo "  4. 更新 tickets.md 中的论坛任务状态"

exit 0