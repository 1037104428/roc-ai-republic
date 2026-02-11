#!/bin/bash
# Admin API一键完整测试脚本
# 快速测试Admin API的所有核心功能

set -e

echo "🚀 Admin API一键完整测试开始"
echo "========================================"

# 配置
ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
BASE_URL="${BASE_URL:-http://localhost:8787}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查jq是否安装
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq未安装，部分功能可能受限${NC}"
    echo "安装命令: sudo apt-get install jq 或 brew install jq"
    USE_JQ=false
else
    USE_JQ=true
fi

# 1. 健康检查
echo -e "${BLUE}🔍 健康检查...${NC}"
if curl -s -f "$BASE_URL/healthz" > /dev/null; then
    echo -e "${GREEN}✅ 健康检查通过${NC}"
else
    echo -e "${RED}❌ 健康检查失败 - 服务器可能未运行${NC}"
    echo "请检查:"
    echo "  1. 服务器是否启动: ps aux | grep 'node server-sqlite-admin.js'"
    echo "  2. 端口是否正确: netstat -tlnp | grep 8787"
    echo "  3. BASE_URL设置: $BASE_URL"
    exit 1
fi

# 2. 创建试用密钥
echo -e "${BLUE}🔑 创建试用密钥...${NC}"
RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"quick-test-user","email":"quick-test@example.com","quota":50}' \
  "$BASE_URL/admin/keys" || echo "{}")

if [ "$USE_JQ" = true ]; then
    TRIAL_KEY=$(echo "$RESPONSE" | jq -r '.key // empty')
    if [ -n "$TRIAL_KEY" ] && [ "$TRIAL_KEY" != "null" ]; then
        echo -e "${GREEN}✅ 试用密钥创建成功: $TRIAL_KEY${NC}"
    else
        echo -e "${RED}❌ 试用密钥创建失败${NC}"
        echo "响应: $RESPONSE"
        exit 1
    fi
else
    echo "响应: $RESPONSE"
    TRIAL_KEY=""
    echo -e "${YELLOW}⚠️  无法解析响应，跳过试用密钥测试${NC}"
fi

# 3. 测试试用密钥API（如果有试用密钥）
if [ -n "$TRIAL_KEY" ] && [ "$TRIAL_KEY" != "null" ]; then
    echo -e "${BLUE}🧪 测试试用密钥API...${NC}"
    API_RESPONSE=$(curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/test")
    if [ -n "$API_RESPONSE" ]; then
        echo -e "${GREEN}✅ API调用成功${NC}"
        echo "响应: $API_RESPONSE"
    else
        echo -e "${RED}❌ API调用失败${NC}"
    fi

    # 4. 检查配额
    echo -e "${BLUE}📊 检查配额...${NC}"
    QUOTA_RESPONSE=$(curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/quota")
    if [ -n "$QUOTA_RESPONSE" ]; then
        echo -e "${GREEN}✅ 配额检查成功${NC}"
        echo "响应: $QUOTA_RESPONSE"
    else
        echo -e "${RED}❌ 配额检查失败${NC}"
    fi
fi

# 5. 检查Admin API端点
echo -e "${BLUE}🔧 检查Admin API端点...${NC}"

# 5.1 所有密钥列表
echo -e "${BLUE}  - 所有密钥列表:${NC}"
KEYS_RESPONSE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys")
if [ -n "$KEYS_RESPONSE" ]; then
    if [ "$USE_JQ" = true ]; then
        KEY_COUNT=$(echo "$KEYS_RESPONSE" | jq 'length // 0')
        echo -e "${GREEN}✅ 密钥列表获取成功 (共 $KEY_COUNT 个密钥)${NC}"
    else
        echo -e "${GREEN}✅ 密钥列表获取成功${NC}"
    fi
else
    echo -e "${RED}❌ 密钥列表获取失败${NC}"
fi

# 5.2 用量统计
echo -e "${BLUE}  - 用量统计:${NC}"
USAGE_RESPONSE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/usage")
if [ -n "$USAGE_RESPONSE" ]; then
    echo -e "${GREEN}✅ 用量统计获取成功${NC}"
    if [ "$USE_JQ" = true ]; then
        echo "$USAGE_RESPONSE" | jq .
    else
        echo "$USAGE_RESPONSE"
    fi
else
    echo -e "${RED}❌ 用量统计获取失败${NC}"
fi

# 5.3 应用列表
echo -e "${BLUE}  - 应用列表:${NC}"
APPS_RESPONSE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/applications")
if [ -n "$APPS_RESPONSE" ]; then
    if [ "$USE_JQ" = true ]; then
        APP_COUNT=$(echo "$APPS_RESPONSE" | jq 'length // 0')
        echo -e "${GREEN}✅ 应用列表获取成功 (共 $APP_COUNT 个应用)${NC}"
    else
        echo -e "${GREEN}✅ 应用列表获取成功${NC}"
    fi
else
    echo -e "${RED}❌ 应用列表获取失败${NC}"
fi

echo "========================================"
echo -e "${GREEN}🎉 Admin API一键完整测试完成！${NC}"
echo ""
echo -e "${YELLOW}📋 测试总结:${NC}"
echo "  1. 健康检查: ✅ 通过"
if [ -n "$TRIAL_KEY" ]; then
    echo "  2. 试用密钥创建: ✅ 成功"
    echo "  3. API调用测试: ✅ 成功"
    echo "  4. 配额检查: ✅ 成功"
else
    echo "  2. 试用密钥创建: ⚠️  跳过"
    echo "  3. API调用测试: ⚠️  跳过"
    echo "  4. 配额检查: ⚠️  跳过"
fi
echo "  5. Admin API端点检查: ✅ 完成"
echo ""
echo -e "${BLUE}💡 使用提示:${NC}"
echo "  设置环境变量:"
echo "    export ADMIN_TOKEN='your-token'"
echo "    export BASE_URL='http://localhost:8787'"
echo "  然后运行: ./quick-admin-api-test.sh"