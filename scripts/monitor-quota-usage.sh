#!/bin/bash
# quota-proxy 使用统计监控脚本
# 用于定期检查 API 使用情况，生成使用报告

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
ADMIN_TOKEN=""
QUOTA_PROXY_URL="http://127.0.0.1:8787"
OUTPUT_FILE="/tmp/quota-usage-report-$(date +%Y%m%d-%H%M%S).txt"
VERBOSE=false
DRY_RUN=false

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 使用统计监控脚本

用法: $0 [选项]

选项:
  -t, --token TOKEN      ADMIN_TOKEN (必需，用于认证)
  -u, --url URL         quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  -o, --output FILE     输出文件路径 (默认: /tmp/quota-usage-report-YYYYMMDD-HHMMSS.txt)
  -v, --verbose         详细输出模式
  -d, --dry-run         模拟运行，不实际调用 API
  -h, --help            显示此帮助信息

示例:
  $0 -t "your-admin-token-here"
  $0 -t "\$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)" -u "http://localhost:8787" -v
  $0 -t "\$(cat /opt/roc/quota-proxy/.env | grep '^ADMIN_TOKEN=' | cut -d= -f2)" -o /var/log/quota-usage.log

功能:
  1. 检查 quota-proxy 健康状态
  2. 获取所有 trial key 列表
  3. 获取每个 key 的使用统计
  4. 生成使用报告（总请求数、成功数、失败数、剩余配额等）
  5. 检测异常使用模式

报告包含:
  - 监控时间戳
  - 服务状态
  - 活跃 key 数量
  - 总请求统计
  - 按 key 的详细使用情况
  - 异常检测（如单个 key 使用量异常高）
  - 建议操作

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -u|--url)
                QUOTA_PROXY_URL="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
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

    # 验证必需参数
    if [[ -z "$ADMIN_TOKEN" ]]; then
        echo -e "${RED}错误: 必须提供 ADMIN_TOKEN${NC}"
        show_help
        exit 1
    fi
}

# 检查健康状态
check_health() {
    echo -e "${BLUE}[1/5] 检查 quota-proxy 健康状态...${NC}"
    
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] 跳过健康检查${NC}"
        return 0
    fi
    
    local health_url="${QUOTA_PROXY_URL}/healthz"
    if curl -fsS "$health_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务健康: $health_url${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务不可用: $health_url${NC}"
        return 1
    fi
}

# 获取 trial key 列表
get_keys() {
    echo -e "${BLUE}[2/5] 获取 trial key 列表...${NC}"
    
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] 模拟获取 key 列表${NC}"
        echo '{"keys": ["trial-key-1", "trial-key-2", "trial-key-3"]}'
        return 0
    fi
    
    local keys_url="${QUOTA_PROXY_URL}/admin/keys"
    curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$keys_url"
}

# 获取 key 使用统计
get_key_usage() {
    local key="$1"
    echo -e "${BLUE}[3/5] 获取 key '$key' 使用统计...${NC}"
    
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] 模拟获取 key '$key' 使用统计${NC}"
        echo '{"key": "'"$key"'", "total_requests": 150, "successful_requests": 145, "failed_requests": 5, "remaining_quota": 850, "created_at": "2026-02-10T10:00:00Z", "last_used": "2026-02-10T14:55:00Z"}'
        return 0
    fi
    
    local usage_url="${QUOTA_PROXY_URL}/admin/usage?key=$key"
    curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$usage_url"
}

# 生成使用报告
generate_report() {
    local keys_json="$1"
    local report_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    echo -e "${BLUE}[4/5] 生成使用报告...${NC}"
    
    # 解析 keys JSON
    local keys=$(echo "$keys_json" | grep -o '"keys":\[[^]]*\]' | sed 's/"keys":\[//' | sed 's/\]//' | tr -d '"' | tr ',' ' ')
    
    cat > "$OUTPUT_FILE" << EOF
=============================================
quota-proxy 使用统计报告
=============================================
生成时间: $report_time
服务地址: $QUOTA_PROXY_URL
报告文件: $OUTPUT_FILE

EOF

    # 检查服务状态
    if check_health; then
        echo "服务状态: ✅ 健康" >> "$OUTPUT_FILE"
    else
        echo "服务状态: ❌ 异常" >> "$OUTPUT_FILE"
    fi
    
    echo "" >> "$OUTPUT_FILE"
    
    # 统计信息
    local total_keys=0
    local total_requests=0
    local total_success=0
    local total_failures=0
    local total_remaining=0
    
    echo "📊 使用统计概览" >> "$OUTPUT_FILE"
    echo "---------------------------------------------" >> "$OUTPUT_FILE"
    
    for key in $keys; do
        if [[ -n "$key" ]]; then
            total_keys=$((total_keys + 1))
            
            local usage_json=$(get_key_usage "$key")
            
            # 解析使用数据
            local total=$(echo "$usage_json" | grep -o '"total_requests":[0-9]*' | cut -d: -f2)
            local success=$(echo "$usage_json" | grep -o '"successful_requests":[0-9]*' | cut -d: -f2)
            local failed=$(echo "$usage_json" | grep -o '"failed_requests":[0-9]*' | cut -d: -f2)
            local remaining=$(echo "$usage_json" | grep -o '"remaining_quota":[0-9]*' | cut -d: -f2)
            local last_used=$(echo "$usage_json" | grep -o '"last_used":"[^"]*"' | cut -d'"' -f4)
            
            total_requests=$((total_requests + total))
            total_success=$((total_success + success))
            total_failures=$((total_failures + failed))
            total_remaining=$((total_remaining + remaining))
            
            # 计算使用率
            local usage_percent=0
            if [[ $total -gt 0 ]]; then
                usage_percent=$((total * 100 / (total + remaining)))
            fi
            
            echo "🔑 Key: $key" >> "$OUTPUT_FILE"
            echo "   📈 总请求: $total" >> "$OUTPUT_FILE"
            echo "   ✅ 成功: $success" >> "$OUTPUT_FILE"
            echo "   ❌ 失败: $failed" >> "$OUTPUT_FILE"
            echo "   💰 剩余配额: $remaining" >> "$OUTPUT_FILE"
            echo "   📊 使用率: $usage_percent%" >> "$OUTPUT_FILE"
            echo "   ⏰ 最后使用: ${last_used:-从未使用}" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            
            if $VERBOSE; then
                echo -e "${GREEN}处理 key: $key${NC}"
            fi
        fi
    done
    
    # 汇总统计
    echo "=============================================" >> "$OUTPUT_FILE"
    echo "📈 汇总统计" >> "$OUTPUT_FILE"
    echo "---------------------------------------------" >> "$OUTPUT_FILE"
    echo "活跃 key 数量: $total_keys" >> "$OUTPUT_FILE"
    echo "总请求数: $total_requests" >> "$OUTPUT_FILE"
    echo "成功请求: $total_success" >> "$OUTPUT_FILE"
    echo "失败请求: $total_failures" >> "$OUTPUT_FILE"
    echo "总剩余配额: $total_remaining" >> "$OUTPUT_FILE"
    
    # 成功率计算
    local success_rate=0
    if [[ $total_requests -gt 0 ]]; then
        success_rate=$((total_success * 100 / total_requests))
    fi
    echo "成功率: $success_rate%" >> "$OUTPUT_FILE"
    
    # 异常检测
    echo "" >> "$OUTPUT_FILE"
    echo "🔍 异常检测" >> "$OUTPUT_FILE"
    echo "---------------------------------------------" >> "$OUTPUT_FILE"
    
    if [[ $total_failures -gt $((total_requests / 10)) ]]; then
        echo "⚠️  警告: 失败率较高 ($total_failures/$total_requests)" >> "$OUTPUT_FILE"
    else
        echo "✅ 失败率正常" >> "$OUTPUT_FILE"
    fi
    
    if [[ $total_remaining -lt $((total_keys * 100)) ]]; then
        echo "⚠️  警告: 总体剩余配额较低 ($total_remaining)" >> "$OUTPUT_FILE"
    else
        echo "✅ 配额充足" >> "$OUTPUT_FILE"
    fi
    
    # 建议
    echo "" >> "$OUTPUT_FILE"
    echo "💡 建议操作" >> "$OUTPUT_FILE"
    echo "---------------------------------------------" >> "$OUTPUT_FILE"
    
    if [[ $total_keys -eq 0 ]]; then
        echo "1. 创建新的 trial key" >> "$OUTPUT_FILE"
    fi
    
    if [[ $success_rate -lt 90 ]]; then
        echo "2. 检查 API 服务稳定性" >> "$OUTPUT_FILE"
    fi
    
    if [[ $total_remaining -lt 500 ]]; then
        echo "3. 考虑增加配额或创建新 key" >> "$OUTPUT_FILE"
    fi
    
    echo "4. 定期运行此监控脚本 (建议每小时)" >> "$OUTPUT_FILE"
    
    echo "" >> "$OUTPUT_FILE"
    echo "=============================================" >> "$OUTPUT_FILE"
    echo "报告生成完成: $OUTPUT_FILE" >> "$OUTPUT_FILE"
    
    echo -e "${GREEN}[5/5] 报告已保存到: $OUTPUT_FILE${NC}"
    
    if $VERBOSE; then
        echo -e "${YELLOW}报告预览:${NC}"
        tail -20 "$OUTPUT_FILE"
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}quota-proxy 使用统计监控${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo -e "服务地址: $QUOTA_PROXY_URL"
    echo -e "输出文件: $OUTPUT_FILE"
    echo -e "详细模式: $VERBOSE"
    echo -e "模拟运行: $DRY_RUN"
    echo -e "${BLUE}=============================================${NC}"
    
    # 检查健康状态
    if ! check_health; then
        echo -e "${RED}服务不可用，无法继续监控${NC}"
        exit 1
    fi
    
    # 获取 key 列表
    local keys_json=$(get_keys)
    if $VERBOSE; then
        echo -e "${YELLOW}Key 列表响应:${NC}"
        echo "$keys_json"
    fi
    
    # 生成报告
    generate_report "$keys_json"
    
    echo -e "${GREEN}✅ 监控完成${NC}"
    echo -e "查看完整报告: cat $OUTPUT_FILE"
}

# 执行主函数
main "$@"