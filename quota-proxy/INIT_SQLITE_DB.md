# SQLite数据库初始化指南

## 概述

`init-sqlite-db.sh` 脚本用于初始化 quota-proxy 服务的 SQLite 数据库。它创建必要的表结构、索引，并可选择性地插入示例数据。

## 功能特性

- ✅ 自动创建 SQLite 数据库文件
- ✅ 初始化核心表结构（api_keys, usage_stats, trial_keys）
- ✅ 创建优化索引
- ✅ 可选插入示例数据
- ✅ 数据库完整性验证
- ✅ 彩色输出和详细日志
- ✅ 支持自定义配置

## 快速开始

### 1. 基本使用

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 运行初始化脚本
./init-sqlite-db.sh
```

### 2. 自定义数据库文件路径

```bash
# 指定自定义数据库文件路径
DB_FILE=/opt/roc/quota-proxy/data/quota.db ./init-sqlite-db.sh
```

### 3. 插入示例数据

```bash
# 初始化并插入示例数据
INSERT_SAMPLES=1 ./init-sqlite-db.sh
```

## 表结构说明

### api_keys 表（API密钥管理）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| key_id | TEXT | 密钥ID，唯一标识 |
| name | TEXT | 密钥名称 |
| quota_daily | INTEGER | 每日配额，默认100 |
| quota_monthly | INTEGER | 每月配额，默认3000 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |
| is_active | INTEGER | 是否激活（1=激活，0=停用） |

### usage_stats 表（使用统计）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| key_id | TEXT | 关联的密钥ID |
| date | DATE | 统计日期 |
| count_daily | INTEGER | 当日使用次数 |
| count_monthly | INTEGER | 当月使用次数 |
| last_used | TIMESTAMP | 最后使用时间 |

### trial_keys 表（试用密钥）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键，自增 |
| key_id | TEXT | 试用密钥ID，唯一标识 |
| email | TEXT | 用户邮箱 |
| created_at | TIMESTAMP | 创建时间 |
| expires_at | TIMESTAMP | 过期时间 |
| is_used | INTEGER | 是否已使用（1=已使用，0=未使用） |
| used_at | TIMESTAMP | 使用时间 |

## 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| DB_FILE | /tmp/quota-proxy.db | SQLite数据库文件路径 |
| INSERT_SAMPLES | 0 | 是否插入示例数据（1=是，0=否） |

## 使用示例

### 示例1：快速初始化

```bash
# 使用默认配置初始化
./init-sqlite-db.sh

# 输出示例：
[INFO] 开始初始化SQLite数据库
[INFO] 创建数据库文件: /tmp/quota-proxy.db
[INFO] 初始化表结构...
[INFO] 验证数据库...
[INFO] ✓ 表 'api_keys' 存在
[INFO] ✓ 表 'usage_stats' 存在
[INFO] ✓ 表 'trial_keys' 存在
[INFO] 表 'api_keys' 有 0 行数据
[INFO] 表 'usage_stats' 有 0 行数据
[INFO] 表 'trial_keys' 有 0 行数据
[INFO] 数据库验证完成
[INFO] 数据库信息:
文件: /tmp/quota-proxy.db
大小: 12K (如果文件存在)
表结构:
CREATE TABLE api_keys (...)
CREATE TABLE usage_stats (...)
CREATE TABLE trial_keys (...)
[INFO] 数据库初始化完成
```

### 示例2：带示例数据的初始化

```bash
# 初始化并插入示例数据
INSERT_SAMPLES=1 ./init-sqlite-db.sh

# 验证示例数据
sqlite3 /tmp/quota-proxy.db "SELECT key_id, name FROM api_keys;"
sqlite3 /tmp/quota-proxy.db "SELECT key_id, count_daily FROM usage_stats;"
sqlite3 /tmp/quota-proxy.db "SELECT key_id, email FROM trial_keys;"
```

### 示例3：生产环境配置

```bash
# 创建数据目录
sudo mkdir -p /opt/roc/quota-proxy/data
sudo chown -R $USER:$USER /opt/roc/quota-proxy

# 初始化生产数据库
DB_FILE=/opt/roc/quota-proxy/data/quota.db ./init-sqlite-db.sh

# 设置数据库权限
chmod 644 /opt/roc/quota-proxy/data/quota.db
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: Test Database Initialization

on: [push, pull_request]

jobs:
  test-db-init:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install sqlite3
        run: sudo apt-get update && sudo apt-get install -y sqlite3
        
      - name: Test database initialization
        run: |
          cd quota-proxy
          chmod +x init-sqlite-db.sh
          ./init-sqlite-db.sh
          
      - name: Test with sample data
        run: |
          cd quota-proxy
          INSERT_SAMPLES=1 ./init-sqlite-db.sh
```

### 定时验证任务

```bash
#!/bin/bash
# 每日数据库健康检查
cd /opt/roc/quota-proxy
DB_FILE=/opt/roc/quota-proxy/data/quota.db ./init-sqlite-db.sh --dry-run 2>&1 | grep -q "数据库验证完成" && echo "数据库正常"
```

## 故障排除

### 常见问题

1. **sqlite3命令未找到**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install sqlite3
   
   # CentOS/RHEL
   sudo yum install sqlite
   
   # macOS
   brew install sqlite
   ```

2. **权限问题**
   ```bash
   # 检查文件权限
   ls -la /tmp/quota-proxy.db
   
   # 修复权限
   chmod 644 /tmp/quota-proxy.db
   ```

3. **数据库文件已存在**
   ```
   [WARN] 数据库文件已存在: /tmp/quota-proxy.db
   是否覆盖现有文件? (y/N):
   ```
   输入 `y` 覆盖，或输入 `n` 使用现有文件。

### 调试模式

```bash
# 启用详细输出
set -x
./init-sqlite-db.sh
set +x
```

## 相关文档

- [quota-proxy 部署指南](./DEPLOYMENT.md)
- [API 文档](./API.md)
- [管理API验证指南](./VERIFY_ADMIN_API_COMPLETE.md)
- [健康检查脚本](./QUICK-HEALTH-CHECK.md)

## 贡献指南

1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/improve-db-init`)
3. 提交更改 (`git commit -am '改进数据库初始化脚本'`)
4. 推送到分支 (`git push origin feature/improve-db-init`)
5. 创建 Pull Request

## 许可证

MIT License
