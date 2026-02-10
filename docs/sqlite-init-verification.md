# SQLite 数据库初始化验证指南

## 概述
本文档提供 quota-proxy SQLite 数据库初始化功能的验证方法，确保数据库结构正确且可正常工作。

## 验证脚本

### 快速验证
```bash
./scripts/verify-sqlite-init.sh
```

### 验证步骤
1. **环境检查**：验证 sqlite3 命令是否可用
2. **数据库创建**：创建临时测试数据库
3. **表结构初始化**：创建必要的表结构
4. **数据操作**：插入测试数据并查询验证
5. **清理**：自动清理测试数据库

## 数据库结构

### api_keys 表（API密钥管理）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 主键 |
| key | TEXT UNIQUE NOT NULL | API密钥（唯一） |
| name | TEXT | 密钥名称 |
| quota_daily | INTEGER DEFAULT 100 | 每日配额 |
| quota_monthly | INTEGER DEFAULT 1000 | 每月配额 |
| created_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 更新时间 |

### usage_logs 表（使用记录）
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 主键 |
| api_key_id | INTEGER NOT NULL | 关联的API密钥ID |
| endpoint | TEXT NOT NULL | 访问的端点 |
| response_time_ms | INTEGER | 响应时间（毫秒） |
| timestamp | TIMESTAMP DEFAULT CURRENT_TIMESTAMP | 记录时间 |

### 索引
1. `idx_api_keys_key`：API密钥查询优化
2. `idx_usage_logs_api_key_id`：按API密钥查询使用记录
3. `idx_usage_logs_timestamp`：按时间范围查询

## 集成验证

### 1. 本地开发环境
```bash
# 创建开发数据库
sqlite3 dev.db < scripts/sql/schema.sql

# 验证表结构
sqlite3 dev.db ".schema"

# 运行测试
./scripts/test-database-operations.sh
```

### 2. Docker 环境验证
```bash
# 在容器内验证
docker exec -it quota-proxy sqlite3 /data/quota.db ".tables"

# 检查数据目录权限
docker exec -it quota-proxy ls -la /data/
```

### 3. 生产环境验证
```bash
# 通过SSH验证服务器数据库
ssh root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db '.schema'"
```

## 故障排除

### 常见问题
1. **sqlite3 命令未找到**
   ```bash
   sudo apt-get install sqlite3
   ```

2. **数据库文件权限问题**
   ```bash
   chmod 644 /path/to/database.db
   chown www-data:www-data /path/to/database.db
   ```

3. **表结构不匹配**
   ```bash
   # 备份旧数据库
   cp quota.db quota.db.backup
   
   # 重新初始化
   sqlite3 quota.db < scripts/sql/schema.sql
   ```

### 验证命令
```bash
# 完整验证流程
./scripts/verify-sqlite-init.sh && \
echo "✅ 数据库初始化验证通过" || \
echo "❌ 验证失败，请检查错误信息"
```

## 下一步
1. ✅ 完成数据库结构验证
2. 🔄 在 quota-proxy 代码中集成 SQLite
3. 🔄 实现 /admin/keys 端点
4. 🔄 实现 /admin/usage 端点
5. 🔄 添加数据库迁移脚本

## 相关文档
- [quota-proxy 管理接口验证](./admin-endpoints-verification.md)
- [部署增强脚本说明](./deploy-admin-enhancements.md)
- [综合测试指南](./verify.md)
