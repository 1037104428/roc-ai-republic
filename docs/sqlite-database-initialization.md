# SQLite数据库初始化指南

本文档介绍quota-proxy SQLite数据库的初始化、配置和使用方法，为TODO-001配置管理工具提供数据库支持。

## 概述

`init-sqlite-db.sh`脚本为quota-proxy提供SQLite数据库初始化功能，支持：
- 自动创建数据库文件和目录
- 创建API密钥表和使用统计表
- 创建索引以提高查询性能
- 验证数据库结构和完整性
- 提供使用示例和集成指南

## 快速开始

### 1. 初始化数据库

```bash
# 使用默认路径 (/opt/roc/quota-proxy/data/quota.db)
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/init-sqlite-db.sh

# 使用自定义路径
./scripts/init-sqlite-db.sh --db-path ./data/test.db

# 干运行模式（只显示SQL不执行）
./scripts/init-sqlite-db.sh --dry-run
```

### 2. 验证数据库

```bash
# 查看数据库结构
sqlite3 /opt/roc/quota-proxy/data/quota.db '.tables'
sqlite3 /opt/roc/quota-proxy/data/quota.db 'PRAGMA table_info(api_keys);'
```

## 数据库设计

### 表结构

#### api_keys表（API密钥表）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 主键ID |
| key | TEXT UNIQUE NOT NULL | API密钥（唯一） |
| name | TEXT | 密钥名称 |
| description | TEXT | 密钥描述 |
| total_quota | INTEGER DEFAULT 1000 | 总配额 |
| used_quota | INTEGER DEFAULT 0 | 已使用配额 |
| remaining_quota | INTEGER DEFAULT 1000 | 剩余配额 |
| is_active | INTEGER DEFAULT 1 | 是否激活（1=激活，0=禁用） |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 更新时间 |
| expires_at | TIMESTAMP | 过期时间 |
| metadata | TEXT | 元数据（JSON格式） |

#### usage_stats表（使用统计表）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 主键ID |
| key_id | INTEGER NOT NULL | 关联的API密钥ID |
| endpoint | TEXT NOT NULL | 访问的端点 |
| request_count | INTEGER DEFAULT 1 | 请求次数 |
| last_used | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 最后使用时间 |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 创建时间 |

### 索引

为提高查询性能，创建以下索引：

1. `idx_api_keys_key` - API密钥查询索引
2. `idx_api_keys_is_active` - 激活状态查询索引
3. `idx_usage_stats_key_id` - 按密钥ID查询使用统计
4. `idx_usage_stats_endpoint` - 按端点查询使用统计
5. `idx_usage_stats_last_used` - 按最后使用时间查询

## 脚本功能详解

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--db-path <路径>` | SQLite数据库文件路径 | `/opt/roc/quota-proxy/data/quota.db` |
| `--dry-run` | 只显示SQL语句，不实际执行 | `false` |
| `--quiet` | 安静模式，只显示错误和重要信息 | `false` |
| `--help` 或 `-h` | 显示帮助信息 | - |

### 功能模块

1. **依赖检查** - 检查sqlite3是否安装
2. **目录创建** - 自动创建数据库目录
3. **表结构初始化** - 创建表和索引
4. **数据库验证** - 验证表结构和完整性
5. **示例生成** - 生成使用示例和集成指南

## 与quota-proxy集成

### 1. 环境变量配置

在quota-proxy的`.env`配置文件中添加：

```bash
# SQLite数据库配置
DB_PATH=/opt/roc/quota-proxy/data/quota.db
DB_SYNC_MODE=normal
DB_JOURNAL_MODE=WAL
```

### 2. Node.js连接示例

```javascript
// database.js
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

class Database {
    constructor() {
        this.dbPath = process.env.DB_PATH || '/opt/roc/quota-proxy/data/quota.db';
        this.db = null;
    }

    async connect() {
        return new Promise((resolve, reject) => {
            this.db = new sqlite3.Database(this.dbPath, (err) => {
                if (err) {
                    reject(err);
                } else {
                    console.log(`Connected to SQLite database: ${this.dbPath}`);
                    resolve();
                }
            });
        });
    }

    async getApiKey(key) {
        return new Promise((resolve, reject) => {
            const sql = 'SELECT * FROM api_keys WHERE key = ? AND is_active = 1';
            this.db.get(sql, [key], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });
    }

    async updateQuota(key, used) {
        return new Promise((resolve, reject) => {
            const sql = `
                UPDATE api_keys 
                SET used_quota = used_quota + ?, 
                    remaining_quota = total_quota - (used_quota + ?),
                    updated_at = CURRENT_TIMESTAMP
                WHERE key = ? AND is_active = 1
                RETURNING remaining_quota
            `;
            this.db.get(sql, [used, used, key], (err, row) => {
                if (err) reject(err);
                else resolve(row ? row.remaining_quota : null);
            });
        });
    }

    async recordUsage(keyId, endpoint) {
        return new Promise((resolve, reject) => {
            const sql = `
                INSERT INTO usage_stats (key_id, endpoint) 
                VALUES (?, ?)
            `;
            this.db.run(sql, [keyId, endpoint], function(err) {
                if (err) reject(err);
                else resolve(this.lastID);
            });
        });
    }

    async createApiKey(keyData) {
        return new Promise((resolve, reject) => {
            const sql = `
                INSERT INTO api_keys (
                    key, name, description, total_quota, 
                    is_active, expires_at, metadata
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            `;
            const params = [
                keyData.key,
                keyData.name || null,
                keyData.description || null,
                keyData.total_quota || 1000,
                keyData.is_active !== undefined ? keyData.is_active : 1,
                keyData.expires_at || null,
                keyData.metadata ? JSON.stringify(keyData.metadata) : null
            ];
            
            this.db.run(sql, params, function(err) {
                if (err) reject(err);
                else resolve(this.lastID);
            });
        });
    }

    async close() {
        return new Promise((resolve, reject) => {
            this.db.close((err) => {
                if (err) reject(err);
                else {
                    console.log('Database connection closed');
                    resolve();
                }
            });
        });
    }
}

module.exports = Database;
```

### 3. 在quota-proxy中使用

```javascript
// app.js 或相关文件
const Database = require('./database');
const db = new Database();

// 启动时连接数据库
async function startServer() {
    try {
        await db.connect();
        
        // 中间件：API密钥验证和配额检查
        app.use('/api/*', async (req, res, next) => {
            const apiKey = req.headers['x-api-key'];
            if (!apiKey) {
                return res.status(401).json({ error: 'API key required' });
            }
            
            const keyInfo = await db.getApiKey(apiKey);
            if (!keyInfo) {
                return res.status(403).json({ error: 'Invalid API key' });
            }
            
            if (keyInfo.remaining_quota <= 0) {
                return res.status(429).json({ error: 'Quota exhausted' });
            }
            
            // 附加密钥信息到请求对象
            req.apiKeyInfo = keyInfo;
            next();
        });
        
        // 响应后更新配额
        app.use('/api/*', async (req, res, next) => {
            const originalSend = res.send;
            res.send = function(data) {
                // 记录使用统计
                if (req.apiKeyInfo) {
                    db.recordUsage(req.apiKeyInfo.id, req.path).catch(console.error);
                    
                    // 更新配额（假设每次请求消耗1个配额）
                    db.updateQuota(req.apiKeyInfo.key, 1).catch(console.error);
                }
                originalSend.call(this, data);
            };
            next();
        });
        
        console.log('Server started with database integration');
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
}
```

## 管理操作

### 1. 生成API密钥

```bash
# 使用sqlite3命令行
sqlite3 /opt/roc/quota-proxy/data/quota.db "
INSERT INTO api_keys (key, name, total_quota) 
VALUES ('$(openssl rand -hex 16)', '生产密钥', 10000);
"

# 或使用Node.js脚本
node -e "
const crypto = require('crypto');
const key = crypto.randomBytes(16).toString('hex');
console.log('Generated API key:', key);
"
```

### 2. 查看使用统计

```sql
-- 查看所有密钥及其使用情况
SELECT 
    ak.key,
    ak.name,
    ak.total_quota,
    ak.used_quota,
    ak.remaining_quota,
    COUNT(us.id) as total_requests,
    MAX(us.last_used) as last_used
FROM api_keys ak
LEFT JOIN usage_stats us ON ak.id = us.key_id
WHERE ak.is_active = 1
GROUP BY ak.id
ORDER BY ak.created_at DESC;

-- 查看端点使用统计
SELECT 
    endpoint,
    COUNT(*) as request_count,
    MIN(last_used) as first_used,
    MAX(last_used) as last_used
FROM usage_stats
GROUP BY endpoint
ORDER BY request_count DESC;
```

### 3. 配额管理

```sql
-- 重置密钥配额
UPDATE api_keys 
SET used_quota = 0, 
    remaining_quota = total_quota,
    updated_at = CURRENT_TIMESTAMP
WHERE key = 'your-api-key';

-- 增加配额
UPDATE api_keys 
SET total_quota = total_quota + 1000,
    remaining_quota = remaining_quota + 1000,
    updated_at = CURRENT_TIMESTAMP
WHERE key = 'your-api-key';

-- 禁用密钥
UPDATE api_keys 
SET is_active = 0,
    updated_at = CURRENT_TIMESTAMP
WHERE key = 'your-api-key';
```

## 生产环境部署

### 1. 数据库备份

```bash
#!/bin/bash
# backup-database.sh
BACKUP_DIR="/opt/roc/quota-proxy/backups"
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/quota_backup_$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"
echo "Backup created: $BACKUP_FILE"

# 保留最近7天的备份
find "$BACKUP_DIR" -name "quota_backup_*.db" -mtime +7 -delete
```

### 2. 监控和告警

```bash
#!/bin/bash
# monitor-database.sh
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
ALERT_THRESHOLD=90  # 配额使用率告警阈值（%）

# 检查数据库文件大小
DB_SIZE=$(du -k "$DB_PATH" | cut -f1)
if [ "$DB_SIZE" -gt 1048576 ]; then  # 大于1GB
    echo "WARNING: Database size exceeds 1GB: ${DB_SIZE}KB"
fi

# 检查配额使用率
sqlite3 "$DB_PATH" "
SELECT 
    key,
    name,
    total_quota,
    used_quota,
    (used_quota * 100.0 / total_quota) as usage_percent
FROM api_keys
WHERE is_active = 1 AND total_quota > 0
" | while IFS='|' read -r key name total used percent; do
    if [ $(echo "$percent > $ALERT_THRESHOLD" | bc) -eq 1 ]; then
        echo "ALERT: Key '$key' ($name) usage at ${percent}%"
    fi
done
```

### 3. 性能优化

```sql
-- 启用WAL模式（提高并发性能）
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;

-- 调整缓存大小
PRAGMA cache_size = -2000;  -- 2MB缓存

-- 定期清理旧数据
DELETE FROM usage_stats 
WHERE last_used < datetime('now', '-90 days');

-- 定期优化数据库
VACUUM;
ANALYZE;
```

## 故障排除

### 常见问题

1. **数据库文件权限错误**
   ```bash
   sudo chown -R $(whoami):$(whoami) /opt/roc/quota-proxy/data
   sudo chmod 755 /opt/roc/quota-proxy/data
   ```

2. **sqlite3未安装**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install sqlite3
   
   # CentOS/RHEL
   sudo yum install sqlite
   
   # macOS
   brew install sqlite
   ```

3. **数据库损坏**
   ```bash
   # 检查数据库完整性
   sqlite3 quota.db "PRAGMA integrity_check;"
   
   # 修复损坏的数据库
   sqlite3 corrupted.db ".recover" | sqlite3 recovered.db
   ```

4. **连接数过多**
   ```bash
   # 查看当前连接
   lsof quota.db
   
   # 在代码中确保及时关闭连接
   try {
       // 使用数据库
   } finally {
       db.close();
   }
   ```

### 日志和调试

```bash
# 启用SQLite调试日志
export SQLITE_LOG=1
export SQLITE_SHELL_DEBUG=1

# 查看数据库状态
sqlite3 quota.db ".stats"
sqlite3 quota.db ".dbinfo"

# 查看查询计划
sqlite3 quota.db "EXPLAIN QUERY PLAN SELECT * FROM api_keys WHERE key = 'test';"
```

## 下一步计划

1. **数据库迁移工具** - 支持从内存存储迁移到SQLite
2. **数据导入/导出** - 支持CSV/JSON格式的数据导入导出
3. **复制和同步** - 支持多节点数据库同步
4. **监控仪表板** - 提供Web界面查看使用统计
5. **自动清理策略** - 基于时间的自动数据清理

## 相关文档

- [quota-proxy快速入门指南](./quota-proxy-quickstart.md)
- [管理员接口测试指南](./admin-api-testing.md)
- [自动化TRIAL_KEY管理](./automated-trial-key-management.md)
- [TODO-001配置管理工具规划](./todo-001-config-management.md)

---

**最后更新**: 2026-02-10  
**脚本版本**: 1.0.0  
**数据库版本**: 1.0