#!/bin/bash
# automate-trial-key-generation.sh - 自动化TRIAL_KEY生成和管理脚本
# 为quota-proxy提供批量密钥生成、管理和监控功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_BASE_URL="http://localhost:8787"
DEFAULT_ADMIN_TOKEN=""
DEFAULT_OUTPUT_FILE="generated-keys.csv"
DEFAULT_DAILY_LIMIT=100

# 显示帮助信息
show_help() {
    cat << EOF
自动化TRIAL_KEY生成和管理脚本

用法: $0 [选项] <命令>

命令:
  generate    生成新的试用密钥
  list        列出所有密钥
  usage       查看使用统计
  reset       重置密钥使用次数
  delete      删除密钥
  batch       批量生成密钥
  monitor     监控使用情况

选项:
  -u, --url URL            quota-proxy服务地址 (默认: $DEFAULT_BASE_URL)
  -t, --token TOKEN        管理员令牌 (必需)
  -l, --limit NUMBER       每日请求限制 (默认: $DEFAULT_DAILY_LIMIT)
  -o, --output FILE        输出文件 (默认: $DEFAULT_OUTPUT_FILE)
  -n, --name LABEL         密钥标签
  -c, --count NUMBER       批量生成数量
  -h, --help               显示此帮助信息

示例:
  # 生成单个密钥
  $0 generate --token "admin-token-123" --name "用户A"

  # 批量生成5个密钥
  $0 batch --token "admin-token-123" --count 5 --limit 200

  # 列出所有密钥
  $0 list --token "admin-token-123"

  # 查看使用统计
  $0 usage --token "admin-token-123"

  # 监控使用情况（每5分钟）
  $0 monitor --token "admin-token-123"

环境变量:
  ADMIN_TOKEN              管理员令牌（可替代--token参数）
  QUOTA_PROXY_URL          quota-proxy服务地址（可替代--url参数）
EOF
}

# 检查必需工具
check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}错误：缺少必需的工具: ${missing[*]}${NC}"
        echo "请安装:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
}

# 解析参数
parse_args() {
    COMMAND=""
    BASE_URL="${QUOTA_PROXY_URL:-$DEFAULT_BASE_URL}"
    ADMIN_TOKEN="${ADMIN_TOKEN:-}"
    DAILY_LIMIT="$DEFAULT_DAILY_LIMIT"
    OUTPUT_FILE="$DEFAULT_OUTPUT_FILE"
    KEY_LABEL=""
    BATCH_COUNT=1
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            generate|list|usage|reset|delete|batch|monitor)
                COMMAND="$1"
                shift
                ;;
            -u|--url)
                BASE_URL="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -l|--limit)
                DAILY_LIMIT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -n|--name)
                KEY_LABEL="$2"
                shift 2
                ;;
            -c|--count)
                BATCH_COUNT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [ -z "$COMMAND" ]; then
        echo -e "${RED}错误：必须指定一个命令${NC}"
        show_help
        exit 1
    fi
    
    if [ -z "$ADMIN_TOKEN" ]; then
        echo -e "${RED}错误：必须提供管理员令牌${NC}"
        echo "使用 --token 参数或设置 ADMIN_TOKEN 环境变量"
        exit 1
    fi
}

# 检查服务健康状态
check_health() {
    echo -e "${BLUE}检查服务健康状态...${NC}"
    if curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务正常运行${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务不可用${NC}"
        echo "请检查："
        echo "  1. quota-proxy服务是否启动"
        echo "  2. 服务地址是否正确: $BASE_URL"
        echo "  3. 网络连接是否正常"
        return 1
    fi
}

# 生成单个密钥
generate_key() {
    local label="${KEY_LABEL:-auto-$(date +%Y%m%d-%H%M%S)}"
    
    echo -e "${BLUE}生成新密钥...${NC}"
    echo "标签: $label"
    echo "每日限制: $DAILY_LIMIT"
    
    local response=$(curl -s -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"label\": \"$label\", \"daily_limit\": $DAILY_LIMIT}")
    
    if echo "$response" | jq -e '.key' > /dev/null 2>&1; then
        local key=$(echo "$response" | jq -r '.key')
        local created_at=$(echo "$response" | jq -r '.created_at')
        
        echo -e "${GREEN}✓ 密钥生成成功${NC}"
        echo "密钥: $key"
        echo "创建时间: $created_at"
        
        # 保存到文件
        echo "$label,$key,$DAILY_LIMIT,$created_at" >> "$OUTPUT_FILE"
        echo -e "${BLUE}密钥已保存到: $OUTPUT_FILE${NC}"
        
        return 0
    else
        echo -e "${RED}✗ 密钥生成失败${NC}"
        echo "响应: $response"
        return 1
    fi
}

# 批量生成密钥
batch_generate() {
    echo -e "${BLUE}批量生成 $BATCH_COUNT 个密钥...${NC}"
    echo "每日限制: $DAILY_LIMIT"
    echo "输出文件: $OUTPUT_FILE"
    
    # 创建CSV文件头
    echo "标签,密钥,每日限制,创建时间" > "$OUTPUT_FILE"
    
    local success_count=0
    local fail_count=0
    
    for ((i=1; i<=BATCH_COUNT; i++)); do
        local label="${KEY_LABEL:-batch-$(date +%Y%m%d)-$i}"
        
        echo -e "${BLUE}生成密钥 $i/$BATCH_COUNT...${NC}"
        
        local response=$(curl -s -X POST "${BASE_URL}/admin/keys" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"label\": \"$label\", \"daily_limit\": $DAILY_LIMIT}")
        
        if echo "$response" | jq -e '.key' > /dev/null 2>&1; then
            local key=$(echo "$response" | jq -r '.key')
            local created_at=$(echo "$response" | jq -r '.created_at')
            
            echo "$label,$key,$DAILY_LIMIT,$created_at" >> "$OUTPUT_FILE"
            echo -e "  ${GREEN}✓ 成功: $key${NC}"
            ((success_count++))
        else
            echo -e "  ${RED}✗ 失败${NC}"
            echo "  响应: $response"
            ((fail_count++))
        fi
        
        # 避免请求过快
        sleep 0.5
    done
    
    echo -e "${GREEN}批量生成完成${NC}"
    echo "成功: $success_count"
    echo "失败: $fail_count"
    echo "密钥文件: $OUTPUT_FILE"
}

# 列出所有密钥
list_keys() {
    echo -e "${BLUE}获取密钥列表...${NC}"
    
    local response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
        "${BASE_URL}/admin/keys")
    
    if echo "$response" | jq -e '.keys' > /dev/null 2>&1; then
        echo "$response" | jq -r '.keys[] | "\(.key) | \(.label) | 限制: \(.daily_limit) | 今日使用: \(.used_today) | 创建: \(.created_at)"' | \
        while read -r line; do
            echo -e "${GREEN}$line${NC}"
        done
        
        local total=$(echo "$response" | jq '.keys | length')
        echo -e "${BLUE}总计: $total 个密钥${NC}"
    else
        echo -e "${RED}✗ 获取密钥列表失败${NC}"
        echo "响应: $response"
    fi
}

# 查看使用统计
show_usage() {
    echo -e "${BLUE}获取使用统计...${NC}"
    
    local response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
        "${BASE_URL}/admin/usage")
    
    if echo "$response" | jq -e '.total_requests' > /dev/null 2>&1; then
        local total_requests=$(echo "$response" | jq -r '.total_requests')
        local active_keys=$(echo "$response" | jq -r '.active_keys')
        local total_keys=$(echo "$response" | jq -r '.total_keys')
        
        echo -e "${GREEN}总请求数: $total_requests${NC}"
        echo -e "${GREEN}活跃密钥: $active_keys${NC}"
        echo -e "${GREEN}总密钥数: $total_keys${NC}"
        
        echo -e "\n${BLUE}详细统计:${NC}"
        echo "$response" | jq -r '.keys[] | "\(.key[:20])... | 标签: \(.label) | 今日使用: \(.used_today)/\(.daily_limit) | 总使用: \(.total_used)"' | \
        while read -r line; do
            echo -e "  $line"
        done
    else
        echo -e "${RED}✗ 获取使用统计失败${NC}"
        echo "响应: $response"
    fi
}

# 重置密钥使用次数
reset_usage() {
    if [ -z "$KEY_LABEL" ]; then
        echo -e "${RED}错误：必须指定要重置的密钥（使用 --name 参数）${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}重置密钥使用次数: $KEY_LABEL${NC}"
    
    local response=$(curl -s -X POST "${BASE_URL}/admin/reset-usage" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$KEY_LABEL\"}")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 使用次数重置成功${NC}"
    else
        echo -e "${RED}✗ 重置失败${NC}"
        echo "响应: $response"
    fi
}

# 删除密钥
delete_key() {
    if [ -z "$KEY_LABEL" ]; then
        echo -e "${RED}错误：必须指定要删除的密钥（使用 --name 参数）${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}删除密钥: $KEY_LABEL${NC}"
    
    local response=$(curl -s -X DELETE "${BASE_URL}/admin/keys/$KEY_LABEL" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
    
    if [ "$response" = "true" ] || [ "$response" = "\"true\"" ]; then
        echo -e "${GREEN}✓ 密钥删除成功${NC}"
    else
        echo -e "${RED}✗ 删除失败${NC}"
        echo "响应: $response"
    fi
}

# 监控使用情况
monitor_usage() {
    echo -e "${BLUE}开始监控使用情况...${NC}"
    echo "按 Ctrl+C 停止监控"
    echo ""
    
    while true; do
        clear
        echo -e "${YELLOW}=== quota-proxy 使用情况监控 ===${NC}"
        echo -e "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        local response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
            "${BASE_URL}/admin/usage" 2>/dev/null || echo '{"error": "请求失败"}')
        
        if echo "$response" | jq -e '.total_requests' > /dev/null 2>&1; then
            local total_requests=$(echo "$response" | jq -r '.total_requests')
            local active_keys=$(echo "$response" | jq -r '.active_keys')
            local total_keys=$(echo "$response" | jq -r '.total_keys')
            
            echo -e "${GREEN}总请求数: $total_requests${NC}"
            echo -e "${GREEN}活跃密钥: $active_keys${NC}"
            echo -e "${GREEN}总密钥数: $total_keys${NC}"
            
            echo -e "\n${BLUE}密钥使用情况:${NC}"
            echo "$response" | jq -r '.keys[] | select(.used_today > 0) | "\(.key[:15])... | \(.label) | 今日: \(.used_today)/\(.daily_limit) | 使用率: \(if .daily_limit > 0 then (.used_today*100/.daily_limit|floor) else 0 end)%"' | \
            while read -r line; do
                echo -e "  $line"
            done | head -10
            
            echo -e "\n${BLUE}最近活跃密钥:${NC}"
            echo "$response" | jq -r '.keys[] | "\(.key[:15])... | \(.label) | 最后使用: \(.last_used)"' | \
            sort -r | head -5 | while read -r line; do
                echo -e "  $line"
            done
        else
            echo -e "${RED}✗ 获取监控数据失败${NC}"
            echo "响应: $response"
        fi
        
        echo -e "\n${YELLOW}下次更新: 5秒后...${NC}"
        sleep 5
    done
}

# 主函数
main() {
    check_dependencies
    parse_args "$@"
    
    echo -e "${YELLOW}=== quota-proxy 密钥管理工具 ===${NC}"
    echo "服务地址: $BASE_URL"
    echo "命令: $COMMAND"
    echo ""
    
    # 检查服务健康状态（除了monitor命令）
    if [ "$COMMAND" != "monitor" ]; then
        check_health || exit 1
    fi
    
    case "$COMMAND" in
        generate)
            generate_key
            ;;
        batch)
            batch_generate
            ;;
        list)
            list_keys
            ;;
        usage)
            show_usage
            ;;
        reset)
            reset_usage
            ;;
        delete)
            delete_key
            ;;
        monitor)
            monitor_usage
            ;;
        *)
            echo -e "${RED}未知命令: $COMMAND${NC}"
            show_help
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}操作完成${NC}"
}

# 运行主函数
main "$@"