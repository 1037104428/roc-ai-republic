#!/bin/bash
# 快速文档完整性检查脚本
# 用于快速验证quota-proxy所有核心文档的完整性

set -e

echo "🔍 quota-proxy 文档完整性快速检查"
echo "=================================="
echo ""

# 检查核心文档是否存在
echo "📄 检查核心文档文件..."
declare -A docs=(
    ["README.md"]="主文档"
    ["VALIDATION-QUICK-INDEX.md"]="验证快速索引"
    ["VALIDATION-EXAMPLES.md"]="验证示例"
    ["ENHANCED-VALIDATION-DOCS-CHECK.md"]="增强版检查指南"
    ["TROUBLESHOOTING.md"]="故障排除指南"
    ["QUICK-VERIFICATION-COMMANDS.md"]="快速验证命令集合"
)

all_exist=true
for doc in "${!docs[@]}"; do
    if [[ -f "$doc" ]]; then
        echo "  ✅ $doc - ${docs[$doc]}"
    else
        echo "  ❌ $doc - ${docs[$doc]} (缺失)"
        all_exist=false
    fi
done

echo ""

# 检查文档互引用
echo "🔗 检查文档互引用..."
if grep -q "VALIDATION-QUICK-INDEX.md" README.md; then
    echo "  ✅ README.md 引用 VALIDATION-QUICK-INDEX.md"
else
    echo "  ⚠️  README.md 未引用 VALIDATION-QUICK-INDEX.md"
fi

if grep -q "TROUBLESHOOTING.md" README.md; then
    echo "  ✅ README.md 引用 TROUBLESHOOTING.md"
else
    echo "  ⚠️  README.md 未引用 TROUBLESHOOTING.md"
fi

echo ""

# 检查脚本可执行权限
echo "⚙️  检查验证脚本..."
scripts=("verify-validation-docs.sh" "verify-validation-docs-enhanced.sh")
for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            echo "  ✅ $script (可执行)"
        else
            echo "  ⚠️  $script (不可执行，尝试修复...)"
            chmod +x "$script" 2>/dev/null && echo "    → 已修复权限"
        fi
    else
        echo "  ❌ $script (缺失)"
    fi
done

echo ""

# 运行增强版检查脚本（如果存在）
if [[ -f "verify-validation-docs-enhanced.sh" && -x "verify-validation-docs-enhanced.sh" ]]; then
    echo "📊 运行增强版文档检查..."
    ./verify-validation-docs-enhanced.sh 2>&1 | head -20
    echo ""
fi

# 总结
echo "📋 检查总结:"
if [[ "$all_exist" == "true" ]]; then
    echo "  ✅ 所有核心文档都存在"
else
    echo "  ⚠️  部分文档缺失，请检查"
fi

echo ""
echo "💡 快速命令参考:"
echo "  ./quick-docs-check.sh              # 运行本检查"
echo "  ./verify-validation-docs.sh        # 基础文档检查"
echo "  ./verify-validation-docs-enhanced.sh # 增强版检查"
echo "  cat VALIDATION-QUICK-INDEX.md      # 查看验证工具索引"

exit 0