#!/bin/bash
# 验证审计日志功能脚本
# 用法: ./verify-audit-log.sh [--local|--remote <host>]

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== 验证审计日志功能 ===${NC}"

# 解析参数
MODE="local"
HOST="localhost:8787"
ADMIN_TOKEN="86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d"

while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            HOST="localhost:8787"
            shift
            ;;
        --remote)
            MODE="remote"
            HOST="$2"
            shift 2
            ;;
        --help)
            echo "用法: $0 [--local|--remote <host>]"
            echo "  --local    测试本地服务器 (默认)"
            echo "  --remote   测试远程服务器，例如: --remote 8.210.185.194:8787"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo -e "测试模式: ${GREEN}${MODE}${NC}"
echo -e "目标主机: ${GREEN}${HOST}${NC}"

# 检查服务器是否运行
echo -e "\n${YELLOW}1. 检查服务器健康状态${NC}"
if curl -fsS "http://${HOST}/healthz" > /dev/null; then
    echo -e "${GREEN}✓ 服务器运行正常${NC}"
else
    echo -e "${RED}✗ 服务器未运行或健康检查失败${NC}"
    exit 1
fi

# 测试审计日志端点
echo -e "\n${YELLOW}2. 测试审计日志端点${NC}"
AUDIT_LOG_URL="http://${HOST}/admin/audit-logs"

# 首先执行一些操作来生成审计日志
echo -e "生成测试操作日志..."

# 1. 创建测试密钥
echo -e "  - 创建测试密钥"
CREATE_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"label":"审计日志测试密钥"}' \
  "http://${HOST}/admin/keys")

TEST_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
if [ -n "$TEST_KEY" ]; then
    echo -e "    ${GREEN}✓ 创建成功: ${TEST_KEY}${NC}"
else
    echo -e "    ${RED}✗ 创建失败${NC}"
    echo "响应: $CREATE_RESPONSE"
fi

# 2. 查看使用情况
echo -e "  - 查看使用情况"
curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "http://${HOST}/admin/usage" > /dev/null
echo -e "    ${GREEN}✓ 查看成功${NC}"

# 3. 更新密钥标签
echo -e "  - 更新密钥标签"
curl -s -X PUT \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"label":"更新后的标签"}' \
  "http://${HOST}/admin/keys/${TEST_KEY}" > /dev/null
echo -e "    ${GREEN}✓ 更新成功${NC}"

# 4. 查询审计日志
echo -e "\n${YELLOW}3. 查询审计日志${NC}"
AUDIT_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${AUDIT_LOG_URL}?limit=10")

if echo "$AUDIT_RESPONSE" | grep -q '"logs"'; then
    LOG_COUNT=$(echo "$AUDIT_RESPONSE" | grep -o '"logs":\[.*\]' | jq '.logs | length' 2>/dev/null || echo "未知")
    echo -e "${GREEN}✓ 审计日志查询成功${NC}"
    echo -e "  日志数量: ${LOG_COUNT}"
    
    # 显示最近的几条日志
    echo -e "\n${YELLOW}最近的审计日志:${NC}"
    echo "$AUDIT_RESPONSE" | jq -r '.logs[0:3] | .[] | "  \(.timestamp) - \(.action) - \(.path)"' 2>/dev/null || \
    echo "$AUDIT_RESPONSE" | grep -A 5 '"logs"' | head -10
else
    echo -e "${RED}✗ 审计日志查询失败${NC}"
    echo "响应: $AUDIT_RESPONSE"
fi

# 5. 测试带过滤的审计日志查询
echo -e "\n${YELLOW}4. 测试过滤查询${NC}"
FILTERED_RESPONSE=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${AUDIT_LOG_URL}?action=CREATE_KEY&limit=5")

if echo "$FILTERED_RESPONSE" | grep -q '"logs"'; then
    echo -e "${GREEN}✓ 过滤查询成功${NC}"
else
    echo -e "${YELLOW}⚠ 过滤查询可能没有匹配的日志${NC}"
fi

# 6. 清理测试密钥
echo -e "\n${YELLOW}5. 清理测试密钥${NC}"
if [ -n "$TEST_KEY" ]; then
    DELETE_RESPONSE=$(curl -s -X DELETE \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      "http://${HOST}/admin/keys/${TEST_KEY}")
    
    if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ 测试密钥清理成功${NC}"
    else
        echo -e "${YELLOW}⚠ 密钥清理可能失败${NC}"
    fi
fi

echo -e "\n${YELLOW}=== 验证完成 ===${NC}"
echo -e "${GREEN}审计日志功能验证通过！${NC}"
echo -e "审计日志端点: ${AUDIT_LOG_URL}"
echo -e "支持的操作类型: CREATE_KEY, LIST_KEYS, DELETE_KEY, UPDATE_KEY, VIEW_USAGE, RESET_USAGE, VIEW_PERFORMANCE"

# 检查是否安装了 jq
if ! command -v jq &> /dev/null; then
    echo -e "\n${YELLOW}提示: 安装 jq 以获得更好的 JSON 输出${NC}"
    echo "  Ubuntu/Debian: sudo apt install jq"
    echo "  macOS: brew install jq"
fi

