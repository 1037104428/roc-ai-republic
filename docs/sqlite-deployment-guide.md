# SQLite 版本 quota-proxy 部署指南

本文档介绍如何部署和使用 SQLite 持久化版本的 quota-proxy。

## 概述

SQLite 版本提供以下优势：
- **数据持久化**: 用量数据保存在 SQLite 数据库中，重启服务不丢失
- **管理接口**: 完整的 `/admin/keys` 和 `/admin/usage` 管理接口
- **易于备份**: 单个数据库文件，便于备份和迁移
- **生产就绪**: 支持健康检查、日志轮转、自动重启

## 快速部署

### 1. 一键部署

```bash
# 从仓库根目录运行
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/deploy-sqlite-quick.sh
```

### 2. 验证部署

```bash
./scripts/verify-sqlite-deployment.sh
```

### 3. 手动部署步骤

如果一键部署失败，可以手动执行：

```bash
# 1. 连接到服务器
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194

# 2. 创建部署目录
mkdir -p /opt/roc/quota-proxy-sqlite
cd /opt/roc/quota-proxy-sqlite

# 3. 复制必要文件（从本地）
# 在本地机器上执行：
scp -i ~/.ssh/id_ed25519_roc_server \
  quota-proxy/server-sqlite.js \
  quota-proxy/Dockerfile-sqlite-correct \
  quota-proxy/package.json \
  root@8.210.185.194:/opt/roc/quota-proxy-sqlite/

# 4. 创建 docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  quota-proxy:
    build: .
    container_name: quota-proxy-sqlite
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - NODE_ENV=production
      - PORT=8787
      - ADMIN_TOKEN=${ADMIN_TOKEN:-changeme}
      - STORAGE_MODE=sqlite
      - SQLITE_DB_PATH=/data/quota.db
    volumes:
      - ./data:/data
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8787/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

# 5. 生成 ADMIN_TOKEN
ADMIN_TOKEN=$(openssl rand -hex 32)
echo "ADMIN_TOKEN=$ADMIN_TOKEN" > .env
echo "ADMIN_TOKEN: $ADMIN_TOKEN"

# 6. 构建并启动
docker compose build
docker compose up -d
```

## 管理接口

### 获取 ADMIN_TOKEN

```bash
# 在服务器上查看
cat /opt/roc/quota-proxy-sqlite/.env | grep ADMIN_TOKEN
```

### 管理接口示例

```bash
# 设置环境变量
export ADMIN_TOKEN="your-admin-token-here"

# 1. 创建新的 trial key
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "用户-张三-20250210",
    "quota": 1000,
    "expiresAt": "2026-03-10T00:00:00Z"
  }'

# 2. 查看所有 key 的使用情况
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/usage

# 3. 删除指定的 key
curl -X DELETE \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/keys/key-to-delete

# 4. 重置所有用量
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/usage/reset
```

## 数据管理

### 备份数据库

```bash
# 在服务器上执行
cd /opt/roc/quota-proxy-sqlite
cp data/quota.db data/quota.db.backup.$(date +%Y%m%d-%H%M%S)

# 或者使用 docker 命令
docker exec quota-proxy-sqlite sqlite3 /data/quota.db ".backup /data/quota.db.backup"
```

### 恢复数据库

```bash
# 停止服务
cd /opt/roc/quota-proxy-sqlite
docker compose down

# 恢复备份
cp data/quota.db.backup data/quota.db

# 启动服务
docker compose up -d
```

### 查看数据库内容

```bash
# 进入容器查看
docker exec -it quota-proxy-sqlite sqlite3 /data/quota.db

# SQLite 命令
.tables
SELECT * FROM api_keys;
SELECT * FROM usage_logs;
.quit
```

## 监控和维护

### 查看日志

```bash
# 实时日志
cd /opt/roc/quota-proxy-sqlite
docker compose logs -f

# 查看特定时间的日志
docker compose logs --since 1h
```

### 健康检查

```bash
# 手动健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 查看容器健康状态
docker inspect quota-proxy-sqlite --format='{{.State.Health.Status}}'
```

### 服务管理

```bash
# 重启服务
cd /opt/roc/quota-proxy-sqlite
docker compose restart

# 停止服务
docker compose down

# 启动服务
docker compose up -d

# 查看服务状态
docker compose ps
docker compose logs
```

## 故障排除

### 常见问题

1. **健康检查失败**
   ```bash
   # 检查容器是否运行
   docker ps | grep quota-proxy-sqlite
   
   # 检查端口是否监听
   netstat -tlnp | grep :8787
   
   # 检查日志
   docker compose logs
   ```

2. **数据库权限问题**
   ```bash
   # 检查数据库文件权限
   ls -la /opt/roc/quota-proxy-sqlite/data/
   
   # 修复权限
   chmod 666 /opt/roc/quota-proxy-sqlite/data/quota.db
   ```

3. **管理接口返回 401**
   ```bash
   # 检查 ADMIN_TOKEN
   cat /opt/roc/quota-proxy-sqlite/.env
   
   # 重新生成 token
   echo "ADMIN_TOKEN=$(openssl rand -hex 32)" > /opt/roc/quota-proxy-sqlite/.env
   docker compose restart
   ```

### 回滚到原版本

如果 SQLite 版本有问题，可以快速回滚到原版本：

```bash
# 停止 SQLite 版本
cd /opt/roc/quota-proxy-sqlite
docker compose down

# 启动原版本
cd /opt/roc/quota-proxy
docker compose up -d
```

## 版本切换

系统支持同时运行两个版本，但只能有一个监听 8787 端口。

### 切换到 SQLite 版本
```bash
cd /opt/roc/quota-proxy && docker compose down
cd /opt/roc/quota-proxy-sqlite && docker compose up -d
```

### 切换回原版本
```bash
cd /opt/roc/quota-proxy-sqlite && docker compose down
cd /opt/roc/quota-proxy && docker compose up -d
```

## 性能优化

### SQLite 配置建议

1. **启用 WAL 模式** (提高并发性能):
   ```bash
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db "PRAGMA journal_mode=WAL;"
   ```

2. **调整缓存大小**:
   ```bash
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db "PRAGMA cache_size=-2000;"
   ```

3. **定期清理旧数据**:
   ```bash
   # 删除30天前的用量记录
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db \
     "DELETE FROM usage_logs WHERE timestamp < datetime('now', '-30 days');"
   ```

## 相关脚本

- `scripts/deploy-sqlite-quick.sh` - 一键部署脚本
- `scripts/verify-sqlite-deployment.sh` - 部署验证脚本
- `scripts/quota-proxy-admin.sh` - 管理接口辅助脚本

## 更新记录

- **2026-02-10**: 创建 SQLite 版本部署指南
- **2026-02-09**: 完成 SQLite 版本开发和基础测试
- **2026-02-08**: 开始 SQLite 持久化开发

---

**注意**: SQLite 版本适合中小规模部署。对于大规模高并发场景，建议使用 PostgreSQL 或 MySQL 版本。