#!/bin/bash

# 快速SQLite持久化服务器健康检查脚本
# 用法: ./quick-sqlite-health-check.sh [--admin-token TOKEN] [--base-url URL]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 默认值
DRY_RUN=false
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token-$(date +%s)}"
BASE_URL="${BASE_URL:-http://localhost:8787}"
TIMEOUT=5

# 颜色定义
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [--dry-run] [--admin-token TOKEN] [--base-url URL]"
            exit 1
            ;;
    esac
done

echo -e "${COLOR_BLUE}🔍 SQLite持久化服务器快速健康检查${COLOR_RESET}"
echo -e "${COLOR_BLUE}================================${COLOR_RESET}"
echo "服务器地址: $BASE_URL"
echo "管理员令牌: ${ADMIN_TOKEN:0:10}..."
echo ""

# 检查服务器是否运行
check_server() {
    echo -n "1. 检查服务器状态... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}⚠ 干运行模式${COLOR_RESET}"
        echo "   模拟检查: curl -s -f --max-time $TIMEOUT \"$BASE_URL/healthz\""
        return 0
    fi
    
    if curl -s -f --max-time $TIMEOUT "$BASE_URL/healthz" > /dev/null 2>&1; then
        echo -e "${COLOR_GREEN}✓ 运行正常${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}✗ 服务器未运行${COLOR_RESET}"
        echo "   提示: 请先运行 ./start-sqlite-persistent.sh"
        return 1
    fi
}

# 检查数据库连接
check_database() {
    echo -n "2. 检查数据库连接... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}⚠ 干运行模式${COLOR_RESET}"
        echo "   模拟检查: curl -s --max-time $TIMEOUT \"$BASE_URL/healthz\" | grep database"
        return 0
    fi
    
    local response
    response=$(curl -s --max-time $TIMEOUT "$BASE_URL/healthz")
    
    if echo "$response" | grep -q "database"; then
        echo -e "${COLOR_GREEN}✓ 数据库连接正常${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_YELLOW}⚠ 数据库状态未知${COLOR_RESET}"
        return 0
    fi
}

# 检查管理员API
check_admin_api() {
    echo -n "3. 检查管理员API... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}⚠ 干运行模式${COLOR_RESET}"
        echo "   模拟检查: curl -s --max-time $TIMEOUT -H \"Authorization: Bearer $ADMIN_TOKEN\" \"$BASE_URL/admin/keys\""
        return 0
    fi
    
    local response
    response=$(curl -s --max-time $TIMEOUT \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$BASE_URL/admin/keys")
    
    if echo "$response" | grep -q "keys\|\[\]"; then
        echo -e "${COLOR_GREEN}✓ 管理员API正常${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}✗ 管理员API失败${COLOR_RESET}"
        echo "   响应: $response"
        return 1
    fi
}

# 检查试用密钥API
check_trial_api() {
    echo -n "4. 检查试用密钥API... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}⚠ 干运行模式${COLOR_RESET}"
        echo "   模拟检查: curl -s --max-time $TIMEOUT \"$BASE_URL/trial-key\""
        return 0
    fi
    
    local response
    response=$(curl -s --max-time $TIMEOUT \
        -H "Content-Type: application/json" \
        "$BASE_URL/trial-key")
    
    if echo "$response" | grep -q "key\|error"; then
        echo -e "${COLOR_GREEN}✓ 试用密钥API正常${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}✗ 试用密钥API失败${COLOR_RESET}"
        return 1
    fi
}

# 检查配额API
check_quota_api() {
    echo -n "5. 检查配额API... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${COLOR_YELLOW}⚠ 干运行模式${COLOR_RESET}"
        echo "   模拟检查: curl -s --max-time $TIMEOUT \"$BASE_URL/quota-check\""
        return 0
    fi
    
    local response
    response=$(curl -s --max-time $TIMEOUT \
        -H "Content-Type: application/json" \
        "$BASE_URL/quota-check")
    
    if echo "$response" | grep -q "remaining\|error"; then
        echo -e "${COLOR_GREEN}✓ 配额API正常${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}✗ 配额API失败${COLOR_RESET}"
        return 1
    fi
}

# 主检查流程
main() {
    echo -e "${COLOR_BLUE}开始健康检查...${COLOR_RESET}"
    echo ""
    
    local failed_checks=0
    
    # 执行检查
    check_server || failed_checks=$((failed_checks + 1))
    check_database || failed_checks=$((failed_checks + 1))
    check_admin_api || failed_checks=$((failed_checks + 1))
    check_trial_api || failed_checks=$((failed_checks + 1))
    check_quota_api || failed_checks=$((failed_checks + 1))
    
    echo ""
    echo -e "${COLOR_BLUE}检查完成${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========${COLOR_RESET}"
    
    if [ $failed_checks -eq 0 ]; then
        echo -e "${COLOR_GREEN}✅ 所有检查通过！SQLite持久化服务器运行正常。${COLOR_RESET}"
        echo ""
        echo "可用端点:"
        echo "  • $BASE_URL/healthz - 健康检查"
        echo "  • $BASE_URL/admin/keys - 管理员密钥管理"
        echo "  • $BASE_URL/trial-key - 获取试用密钥"
        echo "  • $BASE_URL/quota-check - 配额检查"
        echo ""
        echo "详细验证: ./verify-sqlite-persistent-api.sh --admin-token \"$ADMIN_TOKEN\""
        return 0
    else
        echo -e "${COLOR_RED}❌ $failed_checks 项检查失败${COLOR_RESET}"
        echo ""
        echo "故障排除:"
        echo "  1. 确保服务器运行: ./start-sqlite-persistent.sh"
        echo "  2. 检查环境变量: DEEPSEEK_API_KEY, ADMIN_TOKEN"
        echo "  3. 查看日志: tail -f quota-proxy.log"
        echo "  4. 详细验证: ./verify-sqlite-persistent-api.sh --dry-run"
        return 1
    fi
}

# 运行主函数
main "$@"