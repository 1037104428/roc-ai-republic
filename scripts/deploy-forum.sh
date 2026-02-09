#!/usr/bin/env bash
set -e

# 论坛部署脚本 v0.1
# 用于部署Clawd国度社区论坛MVP

echo "=== Clawd论坛部署脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查依赖
command -v docker >/dev/null 2>&1 || { echo "错误: 需要docker"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "错误: 需要docker-compose"; exit 1; }

# 创建部署目录
DEPLOY_DIR="./forum-deploy"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# 创建docker-compose.yml
cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: clawd_forum
      POSTGRES_USER: clawd
      POSTGRES_PASSWORD: ${DB_PASSWORD:-clawd123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U clawd"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  redis_data:
DOCKEREOF

echo "✅ 部署配置已生成到 $DEPLOY_DIR"
echo "📋 下一步："
echo "1. cd $DEPLOY_DIR"
echo "2. 设置环境变量: export DB_PASSWORD=your_secure_password"
echo "3. 启动服务: docker-compose up -d"
echo "4. 验证: docker-compose ps"
