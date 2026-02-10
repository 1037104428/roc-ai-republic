# quota-proxy 持久化版本部署指南

**创建时间**: 2026-02-10 13:15 CST  
**最后更新**: 2026-02-10 13:15 CST  
**版本**: v1.0.0

## 概述

quota-proxy 持久化版本基于 SQLite 数据库，通过 Docker 卷实现数据持久化存储。相比内存版本，持久化版本在容器重启后数据不会丢失，适合生产环境使用。

## 特性

- ✅ **数据持久化**: 使用 Docker 卷存储 SQLite 数据库文件
- ✅ **自动重启**: 容器异常退出时自动重启
- ✅ **健康检查**: 内置健康检查端点
- ✅ **资源限制**: 限制容器内存使用
- ✅ **结构化日志**: JSON 格式日志输出
- ✅ **管理接口**: 完整的密钥管理 API
- ✅ **备份支持**: 数据库备份和恢复机制

## 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, CentOS 7+)
- **Docker**: 20.10+
- **Docker Compose**: v2.0+
- **磁盘空间**: 至少 1GB 可用空间
- **内存**: 至少 512MB RAM

## 快速部署

### 1. 准备环境

确保目标服务器已安装 Docker 和 Docker Compose：

```bash
# 检查 Docker
docker --version

# 检查 Docker Compose
docker compose version
```

### 2. 一键部署

使用部署脚本快速部署：

```bash
# 进入仓库目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 运行部署脚本
./scripts/deploy-quota-proxy-persistent.sh --host <服务器IP>
```

部署脚本会自动：
1. 检查本地文件
2. 创建远程目录 (`/opt/roc/quota-proxy-persistent`)
3. 复制配置文件
4. 启动 Docker 容器
5. 验证部署状态

### 3. 手动部署步骤

如果希望手动部署，按以下步骤操作：

#### 3.1 复制文件到服务器

```bash
# 创建远程目录
ssh root@<服务器IP> "mkdir -p /opt/roc/quota-proxy-persistent"

# 复制必要文件
scp -r quota-proxy/Dockerfile-sqlite-correct \
      quota-proxy/server-sqlite.js \
      quota-proxy/package.json \
      quota-proxy/docker-compose-persistent.yml \
      root@<服务器IP>:/opt/roc/quota-proxy-persistent/
```

#### 3.2 配置环境变量

```bash
# 在服务器上创建环境文件
ssh root@<服务器IP> "cd /opt/roc/quota-proxy-persistent && cat > .env << 'EOF'
ADMIN_TOKEN=your-secure-admin-token-here
STORE_PATH=/data/quota.db
LOG_LEVEL=info
ENABLE_RATE_LIMIT=true
MAX_REQUESTS_PER_MINUTE=60
ENABLE_OPERATION_LOG=true
KEY_EXPIRY_DAYS=30
EOF"
```

**重要**: 务必修改 `ADMIN_TOKEN` 为安全的随机字符串。

#### 3.3 启动服务

```bash
# 在服务器上启动服务
ssh root@<服务器IP> "cd /opt/roc/quota-proxy-persistent && \
  docker compose -f docker-compose-persistent.yml up -d"
```

## 验证部署

### 使用验证脚本

```bash
# 运行验证脚本
./scripts/verify-quota-proxy-persistent.sh --host <服务器IP>
```

验证脚本会检查：
- 远程目录和文件
- Docker 容器状态
- 健康检查端点
- 数据卷状态
- 管理接口可访问性

### 手动验证

```bash
# 1. 检查容器状态
ssh root@<服务器IP> "cd /opt/roc/quota-proxy-persistent && \
  docker compose -f docker-compose-persistent.yml ps"

# 2. 检查健康端点
ssh root@<服务器IP> "curl -fsS http://127.0.0.1:8787/healthz"

# 3. 检查数据卷
ssh root@<服务器IP> "docker volume ls | grep quota-proxy-persistent"

# 4. 测试管理接口（需要 ADMIN_TOKEN）
ssh root@<服务器IP> "cd /opt/roc/quota-proxy-persistent && \
  ADMIN_TOKEN=\$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2-) && \
  curl -H \"Authorization: Bearer \$ADMIN_TOKEN\" \
    http://127.0.0.1:8787/admin/usage"
```

## 管理操作

### 服务管理

```bash
# 查看服务状态
docker compose -f docker-compose-persistent.yml ps

# 查看日志
docker compose -f docker-compose-persistent.yml logs -f

# 停止服务
docker compose -f docker-compose-persistent.yml down

# 停止并删除数据卷
docker compose -f docker-compose-persistent.yml down -v

# 重启服务
docker compose -f docker-compose-persistent.yml restart

# 更新服务（重新构建镜像）
docker compose -f docker-compose-persistent.yml up -d --build
```

### 密钥管理

```bash
# 创建试用密钥
curl -X POST -H "Authorization: Bearer \$ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"测试用户"}' \
  http://127.0.0.1:8787/admin/keys

# 查看所有密钥
curl -H "Authorization: Bearer \$ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/keys

# 查看使用情况
curl -H "Authorization: Bearer \$ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/usage

# 删除密钥
curl -X DELETE -H "Authorization: Bearer \$ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/keys/<key>

# 重置使用统计
curl -X POST -H "Authorization: Bearer \$ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/usage/reset
```

### 数据管理

```bash
# 查看数据库文件
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  ls -la /data/

# 备份数据库
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  sqlite3 /data/quota.db ".backup /data/quota.backup.db"

# 恢复数据库
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  sqlite3 /data/quota.db ".restore /data/quota.backup.db"

# 查看表结构
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  sqlite3 /data/quota.db ".tables"

# 查看数据卷位置
docker volume inspect quota-proxy-persistent_quota-data
```

## 监控和维护

### 健康检查

服务内置健康检查端点：
- `GET http://127.0.0.1:8787/healthz` - 返回 `{"ok":true}`

### 日志管理

日志配置：
- 格式: JSON
- 最大文件大小: 10MB
- 保留文件数: 3

查看日志：
```bash
# 查看实时日志
docker compose -f docker-compose-persistent.yml logs -f

# 查看最近100行日志
docker compose -f docker-compose-persistent.yml logs --tail=100

# 查看特定时间段的日志
docker compose -f docker-compose-persistent.yml logs --since="2026-02-10T00:00:00"
```

### 性能监控

```bash
# 查看容器资源使用
docker stats quota-proxy-sqlite-persistent

# 查看容器详细信息
docker inspect quota-proxy-sqlite-persistent

# 查看进程
docker compose -f docker-compose-persistent.yml top
```

## 故障排除

### 常见问题

#### 1. 容器启动失败

**症状**: `docker compose up` 失败

**解决**:
```bash
# 查看详细错误信息
docker compose -f docker-compose-persistent.yml logs

# 检查端口冲突
ss -tln | grep 8787

# 检查 Docker 服务状态
systemctl status docker
```

#### 2. 健康检查失败

**症状**: `curl http://127.0.0.1:8787/healthz` 返回错误

**解决**:
```bash
# 检查容器是否运行
docker compose -f docker-compose-persistent.yml ps

# 检查应用日志
docker compose -f docker-compose-persistent.yml logs quota-proxy

# 进入容器调试
docker compose -f docker-compose-persistent.yml exec quota-proxy sh
```

#### 3. 数据库问题

**症状**: 管理接口返回数据库错误

**解决**:
```bash
# 检查数据库文件权限
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  ls -la /data/

# 修复数据库文件权限
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  chmod 666 /data/quota.db

# 备份并重建数据库
docker compose -f docker-compose-persistent.yml exec quota-proxy \
  mv /data/quota.db /data/quota.db.bak
docker compose -f docker-compose-persistent.yml restart
```

#### 4. 内存不足

**症状**: 容器频繁重启或被 OOM 杀死

**解决**:
```bash
# 调整内存限制
# 编辑 docker-compose-persistent.yml，修改 memory 限制
# 然后重启服务
docker compose -f docker-compose-persistent.yml up -d
```

### 日志分析

常见错误日志及解决方法：

| 错误信息 | 可能原因 | 解决方法 |
|---------|---------|---------|
| `Error: unable to open database file` | 数据库文件权限问题 | 检查 `/data` 目录权限 |
| `Error: database disk image is malformed` | 数据库文件损坏 | 从备份恢复或重建数据库 |
| `Error: bind: address already in use` | 端口冲突 | 修改端口或停止占用端口的进程 |
| `Error: no such table: keys` | 数据库表不存在 | 重启服务初始化数据库 |

## 备份和恢复

### 定期备份

创建备份脚本 `backup-quota-db.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/quota-proxy"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
docker compose -f /opt/roc/quota-proxy-persistent/docker-compose-persistent.yml \
  exec -T quota-proxy sh -c 'sqlite3 /data/quota.db ".backup /data/quota.db.backup"'

# 复制备份文件
docker compose -f /opt/roc/quota-proxy-persistent/docker-compose-persistent.yml \
  cp quota-proxy:/data/quota.db.backup $BACKUP_DIR/quota.db.$DATE.backup

# 清理旧备份（保留最近7天）
find $BACKUP_DIR -name "*.backup" -mtime +7 -delete

echo "备份完成: $BACKUP_DIR/quota.db.$DATE.backup"
```

### 灾难恢复

从备份恢复数据库：

```bash
# 1. 停止服务
cd /opt/roc/quota-proxy-persistent
docker compose -f docker-compose-persistent.yml down

# 2. 复制备份文件到容器
docker compose -f docker-compose-persistent.yml run --rm -v \
  /opt/backups/quota-proxy/quota.db.20260210_130000.backup:/backup.db \
  quota-proxy sh -c 'cp /backup.db /data/quota.db'

# 3. 启动服务
docker compose -f docker-compose-persistent.yml up -d

# 4. 验证恢复
curl -fsS http://127.0.0.1:8787/healthz
```

## 升级指南

### 版本升级

1. **备份当前数据**
   ```bash
   ./scripts/backup-quota-db.sh
   ```

2. **更新代码**
   ```bash
   # 拉取最新代码
   cd /home/kai/.openclaw/workspace/roc-ai-republic
   git pull

   # 复制更新文件到服务器
   ./scripts/deploy-quota-proxy-persistent.sh --host <服务器IP>
   ```

3. **重启服务**
   ```bash
   ssh root@<服务器IP> "cd /opt/roc/quota-proxy-persistent && \
     docker compose -f docker-compose-persistent.yml up -d --build"
   ```

4. **验证升级**
   ```bash
   ./scripts/verify-quota-proxy-persistent.sh --host <服务器IP>
   ```

### 配置变更

修改配置后重启服务：

```bash
# 1. 修改配置
vim /opt/roc/quota-proxy-persistent/.env

# 2. 重启服务
cd /opt/roc/quota-proxy-persistent
docker compose -f docker-compose-persistent.yml restart
```

## 安全建议

### 1. 管理员令牌安全
- 使用强随机密码生成 `ADMIN_TOKEN`
- 定期轮换管理员令牌
- 不要将令牌提交到版本控制系统

### 2. 网络访问控制
- 仅绑定到 `127.0.0.1`（本地访问）
- 通过反向代理（如 Nginx、Caddy）暴露服务
- 配置防火墙规则限制访问

### 3. 数据安全
- 定期备份数据库
- 加密备份文件
- 监控异常访问模式

### 4. 容器安全
- 使用非 root 用户运行容器
- 定期更新基础镜像
- 扫描镜像漏洞

## 相关文档

- [quota-proxy API 文档](./quota-proxy-v1-admin-spec.md)
- [quota-proxy 管理验收清单](./quota-proxy-v1-admin-acceptance.md)
- [quota-proxy 快速开始](./quota-proxy-api-quickstart.md)
- [服务器运维健康检查](./ops-server-healthcheck.md)

## 支持

遇到问题请：
1. 查看本文档的故障排除部分
2. 检查服务日志
3. 在论坛发帖求助：https://clawdrepublic.cn/forum/

## 更新记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-02-10 | v1.0.0 | 初始版本，包含完整部署指南 |

---

**注意**: 本文档会随项目更新而更新，请定期查看最新版本。