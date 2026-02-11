#!/bin/bash

# 数据库性能基准测试脚本
# 用于测试 quota-proxy 数据库的性能基准

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 默认配置
DB_PATH="./data/quota.db"
TEST_COUNT=100
THREAD_COUNT=4
OUTPUT_FILE="./db-benchmark-results.txt"

# 帮助信息
show_help() {
    cat << EOF
${BOLD}数据库性能基准测试脚本${NC}

${CYAN}用法:${NC}
  $(basename "$0") [选项]

${CYAN}选项:${NC}
  -d, --db-path PATH      数据库文件路径 (默认: ./data/quota.db)
  -c, --count NUM         测试次数 (默认: 100)
  -t, --threads NUM       线程数 (默认: 4)
  -o, --output FILE       输出文件 (默认: ./db-benchmark-results.txt)
  --dry-run               模拟运行，不实际执行测试
  -h, --help              显示此帮助信息

${CYAN}示例:${NC}
  $0 --dry-run                    # 模拟运行
  $0 -c 50 -t 2                   # 50次测试，2个线程
  $0 --db-path /tmp/test.db       # 指定数据库路径

${CYAN}功能:${NC}
  1. 数据库连接测试
  2. 查询性能测试
  3. 写入性能测试
  4. 并发性能测试
  5. 生成性能报告

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--db-path)
                DB_PATH="$2"
                shift 2
                ;;
            -c|--count)
                TEST_COUNT="$2"
                shift 2
                ;;
            -t|--threads)
                THREAD_COUNT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    if ! command -v sqlite3 &> /dev/null; then
        echo -e "${RED}错误: sqlite3 未安装${NC}"
        echo "请安装 sqlite3:"
        echo "  Ubuntu/Debian: sudo apt-get install sqlite3"
        echo "  CentOS/RHEL: sudo yum install sqlite"
        echo "  macOS: brew install sqlite"
        exit 1
    fi
}

# 检查数据库文件
check_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        echo -e "${YELLOW}警告: 数据库文件不存在: $DB_PATH${NC}"
        echo -e "${BLUE}创建测试数据库...${NC}"
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            echo -e "${GREEN}[模拟] 创建数据库: $DB_PATH${NC}"
            return 0
        fi
        
        # 创建数据库目录
        mkdir -p "$(dirname "$DB_PATH")"
        
        # 创建测试数据库
        sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    name TEXT,
    quota_daily INTEGER DEFAULT 100,
    quota_monthly INTEGER DEFAULT 3000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    request_count INTEGER DEFAULT 1,
    response_time_ms INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(id)
);

CREATE INDEX IF NOT EXISTS idx_usage_logs_api_key_id ON usage_logs(api_key_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_timestamp ON usage_logs(timestamp);
EOF
        
        echo -e "${GREEN}测试数据库已创建: $DB_PATH${NC}"
    else
        echo -e "${GREEN}数据库文件存在: $DB_PATH${NC}"
    fi
}

# 数据库连接测试
test_connection() {
    echo -e "${CYAN}=== 数据库连接测试 ===${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${GREEN}[模拟] 连接测试: sqlite3 \"$DB_PATH\" '.tables'${NC}"
        echo -e "${GREEN}[模拟] 连接测试通过${NC}"
        return 0
    fi
    
    if sqlite3 "$DB_PATH" ".tables" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 数据库连接成功${NC}"
        
        # 显示表信息
        echo -e "${BLUE}数据库表:${NC}"
        sqlite3 "$DB_PATH" ".tables"
        
        # 显示行数
        echo -e "${BLUE}数据统计:${NC}"
        sqlite3 "$DB_PATH" << 'EOF'
SELECT 'api_keys' as table_name, COUNT(*) as row_count FROM api_keys
UNION ALL
SELECT 'usage_logs' as table_name, COUNT(*) as row_count FROM usage_logs;
EOF
        
        return 0
    else
        echo -e "${RED}✗ 数据库连接失败${NC}"
        return 1
    fi
}

# 查询性能测试
test_query_performance() {
    echo -e "${CYAN}=== 查询性能测试 ===${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${GREEN}[模拟] 查询性能测试: $TEST_COUNT 次查询${NC}"
        echo -e "${GREEN}[模拟] 平均查询时间: 5ms${NC}"
        return 0
    fi
    
    local total_time=0
    
    for ((i=1; i<=TEST_COUNT; i++)); do
        local start_time=$(date +%s%N)
        
        # 执行简单查询
        sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM api_keys;" > /dev/null 2>&1
        
        local end_time=$(date +%s%N)
        local query_time=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
        
        total_time=$((total_time + query_time))
        
        if (( i % 10 == 0 )); then
            echo -e "${BLUE}已完成 $i/$TEST_COUNT 次查询${NC}"
        fi
    done
    
    local avg_time=$((total_time / TEST_COUNT))
    echo -e "${GREEN}✓ 查询性能测试完成${NC}"
    echo -e "${BLUE}  测试次数: $TEST_COUNT${NC}"
    echo -e "${BLUE}  总时间: ${total_time}ms${NC}"
    echo -e "${BLUE}  平均查询时间: ${avg_time}ms${NC}"
    
    # 返回平均时间
    echo "$avg_time"
}

# 写入性能测试
test_write_performance() {
    echo -e "${CYAN}=== 写入性能测试 ===${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${GREEN}[模拟] 写入性能测试: $TEST_COUNT 次写入${NC}"
        echo -e "${GREEN}[模拟] 平均写入时间: 15ms${NC}"
        return 0
    fi
    
    local total_time=0
    
    for ((i=1; i<=TEST_COUNT; i++)); do
        local start_time=$(date +%s%N)
        
        # 执行写入操作
        sqlite3 "$DB_PATH" << EOF
INSERT INTO api_keys (key, name, quota_daily, quota_monthly) 
VALUES ('test-key-$i', '测试密钥 $i', 100, 3000);
EOF
        
        local end_time=$(date +%s%N)
        local write_time=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
        
        total_time=$((total_time + write_time))
        
        if (( i % 10 == 0 )); then
            echo -e "${BLUE}已完成 $i/$TEST_COUNT 次写入${NC}"
        fi
    done
    
    local avg_time=$((total_time / TEST_COUNT))
    echo -e "${GREEN}✓ 写入性能测试完成${NC}"
    echo -e "${BLUE}  测试次数: $TEST_COUNT${NC}"
    echo -e "${BLUE}  总时间: ${total_time}ms${NC}"
    echo -e "${BLUE}  平均写入时间: ${avg_time}ms${NC}"
    
    # 清理测试数据
    sqlite3 "$DB_PATH" "DELETE FROM api_keys WHERE key LIKE 'test-key-%';"
    
    # 返回平均时间
    echo "$avg_time"
}

# 生成性能报告
generate_report() {
    local query_time="$1"
    local write_time="$2"
    
    echo -e "${CYAN}=== 性能基准测试报告 ===${NC}"
    
    cat > "$OUTPUT_FILE" << EOF
数据库性能基准测试报告
=======================

测试时间: $(date)
数据库路径: $DB_PATH
测试配置:
  - 测试次数: $TEST_COUNT
  - 线程数: $THREAD_COUNT

性能结果:
1. 查询性能:
   - 平均查询时间: ${query_time}ms
   - 测试次数: $TEST_COUNT

2. 写入性能:
   - 平均写入时间: ${write_time}ms
   - 测试次数: $TEST_COUNT

3. 性能评级:
EOF
    
    # 性能评级
    if [[ "$query_time" -lt 10 ]]; then
        echo -e "${GREEN}  查询性能: 优秀 (<10ms)${NC}"
        echo "  查询性能: 优秀 (<10ms)" >> "$OUTPUT_FILE"
    elif [[ "$query_time" -lt 50 ]]; then
        echo -e "${GREEN}  查询性能: 良好 (10-50ms)${NC}"
        echo "  查询性能: 良好 (10-50ms)" >> "$OUTPUT_FILE"
    elif [[ "$query_time" -lt 100 ]]; then
        echo -e "${YELLOW}  查询性能: 一般 (50-100ms)${NC}"
        echo "  查询性能: 一般 (50-100ms)" >> "$OUTPUT_FILE"
    else
        echo -e "${RED}  查询性能: 较差 (>100ms)${NC}"
        echo "  查询性能: 较差 (>100ms)" >> "$OUTPUT_FILE"
    fi
    
    if [[ "$write_time" -lt 20 ]]; then
        echo -e "${GREEN}  写入性能: 优秀 (<20ms)${NC}"
        echo "  写入性能: 优秀 (<20ms)" >> "$OUTPUT_FILE"
    elif [[ "$write_time" -lt 100 ]]; then
        echo -e "${GREEN}  写入性能: 良好 (20-100ms)${NC}"
        echo "  写入性能: 良好 (20-100ms)" >> "$OUTPUT_FILE"
    elif [[ "$write_time" -lt 500 ]]; then
        echo -e "${YELLOW}  写入性能: 一般 (100-500ms)${NC}"
        echo "  写入性能: 一般 (100-500ms)" >> "$OUTPUT_FILE"
    else
        echo -e "${RED}  写入性能: 较差 (>500ms)${NC}"
        echo "  写入性能: 较差 (>500ms)" >> "$OUTPUT_FILE"
    fi
    
    cat >> "$OUTPUT_FILE" << EOF

建议:
1. 定期运行性能测试监控数据库性能变化
2. 如果性能下降，考虑优化索引或清理旧数据
3. 对于高并发场景，考虑使用连接池

测试命令:
  $0 --db-path "$DB_PATH" --count $TEST_COUNT --threads $THREAD_COUNT

EOF
    
    echo -e "${GREEN}✓ 性能报告已生成: $OUTPUT_FILE${NC}"
    echo -e "${BLUE}报告摘要:${NC}"
    tail -20 "$OUTPUT_FILE"
}

# 主函数
main() {
    echo -e "${BOLD}${MAGENTA}数据库性能基准测试${NC}"
    echo -e "${BLUE}================================${NC}"
    
    parse_args "$@"
    check_dependencies
    check_database
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}[模拟运行模式]${NC}"
        test_connection
        test_query_performance
        test_write_performance
        echo -e "${GREEN}[模拟] 性能报告将生成到: $OUTPUT_FILE${NC}"
        return 0
    fi
    
    # 执行测试
    test_connection || exit 1
    
    echo -e "${BLUE}开始查询性能测试...${NC}"
    local query_time=$(test_query_performance)
    
    echo -e "${BLUE}开始写入性能测试...${NC}"
    local write_time=$(test_write_performance)
    
    # 生成报告
    generate_report "$query_time" "$write_time"
    
    echo -e "${GREEN}${BOLD}✓ 数据库性能基准测试完成${NC}"
    echo -e "${BLUE}================================${NC}"
}

# 运行主函数
main "$@"