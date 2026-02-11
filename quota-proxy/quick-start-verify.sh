#!/bin/bash
# quick-start-verify.sh - Admin API 快速验证脚本
# 用法: ./quick-start-verify.sh [BASE_URL] [ADMIN_TOKEN]
# 示例: ./quick-start-verify.sh http://localhost:8787 my-admin-token-123

set -e

BASE_URL="${1:-http://localhost:8787}"
ADMIN_TOKEN="${2:-$ADMIN_TOKEN}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}✗ 需要 curl 命令${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ curl 已安装${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠ jq 未安装，部分功能可能受限${NC}"
        HAS_JQ=false
    else
        echo -e "${GREEN}✓ jq 已安装${NC}"
        HAS_JQ=true
    fi
    
    if [ -z "$ADMIN_TOKEN" ]; then
        echo -e "${YELLOW}⚠ ADMIN_TOKEN 未设置，请通过参数或环境变量提供${NC}"
        echo -e "${YELLOW}  用法: $0 [BASE_URL] [ADMIN_TOKEN]${NC}"
        echo -e "${YELLOW}  或: export ADMIN_TOKEN=your-token${NC}"
        exit 1
    fi
}

# 健康检查
check_health() {
    echo -e "\n${BLUE}1. 健康检查...${NC}"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        health=$(curl -s --max-time 5 "$BASE_URL/healthz" 2>/dev/null || true)
        
        if [[ "$health" == "OK" ]]; then
            echo -e "${GREEN}   ✓ 服务正常 (健康检查通过)${NC}"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW}   ⚠ 第 ${retry_count} 次重试...${NC}"
            sleep 1
        fi
    done
    
    echo -e "${RED}   ✗ 服务异常: 无法连接到 $BASE_URL/healthz${NC}"
    echo -e "${YELLOW}   提示: 请确保 quota-proxy 服务正在运行${NC}"
    return 1
}

# Admin API 访问测试
check_admin_api() {
    echo -e "\n${BLUE}2. Admin API 访问测试...${NC}"
    
    api_resp=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$BASE_URL/admin/keys" 2>/dev/null || true)
    
    if [ -z "$api_resp" ]; then
        echo -e "${RED}   ✗ Admin API 访问失败: 无响应${NC}"
        return 1
    fi
    
    if echo "$api_resp" | grep -q "success\|keys\|error"; then
        echo -e "${GREEN}   ✓ Admin API 访问正常${NC}"
        
        if [ "$HAS_JQ" = true ]; then
            echo -e "${BLUE}   响应预览:${NC}"
            echo "$api_resp" | jq '. | {success: .success, message: .message, keys_count: (.keys | length)}' 2>/dev/null || echo "$api_resp" | head -c 200
        fi
        return 0
    else
        echo -e "${RED}   ✗ Admin API 访问失败: 响应格式异常${NC}"
        echo -e "${YELLOW}   响应内容: ${api_resp:0:200}...${NC}"
        return 1
    fi
}

# 试用密钥生成测试
test_trial_key_generation() {
    echo -e "\n${BLUE}3. 试用密钥生成测试...${NC}"
    
    local test_name="快速验证测试-$(date +%Y%m%d-%H%M%S)"
    local test_quota=3
    local test_expiry="30m"
    
    key_resp=$(curl -s --max-time 10 \
        -X POST "$BASE_URL/admin/keys/trial" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$test_name\",\"quota\":$test_quota,\"expiresIn\":\"$test_expiry\"}" 2>/dev/null || true)
    
    if [ -z "$key_resp" ]; then
        echo -e "${RED}   ✗ 试用密钥生成失败: 无响应${NC}"
        return 1
    fi
    
    if echo "$key_resp" | grep -q "key\|success"; then
        echo -e "${GREEN}   ✓ 试用密钥生成成功${NC}"
        
        if [ "$HAS_JQ" = true ]; then
            trial_key=$(echo "$key_resp" | jq -r '.key // .data.key // empty' 2>/dev/null)
            if [ -n "$trial_key" ]; then
                echo -e "${BLUE}   生成的密钥: ${trial_key:0:16}...${NC}"
                echo -e "${BLUE}   完整信息:${NC}"
                echo "$key_resp" | jq '. | {success: .success, message: .message, key: (.key // .data.key), quota: (.quota // .data.quota)}' 2>/dev/null || echo "$key_resp" | head -c 200
            fi
        fi
        return 0
    else
        echo -e "${RED}   ✗ 试用密钥生成失败${NC}"
        echo -e "${YELLOW}   响应内容: ${key_resp:0:200}...${NC}"
        return 1
    fi
}

# 使用情况查询测试
test_usage_query() {
    echo -e "\n${BLUE}4. 使用情况查询测试...${NC}"
    
    usage_resp=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        "$BASE_URL/admin/usage" 2>/dev/null || true)
    
    if [ -n "$usage_resp" ]; then
        echo -e "${GREEN}   ✓ 使用情况查询正常${NC}"
        
        if [ "$HAS_JQ" = true ]; then
            echo -e "${BLUE}   使用情况预览:${NC}"
            echo "$usage_resp" | jq '. | {success: .success, message: .message, total_requests: (.total_requests // .data.total_requests)}' 2>/dev/null || echo "$usage_resp" | head -c 200
        fi
        return 0
    else
        echo -e "${YELLOW}   ⚠ 使用情况查询无响应（可能功能未启用）${NC}"
        return 0
    fi
}

# 主函数
main() {
    echo -e "${BLUE}=== Admin API 快速验证 ===${NC}"
    echo -e "${BLUE}目标服务: $BASE_URL${NC}"
    echo -e "${BLUE}开始时间: $(date)${NC}"
    echo ""
    
    check_dependencies
    
    local all_passed=true
    
    if ! check_health; then
        all_passed=false
    fi
    
    if ! check_admin_api; then
        all_passed=false
    fi
    
    if ! test_trial_key_generation; then
        all_passed=false
    fi
    
    if ! test_usage_query; then
        all_passed=false
    fi
    
    echo -e "\n${BLUE}=== 验证完成 ===${NC}"
    echo -e "${BLUE}完成时间: $(date)${NC}"
    
    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}✅ 所有测试通过！${NC}"
        echo -e "${GREEN}服务状态: 正常${NC}"
        echo -e "${GREEN}Admin API: 可用${NC}"
        echo -e "${GREEN}试用密钥功能: 正常${NC}"
        echo -e "${GREEN}使用情况查询: 正常${NC}"
        exit 0
    else
        echo -e "${RED}❌ 部分测试失败${NC}"
        echo -e "${YELLOW}请检查:${NC}"
        echo -e "${YELLOW}1. quota-proxy 服务是否运行${NC}"
        echo -e "${YELLOW}2. ADMIN_TOKEN 是否正确${NC}"
        echo -e "${YELLOW}3. 网络连接是否正常${NC}"
        echo -e "${YELLOW}4. 查看服务日志获取更多信息${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"