# quota-proxy 内存存储到 SQLite 数据库迁移指南

## 概述

本文档提供了将 `quota-proxy` 从内存存储迁移到 SQLite 数据库的完整指南。迁移工具 `migrate-to-sqlite.sh` 自动化了整个迁移过程，确保数据持久化和服务高可用性。

## 迁移工具

### 脚本位置
```
scripts/migrate-to-sqlite.sh
```

### 功能特性
- ✅ 自动化迁移流程
- ✅ 服务器连接检查
- ✅ 数据库状态验证
- ✅ 自动备份机制
- ✅ 服务无缝重启
- ✅ 迁移结果验证
- ✅ Dry-run 模式支持
- ✅ 详细日志输出

### 使用说明

#### 1. 检查迁移条件（Dry-run 模式）
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/migrate-to-sqlite.sh --dry-run
```

#### 2. 执行迁移
```bash
./scripts/migrate-to-sqlite.sh
```

#### 3. 自定义服务器配置
```bash
./scripts/migrate-to-sqlite.sh --server 192.168.1.100 --ssh-key ~/.ssh/custom_key
```

#### 4. 查看帮助
```bash
./scripts/migrate-to-sqlite.sh --help
```

## 迁移流程

### 阶段 1: 准备工作
1. **环境检查**
   - 服务器 SSH 连接
   - quota-proxy 服务状态
   - 磁盘空间检查

2. **数据库状态评估**
   - 检查现有数据库文件
   - 验证表结构完整性
   - 评估迁移需求

### 阶段 2: 备份创建
1. **自动备份**
   ```
   /opt/roc/quota-proxy/data/quota.db.backup.YYYYMMDD_HHMMSS
   ```

2. **备份验证**
   - 文件完整性检查
   - 权限验证
   - 大小检查

### 阶段 3: 迁移执行
1. **服务暂停**
   ```bash
   docker compose stop quota-proxy
   ```

2. **数据库初始化**
   - 创建数据库目录
   - 初始化表结构
   - 插入演示数据

3. **配置更新**
   ```env
   # .env 文件更新
   DATABASE_URL=file:/opt/roc/quota-proxy/data/quota.db
   DATABASE_LOGGING=false
   ```

4. **服务重启**
   ```bash
   docker compose up -d quota-proxy
   ```

### 阶段 4: 验证测试
1. **健康检查**
   ```bash
   curl -fsS http://127.0.0.1:8787/healthz
   ```

2. **数据库验证**
   - 表结构检查
   - 数据完整性验证
   - 连接测试

3. **功能测试**
   ```bash
   curl -H "X-API-Key: demo-key-123" http://127.0.0.1:8787/api/test
   ```

## 数据库设计

### 表结构

#### 1. api_keys 表
```sql
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,           -- API密钥
    name TEXT,                          -- 密钥名称
    quota_limit INTEGER DEFAULT 1000,   -- 配额限制
    quota_used INTEGER DEFAULT 0,       -- 已使用配额
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1         -- 是否激活
);
```

#### 2. usage_stats 表
```sql
CREATE TABLE usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,              -- API密钥
    endpoint TEXT NOT NULL,             -- 访问端点
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,           -- 响应时间(毫秒)
    status_code INTEGER,                -- 状态码
    FOREIGN KEY (api_key) REFERENCES api_keys(key)
);
```

### 索引优化
```sql
CREATE INDEX idx_api_keys_key ON api_keys(key);
CREATE INDEX idx_usage_stats_api_key ON usage_stats(api_key);
CREATE INDEX idx_usage_stats_timestamp ON usage_stats(timestamp);
```

### 初始数据
```sql
INSERT INTO api_keys (key, name, quota_limit) VALUES 
    ('demo-key-123', '演示密钥', 100),
    ('test-key-456', '测试密钥', 500);
```

## 迁移验证

### 1. 基础验证
```bash
# 健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 数据库文件检查
ls -la /opt/roc/quota-proxy/data/quota.db

# 表结构检查
sqlite3 /opt/roc/quota-proxy/data/quota.db ".tables"
```

### 2. 功能验证
```bash
# API 测试
curl -H "X-API-Key: demo-key-123" http://127.0.0.1:8787/api/test

# 配额检查
curl -H "X-API-Key: demo-key-123" http://127.0.0.1:8787/api/quota
```

### 3. 数据验证
```bash
# 密钥统计
sqlite3 /opt/roc/quota-proxy/data/quota.db \
  "SELECT key, name, quota_used, quota_limit FROM api_keys;"

# 使用统计
sqlite3 /opt/roc/quota-proxy/data/quota.db \
  "SELECT COUNT(*) as total_requests, 
          AVG(response_time_ms) as avg_response_time 
   FROM usage_stats;"
```

## 故障排除

### 常见问题

#### 1. 迁移失败：服务器连接问题
**症状**: SSH 连接失败
**解决方案**:
```bash
# 检查 SSH 密钥权限
chmod 600 ~/.ssh/id_ed25519_roc_server

# 测试连接
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 echo "测试"
```

#### 2. 迁移失败：服务状态问题
**症状**: quota-proxy 服务未运行
**解决方案**:
```bash
# 启动服务
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose up -d'

# 检查日志
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose logs quota-proxy'
```

#### 3. 迁移失败：数据库权限问题
**症状**: 无法创建数据库文件
**解决方案**:
```bash
# 检查目录权限
ssh root@8.210.185.194 'ls -la /opt/roc/quota-proxy/data/'

# 修复权限
ssh root@8.210.185.194 'chown -R 1000:1000 /opt/roc/quota-proxy/data/'
```

#### 4. 迁移后服务无法启动
**症状**: 健康检查失败
**解决方案**:
```bash
# 恢复备份
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && \
  cp data/quota.db.backup.* data/quota.db && \
  docker compose restart quota-proxy'

# 检查配置
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && cat .env | grep DATABASE'
```

### 回滚步骤

#### 完整回滚流程
1. **停止服务**
   ```bash
   ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose stop quota-proxy'
   ```

2. **恢复数据库备份**
   ```bash
   ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && \
     cp data/quota.db.backup.latest data/quota.db'
   ```

3. **恢复配置**
   ```bash
   ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && \
     sed -i 's|DATABASE_URL=.*|# DATABASE_URL=|' .env'
   ```

4. **重启服务**
   ```bash
   ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose up -d quota-proxy'
   ```

## 维护指南

### 日常维护

#### 1. 数据库备份
```bash
# 手动备份
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && \
  cp data/quota.db data/quota.db.backup.$(date +%Y%m%d)'

# 自动备份（cron）
0 2 * * * ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && cp data/quota.db data/quota.db.backup.$(date +\%Y\%m\%d)'
```

#### 2. 数据库优化
```bash
# 清理旧数据（保留30天）
ssh root@8.210.185.194 'sqlite3 /opt/roc/quota-proxy/data/quota.db \
  "DELETE FROM usage_stats WHERE timestamp < datetime(\"now\", \"-30 days\");"'

# 数据库压缩
ssh root@8.210.185.194 'sqlite3 /opt/roc/quota-proxy/data/quota.db "VACUUM;"'
```

#### 3. 监控检查
```bash
# 数据库大小监控
ssh root@8.210.185.194 'du -h /opt/roc/quota-proxy/data/quota.db'

# 表大小统计
ssh root@8.210.185.194 'sqlite3 /opt/roc/quota-proxy/data/quota.db \
  "SELECT name, COUNT(*) as row_count FROM sqlite_master WHERE type=\"table\" GROUP BY name;"'
```

### 性能优化

#### 1. 查询优化
```sql
-- 创建复合索引
CREATE INDEX idx_usage_stats_api_key_timestamp 
ON usage_stats(api_key, timestamp);

-- 定期分析
ANALYZE;
```

#### 2. 连接池配置
```javascript
// quota-proxy 配置
const dbConfig = {
  connection: {
    filename: '/opt/roc/quota-proxy/data/quota.db',
    busyTimeout: 5000
  },
  pool: {
    max: 10,
    min: 2,
    idleTimeoutMillis: 30000
  }
};
```

## 集成指南

### 与现有系统集成

#### 1. 配置管理
```bash
# 环境变量配置
export DATABASE_URL="file:/opt/roc/quota-proxy/data/quota.db"
export DATABASE_LOGGING="false"

# Docker Compose 配置
services:
  quota-proxy:
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - DATABASE_LOGGING=${DATABASE_LOGGING}
```

#### 2. 监控集成
```yaml
# Prometheus 配置
scrape_configs:
  - job_name: 'quota-proxy'
    static_configs:
      - targets: ['8.210.185.194:8787']
    metrics_path: '/metrics'
```

#### 3. 日志集成
```bash
# 日志收集
docker compose logs quota-proxy >> /var/log/quota-proxy/app.log

# 日志轮转
logrotate /etc/logrotate.d/quota-proxy
```

### CI/CD 集成

#### 1. 迁移测试
```yaml
# GitHub Actions
name: Database Migration Test
on: [push]
jobs:
  test-migration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test migration script
        run: ./scripts/migrate-to-sqlite.sh --dry-run
```

#### 2. 部署流水线
```yaml
# 部署阶段
deploy:
  stage: deploy
  script:
    - ./scripts/migrate-to-sqlite.sh --server $PRODUCTION_SERVER
    - ./scripts/verify-quota-proxy-db.sh --server $PRODUCTION_SERVER
```

## 安全考虑

### 1. 数据库安全
- 数据库文件权限: `600` (仅所有者可读写)
- 备份文件加密: 可选 GPG 加密
- 访问控制: 仅 quota-proxy 用户可访问

### 2. 网络安全
- 数据库仅本地访问
- 防火墙限制数据库端口
- SSH 密钥认证

### 3. 数据安全
- 定期备份验证
- 备份文件完整性检查
- 敏感数据加密存储

## 附录

### A. 迁移检查清单
- [ ] 服务器连接测试
- [ ] 服务状态检查
- [ ] 磁盘空间验证
- [ ] 备份创建确认
- [ ] 迁移执行完成
- [ ] 服务重启验证
- [ ] 功能测试通过
- [ ] 监控配置更新

### B. 性能基准
- 数据库文件大小: < 100MB
- 查询响应时间: < 50ms
- 并发连接数: 10-100
- 数据保留周期: 30天

### C. 相关文档
- [SQLite 数据库初始化指南](./sqlite-database-initialization.md)
- [quota-proxy 数据库验证指南](./quota-proxy-database-verification.md)
- [Docker Compose 部署指南](../deployment/docker-compose-guide.md)

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**状态**: 生产就绪