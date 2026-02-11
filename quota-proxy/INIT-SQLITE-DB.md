# SQLite数据库初始化指南

## 快速开始

### 初始化数据库

```bash
# 基本用法（在当前目录创建quota-proxy.db）
./init-sqlite-db.sh

# 指定数据库路径
./init-sqlite-db.sh --db-path /opt/roc/quota-proxy/quota-proxy.db

# 干运行模式（显示SQL但不执行）
./init-sqlite-db.sh --dry-run

# 详细输出模式
./init-sqlite-db.sh --verbose
```

### 验证数据库

```bash
# 检查数据库文件
ls -la quota-proxy.db

# 查看表结构
sqlite3 quota-proxy.db ".schema"

# 查看表记录
sqlite3 quota-proxy.db "SELECT * FROM api_keys;"
```

## 功能特性

### 1. 数据库表结构

脚本创建以下表结构：

#### api_keys (API密钥表)
- `key_hash`: 密钥哈希值（唯一标识）
- `key_type`: 密钥类型（admin/trial/regular）
- 速率限制配置（每分钟/每小时/每天）
- 使用统计（总请求数、最后使用时间）
- 有效期控制（创建时间、过期时间）
- 激活状态管理

#### usage_records (使用记录表)
- 记录每个API调用的详细信息
- 包含端点、方法、状态码、响应时间
- 请求/响应大小、用户代理、IP地址
- 时间戳索引便于查询分析

#### applications (应用表)
- 应用基本信息管理
- 所有者、联系方式、网站
- 创建/更新时间跟踪
- 激活状态控制

### 2. 性能优化

- **自动创建索引**：为常用查询字段创建索引
- **外键约束**：确保数据完整性
- **默认数据**：包含演示用的管理员和试用密钥

### 3. 安全特性

- 干运行模式支持
- 数据库文件权限检查
- 现有数据库保护（不覆盖已有数据）
- 演示密钥明确标记（生产环境需替换）

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--db-path PATH` | 数据库文件路径 | `./quota-proxy.db` |
| `--dry-run` | 干运行模式，显示SQL但不执行 | `false` |
| `--verbose` | 详细输出模式 | `false` |
| `--help` | 显示帮助信息 | - |

## 使用示例

### 示例1：基本初始化

```bash
# 在当前目录创建数据库
./init-sqlite-db.sh

# 输出示例：
# [INFO] 开始初始化SQLite数据库: ./quota-proxy.db
# [SUCCESS] 数据库初始化成功: ./quota-proxy.db
# [INFO] 数据库信息:
# 文件大小: 24K
# api_keys
# usage_records
# applications
# 表数量: 3
# [INFO] 表记录统计:
# api_keys: 2
# usage_records: 0
# applications: 1
# [SUCCESS] 数据库初始化完成，可以开始使用quota-proxy持久化功能
```

### 示例2：指定路径初始化

```bash
# 在指定目录创建数据库
./init-sqlite-db.sh --db-path /var/lib/quota-proxy/quota-proxy.db --verbose

# 如果目录不存在会自动创建
```

### 示例3：干运行验证

```bash
# 验证SQL语句而不实际执行
./init-sqlite-db.sh --dry-run --verbose

# 输出所有SQL语句，便于审查和调试
```

## CI/CD集成

### 在部署流程中使用

```bash
#!/bin/bash
# deploy-quota-proxy.sh

set -euo pipefail

# 1. 初始化数据库
cd /opt/roc/quota-proxy
./init-sqlite-db.sh --db-path ./quota-proxy.db

# 2. 验证数据库
if [ -f "./quota-proxy.db" ]; then
    echo "✅ 数据库创建成功"
    sqlite3 ./quota-proxy.db "SELECT COUNT(*) as table_count FROM sqlite_master WHERE type='table';"
else
    echo "❌ 数据库创建失败"
    exit 1
fi

# 3. 启动服务（假设使用Docker Compose）
docker-compose up -d
```

### 自动化测试

```bash
#!/bin/bash
# test-database-init.sh

# 测试干运行模式
./init-sqlite-db.sh --dry-run > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ 干运行模式测试通过"
else
    echo "❌ 干运行模式测试失败"
    exit 1
fi

# 测试实际初始化（使用临时文件）
TEMP_DB=$(mktemp)
./init-sqlite-db.sh --db-path "$TEMP_DB" > /dev/null

# 验证表数量
TABLE_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
if [ "$TABLE_COUNT" -eq 3 ]; then
    echo "✅ 数据库表创建测试通过（找到 $TABLE_COUNT 个表）"
else
    echo "❌ 数据库表创建测试失败（期望3个表，找到 $TABLE_COUNT 个）"
    exit 1
fi

# 清理
rm -f "$TEMP_DB"
```

## 故障排除

### 常见问题

#### 1. sqlite3命令未找到
```bash
# Ubuntu/Debian
sudo apt-get install sqlite3

# CentOS/RHEL
sudo yum install sqlite

# macOS
brew install sqlite
```

#### 2. 权限不足
```bash
# 检查目录权限
ls -la /opt/roc/

# 如果需要，创建目录并设置权限
sudo mkdir -p /opt/roc/quota-proxy
sudo chown -R $(whoami):$(whoami) /opt/roc/quota-proxy
```

#### 3. 数据库文件已存在
脚本会检测现有数据库文件并提示确认。可以选择：
- 按 `y` 继续：添加缺失的表，不删除现有数据
- 按 `n` 取消：保留现有数据库不变

### 调试技巧

1. **启用详细输出**
   ```bash
   ./init-sqlite-db.sh --verbose
   ```

2. **手动检查数据库**
   ```bash
   sqlite3 quota-proxy.db ".tables"
   sqlite3 quota-proxy.db ".schema api_keys"
   sqlite3 quota-proxy.db "SELECT * FROM sqlite_master;"
   ```

3. **查看脚本日志**
   ```bash
   # 重定向输出到文件
   ./init-sqlite-db.sh --db-path test.db 2>&1 | tee init.log
   ```

## 最佳实践

### 生产环境部署

1. **安全存储数据库**
   ```bash
   # 使用专用目录，设置适当权限
   sudo mkdir -p /var/lib/quota-proxy
   sudo chown -R quota-proxy:quota-proxy /var/lib/quota-proxy
   sudo chmod 750 /var/lib/quota-proxy
   ```

2. **备份策略**
   ```bash
   # 定期备份数据库
   sqlite3 /var/lib/quota-proxy/quota-proxy.db ".backup /backup/quota-proxy-$(date +%Y%m%d).db"
   ```

3. **监控数据库增长**
   ```bash
   # 监控文件大小
   du -h /var/lib/quota-proxy/quota-proxy.db
   
   # 监控表记录数
   sqlite3 /var/lib/quota-proxy/quota-proxy.db "SELECT 'api_keys:', COUNT(*) FROM api_keys; SELECT 'usage_records:', COUNT(*) FROM usage_records;"
   ```

### 开发环境

1. **使用测试数据库**
   ```bash
   # 创建测试数据库
   ./init-sqlite-db.sh --db-path test.db
   
   # 运行测试后清理
   rm -f test.db
   ```

2. **集成到开发流程**
   ```bash
   # 在package.json或Makefile中添加
   "scripts": {
     "init-db": "./quota-proxy/init-sqlite-db.sh --db-path ./quota-proxy.db",
     "test-db": "./test-database-init.sh"
   }
   ```

## 相关文档

- [SQLite配置验证指南](./VERIFY-SQLITE-CONFIG.md) - 验证数据库配置
- [quota-proxy部署指南](../docs/DEPLOYMENT.md) - 完整部署流程
- [API密钥管理指南](../docs/API-KEY-MANAGEMENT.md) - API密钥管理最佳实践

## 支持与反馈

如有问题或建议，请：
1. 查看[故障排除](#故障排除)章节
2. 检查脚本日志输出
3. 提交Issue到项目仓库

---

**注意**：本脚本创建的演示密钥仅用于测试，生产环境必须生成安全的密钥并替换默认值。
