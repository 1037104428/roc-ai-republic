#!/bin/bash
# 验证 quota-proxy SQLite 数据库是否正常工作
set -e

echo "🔍 验证 SQLite 数据库状态..."

# 检查本地SQLite文件
if [ -f "quota-proxy.db" ]; then
    echo "✅ 本地 quota-proxy.db 存在"
    sqlite3 quota-proxy.db "SELECT COUNT(*) FROM quota_usage;" 2>/dev/null || echo "⚠️  无法查询 quota_usage 表（可能为空）"
    sqlite3 quota-proxy.db "SELECT COUNT(*) FROM api_keys;" 2>/dev/null || echo "⚠️  无法查询 api_keys 表（可能为空）"
else
    echo "⚠️  本地 quota-proxy.db 不存在（正常，如果从未运行过）"
fi

# 检查远程服务器
if [ "$1" = "--remote" ] || [ "$1" = "-r" ]; then
    SERVER=${2:-$(cat /tmp/server.txt 2>/dev/null | cut -d= -f2)}
    if [ -z "$SERVER" ]; then
        echo "❌ 未指定服务器且 /tmp/server.txt 不存在"
        exit 1
    fi
    
    echo "🌐 检查远程服务器 $SERVER..."
    ssh root@$SERVER "cd /opt/roc/quota-proxy && \
        if [ -f quota-proxy.db ]; then \
            echo '✅ 远程 quota-proxy.db 存在'; \
            sqlite3 quota-proxy.db 'SELECT COUNT(*) FROM quota_usage;' 2>/dev/null || echo '⚠️  无法查询 quota_usage 表'; \
            sqlite3 quota-proxy.db 'SELECT COUNT(*) FROM api_keys;' 2>/dev/null || echo '⚠️  无法查询 api_keys 表'; \
        else \
            echo '⚠️  远程 quota-proxy.db 不存在（可能还在内存模式）'; \
        fi && \
        docker compose ps && \
        curl -fsS http://127.0.0.1:8787/healthz"
fi

echo ""
echo "📊 验证完成！如果看到表计数或健康状态，说明 SQLite 数据库工作正常。"
