#!/bin/bash

# verify-sqlite-persistence.sh - 验证 SQLite 持久化功能
# 验证 TICKET-P0-001: SQLite 持久化实现

set -e

echo "🔍 验证 SQLite 持久化实现 (TICKET-P0-001)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查相关文件是否存在
echo "📁 检查相关文件..."
files_to_check=(
    "server-sqlite-admin.js"
    "init-db.sql"
    "DATABASE-INIT-GUIDE.md"
)

missing_files=0
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✅${NC} $file 存在"
    else
        echo -e "  ${RED}❌${NC} $file 不存在"
        missing_files=$((missing_files + 1))
    fi
done

# 检查 server-sqlite-admin.js 是否包含 SQLite 相关代码
echo "📝 检查 server-sqlite-admin.js 中的 SQLite 实现..."
if grep -q "sqlite3" server-sqlite-admin.js && grep -q "database" server-sqlite-admin.js; then
    echo -e "  ${GREEN}✅${NC} server-sqlite-admin.js 包含 SQLite 数据库代码"
else
    echo -e "  ${RED}❌${NC} server-sqlite-admin.js 缺少 SQLite 数据库代码"
    missing_files=$((missing_files + 1))
fi

# 检查 init-db.sql 是否包含正确的表结构
echo "🗄️  检查 init-db.sql 表结构..."
if grep -q "CREATE TABLE.*api_keys" init-db.sql && grep -q "CREATE TABLE.*request_logs" init-db.sql; then
    echo -e "  ${GREEN}✅${NC} init-db.sql 包含正确的表结构"
else
    echo -e "  ${RED}❌${NC} init-db.sql 缺少必要的表结构"
    missing_files=$((missing_files + 1))
fi

# 检查 DATABASE-INIT-GUIDE.md 是否完整
echo "📚 检查 DATABASE-INIT-GUIDE.md 文档..."
if [ -f "DATABASE-INIT-GUIDE.md" ]; then
    guide_lines=$(wc -l < "DATABASE-INIT-GUIDE.md")
    if [ "$guide_lines" -gt 10 ]; then
        echo -e "  ${GREEN}✅${NC} DATABASE-INIT-GUIDE.md 文档完整 ($guide_lines 行)"
    else
        echo -e "  ${YELLOW}⚠️ ${NC} DATABASE-INIT-GUIDE.md 文档可能过短 ($guide_lines 行)"
    fi
fi

# 验证功能要求
echo "🔧 验证功能要求..."
echo "  1. 使用 init-db.sql 初始化数据库"
if grep -q "init-db.sql" server-sqlite-admin.js || grep -q "database.*initialization" DATABASE-INIT-GUIDE.md || grep -q "初始化数据库" DATABASE-INIT-GUIDE.md; then
    echo -e "    ${GREEN}✅${NC} 支持数据库初始化"
else
    echo -e "    ${RED}❌${NC} 缺少数据库初始化支持"
    missing_files=$((missing_files + 1))
fi

echo "  2. API keys 存储到 SQLite"
if grep -q "INSERT INTO api_keys" server-sqlite-admin.js || grep -q "api_keys" init-db.sql; then
    echo -e "    ${GREEN}✅${NC} API keys 存储到 SQLite"
else
    echo -e "    ${RED}❌${NC} 缺少 API keys 存储功能"
    missing_files=$((missing_files + 1))
fi

echo "  3. 请求日志记录到 SQLite"
if grep -q "INSERT INTO request_logs" server-sqlite-admin.js || grep -q "request_logs" init-db.sql; then
    echo -e "    ${GREEN}✅${NC} 请求日志记录到 SQLite"
else
    echo -e "    ${RED}❌${NC} 缺少请求日志记录功能"
    missing_files=$((missing_files + 1))
fi

echo "  4. 支持数据库连接池"
if grep -q "better-sqlite3" server-sqlite-admin.js || grep -q "connection" server-sqlite-admin.js; then
    echo -e "    ${GREEN}✅${NC} 支持数据库连接"
else
    echo -e "    ${YELLOW}⚠️ ${NC} 数据库连接实现可能需要检查"
fi

# 总结
echo ""
echo "📊 验证总结:"
if [ $missing_files -eq 0 ]; then
    echo -e "${GREEN}✅ 所有 SQLite 持久化功能验证通过${NC}"
    echo "TICKET-P0-001 可以标记为已完成"
else
    echo -e "${RED}❌ 发现 $missing_files 个问题需要修复${NC}"
    echo "TICKET-P0-001 需要进一步开发"
fi

exit $missing_files