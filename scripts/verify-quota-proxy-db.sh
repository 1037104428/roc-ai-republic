#!/bin/bash
# quota-proxy 数据库验证脚本
# 用于检查SQLite数据库的健康状态和可用性

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
SERVER_HOST="8.210.185.194"
VERBOSE=false
DRY_RUN=false

# 帮助信息
show_help() {
    cat << EOF
quota-proxy 数据库验证脚本

用法: $0 [选项]

选项:
  --db-path PATH     数据库文件路径 (默认: $DB_PATH)
  --server HOST      服务器地址 (默认: $SERVER_HOST)
  --dry-run          只显示检查命令，不实际执行
  --verbose          显示详细输出
  --help             显示此帮助信息

示例:
  $0 --dry-run
  $0 --verbose
  $0 --db-path /custom/path/quota.db

功能:
  1. 检查数据库文件是否存在
  2. 检查数据库文件权限
  3. 验证数据库完整性
  4. 检查表结构
  5. 检查API密钥表数据
  6. 检查使用统计表数据
  7. 测试数据库连接
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        --server)
            SERVER_HOST="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 打印标题
echo -e "${BLUE}=== quota-proxy 数据库验证检查 ===${NC}"
echo "数据库路径: $DB_PATH"
echo "服务器地址: $SERVER_HOST"
echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 检查数据库文件是否存在
check_db_file_exists() {
    echo -e "${BLUE}[1/7] 检查数据库文件是否存在${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"ls -la $DB_PATH\""
        return 0
    fi
    
    if ssh root@$SERVER_HOST "ls -la $DB_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓ 数据库文件存在${NC}"
        return 0
    else
        echo -e "${RED}✗ 数据库文件不存在: $DB_PATH${NC}"
        return 1
    fi
}

# 检查数据库文件权限
check_db_file_permissions() {
    echo -e "${BLUE}[2/7] 检查数据库文件权限${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"stat -c '%A %U %G %s' $DB_PATH\""
        return 0
    fi
    
    local perms=$(ssh root@$SERVER_HOST "stat -c '%A %U %G %s' $DB_PATH 2>/dev/null" || echo "")
    if [ -n "$perms" ]; then
        echo -e "${GREEN}✓ 文件权限: $perms${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 无法获取文件权限${NC}"
        return 0
    fi
}

# 验证数据库完整性
check_db_integrity() {
    echo -e "${BLUE}[3/7] 验证数据库完整性${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH 'PRAGMA integrity_check;'\""
        return 0
    fi
    
    local result=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH 'PRAGMA integrity_check;' 2>/dev/null" || echo "error")
    if [[ "$result" == "ok" ]]; then
        echo -e "${GREEN}✓ 数据库完整性检查通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 数据库完整性检查失败: $result${NC}"
        return 1
    fi
}

# 检查表结构
check_table_structure() {
    echo -e "${BLUE}[4/7] 检查表结构${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH '.schema api_keys'\""
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH '.schema usage_stats'\""
        return 0
    fi
    
    local api_keys_schema=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH '.schema api_keys' 2>/dev/null" || echo "")
    local usage_stats_schema=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH '.schema usage_stats' 2>/dev/null" || echo "")
    
    if [ -n "$api_keys_schema" ]; then
        echo -e "${GREEN}✓ api_keys 表结构正常${NC}"
        if $VERBOSE; then
            echo "$api_keys_schema"
        fi
    else
        echo -e "${RED}✗ api_keys 表不存在或无法访问${NC}"
    fi
    
    if [ -n "$usage_stats_schema" ]; then
        echo -e "${GREEN}✓ usage_stats 表结构正常${NC}"
        if $VERBOSE; then
            echo "$usage_stats_schema"
        fi
    else
        echo -e "${RED}✗ usage_stats 表不存在或无法访问${NC}"
    fi
    
    return 0
}

# 检查API密钥表数据
check_api_keys_data() {
    echo -e "${BLUE}[5/7] 检查API密钥表数据${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH 'SELECT COUNT(*) FROM api_keys;'\""
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH 'SELECT key, enabled, created_at FROM api_keys LIMIT 3;'\""
        return 0
    fi
    
    local count=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH 'SELECT COUNT(*) FROM api_keys;' 2>/dev/null" || echo "0")
    echo -e "${GREEN}✓ API密钥数量: $count${NC}"
    
    if $VERBOSE && [ "$count" -gt 0 ]; then
        local sample=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH 'SELECT key, enabled, created_at FROM api_keys LIMIT 3;' 2>/dev/null" || echo "")
        if [ -n "$sample" ]; then
            echo "示例数据:"
            echo "$sample" | while read line; do
                echo "  $line"
            done
        fi
    fi
    
    return 0
}

# 检查使用统计表数据
check_usage_stats_data() {
    echo -e "${BLUE}[6/7] 检查使用统计表数据${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH 'SELECT COUNT(*) FROM usage_stats;'\""
        echo "执行命令: ssh root@$SERVER_HOST \"sqlite3 $DB_PATH 'SELECT api_key, endpoint, COUNT(*) as calls FROM usage_stats GROUP BY api_key, endpoint ORDER BY calls DESC LIMIT 3;'\""
        return 0
    fi
    
    local count=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH 'SELECT COUNT(*) FROM usage_stats;' 2>/dev/null" || echo "0")
    echo -e "${GREEN}✓ 使用统计记录数: $count${NC}"
    
    if $VERBOSE && [ "$count" -gt 0 ]; then
        local stats=$(ssh root@$SERVER_HOST "sqlite3 $DB_PATH 'SELECT api_key, endpoint, COUNT(*) as calls FROM usage_stats GROUP BY api_key, endpoint ORDER BY calls DESC LIMIT 3;' 2>/dev/null" || echo "")
        if [ -n "$stats" ]; then
            echo "使用统计示例:"
            echo "$stats" | while read line; do
                echo "  $line"
            done
        fi
    fi
    
    return 0
}

# 测试数据库连接
test_db_connection() {
    echo -e "${BLUE}[7/7] 测试数据库连接${NC}"
    
    if $DRY_RUN; then
        echo "执行命令: ssh root@$SERVER_HOST \"timeout 5 sqlite3 $DB_PATH 'SELECT 1;'\""
        return 0
    fi
    
    if ssh root@$SERVER_HOST "timeout 5 sqlite3 $DB_PATH 'SELECT 1;' 2>/dev/null"; then
        echo -e "${GREEN}✓ 数据库连接测试通过${NC}"
        return 0
    else
        echo -e "${RED}✗ 数据库连接测试失败${NC}"
        return 1
    fi
}

# 执行所有检查
main() {
    local failed_checks=0
    
    check_db_file_exists || ((failed_checks++))
    echo ""
    
    check_db_file_permissions || ((failed_checks++))
    echo ""
    
    check_db_integrity || ((failed_checks++))
    echo ""
    
    check_table_structure || ((failed_checks++))
    echo ""
    
    check_api_keys_data || ((failed_checks++))
    echo ""
    
    check_usage_stats_data || ((failed_checks++))
    echo ""
    
    test_db_connection || ((failed_checks++))
    echo ""
    
    # 总结报告
    echo -e "${BLUE}=== 检查完成 ===${NC}"
    echo "总检查项: 7"
    echo "失败项: $failed_checks"
    
    if [ $failed_checks -eq 0 ]; then
        echo -e "${GREEN}✅ 所有检查通过 - 数据库状态健康${NC}"
        return 0
    elif [ $failed_checks -le 2 ]; then
        echo -e "${YELLOW}⚠ 部分检查失败 - 数据库需要关注${NC}"
        return 1
    else
        echo -e "${RED}❌ 多个检查失败 - 数据库可能存在严重问题${NC}"
        return 2
    fi
}

# 运行主函数
main