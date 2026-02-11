#!/bin/bash
# NodeBB 论坛停止脚本

set -e

echo "=== NodeBB 论坛停止脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查 Docker Compose
command -v docker-compose >/dev/null 2>&1 || { echo "需要 Docker Compose 但未安装"; exit 1; }

# 停止服务
echo "停止 NodeBB 论坛服务..."
docker-compose -f docker-compose-nodebb.yml down

echo "服务已停止"
echo ""
echo "启动论坛: ./start-forum.sh"
echo "查看状态: docker-compose -f docker-compose-nodebb.yml ps"