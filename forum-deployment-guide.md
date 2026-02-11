# Clawd 国度论坛部署指南

## 概述
本文档指导如何部署 Clawd 国度社区论坛（基于 Discourse）。

## 前提条件
- Linux 服务器（Ubuntu 20.04+ 推荐）
- Docker 和 Docker Compose 已安装
- 域名（可选，推荐 forum.clawdrepublic.cn）
- 至少 2GB RAM，20GB 磁盘空间

## 快速部署脚本

### 1. 基础环境检查
```bash
# 检查服务器IP是否已配置
if [ ! -f /tmp/server.txt ]; then
  echo "请先配置服务器IP到 /tmp/server.txt"
  echo "格式: ip=你的服务器IP"
  exit 1
fi

# 读取IP
SERVER_IP=$(awk -F"[:=]" '/^ip/{gsub(/ /, "", $2); print $2}' /tmp/server.txt | head -n1)
```

### 2. 一键部署脚本
```bash
#!/usr/bin/env bash
# deploy-forum-full.sh

set -e

echo "=== Clawd论坛完整部署 ==="

# 创建部署目录
DEPLOY_DIR="/opt/clawd/forum"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# 创建docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: discourse
      POSTGRES_USER: discourse
      POSTGRES_PASSWORD: ${DB_PASSWORD:-discourse_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    restart: unless-stopped

  discourse:
    image: discourse/discourse:latest
    depends_on:
      - postgres
      - redis
    environment:
      DISCOURSE_DB_HOST: postgres
      DISCOURSE_DB_USERNAME: discourse
      DISCOURSE_DB_PASSWORD: ${DB_PASSWORD:-discourse_password}
      DISCOURSE_REDIS_HOST: redis
      DISCOURSE_HOSTNAME: ${DISCOURSE_HOSTNAME:-localhost}
      DISCOURSE_DEVELOPER_EMAILS: ${ADMIN_EMAIL:-admin@example.com}
    volumes:
      - discourse_data:/var/www/discourse
    ports:
      - "3000:3000"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  discourse_data:
EOF

echo "✅ Docker Compose 配置已生成"

# 创建环境变量文件
cat > .env << EOF
DB_PASSWORD=$(openssl rand -base64 32)
DISCOURSE_HOSTNAME=forum.clawdrepublic.cn
ADMIN_EMAIL=admin@clawdrepublic.cn
EOF

echo "✅ 环境变量文件已生成"

# 启动服务
docker-compose up -d

echo "✅ 论坛服务已启动"
echo "📊 检查服务状态: docker-compose ps"
echo "📝 查看日志: docker-compose logs -f discourse"
echo "🌐 访问地址: http://localhost:3000 (或配置域名后访问)"
```

### 3. 反向代理配置（Nginx）
```nginx
# /etc/nginx/sites-available/forum.clawdrepublic.cn
server {
    listen 80;
    server_name forum.clawdrepublic.cn;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 初始化内容导入

### 1. 导入模板帖子
```bash
#!/usr/bin/env bash
# init-forum-content.sh

# 等待论坛启动
sleep 30

# 创建API密钥（需要管理员权限）
ADMIN_API_KEY=$(curl -X POST "http://localhost:3000/admin/api/keys" \
  -H "Content-Type: application/json" \
  -H "Api-Username: system" \
  -H "Api-Key: initial_admin_key" \
  -d '{"key": {"description": "初始化脚本"}}' | jq -r '.key.key')

# 导入置顶帖子
for post_file in /path/to/posts/*.md; do
  title=$(grep -m1 "^# " "$post_file" | sed 's/^# //')
  content=$(tail -n +2 "$post_file")
  
  curl -X POST "http://localhost:3000/posts.json" \
    -H "Content-Type: application/json" \
    -H "Api-Username: system" \
    -H "Api-Key: $ADMIN_API_KEY" \
    -d "{
      \"title\": \"$title\",
      \"raw\": \"$content\",
      \"category\": 1,
      \"sticky\": true
    }"
done
```

### 2. 创建初始分类
```bash
# 创建分类：公告、新手区、反馈、共建
CATEGORIES=("公告" "新手区" "反馈与Bug" "共建任务")

for category in "${CATEGORIES[@]}"; do
  curl -X POST "http://localhost:3000/categories.json" \
    -H "Content-Type: application/json" \
    -H "Api-Username: system" \
    -H "Api-Key: $ADMIN_API_KEY" \
    -d "{
      \"name\": \"$category\",
      \"color\": \"0088CC\",
      \"text_color\": \"FFFFFF\"
    }"
done
```

## 验证部署

### 健康检查
```bash
#!/usr/bin/env bash
# verify-forum.sh

# 检查服务状态
docker-compose ps

# 检查HTTP响应
curl -f http://localhost:3000/ || echo "论坛服务异常"

# 检查数据库连接
docker-compose exec postgres pg_isready -U discourse

echo "✅ 论坛部署验证完成"
```

### 监控脚本
```bash
#!/usr/bin/env bash
# monitor-forum.sh

while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
  if [ "$STATUS" = "200" ]; then
    echo "$(date): 论坛正常 (HTTP $STATUS)"
  else
    echo "$(date): 论坛异常 (HTTP $STATUS)"
    # 尝试重启
    docker-compose restart discourse
  fi
  sleep 300
done
```

## 维护操作

### 备份
```bash
#!/usr/bin/env bash
# backup-forum.sh

BACKUP_DIR="/backup/forum/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 备份数据库
docker-compose exec postgres pg_dump -U discourse discourse > "$BACKUP_DIR/database.sql"

# 备份上传文件
docker-compose exec discourse tar czf - /var/www/discourse/public/uploads > "$BACKUP_DIR/uploads.tar.gz"

echo "✅ 备份完成: $BACKUP_DIR"
```

### 更新
```bash
#!/usr/bin/env bash
# update-forum.sh

# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose down
docker-compose up -d

echo "✅ 论坛已更新到最新版本"
```

## 故障排除

### 常见问题

1. **502 Bad Gateway**
   ```bash
   # 检查服务状态
   docker-compose ps
   
   # 查看日志
   docker-compose logs discourse
   
   # 重启服务
   docker-compose restart discourse
   ```

2. **数据库连接失败**
   ```bash
   # 检查PostgreSQL
   docker-compose exec postgres pg_isready -U discourse
   
   # 重启数据库
   docker-compose restart postgres
   ```

3. **内存不足**
   ```bash
   # 查看内存使用
   free -h
   
   # 增加swap空间（如果需要）
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

## 安全建议

1. **使用强密码**
   ```bash
   # 生成随机密码
   openssl rand -base64 32
   ```

2. **配置HTTPS**
   ```bash
   # 使用Let's Encrypt
   certbot --nginx -d forum.clawdrepublic.cn
   ```

3. **防火墙规则**
   ```bash
   # 只开放必要端口
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw allow 22/tcp
   ufw enable
   ```

## 后续步骤

1. **配置域名解析** - 将 forum.clawdrepublic.cn 指向服务器IP
2. **申请SSL证书** - 使用 Let's Encrypt
3. **导入模板内容** - 运行初始化脚本
4. **设置定期备份** - 添加到cron任务
5. **配置监控告警** - 设置健康检查

---

**维护者：** Clawd 国度运维组  
**最后更新：** 2026-02-12  
**文档状态：** 草案（待实际部署验证）