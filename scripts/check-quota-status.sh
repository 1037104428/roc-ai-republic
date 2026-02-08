#!/bin/bash
# quota-proxy 状态检查脚本
# 快速查看服务状态、持久化模式和基本统计
# 用法: ./scripts/check-quota-status.sh [--url URL] [--admin-token TOKEN]

set -e

# 默认参数
QUOTA_URL="http://127.0.0.1:8787"
ADMIN_TOKEN=""
SHOW_DETAILS=false

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            QUOTA_URL="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --details)
            SHOW_DETAILS=true
            shift
            ;;
        --help)
            echo "quota-proxy 状态检查脚本"
            echo "用法: $0 [--url URL] [--admin-token TOKEN] [--details]"
            echo ""
            echo "参数:"
            echo "  --url URL          quota-proxy URL (默认: $QUOTA_URL)"
            echo "  --admin-token TOKEN 管理员令牌 (可选，用于获取详细统计)"
            echo "  --details          显示详细信息"
            echo "  --help             显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🔍 quota-proxy 状态检查${NC}"
echo "目标地址: $QUOTA_URL"
echo ""

# 1. 检查健康状态
echo -e "${BLUE}1. 健康状态检查...${NC}"
if curl -fsS --max-time 5 "${QUOTA_URL}/healthz" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ 健康检查通过${NC}"
    
    # 获取健康响应详情
    HEALTH_RESPONSE=$(curl -fsS --max-time 5 "${QUOTA_URL}/healthz" 2>/dev/null || echo "{}")
    if echo "$HEALTH_RESPONSE" | grep -q '"ok":true'; then
        echo -e "   ${GREEN}✅ 健康响应正常: $HEALTH_RESPONSE${NC}"
    else
        echo -e "   ${YELLOW}⚠️  健康响应异常: $HEALTH_RESPONSE${NC}"
    fi
else
    echo -e "   ${RED}❌ 健康检查失败${NC}"
    echo "   可能原因:"
    echo "   - 服务未运行"
    echo "   - 网络不可达"
    echo "   - 端口不正确"
    exit 1
fi

echo ""

# 2. 检查持久化配置提示
echo -e "${BLUE}2. 持久化配置分析...${NC}"
echo "   ℹ️  当前实现说明:"
echo "   - 环境变量 SQLITE_PATH 指向持久化文件路径"
echo "   - 当前版本: v0.1 (JSON文件持久化)"
echo "   - 文件扩展名可能是 .sqlite 但实际内容是 JSON 格式"
echo "   - 未来 v1.0 将迁移到真正的 SQLite 数据库"

echo ""

# 3. 检查管理接口（如果提供了令牌）
if [ -n "$ADMIN_TOKEN" ]; then
    echo -e "${BLUE}3. 管理接口检查...${NC}"
    
    # 检查管理接口访问
    if curl -fsS --max-time 5 -H "Authorization: Bearer $ADMIN_TOKEN" \
        "${QUOTA_URL}/admin/usage?limit=1" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ 管理接口访问正常${NC}"
        
        # 获取今日用量统计
        TODAY=$(date +%F)
        USAGE_RESPONSE=$(curl -fsS --max-time 5 \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            "${QUOTA_URL}/admin/usage?day=${TODAY}" 2>/dev/null || echo "{}")
        
        if echo "$USAGE_RESPONSE" | grep -q '"items"'; then
            ITEM_COUNT=$(echo "$USAGE_RESPONSE" | jq -r '.items | length' 2>/dev/null || echo "0")
            echo -e "   ${GREEN}✅ 今日活跃 key 数量: $ITEM_COUNT${NC}"
            
            if [ "$SHOW_DETAILS" = true ] && [ "$ITEM_COUNT" -gt 0 ]; then
                echo "   详细统计:"
                echo "$USAGE_RESPONSE" | jq -r '.items[] | "    - \(.key): \(.req_count) 次请求"' 2>/dev/null || \
                    echo "    (无法解析详细统计)"
            fi
        else
            echo -e "   ${YELLOW}⚠️  无今日用量数据${NC}"
        fi
    else
        echo -e "   ${RED}❌ 管理接口访问失败${NC}"
        echo "   可能原因:"
        echo "   - ADMIN_TOKEN 不正确"
        echo "   - 管理接口未启用"
        echo "   - 持久化未配置"
    fi
else
    echo -e "${BLUE}3. 管理接口检查...${NC}"
    echo -e "   ${YELLOW}⚠️  未提供 ADMIN_TOKEN，跳过管理接口检查${NC}"
    echo "   提示: 使用 --admin-token 参数启用管理接口检查"
fi

echo ""

# 4. 服务状态总结
echo -e "${BLUE}📋 服务状态总结:${NC}"
echo -e "   ${GREEN}✅ 健康状态: 正常${NC}"
echo -e "   ${GREEN}✅ 服务地址: $QUOTA_URL${NC}"
echo -e "   ${YELLOW}🔸 持久化版本: v0.1 (JSON文件)${NC}"

if [ -n "$ADMIN_TOKEN" ]; then
    echo -e "   ${GREEN}✅ 管理接口: 已配置${NC}"
else
    echo -e "   ${YELLOW}🔸 管理接口: 未验证${NC}"
fi

echo ""

# 5. 建议和下一步
echo -e "${BLUE}💡 建议和下一步:${NC}"
echo "   1. 验证持久化文件:"
echo "      docker exec -it \$(docker ps -q -f name=quota-proxy) ls -la \$SQLITE_PATH"
echo ""
echo "   2. 生成 trial key (需要 ADMIN_TOKEN):"
echo "      curl -fsS -X POST $QUOTA_URL/admin/keys \\"
echo "        -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
echo "        -H 'content-type: application/json' \\"
echo "        -d '{\"label\":\"test-user\"}'"
echo ""
echo "   3. 查看详细用量:"
echo "      curl -fsS \"$QUOTA_URL/admin/usage?day=\$(date +%F)\" \\"
echo "        -H 'Authorization: Bearer \$ADMIN_TOKEN' | jq ."

echo ""
echo -e "${GREEN}✅ 状态检查完成${NC}"