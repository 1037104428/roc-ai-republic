# quota-proxy SQLite数据库初始化指南

## 概述

本文档介绍quota-proxy的SQLite数据库初始化脚本 `init-quota-db.sh` 的使用方法和数据库结构。该脚本用于创建和管理quota-proxy的持久化存储数据库，支持API密钥管理、使用情况跟踪和试用密钥功能。

## 快速开始

### 1. 运行初始化脚本

```bash
# 使用默认路径 (/opt/roc/quota-proxy/data/quota.db)
./scripts/init-quota-db.sh

# 指定自定义数据库路径
./scripts/init-quota-db.sh -d /path/to/custom.db

# 模拟运行（不实际创建）
./scripts/init-quota-db.sh --dry-run

# 强制覆盖现有数据库
./scripts/init-quota-db.sh -f
```

### 2. 验证数据库

```bash
# 检查数据库表结构
sqlite3 /opt/roc/quota-proxy/data/quota.db ".tables"

# 查看API密钥
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT key_id, name, total_quota, used_quota FROM api_keys;"

# 查看数据库大小
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT page_count * page_size as bytes FROM pragma_page_count, pragma_page_size;"
```

## 数据库结构

### 表设计

#### 1. api_keys (API密钥表)
| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| key_id | TEXT | API密钥ID，唯一 |
| api_key | TEXT | API密钥值，唯一 |
| name | TEXT | 密钥名称/描述 |
| total_quota | INTEGER | 总配额（默认1000） |
| used_quota | INTEGER | 已使用配额 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |
| expires_at | TIMESTAMP | 过期时间（NULL=永不过期） |
| is_active | BOOLEAN | 是否激活（1=激活） |
| metadata | TEXT | 额外元数据（JSON格式） |

#### 2. usage_logs (使用情况日志表)
| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| key_id | TEXT | 关联的API密钥ID |
| endpoint | TEXT | 调用的端点 |
| request_size | INTEGER | 请求大小（字节） |
| response_size | INTEGER | 响应大小（字节） |
| status_code | INTEGER | 状态码 |
| duration_ms | INTEGER | 处理时长（毫秒） |
| timestamp | TIMESTAMP | 时间戳 |
| ip_address | TEXT | 客户端IP地址 |
| user_agent | TEXT | 用户代理 |

#### 3. trial_keys (试用密钥表)
| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| trial_key | TEXT | 试用密钥，唯一 |
| email | TEXT | 用户邮箱（可选） |
| total_quota | INTEGER | 试用配额（默认100） |
| used_quota | INTEGER | 已使用配额 |
| created_at | TIMESTAMP | 创建时间 |
| activated_at | TIMESTAMP | 激活时间 |
| expires_at | TIMESTAMP | 过期时间（默认7天） |
| is_used | BOOLEAN | 是否已使用 |

### 索引

脚本自动创建以下索引以提高查询性能：

1. `idx_api_keys_key_id` - API密钥ID索引
2. `idx_api_keys_api_key` - API密钥值索引
3. `idx_api_keys_expires` - 过期时间索引
4. `idx_usage_logs_key_id` - 使用日志密钥ID索引
5. `idx_usage_logs_timestamp` - 使用日志时间戳索引
6. `idx_trial_keys_trial_key` - 试用密钥索引
7. `idx_trial_keys_expires` - 试用密钥过期时间索引

### 触发器

- `update_api_keys_timestamp` - 自动更新`api_keys`表的`updated_at`字段

## 脚本功能

### 命令行选项

| 选项 | 说明 |
|------|------|
| `-d, --db-path PATH` | 数据库文件路径（默认：`/opt/roc/quota-proxy/data/quota.db`） |
| `-f, --force` | 强制覆盖现有数据库 |
| `-v, --verbose` | 详细输出模式 |
| `-h, --help` | 显示帮助信息 |
| `--dry-run` | 模拟运行，不实际创建数据库 |

### 错误处理

脚本包含完善的错误处理：

1. **SQLite3检查** - 验证`sqlite3`命令是否可用
2. **目录创建** - 自动创建数据库目录
3. **文件存在检查** - 防止意外覆盖（除非使用`-f`）
4. **SQL执行验证** - 检查SQL语句执行结果

### 输出格式

- **彩色输出**：使用颜色区分信息、成功、警告和错误
- **详细模式**：使用`-v`选项显示数据库验证详情
- **标准化退出码**：
  - `0`：成功
  - `1`：参数错误或SQLite3未安装
  - `2`：数据库文件已存在（未使用`-f`）
  - `3`：SQL执行失败

## 集成到quota-proxy

### 1. 数据库配置

在quota-proxy的Docker Compose配置中添加数据库卷挂载：

```yaml
services:
  quota-proxy:
    volumes:
      - ./data:/opt/roc/quota-proxy/data
```

### 2. 初始化流程

建议的部署流程：

```bash
# 1. 创建数据目录
mkdir -p /opt/roc/quota-proxy/data

# 2. 初始化数据库
./scripts/init-quota-db.sh -d /opt/roc/quota-proxy/data/quota.db

# 3. 设置权限
chmod 644 /opt/roc/quota-proxy/data/quota.db

# 4. 启动服务
docker compose up -d
```

### 3. 数据库维护

#### 备份
```bash
# 自动备份
sqlite3 /opt/roc/quota-proxy/data/quota.db ".backup backup_$(date +%Y%m%d_%H%M%S).db"

# 使用备份脚本
./scripts/backup-quota-db.sh
```

#### 恢复
```bash
# 从备份恢复
cp backup_20250210_203600.db /opt/roc/quota-proxy/data/quota.db
```

#### 监控
```bash
# 检查数据库健康
./scripts/check-db-health.sh -d /opt/roc/quota-proxy/data/quota.db

# 查看使用统计
sqlite3 /opt/roc/quota-proxy/data/quota.db << EOF
SELECT 
  date(timestamp) as day,
  COUNT(*) as total_requests,
  SUM(request_size) as total_request_size,
  SUM(response_size) as total_response_size
FROM usage_logs 
GROUP BY date(timestamp)
ORDER BY day DESC
LIMIT 7;
