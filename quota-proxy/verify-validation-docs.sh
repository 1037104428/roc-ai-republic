#!/bin/bash
# 验证文档完整性检查脚本
# 检查所有验证相关文档的存在性和基本完整性

set -e

echo "🔍 开始验证文档完整性检查..."
echo "========================================"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_doc() {
    local doc_path="$1"
    local doc_name="$2"
    local required="${3:-false}"
    
    if [ -f "$doc_path" ]; then
        local line_count=$(wc -l < "$doc_path" 2>/dev/null || echo "0")
        local size_kb=$(du -k "$doc_path" 2>/dev/null | cut -f1)
        
        if [ "$line_count" -gt 10 ]; then
            echo -e "${GREEN}✅ $doc_name${NC}"
            echo -e "   路径: $doc_path"
            echo -e "   行数: $line_count | 大小: ${size_kb}KB"
            
            # 检查是否有基本章节
            if grep -q -E "^# |^## |^### " "$doc_path"; then
                echo -e "   📑 包含Markdown标题结构"
            fi
            
            if grep -q -E "验证|检查|测试" "$doc_path"; then
                echo -e "   🔧 包含验证相关内容"
            fi
            
            return 0
        else
            echo -e "${YELLOW}⚠️  $doc_name (内容过少)${NC}"
            echo -e "   路径: $doc_path | 行数: $line_count"
            return 1
        fi
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ $doc_name (缺失)${NC}"
            echo -e "   路径: $doc_path 不存在"
            return 2
        else
            echo -e "${YELLOW}⚠️  $doc_name (可选文档缺失)${NC}"
            return 1
        fi
    fi
}

echo -e "${BLUE}📋 核心验证文档检查${NC}"
echo "----------------------------------------"

# 核心文档检查
check_doc "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引" "true"
check_doc "VALIDATION-DECISION-TREE.md" "验证脚本选择决策树" "true"
check_doc "VALIDATION-TOOLS-INDEX.md" "验证工具详细索引" "true"

echo ""
echo -e "${BLUE}📚 相关支持文档检查${NC}"
echo "----------------------------------------"

# 相关文档检查
check_doc "ADMIN-API-EXAMPLES.md" "Admin API详细示例"
check_doc "DATABASE-INIT-GUIDE.md" "数据库初始化指南"
check_doc "DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md" "SQLite持久化部署指南"
check_doc "QUICK-START.md" "快速开始指南"
check_doc "QUICK-SQLITE-HEALTH-CHECK.md" "快速SQLite健康检查"

echo ""
echo -e "${BLUE}🔗 文档互引用检查${NC}"
echo "----------------------------------------"

# 检查文档间的相互引用
echo "检查文档引用关系..."

if grep -q "VALIDATION-DECISION-TREE.md" "VALIDATION-QUICK-INDEX.md"; then
    echo -e "${GREEN}✅ VALIDATION-QUICK-INDEX.md 引用了 VALIDATION-DECISION-TREE.md${NC}"
else
    echo -e "${YELLOW}⚠️  VALIDATION-QUICK-INDEX.md 未引用 VALIDATION-DECISION-TREE.md${NC}"
fi

if grep -q "VALIDATION-QUICK-INDEX.md" "VALIDATION-DECISION-TREE.md"; then
    echo -e "${GREEN}✅ VALIDATION-DECISION-TREE.md 引用了 VALIDATION-QUICK-INDEX.md${NC}"
else
    echo -e "${YELLOW}⚠️  VALIDATION-DECISION-TREE.md 未引用 VALIDATION-QUICK-INDEX.md${NC}"
fi

echo ""
echo -e "${BLUE}📊 文档统计${NC}"
echo "----------------------------------------"

# 文档统计
total_docs=0
valid_docs=0
total_lines=0

for doc in VALIDATION-QUICK-INDEX.md VALIDATION-DECISION-TREE.md VALIDATION-TOOLS-INDEX.md; do
    if [ -f "$doc" ]; then
        total_docs=$((total_docs + 1))
        lines=$(wc -l < "$doc" 2>/dev/null || echo "0")
        if [ "$lines" -gt 10 ]; then
            valid_docs=$((valid_docs + 1))
            total_lines=$((total_lines + lines))
        fi
    fi
done

echo -e "核心验证文档: ${valid_docs}/${total_docs} 个有效"
echo -e "总行数: ${total_lines} 行"

if [ "$valid_docs" -eq "$total_docs" ] && [ "$total_docs" -ge 2 ]; then
    echo -e "${GREEN}📚 验证文档完整性检查通过！${NC}"
    echo ""
    echo -e "${BLUE}🎯 使用建议${NC}"
    echo "----------------------------------------"
    echo "1. 新用户：先阅读 VALIDATION-DECISION-TREE.md 选择验证脚本"
    echo "2. 快速参考：查看 VALIDATION-QUICK-INDEX.md 获取脚本索引"
    echo "3. 详细参考：查看 VALIDATION-TOOLS-INDEX.md 获取完整信息"
    echo ""
    echo "运行示例："
    echo "  ./verify-validation-docs.sh      # 检查文档完整性"
    echo "  ./quick-verify-db.sh            # 快速数据库验证"
    echo "  ./check-deployment-status.sh    # 部署状态检查"
    
    exit 0
else
    echo -e "${YELLOW}⚠️  验证文档完整性检查未完全通过${NC}"
    echo "建议："
    echo "1. 确保至少2个核心验证文档存在且内容完整"
    echo "2. 检查文档间的相互引用"
    echo "3. 确保文档包含基本的Markdown结构"
    
    exit 1
fi