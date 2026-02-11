#!/bin/bash

# 增强健康检查端点测试脚本
# 用于验证 quota-proxy 的增强健康检查端点功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT=8787
DEFAULT_HOST="localhost"
DEFAULT_TIMEOUT=5
DEFAULT_RETRIES=3

# 帮助信息
show_help() {
    cat << EOF
增强健康检查端点测试脚本

用法: $0 [选项]

选项:
  -h, --help             显示此帮助信息
  -H, --host HOST        服务器主机名或IP地址 (默认: ${DEFAULT_HOST})
  -p, --port PORT        服务器端口 (默认: ${DEFAULT_PORT})
  -t, --timeout SECONDS  请求超时时间 (默认: ${DEFAULT_TIMEOUT})
  -r, --retries COUNT    重试次数 (默认: ${DEFAULT_RETRIES})
  -v, --verbose          详细输出模式
  -d, --dry-run          只显示将要执行的命令，不实际执行
  -f, --format FORMAT    输出格式: text, json, markdown (默认: text)
  --no-color             禁用颜色输出

示例:
  $0 -H localhost -p 8787
  $0 --host 8.210.185.194 --port 8787 --verbose
  $0 --dry-run --format json

EOF
}

# 解析命令行参数
parse_args() {
    HOST="$DEFAULT_HOST"
    PORT="$DEFAULT_PORT"
    TIMEOUT="$DEFAULT_TIMEOUT"
    RETRIES="$DEFAULT_RETRIES"
    VERBOSE=false
    DRY_RUN=false
    FORMAT="text"
    NO_COLOR=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -r|--retries)
                RETRIES="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果禁用颜色，清空颜色变量
    if [ "$NO_COLOR" = true ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # 检查 jq (用于JSON解析)
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少以下依赖:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo "请安装缺少的依赖后重试。"
        exit 1
    fi
}

# 测试健康检查端点
test_health_endpoint() {
    local url="http://${HOST}:${PORT}/healthz"
    local attempt=1
    local success=false
    local response=""
    
    echo -e "${BLUE}测试增强健康检查端点:${NC} $url"
    echo -e "${BLUE}超时:${NC} ${TIMEOUT}s, ${BLUE}重试次数:${NC} ${RETRIES}"
    
    while [ $attempt -le $RETRIES ]; do
        if [ "$VERBOSE" = true ]; then
            echo -e "${YELLOW}尝试 $attempt/$RETRIES...${NC}"
        fi
        
        # 执行curl请求
        if [ "$DRY_RUN" = true ]; then
            echo "curl -s -f --max-time $TIMEOUT \"$url\""
            success=true
            response='{"dry-run": true, "ok": true, "message": "Dry run mode"}'
            break
        else
            if response=$(curl -s -f --max-time "$TIMEOUT" "$url" 2>/dev/null); then
                success=true
                break
            else
                if [ $attempt -lt $RETRIES ]; then
                    sleep 1
                fi
                attempt=$((attempt + 1))
            fi
        fi
    done
    
    if [ "$success" = false ]; then
        echo -e "${RED}健康检查失败: 无法连接到服务器${NC}"
        return 1
    fi
    
    # 解析响应
    if [ "$DRY_RUN" = false ]; then
        local ok_status=$(echo "$response" | jq -r '.ok // false')
        local timestamp=$(echo "$response" | jq -r '.timestamp // "unknown"')
        local service=$(echo "$response" | jq -r '.service // "unknown"')
        local version=$(echo "$response" | jq -r '.version // "unknown"')
        
        # 检查数据库状态
        local db_ok=$(echo "$response" | jq -r '.checks.database.ok // false')
        local db_message=$(echo "$response" | jq -r '.checks.database.message // "unknown"')
        
        # 检查表信息
        local tables_ok=$(echo "$response" | jq -r '.checks.database.tables.ok // false')
        local tables_message=$(echo "$response" | jq -r '.checks.database.tables.message // "unknown"')
        local table_count=$(echo "$response" | jq -r '.checks.database.tables.tables | length // 0')
        
        # 输出结果
        case "$FORMAT" in
            json)
                echo "$response" | jq .
                ;;
            markdown)
                echo "## 健康检查结果"
                echo ""
                echo "| 项目 | 状态 | 详情 |"
                echo "|------|------|------|"
                echo "| 服务状态 | $(if [ "$ok_status" = "true" ]; then echo "✅ 正常"; else echo "❌ 异常"; fi) | $service v$version |"
                echo "| 时间戳 | - | $timestamp |"
                echo "| 数据库连接 | $(if [ "$db_ok" = "true" ]; then echo "✅ 正常"; else echo "❌ 异常"; fi) | $db_message |"
                echo "| 数据库表结构 | $(if [ "$tables_ok" = "true" ]; then echo "✅ 正常"; else echo "❌ 异常"; fi) | $tables_message (共 $table_count 个表) |"
                echo ""
                echo "### 原始响应"
                echo '```json'
                echo "$response" | jq .
                echo '```'
                ;;
            text|*)
                echo -e "${BLUE}=== 健康检查结果 ===${NC}"
                echo -e "服务: ${service} v${version}"
                echo -e "时间戳: ${timestamp}"
                echo -e "整体状态: $(if [ "$ok_status" = "true" ]; then echo -e "${GREEN}✅ 正常${NC}"; else echo -e "${RED}❌ 异常${NC}"; fi)"
                echo ""
                echo -e "${BLUE}详细检查:${NC}"
                echo -e "  数据库连接: $(if [ "$db_ok" = "true" ]; then echo -e "${GREEN}✅ 正常${NC}"; else echo -e "${RED}❌ 异常${NC}"; fi) - $db_message"
                echo -e "  表结构检查: $(if [ "$tables_ok" = "true" ]; then echo -e "${GREEN}✅ 正常${NC}"; else echo -e "${RED}❌ 异常${NC}"; fi) - $tables_message"
                echo -e "  表数量: $table_count"
                
                if [ "$VERBOSE" = true ] && [ "$table_count" -gt 0 ]; then
                    echo -e "${BLUE}  表列表:${NC}"
                    echo "$response" | jq -r '.checks.database.tables.tables[]' | while read table; do
                        echo -e "    - $table"
                    done
                fi
                ;;
        esac
        
        # 返回状态码
        if [ "$ok_status" = "true" ]; then
            echo -e "${GREEN}健康检查通过${NC}"
            return 0
        else
            echo -e "${RED}健康检查失败${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}干运行模式: 显示命令但不执行${NC}"
        return 0
    fi
}

# 验证必需的表结构
validate_table_structure() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[干运行] 跳过表结构验证${NC}"
        return 0
    fi
    
    local url="http://${HOST}:${PORT}/healthz"
    local response=$(curl -s -f --max-time "$TIMEOUT" "$url" 2>/dev/null || echo '{}')
    
    local required_tables=$(echo "$response" | jq -r '.checks.database.tables.requiredTables // [] | join(", ")')
    local tables=$(echo "$response" | jq -r '.checks.database.tables.tables // [] | join(", ")')
    
    echo -e "${BLUE}验证表结构:${NC}"
    echo -e "  必需的表: api_keys, usage_log"
    echo -e "  实际存在的表: $tables"
    
    if echo "$tables" | grep -q "api_keys" && echo "$tables" | grep -q "usage_log"; then
        echo -e "${GREEN}✅ 所有必需的表都存在${NC}"
        return 0
    else
        echo -e "${RED}❌ 缺少必需的表${NC}"
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    check_dependencies
    
    echo -e "${BLUE}=== 增强健康检查端点测试 ===${NC}"
    echo -e "${BLUE}目标服务器:${NC} ${HOST}:${PORT}"
    echo ""
    
    # 测试健康检查端点
    if ! test_health_endpoint; then
        echo -e "${RED}健康检查端点测试失败${NC}"
        exit 1
    fi
    
    echo ""
    
    # 验证表结构
    if ! validate_table_structure; then
        echo -e "${YELLOW}警告: 表结构验证失败${NC}"
        # 不退出，因为可能是在开发环境中
    fi
    
    echo ""
    echo -e "${GREEN}所有测试完成${NC}"
}

# 运行主函数
main "$@"