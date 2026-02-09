#!/bin/bash
set -e

echo "🔍 快速验证 SQLite 数据库状态"

# 检查本地文件
echo "📁 检查本地 SQLite 相关文件:"
ls -la quota-proxy/server-*.js 2>/dev/null | grep -E "sqlite|better" || echo "⚠️  未找到 SQLite 服务器文件"
ls -la scripts/*sqlite*.sh 2>/dev/null || echo "⚠️  未找到 SQLite 脚本"

# 检查服务器状态（如果可用）
if [ -f "/tmp/server.txt" ]; then
    SERVER_IP=$(grep -o 'ip=[0-9.]*' /tmp/server.txt | cut -d= -f2)
    if [ -n "$SERVER_IP" ]; then
        echo ""
        echo "🖥️  检查服务器 SQLite 状态 ($SERVER_IP):"
        
        # 检查是否有 SQLite 数据库文件
        if ssh root@$SERVER_IP "test -f /opt/roc/quota-proxy/quota.db" 2>/dev/null; then
            echo "✅ 服务器上存在 quota.db 数据库文件"
            
            # 检查数据库大小
            DB_SIZE=$(ssh root@$SERVER_IP "stat -c%s /opt/roc/quota-proxy/quota.db 2>/dev/null || echo '0'")
            echo "📊 数据库大小: $DB_SIZE 字节"
            
            # 尝试查询数据库（如果 sqlite3 命令可用）
            if ssh root@$SERVER_IP "which sqlite3 >/dev/null 2>&1"; then
                echo "📋 数据库表结构:"
                ssh root@$SERVER_IP "sqlite3 /opt/roc/quota-proxy/quota.db '.tables'" 2>/dev/null || echo "❌ 无法读取数据库表"
            fi
        else
            echo "⚠️  服务器上未找到 quota.db 数据库文件"
        fi
        
        # 检查当前运行的 Docker 容器
        echo ""
        echo "🐳 检查当前运行的容器:"
        ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps" 2>/dev/null || echo "❌ 无法检查容器状态"
    fi
fi

# 检查健康端点
echo ""
echo "🏥 检查健康端点:"
if [ -f "/tmp/server.txt" ]; then
    SERVER_IP=$(grep -o 'ip=[0-9.]*' /tmp/server.txt | cut -d= -f2)
    if curl -fsS -m 5 "http://$SERVER_IP:8787/healthz" 2>/dev/null; then
        echo "✅ 健康端点正常"
    else
        echo "❌ 健康端点不可达"
    fi
fi

echo ""
echo "📝 SQLite 部署状态总结:"
echo "1. 本地文件: $(ls quota-proxy/server-*.js 2>/dev/null | grep -c sqlite || echo 0) 个 SQLite 服务器文件"
echo "2. 本地脚本: $(ls scripts/*sqlite*.sh 2>/dev/null | wc -l) 个 SQLite 相关脚本"
echo "3. 服务器数据库: $(ssh root@$SERVER_IP "test -f /opt/roc/quota-proxy/quota.db && echo '存在' || echo '不存在'" 2>/dev/null || echo '未知')"
echo "4. 健康端点: $(curl -fsS -m 5 "http://$SERVER_IP:8787/healthz" >/dev/null 2>&1 && echo '正常' || echo '异常')"

echo ""
echo "✅ 快速验证完成"