#!/bin/bash
# 验证脚本备份清理工具
# 清理验证工具脚本的备份文件，保持仓库整洁

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔍 开始清理验证脚本备份文件..."

# 查找并删除备份文件
backup_files=()
while IFS= read -r file; do
    backup_files+=("$file")
done < <(find . -name "*.bak" -type f)

if [ ${#backup_files[@]} -eq 0 ]; then
    echo "✅ 没有找到备份文件，仓库已保持整洁"
    exit 0
fi

echo "📋 找到 ${#backup_files[@]} 个备份文件："
for file in "${backup_files[@]}"; do
    echo "  - $file"
done

echo ""
echo "🗑️  删除备份文件..."
for file in "${backup_files[@]}"; do
    rm -v "$file"
done

echo ""
echo "✅ 备份文件清理完成"
echo ""
echo "📊 清理统计："
echo "  - 清理文件数: ${#backup_files[@]}"
echo "  - 清理时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "💡 提示：备份文件通常是在编辑脚本时自动生成的临时文件，"
echo "      清理这些文件有助于保持仓库整洁，减少不必要的文件提交。"