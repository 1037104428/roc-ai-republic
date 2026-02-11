#!/bin/bash
# SQLite数据库完整性验证脚本
# 验证quota-proxy数据库文件的完整性和一致性

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SQLite数据库完整性验证 ===${NC}"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 数据库文件列表
DB_FILES=(
    "quota-proxy.db"
    "data/quota-proxy.db"
    "quota.db"
)

# 检查SQLite3是否可用
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}错误: sqlite3命令未找到${NC}"
    echo "请安装SQLite3: sudo apt-get install sqlite3 或 sudo yum install sqlite"
    exit 1
fi

# 验证函数
verify_database() {
    local db_file="$1"
    local db_path="$2"
    
    echo -e "${YELLOW}验证数据库: $db_file${NC}"
    
    if [ ! -f "$db_path" ]; then
        echo -e "  ${RED}✗ 数据库文件不存在: $db_path${NC}"
        return 1
    fi
    
    # 检查文件大小
    local file_size=$(stat -c%s "$db_path" 2>/dev/null || stat -f%z "$db_path" 2>/dev/null)
    echo -e "  ${GREEN}✓ 文件大小: ${file_size} 字节${NC}"
    
    # 检查文件权限
    local file_perm=$(stat -c%a "$db_path" 2>/dev/null || stat -f%p "$db_path" 2>/dev/null | tail -c 4)
    echo -e "  ${GREEN}✓ 文件权限: $file_perm${NC}"
    
    # 检查SQLite文件头
    local header=$(head -c 16 "$db_path" | xxd -p)
    if [[ "$header" == "53514c69746520666f726d6174203300"* ]]; then
        echo -e "  ${GREEN}✓ SQLite文件头有效${NC}"
    else
        echo -e "  ${RED}✗ SQLite文件头无效${NC}"
        return 1
    fi
    
    # 检查数据库完整性
    if sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        echo -e "  ${GREEN}✓ 数据库完整性检查通过${NC}"
    else
        echo -e "  ${RED}✗ 数据库完整性检查失败${NC}"
        sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null
        return 1
    fi
    
    # 检查表结构
    local table_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
    echo -e "  ${GREEN}✓ 表数量: $table_count${NC}"
    
    # 列出所有表
    if [ "$table_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓ 表列表:${NC}"
        sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null | while read table; do
            echo -e "    - $table"
        done
    fi
    
    # 检查快速查询
    if [ "$table_count" -gt 0 ]; then
        local sample_table=$(sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" 2>/dev/null)
        if [ -n "$sample_table" ]; then
            local row_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM \"$sample_table\";" 2>/dev/null || echo "0")
            echo -e "  ${GREEN}✓ 示例表 '$sample_table' 行数: $row_count${NC}"
        fi
    fi
    
    return 0
}

# 主验证循环
success_count=0
total_count=0

for db_file in "${DB_FILES[@]}"; do
    db_path="quota-proxy/$db_file"
    total_count=$((total_count + 1))
    
    if verify_database "$db_file" "$db_path"; then
        success_count=$((success_count + 1))
    else
        echo ""
    fi
done

echo ""
echo -e "${BLUE}=== 验证结果汇总 ===${NC}"
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "总数据库文件: $total_count"
echo "验证成功: $success_count"
echo "验证失败: $((total_count - success_count))"

if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}✅ 所有数据库文件验证通过${NC}"
    echo ""
    echo -e "${GREEN}下一步建议:${NC}"
    echo "1. 定期运行此脚本检查数据库健康状态"
    echo "2. 使用 auto-backup-database.sh 进行定期备份"
    echo "3. 使用 check-database-health.sh 进行更详细的健康检查"
    exit 0
else
    echo -e "${RED}❌ 部分数据库文件验证失败${NC}"
    echo ""
    echo -e "${YELLOW}修复建议:${NC}"
    echo "1. 检查数据库文件路径和权限"
    echo "2. 运行 sqlite3 命令手动检查问题数据库"
    echo "3. 从备份恢复损坏的数据库"
    echo "4. 重新初始化数据库"
    exit 1
fi