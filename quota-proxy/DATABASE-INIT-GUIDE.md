# 数据库初始化指南

本文档介绍如何初始化 quota-proxy 的 SQLite 数据库。

## 快速开始

### 1. 初始化数据库

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 创建数据库文件（如果不存在）
touch quota.db

# 执行初始化脚本
sqlite3 quota.db < init-db.sql
```

### 2. 验证数据库结构

```bash
# 检查数据库结构
sqlite3 quota.db ".schema"

# 检查表列表
sqlite3 quota.db ".tables"

# 检查视图列表
sqlite3 quota.db ".fullschema" | grep -i view
```

### 3. 查看初始化数据

```bash
# 查看系统配置
sqlite3 quota.db "SELECT * FROM system_config;"

# 查看密钥使用情况汇总视图
sqlite3 quota.db "SELECT * FROM key_usage_summary;"
```

## 数据库结构

### 主要表

#### 1. `api_keys` - API密钥表
存储所有API密钥信息，包括配额和使用情况。

| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER | 主键 |
| key_hash | TEXT | API密钥的SHA256哈希值 |
| key_type | TEXT | 密钥类型：trial/standard/premium |
| name | TEXT | 密钥名称/描述 |
| created_at | TIMESTAMP | 创建时间 |
| expires_at | TIMESTAMP | 过期时间（NULL表示永不过期） |
| total_quota | INTEGER | 总配额（请求次数） |
| used_quota | INTEGER | 已用配额 |
| is_active | BOOLEAN | 是否激活 |
| metadata | TEXT | JSON格式的元数据 |

#### 2. `request_logs` - 请求日志表
记录所有API请求，用于审计和调试。

| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER | 主键 |
| key_hash | TEXT | 关联的API密钥哈希 |
| endpoint | TEXT | 请求的端点 |
| method | TEXT | HTTP方法 |
| status_code | INTEGER | 响应状态码 |
| request_time | TIMESTAMP | 请求时间 |
| response_time_ms | INTEGER | 响应时间（毫秒） |
| user_agent | TEXT | 用户代理 |
| remote_ip | TEXT | 客户端IP |
| metadata | TEXT | JSON格式的额外信息 |

#### 3. `admins` - 管理员表
用于管理界面认证。

| 字段 | 类型 | 描述 |
|------|------|------|
| id | INTEGER | 主键 |
| username | TEXT | 用户名 |
| password_hash | TEXT | bcrypt哈希密码 |
| created_at | TIMESTAMP | 创建时间 |
| last_login | TIMESTAMP | 最后登录时间 |
| is_active | BOOLEAN | 是否激活 |

#### 4. `system_config` - 系统配置表
存储系统级配置参数。

| 字段 | 类型 | 描述 |
|------|------|------|
| key | TEXT | 配置键（主键） |
| value | TEXT | 配置值 |
| description | TEXT | 配置描述 |
| updated_at | TIMESTAMP | 更新时间 |

### 视图

#### 1. `key_usage_summary` - 密钥使用情况汇总
按密钥类型汇总使用情况统计。

#### 2. `recent_requests_24h` - 最近24小时请求统计
按端点和方法统计最近24小时的请求情况。

## 使用示例

### 1. 创建试用密钥

```sql
-- 生成随机密钥（在实际应用中应使用安全的随机生成）
INSERT INTO api_keys (key_hash, key_type, name, expires_at, total_quota)
VALUES (
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', -- SHA256('test-key')
    'trial',
    '测试密钥',
    datetime('now', '+30 days'),
    1000
);
```

### 2. 记录API请求

```sql
INSERT INTO request_logs (key_hash, endpoint, method, status_code, response_time_ms, user_agent, remote_ip)
VALUES (
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    '/api/v1/chat',
    'POST',
    200,
    150,
    'OpenClaw/1.0',
    '192.168.1.100'
);
```

### 3. 更新密钥使用量

```sql
UPDATE api_keys 
SET used_quota = used_quota + 1 
WHERE key_hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
```

### 4. 检查密钥状态

```sql
-- 检查密钥是否有效（未过期、已激活、有剩余配额）
SELECT 
    key_type,
    name,
    total_quota,
    used_quota,
    total_quota - used_quota as remaining_quota,
    expires_at,
    CASE 
        WHEN expires_at < CURRENT_TIMESTAMP THEN '已过期'
        WHEN is_active = 0 THEN '已停用'
        WHEN used_quota >= total_quota THEN '配额已用完'
        ELSE '有效'
    END as status
FROM api_keys
WHERE key_hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
```

## 管理命令

### 1. 备份数据库

```bash
# 完整备份
sqlite3 quota.db ".backup quota-backup-$(date +%Y%m%d-%H%M%S).db"

# 导出为SQL
sqlite3 quota.db .dump > quota-dump-$(date +%Y%m%d-%H%M%S).sql
```

### 2. 性能优化

```bash
# 启用WAL模式（提高并发性能）
sqlite3 quota.db "PRAGMA journal_mode=WAL;"

# 设置缓存大小（单位：页，默认2000）
sqlite3 quota.db "PRAGMA cache_size=-20000;"

# 执行优化
sqlite3 quota.db "VACUUM; ANALYZE;"
```

### 3. 监控查询

```bash
# 查看数据库大小
ls -lh quota.db

# 查看表大小
sqlite3 quota.db "SELECT name, (pgsize*page_count)/1024/1024 as size_mb FROM sqlite_master, dbstat WHERE type='table' AND name=sqlite_master.name ORDER BY size_mb DESC;"

# 查看最近查询性能
sqlite3 quota.db "SELECT endpoint, COUNT(*) as count, AVG(response_time_ms) as avg_ms FROM request_logs WHERE request_time > datetime('now', '-1 hour') GROUP BY endpoint ORDER BY avg_ms DESC LIMIT 10;"
```

## 集成到quota-proxy

### 环境变量配置

在 `.env` 文件中添加数据库配置：

```bash
# SQLite数据库配置
DATABASE_PATH=./quota.db
DATABASE_INIT_SCRIPT=./init-db.sql

# 数据库连接池配置
DATABASE_MAX_CONNECTIONS=10
DATABASE_CONNECTION_TIMEOUT=5000
```

### 初始化检查脚本

创建 `check-db.sh` 脚本：

```bash
#!/bin/bash

DB_FILE="${DATABASE_PATH:-./quota.db}"
INIT_SCRIPT="${DATABASE_INIT_SCRIPT:-./init-db.sql}"

if [ ! -f "$DB_FILE" ]; then
    echo "数据库文件不存在，正在初始化..."
    sqlite3 "$DB_FILE" < "$INIT_SCRIPT"
    if [ $? -eq 0 ]; then
        echo "数据库初始化成功！"
    else
        echo "数据库初始化失败！"
        exit 1
    fi
else
    echo "数据库文件已存在，跳过初始化。"
fi

# 验证数据库结构
echo "验证数据库结构..."
sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" | grep -q '[0-9]'
if [ $? -eq 0 ]; then
    echo "数据库结构验证通过。"
else
    echo "数据库结构验证失败！"
    exit 1
fi
```

## 故障排除

### 常见问题

1. **数据库文件权限问题**
   ```bash
   chmod 644 quota.db
   chmod +x check-db.sh
   ```

2. **SQLite命令未找到**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install sqlite3
   
   # CentOS/RHEL
   sudo yum install sqlite
   ```

3. **数据库损坏**
   ```bash
   # 检查数据库完整性
   sqlite3 quota.db "PRAGMA integrity_check;"
   
   # 修复损坏的数据库
   sqlite3 quota.db ".recover" | sqlite3 quota-recovered.db
   ```

### 性能问题

1. **查询缓慢**
   - 确保在常用查询字段上创建了索引
   - 定期执行 `VACUUM` 和 `ANALYZE`
   - 考虑分区大表（如 `request_logs`）

2. **并发写入冲突**
   - 启用WAL模式：`PRAGMA journal_mode=WAL;`
   - 增加超时时间：`PRAGMA busy_timeout=5000;`

## 下一步

1. **集成到quota-proxy服务**
   - 修改 `main.go` 添加数据库连接
   - 实现API密钥验证逻辑
   - 添加请求日志记录

2. **添加管理API**
   - `POST /admin/keys` - 生成新密钥
   - `GET /admin/usage` - 查看使用情况
   - `DELETE /admin/keys/{id}` - 删除密钥

3. **监控和告警**
   - 添加数据库健康检查端点
   - 实现配额使用率告警
   - 添加审计日志导出功能