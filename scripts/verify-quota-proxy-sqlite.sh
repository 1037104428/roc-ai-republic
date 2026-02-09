#!/bin/bash
# 快速验证 quota-proxy SQLite 版本部署状态

set -e

echo "🔍 验证 quota-proxy SQLite 部署状态"

# 检查本地文件
echo "📁 检查本地文件..."
if [ ! -f "quota-proxy/server-sqlite.js" ]; then
    echo "❌ 缺少 server-sqlite.js"
    exit 1
fi

if [ ! -f "quota-proxy/compose.yaml" ]; then
    echo "❌ 缺少 compose.yaml"
    exit 1
fi

if [ ! -f "scripts/deploy-quota-proxy-sqlite.sh" ]; then
    echo "❌ 缺少 deploy-quota-proxy-sqlite.sh"
    exit 1
fi

echo "✅ 本地文件检查通过"

# 检查部署脚本语法
echo "📝 检查部署脚本语法..."
bash -n scripts/deploy-quota-proxy-sqlite.sh
echo "✅ 部署脚本语法检查通过"

# 检查服务器状态（如果 SERVER_FILE 存在）
if [ -f "/tmp/server.txt" ]; then
    echo "🌐 检查服务器状态..."
    SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [ -n "$SERVER_IP" ]; then
        echo "📡 连接到服务器 $SERVER_IP..."
        if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
            "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep -q quota-proxy && echo '✅ 容器运行中'"; then
            echo "✅ 服务器容器状态正常"
            
            # 检查健康端点
            if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
                "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null | grep -q '\"ok\":true' && echo '✅ 健康检查通过'"; then
                echo "✅ 服务器健康检查通过"
            else
                echo "⚠️  健康检查失败（可能正常，如果未部署SQLite版本）"
            fi
        else
            echo "⚠️  服务器容器未运行（可能正常，如果未部署SQLite版本）"
        fi
    else
        echo "⚠️  无法从 /tmp/server.txt 解析服务器IP"
    fi
else
    echo "ℹ️  跳过服务器检查（/tmp/server.txt 不存在）"
fi

# 检查文档
echo "📚 检查相关文档..."
if [ -f "docs/deploy-quota-proxy-sqlite.md" ]; then
    echo "✅ SQLite部署文档存在"
else
    echo "⚠️  缺少 SQLite部署文档"
fi

if [ -f "docs/sqlite-migration-guide.md" ]; then
    echo "✅ SQLite迁移指南存在"
else
    echo "⚠️  缺少 SQLite迁移指南"
fi

echo ""
echo "🎉 验证完成！"
echo ""
echo "下一步："
echo "1. 部署SQLite版本: ./scripts/deploy-quota-proxy-sqlite.sh"
echo "2. 验证部署: ./scripts/verify-sqlite-deployment.sh"
echo "3. 检查数据库: ssh root@服务器IP 'cd /opt/roc/quota-proxy && [ -f data/quota.db ] && echo \"SQLite数据库存在\"'"
echo "4. 查看文档: docs/deploy-quota-proxy-sqlite.md"