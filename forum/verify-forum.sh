#!/bin/bash
# NodeBB 论坛验证脚本

set -e

echo "=== NodeBB 论坛验证脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查 Docker 和 Docker Compose
command -v docker >/dev/null 2>&1 || { echo "❌ 需要 Docker 但未安装"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ 需要 Docker Compose 但未安装"; exit 1; }

echo "✅ Docker 和 Docker Compose 已安装"

# 检查配置文件
if [ -f "docker-compose-nodebb.yml" ]; then
    echo "✅ docker-compose-nodebb.yml 配置文件存在"
else
    echo "❌ docker-compose-nodebb.yml 配置文件不存在"
    exit 1
fi

if [ -f "start-forum.sh" ]; then
    echo "✅ start-forum.sh 启动脚本存在"
    chmod +x start-forum.sh 2>/dev/null || true
else
    echo "❌ start-forum.sh 启动脚本不存在"
    exit 1
fi

if [ -f "stop-forum.sh" ]; then
    echo "✅ stop-forum.sh 停止脚本存在"
    chmod +x stop-forum.sh 2>/dev/null || true
else
    echo "❌ stop-forum.sh 停止脚本不存在"
    exit 1
fi

# 检查 Docker Compose 配置语法
echo "检查 Docker Compose 配置语法..."
docker-compose -f docker-compose-nodebb.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Docker Compose 配置语法正确"
else
    echo "❌ Docker Compose 配置语法错误"
    exit 1
fi

# 检查启动脚本语法
echo "检查启动脚本语法..."
bash -n start-forum.sh
if [ $? -eq 0 ]; then
    echo "✅ 启动脚本语法正确"
else
    echo "❌ 启动脚本语法错误"
    exit 1
fi

# 检查停止脚本语法
echo "检查停止脚本语法..."
bash -n stop-forum.sh
if [ $? -eq 0 ]; then
    echo "✅ 停止脚本语法正确"
else
    echo "❌ 停止脚本语法错误"
    exit 1
fi

# 检查服务状态（如果正在运行）
echo "检查论坛服务状态..."
if docker-compose -f docker-compose-nodebb.yml ps 2>/dev/null | grep -q "Up"; then
    echo "✅ 论坛服务正在运行"
    
    # 检查 NodeBB 健康状态
    echo "检查 NodeBB 健康状态..."
    if curl -fsS http://localhost:4567/api/ping 2>/dev/null | grep -q "pong"; then
        echo "✅ NodeBB API 响应正常"
    else
        echo "⚠️  NodeBB API 无响应，但服务正在运行"
    fi
    
    # 检查 Redis 健康状态
    echo "检查 Redis 健康状态..."
    if docker-compose -f docker-compose-nodebb.yml exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo "✅ Redis 响应正常"
    else
        echo "⚠️  Redis 无响应，但服务正在运行"
    fi
else
    echo "ℹ️  论坛服务未运行"
    echo "   启动论坛: ./start-forum.sh"
fi

# 检查目录结构
echo "检查目录结构..."
mkdir -p logs/nginx ssl 2>/dev/null || true
if [ -d "logs/nginx" ] && [ -d "ssl" ]; then
    echo "✅ 必要的目录已创建"
else
    echo "⚠️  部分目录创建失败"
fi

echo ""
echo "=== 验证完成 ==="
echo "✅ 所有基本验证通过"
echo ""
echo "可用命令:"
echo "  ./start-forum.sh    - 启动论坛"
echo "  ./stop-forum.sh     - 停止论坛"
echo "  ./verify-forum.sh   - 验证论坛配置"
echo ""
echo "访问地址:"
echo "  - NodeBB 直接访问: http://localhost:4567"
echo "  - 通过 Nginx: http://forum.localhost"