#!/bin/bash
# 验证文档完整性检查脚本（修复版）
# 检查所有验证相关文档的存在性和基本完整性

set -e

echo "🔍 开始验证文档完整性检查..."
echo "========================================"

# 检查函数
check_doc() {
    local doc_path="$1"
    local doc_name="$2"
    
    if [ -f "$doc_path" ]; then
        local line_count=$(wc -l < "$doc_path" 2>/dev/null || echo "0")
        
        if [ "$line_count" -gt 10 ]; then
            echo "✅ $doc_name"
            echo "   路径: $doc_path"
            echo "   行数: $line_count"
            return 0
        else
            echo "⚠️  $doc_name (内容过少)"
            echo "   路径: $doc_path | 行数: $line_count"
            return 1
        fi
    else
        echo "❌ $doc_name (缺失)"
        echo "   路径: $doc_path 不存在"
        return 2
    fi
}

echo "📋 核心验证文档检查"
echo "----------------------------------------"

# 核心文档检查
check_doc "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引"
check_doc "VALIDATION-DECISION-TREE.md" "验证脚本选择决策树"
check_doc "VALIDATION-TOOLS-INDEX.md" "验证工具详细索引"

echo ""
echo "🔗 文档互引用检查"
echo "----------------------------------------"

# 检查文档间的相互引用
echo "检查文档引用关系..."

if grep -q "VALIDATION-DECISION-TREE.md" "VALIDATION-QUICK-INDEX.md"; then
    echo "✅ VALIDATION-QUICK-INDEX.md 引用了 VALIDATION-DECISION-TREE.md"
else
    echo "⚠️  VALIDATION-QUICK-INDEX.md 未引用 VALIDATION-DECISION-TREE.md"
fi

if grep -q "VALIDATION-QUICK-INDEX.md" "VALIDATION-DECISION-TREE.md"; then
    echo "✅ VALIDATION-DECISION-TREE.md 引用了 VALIDATION-QUICK-INDEX.md"
else
    echo "⚠️  VALIDATION-DECISION-TREE.md 未引用 VALIDATION-QUICK-INDEX.md"
fi

echo ""
echo "📊 文档统计"
echo "----------------------------------------"

# 文档统计
total_docs=0
valid_docs=0

for doc in VALIDATION-QUICK-INDEX.md VALIDATION-DECISION-TREE.md VALIDATION-TOOLS-INDEX.md; do
    if [ -f "$doc" ]; then
        total_docs=$((total_docs + 1))
        lines=$(wc -l < "$doc" 2>/dev/null || echo "0")
        if [ "$lines" -gt 10 ]; then
            valid_docs=$((valid_docs + 1))
        fi
    fi
done

echo "核心验证文档: ${valid_docs}/${total_docs} 个有效"

if [ "$valid_docs" -eq "$total_docs" ] && [ "$total_docs" -ge 2 ]; then
    echo "📚 验证文档完整性检查通过！"
    exit 0
else
    echo "⚠️  验证文档完整性检查未完全通过"
    exit 1
fi