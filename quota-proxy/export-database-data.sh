#!/bin/bash
# 数据库数据导出脚本
# 将 quota-proxy 的 SQLite 数据库导出为 JSON 或 CSV 格式
# 用法: ./export-database-data.sh [--format json|csv] [--output FILE]

set -e

# 默认值
DB_FILE="${DB_FILE:-./data/quota.db}"
FORMAT="json"
OUTPUT_FILE=""
VERBOSE=0

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
数据库数据导出脚本 - 将 quota-proxy 的 SQLite 数据库导出为 JSON 或 CSV 格式

用法: $0 [选项]

选项:
  --format FORMAT     导出格式: json 或 csv (默认: json)
  --output FILE       输出文件路径 (默认: 标准输出)
  --db FILE           数据库文件路径 (默认: ./data/quota.db)
  --verbose           显示详细输出
  --help              显示此帮助信息

示例:
  $0 --format json --output keys.json
  $0 --format csv --output usage.csv
  DB_FILE=/path/to/db.db $0 --format json

环境变量:
  DB_FILE             数据库文件路径 (默认: ./data/quota.db)

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --db)
            DB_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=1
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

# 验证参数
if [[ ! "$FORMAT" =~ ^(json|csv)$ ]]; then
    echo -e "${RED}错误: 格式必须是 'json' 或 'csv'${NC}"
    exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
    echo -e "${RED}错误: 数据库文件不存在: $DB_FILE${NC}"
    echo -e "${YELLOW}提示: 请确保数据库文件存在，或使用 --db 参数指定路径${NC}"
    exit 1
fi

# 显示信息
echo -e "${BLUE}数据库数据导出脚本${NC}"
echo -e "数据库文件: ${GREEN}$DB_FILE${NC}"
echo -e "导出格式: ${GREEN}$FORMAT${NC}"
if [[ -n "$OUTPUT_FILE" ]]; then
    echo -e "输出文件: ${GREEN}$OUTPUT_FILE${NC}"
else
    echo -e "输出: ${GREEN}标准输出${NC}"
fi
echo

# 检查 sqlite3 命令
if ! command -v sqlite3 &> /dev/null; then
    echo -e "${RED}错误: 需要 sqlite3 命令，但未找到${NC}"
    echo -e "${YELLOW}请安装: sudo apt-get install sqlite3 或 sudo yum install sqlite${NC}"
    exit 1
fi

# 导出函数
export_json() {
    local table="$1"
    echo -e "${BLUE}导出表: $table${NC}"
    
    # 获取表结构
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${YELLOW}表结构:${NC}"
        sqlite3 "$DB_FILE" ".schema $table" 2>/dev/null || echo "无法获取表结构"
    fi
    
    # 导出数据为 JSON
    sqlite3 "$DB_FILE" << EOF
.mode json
SELECT * FROM $table;
EOF
}

export_csv() {
    local table="$1"
    echo -e "${BLUE}导出表: $table${NC}"
    
    # 获取表结构
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${YELLOW}表结构:${NC}"
        sqlite3 "$DB_FILE" ".schema $table" 2>/dev/null || echo "无法获取表结构"
    fi
    
    # 导出数据为 CSV
    sqlite3 "$DB_FILE" << EOF
.headers on
.mode csv
SELECT * FROM $table;
EOF
}

# 获取所有表
TABLES=$(sqlite3 "$DB_FILE" ".tables" 2>/dev/null)

if [[ -z "$TABLES" ]]; then
    echo -e "${YELLOW}警告: 数据库中没有找到表${NC}"
    exit 0
fi

echo -e "${GREEN}找到表: $TABLES${NC}"
echo

# 创建输出
if [[ -n "$OUTPUT_FILE" ]]; then
    # 清空或创建输出文件
    > "$OUTPUT_FILE"
    
    # 根据格式导出
    if [[ "$FORMAT" == "json" ]]; then
        echo "{" >> "$OUTPUT_FILE"
        FIRST_TABLE=1
        for table in $TABLES; do
            if [[ $FIRST_TABLE -eq 0 ]]; then
                echo "," >> "$OUTPUT_FILE"
            fi
            echo -n "  \"$table\": " >> "$OUTPUT_FILE"
            sqlite3 "$DB_FILE" << EOF >> "$OUTPUT_FILE"
.mode json
SELECT * FROM $table;
EOF
            FIRST_TABLE=0
        done
        echo -e "\n}" >> "$OUTPUT_FILE"
    else # CSV格式
        for table in $TABLES; do
            echo "=== 表: $table ===" >> "$OUTPUT_FILE"
            sqlite3 "$DB_FILE" << EOF >> "$OUTPUT_FILE"
.headers on
.mode csv
SELECT * FROM $table;
EOF
            echo "" >> "$OUTPUT_FILE"
        done
    fi
    
    echo -e "${GREEN}✓ 数据已导出到: $OUTPUT_FILE${NC}"
    
    # 显示文件信息
    if [[ -f "$OUTPUT_FILE" ]]; then
        FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
        if [[ $FILE_SIZE -gt 1048576 ]]; then
            SIZE_MB=$(echo "scale=2; $FILE_SIZE / 1048576" | bc)
            echo -e "${YELLOW}文件大小: ${SIZE_MB} MB${NC}"
        elif [[ $FILE_SIZE -gt 1024 ]]; then
            SIZE_KB=$(echo "scale=2; $FILE_SIZE / 1024" | bc)
            echo -e "${YELLOW}文件大小: ${SIZE_KB} KB${NC}"
        else
            echo -e "${YELLOW}文件大小: ${FILE_SIZE} 字节${NC}"
        fi
    fi
else
    # 输出到标准输出
    if [[ "$FORMAT" == "json" ]]; then
        echo "{"
        FIRST_TABLE=1
        for table in $TABLES; do
            if [[ $FIRST_TABLE -eq 0 ]]; then
                echo ","
            fi
            echo -n "  \"$table\": "
            sqlite3 "$DB_FILE" << EOF
.mode json
SELECT * FROM $table;
EOF
            FIRST_TABLE=0
        done
        echo -e "\n}"
    else # CSV格式
        for table in $TABLES; do
            echo "=== 表: $table ==="
            sqlite3 "$DB_FILE" << EOF
.headers on
.mode csv
SELECT * FROM $table;
EOF
            echo ""
        done
    fi
fi

echo -e "${GREEN}✓ 数据导出完成${NC}"