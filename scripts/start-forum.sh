#!/bin/bash
# Clawd 国度论坛启动脚本
# 使用: ./scripts/start-forum.sh

set -e

echo "🚀 启动 Clawd 国度论坛服务..."

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  docker-compose 未安装，尝试使用 docker compose"
    if ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# 创建数据目录
mkdir -p forum-data/{nodebb,redis,uploads}

# 启动服务
echo "📦 启动论坛容器..."
$COMPOSE_CMD -f docker-compose.forum.yml up -d

echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "🔍 检查服务状态..."
if $COMPOSE_CMD -f docker-compose.forum.yml ps | grep -q "Up"; then
    echo "✅ 论坛服务启动成功！"
    echo "🌐 访问地址: http://localhost:4567"
    echo "📊 管理面板: http://localhost:4567/admin"
    echo ""
    echo "📝 后续步骤:"
    echo "1. 访问 http://localhost:4567 完成 NodeBB 初始化设置"
    echo "2. 创建管理员账户"
    echo "3. 配置论坛基本信息"
    echo "4. 导入论坛信息架构模板"
else
    echo "❌ 服务启动失败，请检查日志:"
    $COMPOSE_CMD -f docker-compose.forum.yml logs --tail=20
    exit 1
fi

# 显示容器日志
echo ""
echo "📋 容器状态:"
$COMPOSE_CMD -f docker-compose.forum.yml ps

echo ""
echo "📜 查看实时日志: $COMPOSE_CMD -f docker-compose.forum.yml logs -f"
echo "🛑 停止服务: $COMPOSE_CMD -f docker-compose.forum.yml down"