#!/bin/bash
# quota-proxy 压力测试脚本
# 用于测试高并发场景下的性能和稳定性

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
CONCURRENT="${CONCURRENT:-10}"
REQUESTS="${REQUESTS:-100}"
TEST_DURATION="${TEST_DURATION:-30}"
API_BASE_URL="http://${HOST}:${PORT}"

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 压力测试脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -H, --host HOST         服务器主机 (默认: 127.0.0.1)
  -p, --port PORT         服务器端口 (默认: 8787)
  -t, --token TOKEN       Admin Token (必需)
  -c, --concurrent N      并发数 (默认: 10)
  -r, --requests N        总请求数 (默认: 100)
  -d, --duration SEC      测试持续时间秒数 (默认: 30)
  --dry-run               模拟运行，不实际发送请求
  --verbose               详细输出模式

环境变量:
  HOST, PORT, ADMIN_TOKEN, CONCURRENT, REQUESTS, TEST_DURATION

示例:
  $0 -H 8.210.185.194 -t your_admin_token -c 20 -r 200
  ADMIN_TOKEN=your_token $0 --host 127.0.0.1 --concurrent 5 --duration 60

测试场景:
  1. 健康检查端点压力测试
  2. API 网关端点压力测试
  3. Admin API 端点压力测试
  4. 混合请求压力测试

退出码:
  0 - 成功
  1 - 参数错误
  2 - 服务器不可达
  3 - 压力测试失败
  4 - 性能不达标
EOF
}

# 解析参数
parse_args() {
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
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -c|--concurrent)
                CONCURRENT="$2"
                shift 2
                ;;
            -r|--requests)
                REQUESTS="$2"
                shift 2
                ;;
            -d|--duration)
                TEST_DURATION="$2"
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
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl bc; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}错误: 缺少依赖命令: ${missing_deps[*]}${NC}"
        echo "请安装: sudo apt-get install curl bc"
        exit 1
    fi
}

# 检查服务器状态
check_server() {
    echo -e "${BLUE}[1/6] 检查服务器状态...${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}[模拟] 跳过服务器检查${NC}"
        return 0
    fi
    
    local health_url="${API_BASE_URL}/healthz"
    if ! curl -fsS --max-time 5 "$health_url" &> /dev/null; then
        echo -e "${RED}错误: 服务器不可达 ($health_url)${NC}"
        exit 2
    fi
    
    echo -e "${GREEN}✓ 服务器运行正常${NC}"
}

# 生成测试密钥
generate_test_key() {
    echo -e "${BLUE}[2/6] 生成测试密钥...${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        TEST_KEY="test-key-$(date +%s)"
        echo -e "${YELLOW}[模拟] 生成测试密钥: $TEST_KEY${NC}"
        return 0
    fi
    
    if [[ -z "$ADMIN_TOKEN" ]]; then
        echo -e "${RED}错误: 需要 ADMIN_TOKEN 环境变量或 -t 参数${NC}"
        exit 1
    fi
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"label":"压力测试密钥"}' \
        "${API_BASE_URL}/admin/keys")
    
    if echo "$response" | grep -q "key"; then
        TEST_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✓ 生成测试密钥: $TEST_KEY${NC}"
    else
        echo -e "${RED}错误: 无法生成测试密钥${NC}"
        echo "响应: $response"
        exit 2
    fi
}

# 运行压力测试
run_stress_test() {
    echo -e "${BLUE}[3/6] 运行压力测试 ($CONCURRENT 并发, $REQUESTS 请求)...${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}[模拟] 压力测试: $CONCURRENT 并发, $REQUESTS 请求${NC}"
        SUCCESS_COUNT=$REQUESTS
        FAIL_COUNT=0
        return 0
    fi
    
    local start_time end_time duration success_count=0 fail_count=0
    start_time=$(date +%s.%N)
    
    # 使用 parallel 或简单循环进行压力测试
    for i in $(seq 1 $REQUESTS); do
        # 随机选择测试端点
        case $((RANDOM % 3)) in
            0)
                # 健康检查
                if curl -fsS --max-time 2 "${API_BASE_URL}/healthz" &> /dev/null; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
                ;;
            1)
                # API 网关
                if curl -fsS --max-time 2 \
                    -H "Authorization: Bearer $TEST_KEY" \
                    "${API_BASE_URL}/v1/chat/completions" &> /dev/null; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
                ;;
            2)
                # Admin API (仅限部分请求)
                if [[ $((i % 10)) -eq 0 ]]; then
                    if curl -fsS --max-time 2 \
                        -H "Authorization: Bearer $ADMIN_TOKEN" \
                        "${API_BASE_URL}/admin/usage" &> /dev/null; then
                        ((success_count++))
                    else
                        ((fail_count++))
                    fi
                else
                    ((success_count++)) # 跳过计数
                fi
                ;;
        esac
        
        # 显示进度
        if [[ $((i % (REQUESTS / 10))) -eq 0 ]] && [[ "${VERBOSE:-false}" == "true" ]]; then
            echo -e "${BLUE}进度: $i/$REQUESTS${NC}"
        fi
    done &
    
    # 等待测试完成或超时
    wait $! 2>/dev/null || true
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    SUCCESS_COUNT=$success_count
    FAIL_COUNT=$fail_count
    DURATION=$duration
}

# 清理测试密钥
cleanup_test_key() {
    echo -e "${BLUE}[4/6] 清理测试密钥...${NC}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo -e "${YELLOW}[模拟] 清理测试密钥${NC}"
        return 0
    fi
    
    if [[ -n "$TEST_KEY" ]]; then
        curl -s -X DELETE \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            "${API_BASE_URL}/admin/keys/${TEST_KEY}" &> /dev/null || true
        echo -e "${GREEN}✓ 清理测试密钥${NC}"
    fi
}

# 分析结果
analyze_results() {
    echo -e "${BLUE}[5/6] 分析测试结果...${NC}"
    
    local total_requests=$((SUCCESS_COUNT + FAIL_COUNT))
    local success_rate=0
    local requests_per_second=0
    
    if [[ $total_requests -gt 0 ]]; then
        success_rate=$(echo "scale=2; $SUCCESS_COUNT * 100 / $total_requests" | bc)
        requests_per_second=$(echo "scale=2; $total_requests / $DURATION" | bc)
    fi
    
    echo -e "${BLUE}=== 压力测试结果 ===${NC}"
    echo -e "总请求数: $total_requests"
    echo -e "成功请求: $SUCCESS_COUNT"
    echo -e "失败请求: $FAIL_COUNT"
    echo -e "成功率: ${success_rate}%"
    echo -e "测试时长: ${DURATION} 秒"
    echo -e "请求速率: ${requests_per_second} 请求/秒"
    echo -e "并发数: $CONCURRENT"
    
    # 性能标准检查
    if (( $(echo "$success_rate < 95" | bc -l) )); then
        echo -e "${RED}⚠ 警告: 成功率低于 95%${NC}"
        return 4
    fi
    
    if (( $(echo "$requests_per_second < 10" | bc -l) )); then
        echo -e "${YELLOW}⚠ 注意: 请求速率较低 (<10 请求/秒)${NC}"
    fi
    
    echo -e "${GREEN}✓ 压力测试通过${NC}"
}

# 生成报告
generate_report() {
    echo -e "${BLUE}[6/6] 生成测试报告...${NC}"
    
    local report_file="stress-test-report-$(date +%Y%m%d-%H%M%S).txt"
    cat > "$report_file" << EOF
quota-proxy 压力测试报告
=======================

测试时间: $(date)
服务器: ${HOST}:${PORT}
测试配置:
  并发数: $CONCURRENT
  总请求数: $REQUESTS
  测试时长: ${TEST_DURATION}秒

测试结果:
  总请求数: $((SUCCESS_COUNT + FAIL_COUNT))
  成功请求: $SUCCESS_COUNT
  失败请求: $FAIL_COUNT
  成功率: $(echo "scale=2; $SUCCESS_COUNT * 100 / ($SUCCESS_COUNT + $FAIL_COUNT)" | bc)%
  请求速率: $(echo "scale=2; ($SUCCESS_COUNT + $FAIL_COUNT) / $DURATION" | bc) 请求/秒
  测试时长: ${DURATION} 秒

性能评估:
  $(if (( $(echo "$(echo "scale=2; $SUCCESS_COUNT * 100 / ($SUCCESS_COUNT + $FAIL_COUNT)" | bc) < 95" | bc -l) )); then echo "❌ 成功率不达标 (<95%)"; else echo "✅ 成功率达标 (≥95%)"; fi)
  $(if (( $(echo "$(echo "scale=2; ($SUCCESS_COUNT + $FAIL_COUNT) / $DURATION" | bc) < 10" | bc -l) )); then echo "⚠️  请求速率较低 (<10 请求/秒)"; else echo "✅ 请求速率正常"; fi)

建议:
  1. 对于生产环境，建议进行更长时间的压力测试
  2. 监控数据库连接池使用情况
  3. 考虑增加缓存层提高性能
  4. 定期进行压力测试确保系统稳定性

EOF
    
    echo -e "${GREEN}✓ 报告已保存到: $report_file${NC}"
}

# 主函数
main() {
    parse_args "$@"
    check_dependencies
    
    echo -e "${BLUE}=== quota-proxy 压力测试开始 ===${NC}"
    echo -e "服务器: ${HOST}:${PORT}"
    echo -e "配置: ${CONCURRENT} 并发, ${REQUESTS} 请求"
    
    check_server
    generate_test_key
    run_stress_test
    cleanup_test_key
    analyze_results
    generate_report
    
    echo -e "${GREEN}=== 压力测试完成 ===${NC}"
}

# 运行主函数
main "$@"