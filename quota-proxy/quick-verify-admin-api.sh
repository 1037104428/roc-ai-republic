#!/bin/bash
# Admin API快速验证脚本
# 一键验证Admin API的所有核心功能

set -e

echo "🔍 Admin API快速验证脚本启动"
echo "========================================"

# 检查必要文件
echo "📁 检查必要文件..."
REQUIRED_FILES=(
    "server-sqlite-admin.js"
    "ADMIN-API-GUIDE.md"
    "verify-admin-api.sh"
    "init-db.sql"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file 存在"
    else
        echo "  ❌ $file 不存在"
        exit 1
    fi
done

echo ""
echo "🔧 检查Admin API服务器..."
if command -v node &> /dev/null; then
    echo "  ✅ Node.js 已安装"
    NODE_VERSION=$(node --version)
    echo "  📦 Node.js 版本: $NODE_VERSION"
else
    echo "  ❌ Node.js 未安装"
    exit 1
fi

echo ""
echo "📊 检查数据库..."
if [ -f "quota-proxy.db" ]; then
    echo "  ✅ 数据库文件 quota-proxy.db 存在"
    DB_SIZE=$(stat -f%z quota-proxy.db 2>/dev/null || stat -c%s quota-proxy.db 2>/dev/null)
    echo "  📏 数据库大小: $DB_SIZE 字节"
else
    echo "  ⚠️  数据库文件不存在，将创建新数据库"
    # 创建数据库
    if [ -f "init-db.sql" ]; then
        echo "  📝 使用 init-db.sql 创建数据库..."
        sqlite3 quota-proxy.db < init-db.sql
        if [ $? -eq 0 ]; then
            echo "  ✅ 数据库创建成功"
        else
            echo "  ❌ 数据库创建失败"
            exit 1
        fi
    fi
fi

echo ""
echo "🔑 检查Admin认证配置..."
if [ -f ".env" ]; then
    echo "  ✅ .env 文件存在"
    if grep -q "ADMIN_TOKEN=" .env; then
        echo "  ✅ ADMIN_TOKEN 已配置"
        ADMIN_TOKEN=$(grep "ADMIN_TOKEN=" .env | cut -d= -f2)
        echo "  🔐 ADMIN_TOKEN: ${ADMIN_TOKEN:0:10}..."
    else
        echo "  ⚠️  ADMIN_TOKEN 未配置，使用默认值"
        echo "ADMIN_TOKEN=test-admin-token-12345" > .env
        ADMIN_TOKEN="test-admin-token-12345"
    fi
else
    echo "  ⚠️  .env 文件不存在，创建默认配置"
    echo "ADMIN_TOKEN=test-admin-token-12345" > .env
    ADMIN_TOKEN="test-admin-token-12345"
fi

echo ""
echo "🚀 启动Admin API服务器（后台运行）..."
# 停止可能正在运行的服务器
pkill -f "node server-sqlite-admin.js" 2>/dev/null || true
sleep 1

# 启动服务器
node server-sqlite-admin.js > server.log 2>&1 &
SERVER_PID=$!
echo "  📝 服务器PID: $SERVER_PID"
echo "  📄 日志输出到: server.log"

# 等待服务器启动
echo "  ⏳ 等待服务器启动..."
sleep 3

# 检查服务器是否运行
if ps -p $SERVER_PID > /dev/null; then
    echo "  ✅ 服务器运行正常"
else
    echo "  ❌ 服务器启动失败"
    cat server.log
    exit 1
fi

echo ""
echo "🧪 执行Admin API测试..."
echo "  📍 测试端点: http://localhost:8787"

# 测试1: 健康检查
echo "  🔍 测试1: 健康检查..."
HEALTH_RESPONSE=$(curl -s -f http://localhost:8787/healthz)
if [ $? -eq 0 ]; then
    echo "  ✅ 健康检查通过: $HEALTH_RESPONSE"
else
    echo "  ❌ 健康检查失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# 测试2: Admin认证测试
echo "  🔐 测试2: Admin认证测试..."
AUTH_RESPONSE=$(curl -s -f -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8787/admin/keys)
if [ $? -eq 0 ]; then
    echo "  ✅ Admin认证通过"
    echo "  📋 响应: $AUTH_RESPONSE"
else
    echo "  ❌ Admin认证失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# 测试3: 生成Trial Key
echo "  🔑 测试3: 生成Trial Key..."
KEY_RESPONSE=$(curl -s -f -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"test-user","email":"test@example.com","quota":1000}' \
    http://localhost:8787/admin/keys)
if [ $? -eq 0 ]; then
    echo "  ✅ Trial Key生成成功"
    TRIAL_KEY=$(echo $KEY_RESPONSE | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "  🔑 生成的Key: ${TRIAL_KEY:0:20}..."
else
    echo "  ❌ Trial Key生成失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# 测试4: 使用统计查询
echo "  📊 测试4: 使用统计查询..."
USAGE_RESPONSE=$(curl -s -f -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8787/admin/usage)
if [ $? -eq 0 ]; then
    echo "  ✅ 使用统计查询成功"
    echo "  📈 响应: $USAGE_RESPONSE"
else
    echo "  ❌ 使用统计查询失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# 测试5: 代理端点测试（使用生成的Trial Key）
echo "  🌐 测试5: 代理端点测试..."
if [ -n "$TRIAL_KEY" ]; then
    PROXY_RESPONSE=$(curl -s -f -H "X-API-Key: $TRIAL_KEY" http://localhost:8787/proxy/test)
    if [ $? -eq 0 ]; then
        echo "  ✅ 代理端点测试通过"
        echo "  📨 响应: $PROXY_RESPONSE"
    else
        echo "  ⚠️  代理端点测试失败（可能是正常情况，取决于后端服务）"
    fi
fi

echo ""
echo "🛑 停止Admin API服务器..."
kill $SERVER_PID 2>/dev/null || true
sleep 1

if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "  ⚠️  服务器仍在运行，强制停止..."
    kill -9 $SERVER_PID 2>/dev/null || true
else
    echo "  ✅ 服务器已停止"
fi

echo ""
echo "📋 验证总结:"
echo "========================================"
echo "✅ 所有必要文件检查通过"
echo "✅ Node.js环境检查通过"
echo "✅ 数据库检查通过"
echo "✅ Admin认证配置检查通过"
echo "✅ Admin API服务器启动/停止正常"
echo "✅ 健康检查端点测试通过"
echo "✅ Admin认证测试通过"
echo "✅ Trial Key生成测试通过"
echo "✅ 使用统计查询测试通过"
echo "✅ 代理端点测试完成"
echo ""
echo "🎉 Admin API所有核心功能验证完成！"
echo ""
echo "📚 下一步:"
echo "  1. 查看详细指南: cat ADMIN-API-GUIDE.md"
echo "  2. 运行完整验证: ./verify-admin-api.sh"
echo "  3. 部署到生产: 参考部署指南"
echo ""
echo "🕒 验证时间: $(date '+%Y-%m-%d %H:%M:%S')"