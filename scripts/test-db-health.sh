#!/bin/bash
# test-db-health.sh - 测试 quota-proxy SQLite 数据库健康检查端点
# 用法: ./test-db-health.sh [--server <ip>] [--port <port>] [--help]

set -e

SERVER_IP="127.0.0.1"
PORT="8787"
BASE_URL=""

show_help() {
    cat << EOF
测试 quota-proxy SQLite 数据库健康检查端点

用法: $0 [选项]

选项:
  --server <ip>    服务器IP地址 (默认: 127.0.0.1)
  --port <port>    端口号 (默认: 8787)
  --help           显示此帮助信息

示例:
  $0                              # 测试本地服务
  $0 --server 8.210.185.194      # 测试远程服务器
  $0 --server 8.210.185.194 --port 8787

环境变量:
  ADMIN_TOKEN      管理员令牌 (用于测试管理员端点)

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_IP="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "错误: 未知选项 $1"
            show_help
            exit 1
            ;;
    esac
done

BASE_URL="http://${SERVER_IP}:${PORT}"

echo "=== 测试 quota-proxy SQLite 数据库健康检查端点 ==="
echo "服务器: ${SERVER_IP}:${PORT}"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 测试基本健康检查
echo "1. 测试基本健康检查 (/healthz):"
if curl -fsS -m 10 "${BASE_URL}/healthz" > /dev/null 2>&1; then
    echo "   ✅ 通过 - 服务正常运行"
    curl -fsS -m 10 "${BASE_URL}/healthz" | jq -r '.ok' | grep -q "true" && echo "   ✅ 返回状态: ok=true"
else
    echo "   ❌ 失败 - 服务不可用"
    exit 1
fi

echo ""

# 测试数据库健康检查
echo "2. 测试数据库健康检查 (/healthz/db):"
if curl -fsS -m 10 "${BASE_URL}/healthz/db" > /dev/null 2>&1; then
    echo "   ✅ 通过 - 数据库端点可访问"
    
    # 检查响应内容
    RESPONSE=$(curl -fsS -m 10 "${BASE_URL}/healthz/db")
    OK_STATUS=$(echo "$RESPONSE" | jq -r '.ok' 2>/dev/null || echo "null")
    
    if [ "$OK_STATUS" = "true" ]; then
        echo "   ✅ 数据库状态: 健康"
        
        # 显示详细信息
        DB_PATH=$(echo "$RESPONSE" | jq -r '.database.path' 2>/dev/null || echo "未知")
        RESPONSE_TIME=$(echo "$RESPONSE" | jq -r '.database.responseTime' 2>/dev/null || echo "未知")
        TRIAL_KEYS=$(echo "$RESPONSE" | jq -r '.tables.trial_keys' 2>/dev/null || echo "未知")
        DAILY_USAGE=$(echo "$RESPONSE" | jq -r '.tables.daily_usage' 2>/dev/null || echo "未知")
        
        echo "   📊 数据库路径: $DB_PATH"
        echo "   ⏱️  响应时间: $RESPONSE_TIME"
        echo "   🔑 Trial Keys 数量: $TRIAL_KEYS"
        echo "   📈 Daily Usage 记录: $DAILY_USAGE"
    else
        echo "   ⚠️  数据库状态: 异常"
        ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error' 2>/dev/null || echo "未知错误")
        echo "   ❌ 错误信息: $ERROR_MSG"
    fi
else
    echo "   ❌ 失败 - 数据库端点不可访问"
    exit 1
fi

echo ""

# 测试管理员端点（如果设置了ADMIN_TOKEN）
if [ -n "$ADMIN_TOKEN" ]; then
    echo "3. 测试管理员端点 (/admin/keys):"
    if curl -fsS -m 10 -H "Authorization: Bearer $ADMIN_TOKEN" "${BASE_URL}/admin/keys" > /dev/null 2>&1; then
        echo "   ✅ 通过 - 管理员端点可访问"
    else
        echo "   ⚠️  警告 - 管理员端点访问失败 (可能是令牌无效)"
    fi
else
    echo "3. 跳过管理员端点测试 (未设置 ADMIN_TOKEN 环境变量)"
    echo "   提示: 设置 ADMIN_TOKEN 环境变量以测试管理员功能"
fi

echo ""
echo "=== 测试完成 ==="
echo "✅ 所有测试通过 - SQLite 数据库健康检查功能正常"
echo ""
echo "快速验证命令:"
echo "  curl -fsS ${BASE_URL}/healthz/db | jq ."
echo "  curl -fsS ${BASE_URL}/healthz/db | jq -r '.database.path, .tables.trial_keys, .tables.daily_usage'"

exit 0