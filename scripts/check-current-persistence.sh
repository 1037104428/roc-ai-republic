#!/bin/bash
# 检查 quota-proxy 当前实际的持久化模式（JSON/SQLite/内存）
# 用法：./scripts/check-current-persistence.sh [base_url]

set -e

BASE_URL="${1:-http://127.0.0.1:8787}"
HEALTH_URL="$BASE_URL/healthz"
ADMIN_KEYS_URL="$BASE_URL/admin/keys"

echo "🔍 检查 quota-proxy 持久化模式 ($BASE_URL)"
echo "=========================================="

# 1. 检查健康状态
echo "1. 健康检查..."
if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    echo "   ✅ 服务健康"
else
    echo "   ❌ 服务不可达"
    exit 1
fi

# 2. 检查环境变量提示（如果有的话）
echo "2. 检查持久化配置提示..."
if curl -fsS "$HEALTH_URL" | grep -q "persistence"; then
    echo "   ℹ️  健康端点包含持久化信息"
    curl -fsS "$HEALTH_URL" | grep -i "persistence\|sqlite\|json\|memory" || true
else
    echo "   ℹ️  健康端点未明确持久化模式"
fi

# 3. 检查数据目录（如果本地）
echo "3. 检查本地数据文件..."
if [ -f "/data/quota-proxy.json" ]; then
    echo "   📁 找到 JSON 持久化文件: /data/quota-proxy.json"
    echo "   📊 文件大小: $(stat -c%s /data/quota-proxy.json) 字节"
elif [ -f "/data/quota-proxy.db" ]; then
    echo "   📁 找到 SQLite 数据库: /data/quota-proxy.db"
    echo "   📊 文件大小: $(stat -c%s /data/quota-proxy.db) 字节"
else
    echo "   ℹ️  未找到标准数据文件（可能是内存模式或不同路径）"
fi

# 4. 检查环境变量
echo "4. 检查相关环境变量..."
if [ -n "$SQLITE_PATH" ]; then
    echo "   🔧 SQLITE_PATH=$SQLITE_PATH"
    if [[ "$SQLITE_PATH" == *.json ]]; then
        echo "   📝 注意：SQLITE_PATH 指向 .json 文件（当前为 JSON 持久化）"
    elif [[ "$SQLITE_PATH" == *.db ]]; then
        echo "   📝 注意：SQLITE_PATH 指向 .db 文件（SQLite 持久化）"
    fi
else
    echo "   ℹ️  SQLITE_PATH 未设置（可能是内存模式）"
fi

echo ""
echo "📋 总结："
echo "------------------------------------------"
echo "当前实现：JSON 文件持久化（v0.1）"
echo "环境变量：SQLITE_PATH 指向 JSON 文件"
echo "升级计划：未来会迁移到真正的 SQLite 数据库"
echo ""
echo "💡 验证命令："
echo "  # 检查健康状态"
echo "  curl -fsS $HEALTH_URL"
echo ""
echo "  # 查看数据文件（如果存在）"
echo "  ls -la /data/quota-proxy.* 2>/dev/null || echo '无数据文件'"
echo ""
echo "  # 检查环境变量"
echo "  echo \"SQLITE_PATH=\$SQLITE_PATH\""

exit 0