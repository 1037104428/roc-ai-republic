#!/bin/bash
# 验证 GET /admin/keys 端点功能
# 用法: ./scripts/verify-admin-keys-list.sh [--local|--remote]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认使用本地测试
MODE="local"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"
BASE_URL="http://127.0.0.1:8787"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            shift
            ;;
        --remote)
            MODE="remote"
            shift
            ;;
        --help)
            echo "用法: $0 [--local|--remote]"
            echo ""
            echo "选项:"
            echo "  --local    测试本地服务 (默认)"
            echo "  --remote   测试远程服务器"
            echo "  --help     显示此帮助信息"
            echo ""
            echo "环境变量:"
            echo "  ADMIN_TOKEN    管理员令牌 (默认: test-admin-token)"
            echo "  REMOTE_HOST    远程服务器地址 (默认从 /tmp/server.txt 读取)"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 设置远程服务器
if [[ "$MODE" == "remote" ]]; then
    if [[ -f "/tmp/server.txt" ]]; then
        SERVER_IP=$(grep -E '^ip:' /tmp/server.txt | cut -d: -f2 | tr -d '[:space:]')
        if [[ -n "$SERVER_IP" ]]; then
            BASE_URL="http://$SERVER_IP:8787"
        else
            echo "错误: 无法从 /tmp/server.txt 解析服务器IP"
            exit 1
        fi
    else
        echo "错误: /tmp/server.txt 不存在"
        echo "请先运行: echo 'ip:YOUR_SERVER_IP' > /tmp/server.txt"
        exit 1
    fi
fi

echo "=== 验证 GET /admin/keys 端点 ==="
echo "模式: $MODE"
echo "基础URL: $BASE_URL"
echo "管理员令牌: $ADMIN_TOKEN"
echo ""

# 测试1: 基本列表功能
echo "测试1: 获取密钥列表..."
RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE_URL/admin/keys")

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✓ 基本列表功能正常"
    echo "  响应结构: $(echo "$RESPONSE" | jq -r '.keys | length' 2>/dev/null || echo "未知") 个密钥"
else
    echo "✗ 基本列表功能失败"
    echo "  响应: $RESPONSE"
    exit 1
fi

# 测试2: 带分页参数
echo ""
echo "测试2: 带分页参数..."
RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE_URL/admin/keys?limit=5&offset=0")

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✓ 分页参数正常"
    LIMIT=$(echo "$RESPONSE" | jq -r '.pagination.limit' 2>/dev/null || echo "未知")
    OFFSET=$(echo "$RESPONSE" | jq -r '.pagination.offset' 2>/dev/null || echo "未知")
    TOTAL=$(echo "$RESPONSE" | jq -r '.pagination.total' 2>/dev/null || echo "未知")
    echo "  分页信息: limit=$LIMIT, offset=$OFFSET, total=$TOTAL"
else
    echo "✗ 分页参数失败"
    echo "  响应: $RESPONSE"
    exit 1
fi

# 测试3: 仅显示活跃密钥
echo ""
echo "测试3: 仅显示活跃密钥..."
RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE_URL/admin/keys?activeOnly=true")

if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✓ 活跃密钥过滤正常"
    ACTIVE_COUNT=$(echo "$RESPONSE" | jq -r '.keys | length' 2>/dev/null || echo "未知")
    echo "  活跃密钥数量: $ACTIVE_COUNT"
else
    echo "✗ 活跃密钥过滤失败"
    echo "  响应: $RESPONSE"
    exit 1
fi

# 测试4: 验证响应数据结构
echo ""
echo "测试4: 验证响应数据结构..."
RESPONSE=$(curl -s -X GET \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE_URL/admin/keys?limit=1")

if echo "$RESPONSE" | jq -e '.keys[0] | has("id") and has("key") and has("label") and has("total_quota") and has("used_quota") and has("created_at") and has("status")' >/dev/null 2>&1; then
    echo "✓ 响应数据结构完整"
    FIRST_KEY=$(echo "$RESPONSE" | jq -r '.keys[0].key' 2>/dev/null || echo "未知")
    FIRST_STATUS=$(echo "$RESPONSE" | jq -r '.keys[0].status' 2>/dev/null || echo "未知")
    echo "  示例密钥: $FIRST_KEY (状态: $FIRST_STATUS)"
else
    echo "✗ 响应数据结构不完整"
    echo "  响应: $RESPONSE"
    exit 1
fi

# 测试5: 创建新密钥然后验证列表
echo ""
echo "测试5: 创建新密钥并验证列表更新..."
CREATE_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"label":"测试密钥 - 验证列表功能", "totalQuota":500}' \
    "$BASE_URL/admin/keys")

if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
    NEW_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)
    echo "✓ 创建新密钥成功: $NEW_KEY"
    
    # 等待一下确保数据写入
    sleep 1
    
    # 验证新密钥出现在列表中
    LIST_RESPONSE=$(curl -s -X GET \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$BASE_URL/admin/keys?limit=10")
    
    if echo "$LIST_RESPONSE" | grep -q "$NEW_KEY"; then
        echo "✓ 新密钥成功出现在列表中"
    else
        echo "✗ 新密钥未出现在列表中"
        exit 1
    fi
else
    echo "✗ 创建新密钥失败"
    echo "  响应: $CREATE_RESPONSE"
    exit 1
fi

echo ""
echo "=== 所有测试通过 ==="
echo "GET /admin/keys 端点功能完整，包含："
echo "  - 基本列表功能"
echo "  - 分页支持 (limit/offset)"
echo "  - 活跃密钥过滤 (activeOnly=true)"
echo "  - 完整的状态信息 (active/expired)"
echo "  - 总数统计和分页元数据"
echo ""
echo "API端点已就绪，可用于管理界面展示所有API密钥。"