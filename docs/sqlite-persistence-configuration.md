# SQLite数据库持久化配置指南

本文档介绍如何配置quota-proxy的SQLite数据库持久化选项，包括内存数据库和文件数据库的配置方法。

## 概述

quota-proxy支持两种SQLite数据库模式：

1. **内存数据库** (`:memory:`)
   - 高性能，数据存储在内存中
   - 重启服务后数据丢失
   - 适用于开发、测试环境

2. **文件数据库** (文件路径)
   - 数据持久化到磁盘文件
   - 重启服务后数据保留
   - 适用于生产环境

## 配置工具

我们提供了自动化配置脚本：`scripts/configure-sqlite-persistence.sh`

### 安装依赖

```bash
# 确保脚本有执行权限
chmod +x scripts/configure-sqlite-persistence.sh
```

### 使用说明

#### 1. 检查当前配置

```bash
./scripts/configure-sqlite-persistence.sh --check
```

输出示例：
```
[INFO] 检查当前数据库配置...
[INFO] 当前配置: 内存数据库 (:memory:)
   模式: 内存数据库
   特点: 高性能，重启后数据丢失
   适用: 开发/测试环境
```

#### 2. 配置为内存数据库

```bash
./scripts/configure-sqlite-persistence.sh --memory
```

输出示例：
```
[INFO] 配置为内存数据库...
[SUCCESS] 已配置为内存数据库
   配置: new sqlite3.Database(':memory:')
   注意: 重启服务后数据会丢失
```

#### 3. 配置为文件数据库

```bash
# 使用默认路径
./scripts/configure-sqlite-persistence.sh --file

# 使用自定义路径
./scripts/configure-sqlite-persistence.sh --file /var/lib/quota-proxy/quota.db
```

输出示例：
```
[INFO] 配置为文件数据库: /opt/roc/quota-proxy/data/quota.db
[INFO] 确保数据库目录存在: /opt/roc/quota-proxy/data
[SUCCESS] 已配置为文件数据库
   路径: /opt/roc/quota-proxy/data/quota.db
   持久化: 数据会保存到文件

部署说明:
1. 在服务器上创建数据库目录:
   sudo mkdir -p /opt/roc/quota-proxy/data
   sudo chown -R $USER:$USER /opt/roc/quota-proxy/data

2. 更新Docker Compose配置（如果需要）:
   在 docker-compose.yml 中添加数据卷:
   volumes:
     - ./data:/opt/roc/quota-proxy/data

3. 重启服务:
   docker compose down
   docker compose up -d

4. 验证数据库文件:
   ls -la /opt/roc/quota-proxy/data/quota.db
```

## 手动配置方法

### 内存数据库配置

编辑 `quota-proxy/server-sqlite.js`，确保数据库配置为：

```javascript
const db = new sqlite3.Database(':memory:');
```

### 文件数据库配置

编辑 `quota-proxy/server-sqlite.js`，将数据库配置改为文件路径：

```javascript
const db = new sqlite3.Database('/opt/roc/quota-proxy/data/quota.db');
```

## 生产环境部署指南

### 步骤1：配置文件数据库

```bash
# 在开发环境配置
./scripts/configure-sqlite-persistence.sh --file /opt/roc/quota-proxy/data/quota.db
```

### 步骤2：更新Docker Compose配置

编辑 `docker-compose.yml`，添加数据卷：

```yaml
version: '3.8'
services:
  quota-proxy:
    build: .
    ports:
      - "8787:8787"
    environment:
      - ADMIN_TOKEN=${ADMIN_TOKEN}
    volumes:
      - ./data:/opt/roc/quota-proxy/data  # 添加这行
```

### 步骤3：服务器部署

```bash
# 在服务器上创建数据目录
ssh root@your-server "mkdir -p /opt/roc/quota-proxy/data"

# 部署代码
scp -r quota-proxy root@your-server:/opt/roc/

# 启动服务
ssh root@your-server "cd /opt/roc/quota-proxy && docker compose up -d"
```

### 步骤4：验证部署

```bash
# 检查服务状态
ssh root@your-server "cd /opt/roc/quota-proxy && docker compose ps"

# 检查数据库文件
ssh root@your-server "ls -la /opt/roc/quota-proxy/data/"

# 测试健康检查
curl http://your-server:8787/healthz
```

## 数据备份策略

### 自动备份脚本

使用我们提供的备份脚本：

```bash
# 执行数据库备份
./scripts/backup-database.sh

# 检查备份状态
./scripts/check-server-backup-status.sh

# 查看备份摘要
./scripts/backup-status-summary.sh
```

### 备份恢复

```bash
# 恢复数据库
./scripts/restore-database.sh /path/to/backup.db
```

## 性能优化建议

### 内存数据库
- 适合高并发读写场景
- 定期导出数据到文件备份
- 监控内存使用情况

### 文件数据库
- 启用WAL模式提高并发性能
- 定期执行VACUUM优化数据库
- 配置适当的文件系统缓存

### 启用WAL模式（文件数据库）

在 `server-sqlite.js` 中添加：

```javascript
// 在创建数据库连接后
db.serialize(() => {
    db.run('PRAGMA journal_mode = WAL;');
    db.run('PRAGMA synchronous = NORMAL;');
    // ... 其他初始化
});
```

## 故障排除

### 常见问题

#### 1. 数据库文件权限问题

```bash
# 检查权限
ls -la /opt/roc/quota-proxy/data/quota.db

# 修复权限
sudo chown $USER:$USER /opt/roc/quota-proxy/data/quota.db
sudo chmod 644 /opt/roc/quota-proxy/data/quota.db
```

#### 2. 数据库损坏

```bash
# 检查数据库完整性
sqlite3 /opt/roc/quota-proxy/data/quota.db "PRAGMA integrity_check;"

# 修复数据库
sqlite3 /opt/roc/quota-proxy/data/quota.db ".dump" | sqlite3 repaired.db
```

#### 3. 磁盘空间不足

```bash
# 检查磁盘空间
df -h /opt/roc/quota-proxy/data/

# 清理旧备份
find /opt/roc/quota-proxy/backups -name "*.db" -mtime +30 -delete
```

## 监控和告警

### 健康检查

```bash
# 使用验证脚本
./scripts/verify-sqlite-status.sh

# 输出示例：
# [INFO] 检查quota-proxy服务状态...
# [SUCCESS] 服务运行正常
# [INFO] 检查数据库连接...
# [SUCCESS] 数据库连接正常
# [INFO] 检查API密钥功能...
# [SUCCESS] API密钥功能正常
```

### 集成到监控系统

将验证脚本集成到监控系统（如Prometheus、Nagios）：

```bash
# 返回JSON格式的状态
./scripts/verify-sqlite-status.sh --json
```

## 相关文档

- [数据库备份和恢复指南](./database-backup-recovery.md)
- [服务器部署指南](./server-deployment.md)
- [API文档](./api-documentation.md)

## 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-02-10 | 1.0.0 | 初始版本，提供SQLite持久化配置工具和文档 |

## 技术支持

如有问题，请参考：
1. 查看详细日志：`docker compose logs quota-proxy`
2. 检查数据库状态：`./scripts/verify-sqlite-status.sh`
3. 查看项目文档：`docs/` 目录