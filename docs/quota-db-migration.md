# quota-proxy数据库迁移指南

## 概述

本文档介绍quota-proxy数据库迁移脚本的使用方法和最佳实践。数据库迁移是维护数据库结构演进的关键工具，确保在不同版本间平滑升级和降级。

## 迁移脚本功能

`migrate-quota-db.sh` 脚本提供以下功能：

1. **数据库版本管理** - 跟踪数据库结构版本
2. **自动化迁移** - 执行SQL迁移脚本
3. **备份保护** - 自动创建迁移前备份
4. **事务安全** - 使用事务确保迁移原子性
5. **多种运行模式** - 支持模拟运行、详细模式、安静模式
6. **版本控制** - 支持指定目标版本或自动选择最新版本

## 快速开始

### 基本用法

```bash
# 查看帮助
./scripts/migrate-quota-db.sh --help

# 列出所有可用迁移脚本
./scripts/migrate-quota-db.sh --list

# 模拟运行迁移（不实际执行）
./scripts/migrate-quota-db.sh --dry-run

# 详细模式运行迁移
./scripts/migrate-quota-db.sh --verbose

# 迁移到指定版本
./scripts/migrate-quota-db.sh --target-version v1.1.0
```

### 默认配置

- **数据库路径**: `./data/quota.db`
- **备份目录**: `./backups`
- **迁移脚本目录**: `./migrations`

## 迁移脚本目录结构

```
migrations/
├── v1.0.0.sql    # 初始版本
├── v1.1.0.sql    # 添加新功能
├── v1.2.0.sql    # 性能优化
└── v2.0.0.sql    # 重大更新
```

## 迁移脚本格式

每个迁移脚本应包含完整的SQL语句，支持以下操作：

### 1. 表结构修改
```sql
-- 添加新表
CREATE TABLE IF NOT EXISTS new_table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 添加列
ALTER TABLE existing_table ADD COLUMN new_column TEXT;

-- 修改列
-- SQLite不支持直接修改列，需要创建新表
```

### 2. 索引管理
```sql
-- 创建索引
CREATE INDEX IF NOT EXISTS idx_table_column ON table_name(column_name);

-- 删除索引
DROP INDEX IF EXISTS idx_table_column;
```

### 3. 数据迁移
```sql
-- 插入初始数据
INSERT INTO table_name (column1, column2)
SELECT old_column1, old_column2 FROM old_table;

-- 更新现有数据
UPDATE table_name SET column = 'new_value' WHERE condition;
```

### 4. 触发器
```sql
-- 创建触发器
CREATE TRIGGER IF NOT EXISTS trigger_name
AFTER INSERT ON table_name
BEGIN
    -- 触发器逻辑
END;
```

## 版本管理

### 版本表结构

迁移脚本会自动维护 `schema_version` 表：

```sql
CREATE TABLE schema_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,        -- 版本号 (如: v1.0.0)
    applied_at TEXT NOT NULL,     -- 应用时间
    description TEXT              -- 迁移描述
);
```

### 版本号约定

建议使用语义化版本号：
- **主版本号**: 不兼容的API修改
- **次版本号**: 向下兼容的功能性新增
- **修订号**: 向下兼容的问题修正

## 备份策略

### 自动备份

每次迁移前会自动创建备份：
- 备份文件命名: `quota_db_backup_YYYYMMDD_HHMMSS.db`
- 备份目录: `./backups` (可配置)
- 保留策略: 手动管理，建议定期清理

### 恢复备份

```bash
# 查看备份文件
ls -la ./backups/

# 恢复备份
cp ./backups/quota_db_backup_20260210_212352.db ./data/quota.db
```

## 错误处理

### 常见错误

1. **数据库文件不存在**
   ```
   [ERROR] 数据库文件不存在: ./data/quota.db
   ```

2. **数据库文件损坏**
   ```
   [ERROR] 数据库文件损坏或不是有效的SQLite数据库
   ```

3. **迁移脚本不存在**
   ```
   [ERROR] 迁移脚本不存在: ./migrations/v1.1.0.sql
   ```

4. **SQL执行错误**
   ```
   [ERROR] 执行迁移SQL失败
   ```

### 故障排除

1. **检查数据库状态**
   ```bash
   sqlite3 ./data/quota.db ".tables"
   sqlite3 ./data/quota.db "SELECT * FROM schema_version;"
   ```

2. **验证迁移脚本**
   ```bash
   # 检查SQL语法
   sqlite3 :memory: < ./migrations/v1.1.0.sql
   ```

3. **手动恢复**
   ```bash
   # 停止quota-proxy服务
   docker compose stop quota-proxy
   
   # 恢复备份
   cp ./backups/quota_db_backup_*.db ./data/quota.db
   
   # 启动服务
   docker compose start quota-proxy
   ```

## 最佳实践

### 1. 开发流程

```bash
# 1. 创建迁移脚本
echo "-- v1.1.0: 添加用户表" > ./migrations/v1.1.0.sql

# 2. 编写SQL
cat >> ./migrations/v1.1.0.sql << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
EOF

# 3. 测试迁移
./scripts/migrate-quota-db.sh --dry-run --target-version v1.1.0

# 4. 执行迁移
./scripts/migrate-quota-db.sh --target-version v1.1.0
```

### 2. 生产环境部署

```bash
# 1. 备份生产数据库
ssh user@production-server "cd /opt/roc/quota-proxy && tar czf quota-backup-$(date +%Y%m%d).tar.gz data/"

# 2. 上传迁移脚本
scp -r migrations/ user@production-server:/opt/roc/quota-proxy/

# 3. 执行迁移（使用详细模式监控）
ssh user@production-server "cd /opt/roc/quota-proxy && ./scripts/migrate-quota-db.sh --verbose"

# 4. 验证迁移
ssh user@production-server "cd /opt/roc/quota-proxy && sqlite3 data/quota.db 'SELECT version, applied_at FROM schema_version ORDER BY id DESC LIMIT 1;'"
```

### 3. CI/CD集成

```yaml
# GitHub Actions示例
name: Database Migration

on:
  push:
    paths:
      - 'migrations/**'

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SQLite
        run: sudo apt-get install -y sqlite3
        
      - name: Test Migration
        run: |
          chmod +x ./scripts/migrate-quota-db.sh
          ./scripts/migrate-quota-db.sh --dry-run --verbose
          
      - name: Deploy to Production
        if: github.ref == 'refs/heads/main'
        run: |
          ssh user@production-server "cd /opt/roc/quota-proxy && git pull"
          ssh user@production-server "cd /opt/roc/quota-proxy && ./scripts/migrate-quota-db.sh --quiet"
```

## 示例迁移脚本

### v1.1.0.sql - 添加API使用统计功能

```sql
-- v1.1.0: 添加API使用统计功能
-- 创建时间: 2026-02-10
-- 描述: 添加API使用统计表，支持按日、按月统计

-- 创建API使用统计表
CREATE TABLE IF NOT EXISTS api_usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,
    date TEXT NOT NULL,           -- 日期 (YYYY-MM-DD)
    request_count INTEGER DEFAULT 0,
    total_duration_ms INTEGER DEFAULT 0,
    avg_duration_ms INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(api_key, date)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_usage_stats_date ON api_usage_stats(date);
CREATE INDEX IF NOT EXISTS idx_api_usage_stats_api_key ON api_usage_stats(api_key);

-- 创建更新触发器
CREATE TRIGGER IF NOT EXISTS update_api_usage_stats_timestamp
AFTER UPDATE ON api_usage_stats
BEGIN
    UPDATE api_usage_stats SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- 插入初始统计数据（从usage_logs迁移）
INSERT INTO api_usage_stats (api_key, date, request_count, total_duration_ms)
SELECT 
    api_key,
    DATE(timestamp) as date,
    COUNT(*) as request_count,
    SUM(duration_ms) as total_duration_ms
FROM usage_logs
WHERE timestamp >= DATE('now', '-30 days')
GROUP BY api_key, DATE(timestamp);

-- 更新平均时长
UPDATE api_usage_stats 
SET avg_duration_ms = CASE 
    WHEN request_count > 0 THEN total_duration_ms / request_count 
    ELSE 0 
END;
```

### v1.2.0.sql - 添加审计日志功能

```sql
-- v1.2.0: 添加审计日志功能
-- 创建时间: 2026-02-15
-- 描述: 添加系统审计日志表，记录关键操作

-- 创建审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,                  -- 操作用户
    action TEXT NOT NULL,          -- 操作类型
    resource_type TEXT NOT NULL,   -- 资源类型
    resource_id TEXT,              -- 资源ID
    details TEXT,                  -- 操作详情
    ip_address TEXT,               -- IP地址
    user_agent TEXT,               -- 用户代理
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);

-- 添加审计日志触发器示例
CREATE TRIGGER IF NOT EXISTS audit_api_key_creation
AFTER INSERT ON api_keys
BEGIN
    INSERT INTO audit_logs (action, resource_type, resource_id, details)
    VALUES ('CREATE', 'api_key', NEW.key, '创建API密钥: ' || NEW.name);
END;
```

## 监控和维护

### 监控迁移状态

```bash
# 查看迁移历史
sqlite3 ./data/quota.db "SELECT * FROM schema_version ORDER BY id DESC;"

# 检查数据库完整性
sqlite3 ./data/quota.db "PRAGMA integrity_check;"

# 查看表结构
sqlite3 ./data/quota.db ".schema"
```

### 定期维护任务

1. **清理旧备份**
   ```bash
   # 删除30天前的备份
   find ./backups -name "*.db" -mtime +30 -delete
   ```

2. **优化数据库**
   ```bash
   sqlite3 ./data/quota.db "VACUUM;"
   sqlite3 ./data/quota.db "ANALYZE;"
   ```

3. **验证迁移脚本**
   ```bash
   # 定期测试所有迁移脚本
   for migration in ./migrations/*.sql; do
     echo "测试: $(basename $migration)"
     sqlite3 :memory: < "$migration" && echo "✓ 通过" || echo "✗ 失败"
   done
   ```

## 安全注意事项

1. **权限管理**
   - 迁移脚本应具有最小必要权限
   - 生产环境使用专用数据库用户

2. **敏感数据处理**
   - 不要在迁移脚本中硬编码敏感信息
   - 使用环境变量或配置文件

3. **回滚计划**
   - 始终准备回滚方案
   - 测试备份恢复流程

4. **审计跟踪**
   - 记录所有迁移操作
   - 保留迁移日志供审计

## 故障恢复

### 完整恢复流程

```bash
# 1. 停止服务
docker compose stop quota-proxy

# 2. 恢复最新备份
LATEST_BACKUP=$(ls -t ./backups/quota_db_backup_*.db | head -1)
cp "$LATEST_BACKUP" ./data/quota.db

# 3. 验证恢复
sqlite3 ./data/quota.db "PRAGMA integrity_check;"

# 4. 启动服务
docker compose start quota-proxy

# 5. 验证服务
curl -f http://localhost:8787/healthz
```

## 总结

数据库迁移是quota-proxy持续演进的关键工具。通过规范的迁移流程、完善的备份策略和严格的测试验证，可以确保数据库结构变更的安全性和可靠性。

建议在每次发布新版本前，都创建相应的迁移脚本，并确保：
1. 迁移脚本经过充分测试
2. 有完整的回滚方案
3. 生产环境有备份保护
4. 迁移过程可监控、可审计