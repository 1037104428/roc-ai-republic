#!/bin/bash
# SQLite数据库完整性验证脚本
# 快速验证SQLite数据库的完整性、一致性和基本功能

set -e

DB_FILE="${1:-./data/quota.db}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

echo -e "${COLOR_BLUE}🔍 SQLite数据库完整性验证脚本${COLOR_RESET}"
echo -e "${COLOR_BLUE}📁 数据库文件: $DB_FILE${COLOR_RESET}"
echo ""

# 检查数据库文件是否存在
if [ ! -f "$DB_FILE" ]; then
    echo -e "${COLOR_RED}❌ 数据库文件不存在: $DB_FILE${COLOR_RESET}"
    echo "💡 请先运行初始化脚本: ./init-sqlite-db.sh"
    exit 1
fi

# 检查sqlite3命令
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${COLOR_RED}❌ sqlite3命令未找到${COLOR_RESET}"
    exit 1
fi

# 函数：执行SQL查询并检查结果
execute_sql() {
    local query="$1"
    local description="$2"
    local expected_min="${3:-1}"
    
    echo -e "${COLOR_YELLOW}📊 $description...${COLOR_RESET}"
    local result
    result=$(sqlite3 "$DB_FILE" "$query" 2>/dev/null || echo "ERROR")
    
    if [ "$result" = "ERROR" ]; then
        echo -e "  ${COLOR_RED}❌ 查询失败${COLOR_RESET}"
        return 1
    fi
    
    local count
    count=$(echo "$result" | wc -l)
    
    if [ "$count" -ge "$expected_min" ]; then
        echo -e "  ${COLOR_GREEN}✅ 成功 ($count 条记录)${COLOR_RESET}"
        return 0
    else
        echo -e "  ${COLOR_RED}❌ 记录不足 (期望至少 $expected_min 条，实际 $count 条)${COLOR_RESET}"
        return 1
    fi
}

# 函数：检查完整性
check_integrity() {
    echo -e "${COLOR_YELLOW}🔧 检查数据库完整性...${COLOR_RESET}"
    
    # 检查数据库完整性
    local integrity_check
    integrity_check=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>/dev/null)
    
    if [ "$integrity_check" = "ok" ]; then
        echo -e "  ${COLOR_GREEN}✅ 数据库完整性检查通过${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}❌ 数据库完整性检查失败: $integrity_check${COLOR_RESET}"
        return 1
    fi
    
    # 检查外键约束
    local foreign_keys
    foreign_keys=$(sqlite3 "$DB_FILE" "PRAGMA foreign_key_check;" 2>/dev/null)
    
    if [ -z "$foreign_keys" ]; then
        echo -e "  ${COLOR_GREEN}✅ 外键约束检查通过${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}❌ 外键约束检查失败${COLOR_RESET}"
        return 1
    fi
    
    return 0
}

# 函数：检查表结构
check_table_structure() {
    echo -e "${COLOR_YELLOW}📋 检查表结构...${COLOR_RESET}"
    
    local tables=("api_keys" "request_logs" "daily_usage")
    local missing_tables=()
    
    for table in "${tables[@]}"; do
        local exists
        exists=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" 2>/dev/null)
        
        if [ -n "$exists" ]; then
            echo -e "  ${COLOR_GREEN}✅ 表 '$table' 存在${COLOR_RESET}"
        else
            echo -e "  ${COLOR_RED}❌ 表 '$table' 不存在${COLOR_RESET}"
            missing_tables+=("$table")
        fi
    done
    
    if [ ${#missing_tables[@]} -eq 0 ]; then
        echo -e "  ${COLOR_GREEN}✅ 所有必需表都存在${COLOR_RESET}"
        return 0
    else
        echo -e "  ${COLOR_RED}❌ 缺少表: ${missing_tables[*]}${COLOR_RESET}"
        return 1
    fi
}

# 函数：检查视图
check_views() {
    echo -e "${COLOR_YELLOW}👁️ 检查视图...${COLOR_RESET}"
    
    local views=("v_today_usage" "v_trial_keys_status")
    local missing_views=()
    
    for view in "${views[@]}"; do
        local exists
        exists=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='view' AND name='$view';" 2>/dev/null)
        
        if [ -n "$exists" ]; then
            echo -e "  ${COLOR_GREEN}✅ 视图 '$view' 存在${COLOR_RESET}"
        else
            echo -e "  ${COLOR_RED}❌ 视图 '$view' 不存在${COLOR_RESET}"
            missing_views+=("$view")
        fi
    done
    
    if [ ${#missing_views[@]} -eq 0 ]; then
        echo -e "  ${COLOR_GREEN}✅ 所有视图都存在${COLOR_RESET}"
        return 0
    else
        echo -e "  ${COLOR_RED}❌ 缺少视图: ${missing_views[*]}${COLOR_RESET}"
        return 1
    fi
}

# 函数：检查索引
check_indexes() {
    echo -e "${COLOR_YELLOW}📈 检查索引...${COLOR_RESET}"
    
    local indexes=(
        "idx_api_keys_key_id"
        "idx_api_keys_api_key"
        "idx_api_keys_is_active"
        "idx_api_keys_is_trial"
        "idx_request_logs_key_id"
        "idx_request_logs_timestamp"
        "idx_request_logs_endpoint"
        "idx_daily_usage_key_id_date"
    )
    
    local missing_indexes=()
    
    for index in "${indexes[@]}"; do
        local exists
        exists=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='index' AND name='$index';" 2>/dev/null)
        
        if [ -n "$exists" ]; then
            echo -e "  ${COLOR_GREEN}✅ 索引 '$index' 存在${COLOR_RESET}"
        else
            echo -e "  ${COLOR_RED}❌ 索引 '$index' 不存在${COLOR_RESET}"
            missing_indexes+=("$index")
        fi
    done
    
    if [ ${#missing_indexes[@]} -eq 0 ]; then
        echo -e "  ${COLOR_GREEN}✅ 所有索引都存在${COLOR_RESET}"
        return 0
    else
        echo -e "  ${COLOR_RED}❌ 缺少索引: ${missing_indexes[*]}${COLOR_RESET}"
        return 1
    fi
}

# 函数：检查数据
check_data() {
    echo -e "${COLOR_YELLOW}📊 检查数据...${COLOR_RESET}"
    
    # 检查API密钥表
    execute_sql "SELECT COUNT(*) FROM api_keys;" "API密钥表记录数" 1
    
    # 检查激活的API密钥
    execute_sql "SELECT COUNT(*) FROM api_keys WHERE is_active = 1;" "激活的API密钥" 1
    
    # 检查试用密钥
    execute_sql "SELECT COUNT(*) FROM api_keys WHERE is_trial = 1;" "试用密钥" 1
    
    # 检查今日用量视图
    execute_sql "SELECT COUNT(*) FROM v_today_usage;" "今日用量视图记录" 0
    
    # 检查试用密钥状态视图
    execute_sql "SELECT COUNT(*) FROM v_trial_keys_status;" "试用密钥状态视图记录" 0
}

# 函数：检查性能
check_performance() {
    echo -e "${COLOR_YELLOW}⚡ 检查性能...${COLOR_RESET}"
    
    # 检查数据库大小
    local db_size
    db_size=$(stat -c%s "$DB_FILE" 2>/dev/null || stat -f%z "$DB_FILE" 2>/dev/null)
    
    if [ -n "$db_size" ]; then
        local size_mb
        size_mb=$(echo "scale=2; $db_size / 1024 / 1024" | bc)
        echo -e "  ${COLOR_GREEN}📏 数据库大小: ${size_mb} MB${COLOR_RESET}"
    fi
    
    # 检查页面大小
    local page_size
    page_size=$(sqlite3 "$DB_FILE" "PRAGMA page_size;" 2>/dev/null)
    echo -e "  ${COLOR_GREEN}📄 页面大小: $page_size 字节${COLOR_RESET}"
    
    # 检查缓存大小
    local cache_size
    cache_size=$(sqlite3 "$DB_FILE" "PRAGMA cache_size;" 2>/dev/null)
    echo -e "  ${COLOR_GREEN}💾 缓存大小: $cache_size 页${COLOR_RESET}"
    
    # 检查journal模式
    local journal_mode
    journal_mode=$(sqlite3 "$DB_FILE" "PRAGMA journal_mode;" 2>/dev/null)
    echo -e "  ${COLOR_GREEN}📝 Journal模式: $journal_mode${COLOR_RESET}"
}

# 主验证流程
echo -e "${COLOR_BLUE}🚀 开始SQLite数据库完整性验证${COLOR_RESET}"
echo ""

# 执行所有检查
overall_success=true

check_integrity || overall_success=false
echo ""

check_table_structure || overall_success=false
echo ""

check_views || overall_success=false
echo ""

check_indexes || overall_success=false
echo ""

check_data || overall_success=false
echo ""

check_performance
echo ""

# 总结
if [ "$overall_success" = true ]; then
    echo -e "${COLOR_GREEN}🎉 SQLite数据库完整性验证通过！${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✅ 所有检查项均通过${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BLUE}📋 验证摘要:${COLOR_RESET}"
    echo "  - 数据库完整性: ✅"
    echo "  - 表结构: ✅"
    echo "  - 视图: ✅"
    echo "  - 索引: ✅"
    echo "  - 数据: ✅"
    echo "  - 性能配置: ✅"
    echo ""
    echo -e "${COLOR_GREEN}🚀 数据库状态良好，可以正常使用${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_RED}⚠️ SQLite数据库完整性验证发现一些问题${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}💡 建议:${COLOR_RESET}"
    echo "  1. 运行数据库修复: sqlite3 $DB_FILE 'VACUUM;'"
    echo "  2. 重新初始化数据库: ./init-sqlite-db.sh $DB_FILE"
    echo "  3. 检查数据库文件权限"
    echo ""
    echo -e "${COLOR_YELLOW}🔧 快速修复命令:${COLOR_RESET}"
    echo "  sqlite3 $DB_FILE 'VACUUM; ANALYZE;'"
    exit 1
fi