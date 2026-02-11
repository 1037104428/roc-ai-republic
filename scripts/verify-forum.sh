#!/bin/bash
# 论坛部署验证脚本
# 使用: ./scripts/verify-forum.sh

set -e

echo "🔍 验证论坛部署状态..."

# 检查 Docker 是否运行
if ! docker info &> /dev/null; then
    echo "❌ Docker 守护进程未运行"
    exit 1
fi

# 检查容器状态
if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "clawd-forum-nodebb"; then
    echo "✅ NodeBB 容器正在运行"
    NODEBB_STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "clawd-forum-nodebb" | awk '{print $2}')
    echo "   状态: $NODEBB_STATUS"
else
    echo "❌ NodeBB 容器未运行"
fi

if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "clawd-forum-redis"; then
    echo "✅ Redis 容器正在运行"
    REDIS_STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "clawd-forum-redis" | awk '{print $2}')
    echo "   状态: $REDIS_STATUS"
else
    echo "❌ Redis 容器未运行"
fi

# 检查端口监听
echo ""
echo "🔌 检查端口监听状态:"
if netstat -tuln 2>/dev/null | grep -q ":4567"; then
    echo "✅ 端口 4567 正在监听"
else
    echo "❌ 端口 4567 未监听"
fi

# 测试 HTTP 访问
echo ""
echo "🌐 测试 HTTP 访问:"
if command -v curl &> /dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:4567 2>/dev/null | grep -q "200\|302"; then
        echo "✅ HTTP 访问正常 (200/302)"
    else
        echo "❌ HTTP 访问失败"
    fi
else
    echo "⚠️  curl 未安装，跳过 HTTP 测试"
fi

# 检查健康状态
echo ""
echo "🏥 检查容器健康状态:"
if docker inspect --format='{{.State.Health.Status}}' clawd-forum-nodebb 2>/dev/null | grep -q "healthy"; then
    echo "✅ NodeBB 健康检查通过"
elif docker inspect --format='{{.State.Health.Status}}' clawd-forum-nodebb 2>/dev/null | grep -q "starting"; then
    echo "🔄 NodeBB 正在启动中"
else
    echo "⚠️  NodeBB 健康状态未知"
fi

# 显示容器信息
echo ""
echo "📊 容器详细信息:"
docker ps -a --filter "name=clawd-forum" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📋 快速命令:"
echo "启动论坛: ./scripts/start-forum.sh"
echo "停止论坛: docker-compose -f docker-compose.forum.yml down"
echo "查看日志: docker-compose -f docker-compose.forum.yml logs -f"
echo "重启服务: docker-compose -f docker-compose.forum.yml restart"
echo ""
echo "📚 文档位置:"
echo "- 论坛部署指南: docs/forum-mvp-implementation.md"
echo "- 信息架构: docs/forum/forum-info-architecture.md"
echo "- 模板帖: docs/forum/posts/"