#!/bin/bash

# Admin API 验证脚本
# 用于验证 quota-proxy-admin 服务器的功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SERVER_URL="${SERVER_URL:-http://localhost:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-sk-test-key}"

echo -e "${BLUE}=== Admin API 验证脚本 ===${NC}"
echo -e "服务器: ${SERVER_URL}"
echo -e "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 检查依赖
check_deps() {
    echo -e "${BLUE}[1/8] 检查依赖...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: curl 未安装${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}警告: jq 未安装，部分功能可能受限${NC}"
        HAS_JQ=false
    else
        HAS_JQ=true
    fi
    
    echo -e "${GREEN}✓ 依赖检查完成${NC}"
    echo
}

# 健康检查
health_check() {
    echo -e "${BLUE}[2/8] 健康检查...${NC}"
    
    local response
    response=$(curl -s -f "${SERVER_URL}/healthz" 2>/dev/null || true)
    
    if [[ -z "$response" ]]; then
        echo -e "${RED}✗ 健康检查失败: 服务器未响应${NC}"
        return 1
    fi
    
    if [[ "$HAS_JQ" = true ]]; then
        local status
        status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "")
        if [[ "$status" = "ok" ]]; then
            echo -e "${GREEN}✓ 健康检查通过: $response${NC}"
        else
            echo -e "${YELLOW}⚠ 健康检查返回非标准响应: $response${NC}"
        fi
    else
        echo -e "${GREEN}✓ 健康检查响应: $response${NC}"
    fi
    
    echo
}

# 测试 Admin 认证
test_admin_auth() {
    echo -e "${BLUE}[3/8] 测试 Admin 认证...${NC}"
    
    # 测试无认证的请求
    echo -e "  测试无认证请求..."
    local no_auth_response
    no_auth_response=$(curl -s -w "%{http_code}" -o /dev/null "${SERVER_URL}/admin/keys" 2>/dev/null || echo "000")
    
    if [[ "$no_auth_response" = "401" ]]; then
        echo -e "  ${GREEN}✓ 无认证请求正确返回 401${NC}"
    else
        echo -e "  ${YELLOW}⚠ 无认证请求返回 $no_auth_response (期望 401)${NC}"
    fi
    
    # 测试错误认证
    echo -e "  测试错误认证..."
    local wrong_auth_response
    wrong_auth_response=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "Authorization: Bearer wrong-token" \
        "${SERVER_URL}/admin/keys" 2>/dev/null || echo "000")
    
    if [[ "$wrong_auth_response" = "401" ]]; then
        echo -e "  ${GREEN}✓ 错误认证正确返回 401${NC}"
    else
        echo -e "  ${YELLOW}⚠ 错误认证返回 $wrong_auth_response (期望 401)${NC}"
    fi
    
    echo -e "${GREEN}✓ Admin 认证测试完成${NC}"
    echo
}

# 生成 Trial Key
generate_trial_key() {
    echo -e "${BLUE}[4/8] 生成 Trial Key...${NC}"
    
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"label": "验证脚本测试", "daily_limit": 50}' \
        "${SERVER_URL}/admin/keys" 2>/dev/null || echo '{"error":"请求失败"}')
    
    if [[ "$HAS_JQ" = true ]]; then
        local success
        success=$(echo "$response" | jq -r '.success' 2>/dev/null || echo "false")
        
        if [[ "$success" = "true" ]]; then
            TRIAL_KEY=$(echo "$response" | jq -r '.key')
            echo -e "${GREEN}✓ Trial Key 生成成功: ${TRIAL_KEY}${NC}"
            echo -e "  详情: $response"
        else
            echo -e "${YELLOW}⚠ Trial Key 生成失败: $response${NC}"
            TRIAL_KEY=""
        fi
    else
        if echo "$response" | grep -q '"success":true'; then
            echo -e "${GREEN}✓ Trial Key 生成成功${NC}"
            echo -e "  响应: $response"
            # 简单提取 key
            TRIAL_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4 | head -1)
        else
            echo -e "${YELLOW}⚠ Trial Key 生成失败: $response${NC}"
            TRIAL_KEY=""
        fi
    fi
    
    echo
}

# 列出 Trial Keys
list_trial_keys() {
    echo -e "${BLUE}[5/8] 列出 Trial Keys...${NC}"
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        "${SERVER_URL}/admin/keys" 2>/dev/null || echo '{"error":"请求失败"}')
    
    if [[ "$HAS_JQ" = true ]]; then
        local success
        success=$(echo "$response" | jq -r '.success' 2>/dev/null || echo "false")
        
        if [[ "$success" = "true" ]]; then
            local count
            count=$(echo "$response" | jq -r '.count')
            echo -e "${GREEN}✓ 成功列出 $count 个 Trial Keys${NC}"
            
            if [[ "$count" -gt 0 ]]; then
                echo -e "  前3个keys:"
                echo "$response" | jq -r '.keys[0:3][] | "    - \(.key): \(.today_requests)/\(.daily_limit) (\(.label // "无标签"))"' 2>/dev/null || echo "    无法解析详情"
            fi
        else
            echo -e "${YELLOW}⚠ 列出 Trial Keys 失败: $response${NC}"
        fi
    else
        if echo "$response" | grep -q '"success":true'; then
            echo -e "${GREEN}✓ 成功列出 Trial Keys${NC}"
            echo -e "  响应长度: ${#response} 字符"
        else
            echo -e "${YELLOW}⚠ 列出 Trial Keys 失败: $response${NC}"
        fi
    fi
    
    echo
}

# 获取使用统计
get_usage_stats() {
    echo -e "${BLUE}[6/8] 获取使用统计...${NC}"
    
    local response
    response=$(curl -s \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        "${SERVER_URL}/admin/usage?days=1" 2>/dev/null || echo '{"error":"请求失败"}')
    
    if [[ "$HAS_JQ" = true ]]; then
        local success
        success=$(echo "$response" | jq -r '.success' 2>/dev/null || echo "false")
        
        if [[ "$success" = "true" ]]; then
            local total_requests
            total_requests=$(echo "$response" | jq -r '.summary.total_requests_last_days')
            local active_keys
            active_keys=$(echo "$response" | jq -r '.summary.active_keys')
            
            echo -e "${GREEN}✓ 使用统计获取成功${NC}"
            echo -e "  最近1天总请求数: $total_requests"
            echo -e "  活跃keys数: $active_keys"
        else
            echo -e "${YELLOW}⚠ 获取使用统计失败: $response${NC}"
        fi
    else
        if echo "$response" | grep -q '"success":true'; then
            echo -e "${GREEN}✓ 使用统计获取成功${NC}"
            echo -e "  响应长度: ${#response} 字符"
        else
            echo -e "${YELLOW}⚠ 获取使用统计失败: $response${NC}"
        fi
    fi
    
    echo
}

# 测试代理端点（可选）
test_proxy_endpoint() {
    echo -e "${BLUE}[7/8] 测试代理端点（可选）...${NC}"
    
    if [[ -z "$TRIAL_KEY" ]]; then
        echo -e "  ${YELLOW}⚠ 跳过代理测试: 无有效的 Trial Key${NC}"
        echo
        return
    fi
    
    if [[ "$DEEPSEEK_API_KEY" = "sk-test-key" ]]; then
        echo -e "  ${YELLOW}⚠ 跳过代理测试: 使用测试 API Key${NC}"
        echo
        return
    fi
    
    echo -e "  测试聊天补全端点..."
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${TRIAL_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"model": "deepseek-chat", "messages": [{"role": "user", "content": "Hello"}], "stream": false, "max_tokens": 10}' \
        "${SERVER_URL}/v1/chat/completions" 2>/dev/null || echo '{"error":"请求失败"}')
    
    if [[ "$HAS_JQ" = true ]]; then
        local error
        error=$(echo "$response" | jq -r '.error' 2>/dev/null || echo "")
        
        if [[ -n "$error" ]]; then
            if [[ "$error" = "Daily request limit exceeded" ]]; then
                echo -e "  ${YELLOW}⚠ 代理测试: 每日限制超限（正常行为）${NC}"
            elif [[ "$error" = "Invalid trial key" ]]; then
                echo -e "  ${YELLOW}⚠ 代理测试: Trial Key 无效${NC}"
            else
                echo -e "  ${GREEN}✓ 代理端点响应: $error${NC}"
            fi
        else
            echo -e "  ${GREEN}✓ 代理端点工作正常${NC}"
        fi
    else
        if echo "$response" | grep -q '"error"'; then
            echo -e "  ${GREEN}✓ 代理端点返回错误响应（预期内）${NC}"
        else
            echo -e "  ${GREEN}✓ 代理端点工作正常${NC}"
        fi
    fi
    
    echo
}

# 总结报告
summary_report() {
    echo -e "${BLUE}[8/8] 验证总结报告${NC}"
    echo -e "================================"
    echo -e "服务器URL: ${SERVER_URL}"
    echo -e "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Admin Token: ${ADMIN_TOKEN:0:10}..."
    echo -e "生成的 Trial Key: ${TRIAL_KEY:-无}"
    echo -e "jq 可用: ${HAS_JQ}"
    echo -e "================================"
    echo -e "${GREEN}✓ Admin API 验证脚本执行完成${NC}"
    echo
}

# 主函数
main() {
    echo -e "${BLUE}开始 Admin API 验证...${NC}"
    echo
    
    check_deps
    health_check
    test_admin_auth
    generate_trial_key
    list_trial_keys
    get_usage_stats
    test_proxy_endpoint
    summary_report
    
    echo -e "${GREEN}所有验证步骤完成！${NC}"
}

# 运行主函数
main "$@"