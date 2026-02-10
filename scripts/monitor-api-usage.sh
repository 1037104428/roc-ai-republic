#!/bin/bash
# quota-proxy API使用情况监控脚本
# 提供API密钥使用情况的监控和摘要报告功能

set -euo pipefail

# 默认配置
DEFAULT_BASE_URL="http://127.0.0.1:8787"
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-}"
DEFAULT_OUTPUT_FORMAT="text"  # text, json, csv
DEFAULT_WARNING_THRESHOLD=80  # 警告阈值（百分比）
DEFAULT_CRITICAL_THRESHOLD=95 # 严重阈值（百分比）

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
quota-proxy API使用情况监控脚本

用法: $0 [选项]

选项:
  -h, --help                   显示此帮助信息
  -u, --url URL                quota-proxy基础URL (默认: ${DEFAULT_BASE_URL})
  -t, --token TOKEN            管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 读取)
  -f, --format FORMAT          输出格式: text, json, csv (默认: ${DEFAULT_OUTPUT_FORMAT})
  -w, --warning THRESHOLD      警告阈值 (百分比, 默认: ${DEFAULT_WARNING_THRESHOLD})
  -c, --critical THRESHOLD     严重阈值 (百分比, 默认: ${DEFAULT_CRITICAL_THRESHOLD})
  -q, --quiet                  安静模式，只输出摘要
  -v, --verbose                详细模式，显示所有详细信息
  -d, --dry-run                干运行模式，不实际调用API
  --no-color                   禁用彩色输出

示例:
  $0 --url http://localhost:8787 --token my-admin-token
  $0 --format json --warning 70 --critical 90
  ADMIN_TOKEN=my-token $0 --verbose

环境变量:
  ADMIN_TOKEN  管理员令牌（可通过此变量设置，避免在命令行中暴露）

退出码:
  0   正常，所有密钥使用率正常
  1   警告，有密钥使用率超过警告阈值
  2   严重，有密钥使用率超过严重阈值
  3   错误，脚本执行出错
EOF
}

# 解析命令行参数
parse_args() {
    BASE_URL="${DEFAULT_BASE_URL}"
    ADMIN_TOKEN="${DEFAULT_ADMIN_TOKEN}"
    OUTPUT_FORMAT="${DEFAULT_OUTPUT_FORMAT}"
    WARNING_THRESHOLD="${DEFAULT_WARNING_THRESHOLD}"
    CRITICAL_THRESHOLD="${DEFAULT_CRITICAL_THRESHOLD}"
    QUIET=false
    VERBOSE=false
    DRY_RUN=false
    NO_COLOR=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--url)
                BASE_URL="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -w|--warning)
                WARNING_THRESHOLD="$2"
                shift 2
                ;;
            -c|--critical)
                CRITICAL_THRESHOLD="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-color)
                NO_COLOR=true
                shift
                ;;
            *)
                echo "错误: 未知选项 $1"
                show_help
                exit 3
                ;;
        esac
    done
    
    # 验证参数
    if [[ -z "${ADMIN_TOKEN}" ]]; then
        echo "错误: 管理员令牌未设置，请通过 -t/--token 参数或 ADMIN_TOKEN 环境变量设置"
        exit 3
    fi
    
    if [[ ${WARNING_THRESHOLD} -ge ${CRITICAL_THRESHOLD} ]]; then
        echo "错误: 警告阈值 (${WARNING_THRESHOLD}%) 必须小于严重阈值 (${CRITICAL_THRESHOLD}%)"
        exit 3
    fi
}

# 彩色输出函数
colorize() {
    local color="$1"
    local text="$2"
    
    if [[ "${NO_COLOR}" == "true" ]]; then
        echo -n "${text}"
    else
        echo -n "${color}${text}${NC}"
    fi
}

# 获取API使用情况
get_api_usage() {
    local url="${BASE_URL}/admin/usage"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        if [[ "${VERBOSE}" == "true" ]]; then
            echo "干运行: 将调用 GET ${url}" >&2
        fi
        cat << 'EOF'
{
  "keys": [
    {
      "key": "demo-key-1",
      "total_quota": 1000,
      "used": 150,
      "remaining": 850,
      "usage_percent": 15.0,
      "created_at": "2026-02-10T10:00:00Z",
      "last_used": "2026-02-10T19:30:00Z"
    },
    {
      "key": "demo-key-2",
      "total_quota": 500,
      "used": 450,
      "remaining": 50,
      "usage_percent": 90.0,
      "created_at": "2026-02-10T11:00:00Z",
      "last_used": "2026-02-10T19:45:00Z"
    },
    {
      "key": "demo-key-3",
      "total_quota": 2000,
      "used": 50,
      "remaining": 1950,
      "usage_percent": 2.5,
      "created_at": "2026-02-10T12:00:00Z",
      "last_used": "2026-02-10T18:20:00Z"
    }
  ],
  "total_keys": 3,
  "total_quota": 3500,
  "total_used": 650,
  "total_remaining": 2850,
  "average_usage_percent": 35.83
}
EOF
    else
        curl -s -f \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" \
            -H "Content-Type: application/json" \
            "${url}"
    fi
}

# 分析使用情况
analyze_usage() {
    local json_data="$1"
    local exit_code=0
    local warning_count=0
    local critical_count=0
    local total_keys=0
    
    # 解析JSON数据
    total_keys=$(echo "${json_data}" | jq -r '.total_keys // 0')
    
    if [[ "${total_keys}" -eq 0 ]]; then
        echo "信息: 没有找到API密钥"
        return 0
    fi
    
    # 文本格式输出
    if [[ "${OUTPUT_FORMAT}" == "text" ]]; then
        if [[ "${QUIET}" != "true" ]]; then
            echo "=== quota-proxy API使用情况监控报告 ==="
            echo "监控时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
            echo "基础URL: ${BASE_URL}"
            echo "总密钥数: ${total_keys}"
            echo "阈值配置: 警告=${WARNING_THRESHOLD}%, 严重=${CRITICAL_THRESHOLD}%"
            echo ""
        fi
        
        # 输出每个密钥的状态
        echo "${json_data}" | jq -c '.keys[]' | while read -r key_data; do
            local key=$(echo "${key_data}" | jq -r '.key')
            local total_quota=$(echo "${key_data}" | jq -r '.total_quota')
            local used=$(echo "${key_data}" | jq -r '.used')
            local remaining=$(echo "${key_data}" | jq -r '.remaining')
            local usage_percent=$(echo "${key_data}" | jq -r '.usage_percent')
            local created_at=$(echo "${key_data}" | jq -r '.created_at')
            local last_used=$(echo "${key_data}" | jq -r '.last_used')
            
            # 计算状态
            local status="正常"
            local color="${GREEN}"
            
            if (( $(echo "${usage_percent} >= ${CRITICAL_THRESHOLD}" | bc -l) )); then
                status="严重"
                color="${RED}"
                ((critical_count++))
                exit_code=2
            elif (( $(echo "${usage_percent} >= ${WARNING_THRESHOLD}" | bc -l) )); then
                status="警告"
                color="${YELLOW}"
                ((warning_count++))
                if [[ ${exit_code} -eq 0 ]]; then
                    exit_code=1
                fi
            fi
            
            if [[ "${QUIET}" != "true" ]] || [[ "${status}" != "正常" ]]; then
                echo "密钥: $(colorize "${CYAN}" "${key}")"
                echo "  状态: $(colorize "${color}" "${status}")"
                echo "  使用率: $(colorize "${color}" "${usage_percent}%") (已用: ${used}/${total_quota}, 剩余: ${remaining})"
                echo "  创建时间: ${created_at}"
                echo "  最后使用: ${last_used}"
                echo ""
            fi
        done
        
        # 输出摘要
        local total_quota=$(echo "${json_data}" | jq -r '.total_quota')
        local total_used=$(echo "${json_data}" | jq -r '.total_used')
        local total_remaining=$(echo "${json_data}" | jq -r '.total_remaining')
        local average_usage=$(echo "${json_data}" | jq -r '.average_usage_percent')
        
        echo "=== 监控摘要 ==="
        echo "总配额: ${total_quota}"
        echo "总使用量: ${total_used}"
        echo "总剩余量: ${total_remaining}"
        echo "平均使用率: ${average_usage}%"
        echo ""
        echo "状态统计:"
        echo "  $(colorize "${GREEN}" "正常密钥"): $((total_keys - warning_count - critical_count))"
        echo "  $(colorize "${YELLOW}" "警告密钥"): ${warning_count}"
        echo "  $(colorize "${RED}" "严重密钥"): ${critical_count}"
        
        if [[ ${critical_count} -gt 0 ]]; then
            echo ""
            colorize "${RED}" "警告: 发现 ${critical_count} 个密钥使用率超过严重阈值 (${CRITICAL_THRESHOLD}%)"
            echo ""
        elif [[ ${warning_count} -gt 0 ]]; then
            echo ""
            colorize "${YELLOW}" "注意: 发现 ${warning_count} 个密钥使用率超过警告阈值 (${WARNING_THRESHOLD}%)"
            echo ""
        fi
        
    # JSON格式输出
    elif [[ "${OUTPUT_FORMAT}" == "json" ]]; then
        # 添加监控分析结果到原始数据
        echo "${json_data}" | jq --arg warning_threshold "${WARNING_THRESHOLD}" \
                                 --arg critical_threshold "${CRITICAL_THRESHOLD}" \
                                 --arg monitored_at "$(date -Iseconds)" \
                                 '. + {
                                    monitoring: {
                                        warning_threshold: ($warning_threshold | tonumber),
                                        critical_threshold: ($critical_threshold | tonumber),
                                        monitored_at: $monitored_at,
                                        warning_count: 0,
                                        critical_count: 0,
                                        status: "normal"
                                    }
                                 }'
    
    # CSV格式输出
    elif [[ "${OUTPUT_FORMAT}" == "csv" ]]; then
        echo "key,total_quota,used,remaining,usage_percent,status,created_at,last_used"
        echo "${json_data}" | jq -c '.keys[]' | while read -r key_data; do
            local key=$(echo "${key_data}" | jq -r '.key')
            local total_quota=$(echo "${key_data}" | jq -r '.total_quota')
            local used=$(echo "${key_data}" | jq -r '.used')
            local remaining=$(echo "${key_data}" | jq -r '.remaining')
            local usage_percent=$(echo "${key_data}" | jq -r '.usage_percent')
            local created_at=$(echo "${key_data}" | jq -r '.created_at')
            local last_used=$(echo "${key_data}" | jq -r '.last_used')
            
            # 确定状态
            local status="normal"
            if (( $(echo "${usage_percent} >= ${CRITICAL_THRESHOLD}" | bc -l) )); then
                status="critical"
            elif (( $(echo "${usage_percent} >= ${WARNING_THRESHOLD}" | bc -l) )); then
                status="warning"
            fi
            
            echo "${key},${total_quota},${used},${remaining},${usage_percent},${status},${created_at},${last_used}"
        done
    fi
    
    return ${exit_code}
}

# 主函数
main() {
    parse_args "$@"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "配置信息:"
        echo "  基础URL: ${BASE_URL}"
        echo "  输出格式: ${OUTPUT_FORMAT}"
        echo "  警告阈值: ${WARNING_THRESHOLD}%"
        echo "  严重阈值: ${CRITICAL_THRESHOLD}%"
        echo "  运行模式: ${DRY_RUN:+干运行}${QUIET:+安静}${VERBOSE:+详细}"
        echo ""
    fi
    
    # 获取API使用情况
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "正在获取API使用情况..."
    fi
    
    local usage_data
    usage_data=$(get_api_usage)
    local curl_exit_code=$?
    
    if [[ ${curl_exit_code} -ne 0 ]] && [[ "${DRY_RUN}" != "true" ]]; then
        echo "错误: 获取API使用情况失败 (curl退出码: ${curl_exit_code})"
        exit 3
    fi
    
    # 分析使用情况
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "正在分析使用情况..."
        echo ""
    fi
    
    analyze_usage "${usage_data}"
    local exit_code=$?
    
    if [[ "${VERBOSE}" == "true" ]]; then
        echo ""
        echo "监控完成，退出码: ${exit_code}"
    fi
    
    exit ${exit_code}
}

# 运行主函数
main "$@"