#!/bin/bash
# 测试Quota Proxy管理接口
# 用法: ./test-admin-interface.sh [--local|--remote] [--admin-token TOKEN]

set -e

# 默认配置
MODE="local"
ADMIN_TOKEN="${ADMIN_TOKEN:-dev-admin-token-change-in-production}"
BASE_URL="http://localhost:8787"
SERVER_IP=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            BASE_URL="http://localhost:8787"
            shift
            ;;
        --remote)
            MODE="remote"
            if [[ -f "/tmp/server.txt" ]]; then
                SERVER_IP=$(grep -oP 'ip:\K[0-9.]+' /tmp/server.txt)
                BASE_URL="http://${SERVER_IP}:8787"
            else
                echo "错误: /tmp/server.txt 文件不存在，无法获取远程服务器IP"
                exit 1
            fi
            shift
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --local             测试本地服务 (默认)"
            echo "  --remote            测试远程服务器"
            echo "  --admin-token TOKEN 指定管理员令牌"
            echo "  --help              显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done

echo "=== Quota Proxy 管理接口测试 ==="
echo "模式: $MODE"
echo "基础URL: $BASE_URL"
echo "管理员令牌: ${ADMIN_TOKEN:0:10}..."
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local description="$4"
    
    echo -n "测试: $description ... "
    
    local curl_cmd="curl -s -X $method '$BASE_URL$endpoint' \
        -H 'Authorization: Bearer $ADMIN_TOKEN' \
        -H 'Content-Type: application/json'"
    
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    local response
    response=$(eval $curl_cmd 2>/dev/null || echo '{"error":"curl_failed"}')
    
    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ 成功${NC}"
        return 0
    elif echo "$response" | grep -q '"ok":true'; then
        echo -e "${GREEN}✓ 成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        echo "  响应: $response"
        return 1
    fi
}

# 健康检查
echo -n "健康检查 ... "
if curl -fsS "$BASE_URL/healthz" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 服务运行正常${NC}"
else
    echo -e "${RED}✗ 服务不可用${NC}"
    exit 1
fi

echo ""
echo "=== 开始测试管理接口 ==="

# 1. 测试创建试用密钥
test_endpoint "POST" "/admin/keys" '{"label":"测试密钥-接口测试","totalQuota":100}' "创建试用密钥"

# 2. 测试获取密钥列表
test_endpoint "GET" "/admin/keys" "" "获取密钥列表"

# 3. 测试使用情况查询
test_endpoint "GET" "/admin/usage" "" "查询使用情况"

# 4. 测试数据库性能统计
test_endpoint "GET" "/admin/performance" "" "数据库性能统计"

# 5. 测试管理界面HTML
echo -n "测试: 管理界面HTML ... "
if curl -fsS "$BASE_URL/admin" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 可访问${NC}"
else
    echo -e "${YELLOW}⚠ 不可访问（可能未启用）${NC}"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo "管理界面访问地址:"
echo "  $BASE_URL/admin"
echo ""
echo "API调用示例:"
echo "  创建密钥: curl -X POST '$BASE_URL/admin/keys' \\"
echo "    -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"label\":\"新用户\",\"totalQuota\":1000}'"
echo ""
echo "  查看使用情况: curl -X GET '$BASE_URL/admin/usage' \\"
echo "    -H 'Authorization: Bearer \$ADMIN_TOKEN'"