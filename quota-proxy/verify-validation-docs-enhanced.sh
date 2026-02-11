#!/bin/bash
# 增强版验证文档完整性检查脚本
# 检查所有验证相关文档的存在性、完整性和文档体系一致性

set -e

echo "🔍 开始增强版验证文档完整性检查..."
echo "========================================"
echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_doc() {
    local doc_path="$1"
    local doc_name="$2"
    local min_lines="${3:-10}"
    
    if [ -f "$doc_path" ]; then
        local line_count=$(wc -l < "$doc_path" 2>/dev/null || echo "0")
        local byte_count=$(wc -c < "$doc_path" 2>/dev/null || echo "0")
        
        if [ "$line_count" -gt "$min_lines" ]; then
            echo -e "${GREEN}✅ $doc_name${NC}"
            echo "   路径: $doc_path"
            echo "   行数: $line_count | 大小: ${byte_count}字节"
            return 0
        else
            echo -e "${YELLOW}⚠️  $doc_name (内容过少)${NC}"
            echo "   路径: $doc_path | 行数: $line_count | 最小要求: ${min_lines}行"
            return 1
        fi
    else
        echo -e "${RED}❌ $doc_name (缺失)${NC}"
        echo "   路径: $doc_path 不存在"
        return 2
    fi
}

echo -e "${BLUE}📋 核心验证文档检查${NC}"
echo "----------------------------------------"

# 核心文档检查
check_doc "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引" 20
check_doc "VALIDATION-DECISION-TREE.md" "验证脚本选择决策树" 30
check_doc "VALIDATION-TOOLS-INDEX.md" "验证工具详细索引" 40
check_doc "VALIDATION-EXAMPLES.md" "验证脚本使用示例" 50
check_doc "TROUBLESHOOTING.md" "故障排除指南" 30
check_doc "QUICK-VERIFICATION-COMMANDS.md" "快速验证命令集合" 30
check_doc "QUICK-DOCS-CHECK-GUIDE.md" "快速文档检查指南" 20
check_doc "TODO-TICKETS.md" "开发任务跟踪系统" 20
check_doc "ADMIN-API-GUIDE.md" "Admin API 使用指南" 30
check_doc "quick-verify-admin-api.sh" "Admin API快速验证脚本" 10
check_doc "QUICK-DEPLOY-ADMIN-API.md" "Admin API快速部署指南" 30
check_doc "test-admin-api-quick.js" "Admin API快速测试用例" 10
check_doc "quick-test-admin-api.sh" "Admin API快速测试脚本" 10
check_doc "quick-test-admin-api-usage.md" "Admin API快速测试脚本使用说明文档" 20
check_doc "test-admin-keys-usage.sh" "Admin密钥生成和用量统计测试脚本" 10
check_doc "ADMIN-API-QUICK-TEST-EXAMPLES.md" "Admin API快速测试示例" 30
check_doc "quick-admin-api-test.sh" "Admin API一键完整测试脚本" 10
check_doc "test-admin-keys-usage-usage.md" "Admin密钥生成和用量统计测试使用说明" 20
check_doc "verify-admin-api-complete.sh" "Admin API完整功能验证脚本" 10
check_doc "ADMIN-API-TEST-ENV-SETUP.md" "Admin API测试环境配置指南" 30
check_doc "../scripts/verify-install-cn.sh" "安装脚本验证脚本" 10
check_doc "../scripts/quick-verify-install-cn.sh" "安装脚本快速验证工具" 10
check_doc "../scripts/quick-verify-install-cn-enhanced.sh" "安装脚本增强版快速验证工具" 10
check_doc "../scripts/verify-install-cn-complete.sh" "安装脚本完整功能验证脚本" 10
check_doc "../scripts/install-cn-fallback-recovery.sh" "安装失败恢复脚本" 10
check_doc "../docs/install-cn-fallback-recovery-guide.md" "安装失败恢复指南" 10
check_doc "../scripts/install-cn-self-check.sh" "安装自检脚本" 10
check_doc "../scripts/quick-verify-cdn-fallback.sh" "CDN回退策略验证脚本" 10
check_doc "../docs/install-cn-script-verification-guide.md" "安装脚本验证指南" 20
check_doc "../docs/install-cn-quick-test-examples.md" "安装脚本快速测试示例" 20
check_doc "../docs/install-cn-complete-verification-guide.md" "安装脚本完整功能验证指南" 20
check_doc "../docs/validation-toolchain-overview.md" "验证工具链概览文档" 20
check_doc "verify-env.sh" "环境变量验证脚本" 10
check_doc "verify-sqlite-persistence.sh" "SQLite持久化验证脚本" 10
check_doc "init-sqlite-db.sh" "SQLite数据库初始化脚本" 10
check_doc "verify-sqlite-init.sh" "SQLite初始化验证脚本" 10
check_doc "verify-sqlite-integrity.sh" "SQLite数据库完整性验证脚本" 10
check_doc "verify-env-vars.sh" "环境变量验证脚本" 10
check_doc "PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md" "Prometheus监控集成指南" 20
check_doc "verify-prometheus-metrics.sh" "Prometheus监控指标验证脚本" 10
check_doc "quick-verify-prometheus-monitoring.sh" "Prometheus监控快速验证脚本" 10
check_doc "QUICK-VALIDATION-TOOLS-GUIDE.md" "快速验证工具指南" 20
check_doc "../scripts/quick-verify-install-cn.sh" "安装脚本快速验证工具" 10
check_doc "../docs/install-cn-quick-verify.md" "安装脚本快速验证文档" 20
check_doc "../docs/install-cn-quick-test-example.md" "安装脚本快速测试示例文档" 30
check_doc "../docs/quick-validation-examples.md" "快速验证示例文档" 20

echo ""
echo -e "${BLUE}🔗 文档互引用检查${NC}"
echo "----------------------------------------"

# 检查文档间的相互引用
echo "检查文档引用关系..."

ref_errors=0

check_ref() {
    local source="$1"
    local target="$2"
    local desc="$3"
    
    if [ -f "$source" ]; then
        if grep -q "$target" "$source"; then
            echo -e "${GREEN}✅ $source 引用了 $target ($desc)${NC}"
        else
            echo -e "${YELLOW}⚠️  $source 未引用 $target ($desc)${NC}"
            ref_errors=$((ref_errors + 1))
        fi
    else
        echo -e "${RED}❌ $source 不存在，无法检查引用${NC}"
        ref_errors=$((ref_errors + 1))
    fi
}

check_ref "VALIDATION-QUICK-INDEX.md" "VALIDATION-DECISION-TREE.md" "决策树文档"
check_ref "VALIDATION-QUICK-INDEX.md" "VALIDATION-EXAMPLES.md" "使用示例文档"
check_ref "VALIDATION-DECISION-TREE.md" "VALIDATION-QUICK-INDEX.md" "快速索引文档"
check_ref "VALIDATION-EXAMPLES.md" "VALIDATION-DECISION-TREE.md" "决策树文档"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-script-verification-guide.md" "安装脚本验证指南"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-quick-test-examples.md" "安装脚本快速测试示例"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-complete-verification-guide.md" "安装脚本完整功能验证指南"
check_ref "VALIDATION-QUICK-INDEX.md" "validation-toolchain-overview.md" "验证工具链概览文档"
check_ref "VALIDATION-QUICK-INDEX.md" "quick-verify-install-cn.sh" "安装脚本快速验证工具"
check_ref "VALIDATION-QUICK-INDEX.md" "quick-verify-install-cn-enhanced.sh" "安装脚本增强版快速验证工具"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-install-cn-complete.sh" "安装脚本完整功能验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-fallback-recovery.sh" "安装失败恢复脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-fallback-recovery-guide.md" "安装失败恢复指南"
check_ref "VALIDATION-QUICK-INDEX.md" "install-cn-self-check.sh" "安装自检脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "quick-verify-cdn-fallback.sh" "CDN回退策略验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-sqlite-persistence.sh" "SQLite持久化验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "init-sqlite-db.sh" "SQLite数据库初始化脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-sqlite-init.sh" "SQLite初始化验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-sqlite-integrity.sh" "SQLite数据库完整性验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-env-vars.sh" "环境变量验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-prometheus-metrics.sh" "Prometheus监控指标验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "quick-verify-prometheus-monitoring.sh" "Prometheus监控快速验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-web-deployment-ready.sh" "Web站点部署就绪验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "ops-web-deploy.md" "Web站点部署指南"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-admin-api-complete.sh" "Admin API完整功能验证脚本"
check_ref "VALIDATION-QUICK-INDEX.md" "ADMIN-API-TEST-ENV-SETUP.md" "Admin API测试环境配置指南"
check_ref "VALIDATION-QUICK-INDEX.md" "cleanup-validation-backups.sh" "验证脚本备份清理工具"
check_ref "VALIDATION-QUICK-INDEX.md" "verify-env-vars.sh" "环境变量验证脚本"
check_ref "../docs/install-cn-script-verification-guide.md" "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引"
check_ref "../docs/install-cn-quick-test-examples.md" "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引"
check_ref "../docs/install-cn-complete-verification-guide.md" "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引"
check_ref "../docs/validation-toolchain-overview.md" "VALIDATION-QUICK-INDEX.md" "验证脚本快速索引"

echo ""
echo -e "${BLUE}📚 README.md 集成检查${NC}"
echo "----------------------------------------"

# 检查README.md是否包含验证工具链引用
if [ -f "README.md" ]; then
    echo "检查README.md中的验证工具链集成..."
    
    readme_checks=0
    readme_passed=0
    
    # 检查验证工具链章节
    if grep -q "验证工具链" README.md; then
        echo -e "${GREEN}✅ README.md 包含'验证工具链'章节${NC}"
        readme_passed=$((readme_passed + 1))
    else
        echo -e "${YELLOW}⚠️  README.md 缺少'验证工具链'章节${NC}"
    fi
    readme_checks=$((readme_checks + 1))
    
    # 检查验证脚本快速索引引用
    if grep -q "VALIDATION-QUICK-INDEX.md" README.md; then
        echo -e "${GREEN}✅ README.md 引用了 VALIDATION-QUICK-INDEX.md${NC}"
        readme_passed=$((readme_passed + 1))
    else
        echo -e "${YELLOW}⚠️  README.md 未引用 VALIDATION-QUICK-INDEX.md${NC}"
    fi
    readme_checks=$((readme_checks + 1))
    
    # 检查验证脚本选择决策树引用
    if grep -q "VALIDATION-DECISION-TREE.md" README.md; then
        echo -e "${GREEN}✅ README.md 引用了 VALIDATION-DECISION-TREE.md${NC}"
        readme_passed=$((readme_passed + 1))
    else
        echo -e "${YELLOW}⚠️  README.md 未引用 VALIDATION-DECISION-TREE.md${NC}"
    fi
    readme_checks=$((readme_checks + 1))
    
    echo "README.md 集成检查: ${readme_passed}/${readme_checks} 项通过"
else
    echo -e "${RED}❌ README.md 不存在${NC}"
    ref_errors=$((ref_errors + 1))
fi

echo ""
echo -e "${BLUE}📊 文档统计与完整性评估${NC}"
echo "----------------------------------------"

# 文档统计
total_docs=0
valid_docs=0
total_lines=0

docs_to_check=(
    "VALIDATION-QUICK-INDEX.md:20"
    "VALIDATION-DECISION-TREE.md:30"
    "VALIDATION-TOOLS-INDEX.md:40"
    "VALIDATION-EXAMPLES.md:50"
    "QUICK-VERIFICATION-COMMANDS.md:30"
    "TROUBLESHOOTING.md:30"
    "ENHANCED-VALIDATION-DOCS-CHECK.md:20"
    "CONFIG-VERIFICATION-GUIDE.md:20"
    "TODO-TICKETS.md:20"
    "ADMIN-API-GUIDE.md:30"
    "../docs/install-cn-script-verification-guide.md:20"
    "../docs/ops-web-deploy.md:20"
    "../docs/quick-validation-examples.md:20"
)

for doc_spec in "${docs_to_check[@]}"; do
    doc=$(echo "$doc_spec" | cut -d: -f1)
    min_lines=$(echo "$doc_spec" | cut -d: -f2)
    
    if [ -f "$doc" ]; then
        total_docs=$((total_docs + 1))
        lines=$(wc -l < "$doc" 2>/dev/null || echo "0")
        total_lines=$((total_lines + lines))
        
        if [ "$lines" -gt "$min_lines" ]; then
            valid_docs=$((valid_docs + 1))
        fi
    fi
done

echo "核心验证文档数量: ${total_docs}/9"
echo "有效文档数量: ${valid_docs}/${total_docs}"
echo "总行数: ${total_lines} 行"
echo "平均行数: $((total_lines / (total_docs > 0 ? total_docs : 1))) 行/文档"

echo ""
echo -e "${BLUE}📈 完整性评分${NC}"
echo "----------------------------------------"

# 计算完整性评分
doc_score=$((valid_docs * 25))  # 每个有效文档25分
readme_score=0
if [ -f "README.md" ]; then
    if grep -q "验证工具链" README.md; then
        readme_score=$((readme_score + 20))
    fi
    if grep -q "VALIDATION-QUICK-INDEX.md" README.md; then
        readme_score=$((readme_score + 15))
    fi
    if grep -q "VALIDATION-DECISION-TREE.md" README.md; then
        readme_score=$((readme_score + 15))
    fi
fi

ref_score=$(( (4 - ref_errors) * 10 ))  # 每个引用正确10分

total_score=$((doc_score + readme_score + ref_score))
max_score=100

echo "文档完整性得分: ${doc_score}/100"
echo "README集成得分: ${readme_score}/50"
echo "引用关系得分: ${ref_score}/40"
echo "------------------------"
echo -e "${BLUE}总分: ${total_score}/${max_score}${NC}"

echo ""
echo -e "${BLUE}🎯 检查结果${NC}"
echo "========================================"

if [ "$total_score" -ge 80 ] && [ "$valid_docs" -eq "$total_docs" ] && [ "$total_docs" -ge 3 ]; then
    echo -e "${GREEN}📚 验证文档完整性检查通过！${NC}"
    echo -e "${GREEN}文档体系完整，集成良好。${NC}"
    exit 0
elif [ "$total_score" -ge 60 ]; then
    echo -e "${YELLOW}⚠️  验证文档完整性检查基本通过，但有改进空间${NC}"
    echo -e "${YELLOW}建议完善文档引用关系和README集成。${NC}"
    exit 0
else
    echo -e "${RED}❌ 验证文档完整性检查未通过${NC}"
    echo -e "${RED}需要完善核心文档内容和文档体系集成。${NC}"
    exit 1
fi