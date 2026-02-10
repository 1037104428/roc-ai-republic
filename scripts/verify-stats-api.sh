#!/bin/bash
# 验证 quota-proxy 统计API功能
# 用法: ./verify-stats-api.sh [--local|--remote <host>] [--admin-token <token>]

set -e

# 默认配置
MODE="local"
HOST="localhost:8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-dev-admin-token-change-in-production}"
VERBOSE=false

# 解析参数
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
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --local                   测试本地实例 (默认)"
            echo "  --remote <host:port>      测试远程实例"
            echo "  --admin-token <token>     管理员令牌 (默认: \$ADMIN_TOKEN 或 dev-admin-token-change-in-production)"
            echo "  --verbose                 显示详细输出"
            echo "  --help                    显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

echo "=== 验证 quota-proxy 统计API功能 ==="
echo "模式: $MODE"
echo "主机: $HOST"
echo "管理员令牌: ${ADMIN_TOKEN:0:10}..."
echo ""

# 检查 curl 是否可用
if ! command -v curl &> /dev/null; then
    echo "错误: curl 未安装"
    exit 1
fi

# 检查健康状态
echo "1. 检查健康状态..."
if ! curl -fsS -m 5 "http://$HOST/healthz" > /dev/null 2>&1; then
    echo "   ❌ 健康检查失败: 无法连接到 http://$HOST/healthz"
    echo "   请确保 quota-proxy 正在运行"
    exit 1
fi
echo "   ✅ 健康检查通过"

# 测试统计API
echo ""
echo "2. 测试统计API端点..."
STATS_RESPONSE=$(curl -fsS -m 10 \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "http://$HOST/admin/stats" 2>/dev/null || echo "ERROR")

if [[ "$STATS_RESPONSE" == "ERROR" ]]; then
    echo "   ❌ 统计API请求失败"
    echo "   可能原因:"
    echo "   - 管理员令牌不正确"
    echo "   - 服务器未运行"
    echo "   - 网络连接问题"
    exit 1
fi

# 验证响应格式
if echo "$STATS_RESPONSE" | jq -e . > /dev/null 2>&1; then
    echo "   ✅ 统计API返回有效JSON"
    
    if $VERBOSE; then
        echo "   响应内容:"
        echo "$STATS_RESPONSE" | jq .
    else
        # 提取关键信息
        TIMESTAMP=$(echo "$STATS_RESPONSE" | jq -r '.timestamp // "N/A"')
        TOTAL_KEYS=$(echo "$STATS_RESPONSE" | jq -r '.database.total_keys // 0')
        ACTIVE_KEYS=$(echo "$STATS_RESPONSE" | jq -r '.database.active_keys // 0')
        TOTAL_REQUESTS=$(echo "$STATS_RESPONSE" | jq -r '.database.total_requests // 0')
        
        echo "   统计摘要:"
        echo "   - 时间戳: $TIMESTAMP"
        echo "   - 总密钥数: $TOTAL_KEYS"
        echo "   - 活跃密钥数: $ACTIVE_KEYS"
        echo "   - 总请求数: $TOTAL_REQUESTS"
    fi
else
    echo "   ⚠️  统计API返回非JSON响应"
    echo "   响应内容: $STATS_RESPONSE"
fi

# 测试无权限访问
echo ""
echo "3. 测试无权限访问..."
UNAUTH_RESPONSE=$(curl -fsS -m 5 "http://$HOST/admin/stats" 2>&1 || true)

if echo "$UNAUTH_RESPONSE" | grep -q "401\|Unauthorized\|Forbidden"; then
    echo "   ✅ 无权限访问被正确拒绝"
else
    echo "   ⚠️  无权限访问未返回预期错误"
    if $VERBOSE; then
        echo "   响应: $UNAUTH_RESPONSE"
    fi
fi

echo ""
echo "=== 验证完成 ==="
echo "✅ 统计API功能验证通过"
echo ""
echo "快速测试命令:"
echo "  curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" http://$HOST/admin/stats | jq ."
echo ""
echo "生产环境建议:"
echo "  1. 确保 ADMIN_TOKEN 设置为强密码"
echo "  2. 定期监控统计信息"
echo "  3. 考虑添加统计信息的历史记录"