# quota-proxy 数据库验证指南

## 概述

`verify-quota-db.sh` 脚本用于验证 quota-proxy SQLite 数据库的完整性和表结构。该脚本提供全面的数据库验证功能，包括文件检查、表结构验证、索引检查、触发器验证和数据完整性检查。

## 功能特性

### 1. 数据库文件验证
- 检查数据库文件是否存在
- 验证文件可读性
- 检查文件大小（防止空文件）

### 2. 表结构验证
- 验证所有必需表的存在性（api_keys, usage_logs, trial_keys）
- 检查表结构定义
- 支持详细模式查看完整表结构

### 3. 索引验证
- 验证所有必需索引的存在性
- 检查索引定义
- 支持详细模式查看索引信息

### 4. 触发器验证
- 验证必需触发器的存在性
- 检查触发器定义
- 支持详细模式查看触发器信息

### 5. 数据完整性验证
- 检查各表记录数量
- 验证活跃API密钥
- 检查最近使用记录
- 验证可用试用密钥
- 检查外键约束

## 使用方法

### 基本用法

```bash
# 使用默认数据库路径（./quota.db）
./scripts/verify-quota-db.sh

# 指定数据库路径
./scripts/verify-quota-db.sh --db-path /opt/roc/quota-proxy/quota.db

# 详细输出模式
./scripts/verify-quota-db.sh --verbose

# 模拟运行（只显示验证计划）
./scripts/verify-quota-db.sh --dry-run

# 列表模式（显示所有检查项）
./scripts/verify-quota-db.sh --list

# 显示帮助信息
./scripts/verify-quota-db.sh --help
```

### 典型使用场景

#### 1. 部署后验证
```bash
# 在quota-proxy目录下验证数据库
cd /opt/roc/quota-proxy
./verify-quota-db.sh --db-path ./quota.db --verbose
```

#### 2. 自动化监控
```bash
# 在cron作业中定期验证
0 */6 * * * cd /opt/roc/quota-proxy && ./verify-quota-db.sh --db-path ./quota.db > /var/log/quota-db-verify.log 2>&1
```

#### 3. 故障排除
```bash
# 详细模式查看所有问题
./scripts/verify-quota-db.sh --db-path /path/to/database.db --verbose

# 检查特定问题
./scripts/verify-quota-db.sh --db-path /path/to/database.db | grep -E "ERROR|WARNING"
```

## 验证内容详解

### 必需的表结构

#### 1. api_keys 表
```sql
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    quota_daily INTEGER DEFAULT 1000,
    quota_monthly INTEGER DEFAULT 30000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    notes TEXT
)
```

#### 2. usage_logs 表
```sql
CREATE TABLE usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    request_size INTEGER,
    response_size INTEGER,
    status_code INTEGER,
    user_agent TEXT,
    ip_address TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(id) ON DELETE CASCADE
)
```

#### 3. trial_keys 表
```sql
CREATE TABLE trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trial_key TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    quota_daily INTEGER DEFAULT 100,
    quota_monthly INTEGER DEFAULT 3000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT 0,
    used_at TIMESTAMP,
    notes TEXT
)
```

### 必需索引

1. **idx_api_keys_api_key** - API密钥快速查找
2. **idx_api_keys_email** - 邮箱查找
3. **idx_api_keys_is_active** - 活跃状态筛选
4. **idx_usage_logs_api_key_id** - 使用记录关联查询
5. **idx_usage_logs_timestamp** - 时间范围查询
6. **idx_trial_keys_trial_key** - 试用密钥查找
7. **idx_trial_keys_email** - 试用邮箱查找
8. **idx_trial_keys_expires_at** - 过期时间筛选
9. **idx_trial_keys_is_used** - 使用状态筛选

### 必需触发器

1. **update_api_keys_updated_at** - 自动更新updated_at时间戳

## 退出码说明

| 退出码 | 说明 | 处理建议 |
|--------|------|----------|
| 0 | 所有验证通过 | 数据库正常，无需操作 |
| 1 | 参数错误或帮助请求 | 检查命令行参数 |
| 2 | 数据库文件不存在或不可访问 | 检查文件路径和权限 |
| 3 | 表结构验证失败 | 运行数据库初始化脚本 |
| 4 | 索引验证失败 | 创建缺失的索引 |
| 5 | 触发器验证失败 | 创建缺失的触发器 |
| 6 | 数据完整性验证失败 | 检查数据和外键约束 |
| 7 | 其他验证错误 | 查看详细错误信息 |

## 集成指南

### 与CI/CD集成

```yaml
# GitHub Actions示例
name: Database Verification
on: [push, pull_request]
jobs:
  verify-db:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install sqlite3
        run: sudo apt-get install -y sqlite3
      - name: Verify database
        run: ./scripts/verify-quota-db.sh --dry-run
```

### 与监控系统集成

```bash
#!/bin/bash
# 监控脚本示例
DB_PATH="/opt/roc/quota-proxy/quota.db"
LOG_FILE="/var/log/quota-db-monitor.log"

# 运行验证
./scripts/verify-quota-db.sh --db-path "$DB_PATH" > "$LOG_FILE" 2>&1
EXIT_CODE=$?

# 根据退出码发送告警
case $EXIT_CODE in
    0)
        echo "数据库验证通过 $(date)" >> "$LOG_FILE"
        ;;
    2|3|4|5|6|7)
        # 发送告警
        echo "数据库验证失败，退出码: $EXIT_CODE" | mail -s "quota-proxy数据库告警" admin@example.com
        ;;
    *)
        echo "未知错误，退出码: $EXIT_CODE" >> "$LOG_FILE"
        ;;
esac
```

## 故障排除

### 常见问题

#### 1. 数据库文件不存在
```bash
# 错误信息
[ERROR] 数据库文件不存在: ./quota.db

# 解决方案
# 运行数据库初始化脚本
./scripts/init-quota-db.sh --db-path ./quota.db
```

#### 2. 表结构缺失
```bash
# 错误信息
[ERROR] 表不存在: api_keys

# 解决方案
# 重新初始化数据库（注意：会清空现有数据）
./scripts/init-quota-db.sh --db-path ./quota.db --force
```

#### 3. 索引缺失
```bash
# 警告信息
[WARNING] 缺少索引: idx_api_keys_api_key

# 解决方案
# 手动创建缺失的索引
sqlite3 quota.db "CREATE INDEX idx_api_keys_api_key ON api_keys(api_key);"
```

#### 4. 外键约束失败
```bash
# 错误信息
[ERROR] 外键约束检查失败:

# 解决方案
# 检查并修复数据一致性
sqlite3 quota.db "PRAGMA foreign_key_check;"
```

### 调试技巧

1. **使用详细模式**：添加 `--verbose` 参数查看详细信息
2. **模拟运行**：添加 `--dry-run` 参数查看验证计划而不实际执行
3. **逐步验证**：可以注释掉部分检查代码，逐步排查问题
4. **手动SQL验证**：使用 `sqlite3` 命令行工具手动验证

## 最佳实践

### 1. 定期验证
建议在生产环境中定期运行数据库验证，例如：
- 每天一次完整验证
- 每次部署前验证
- 数据库备份后验证

### 2. 验证时机
- **部署时**：确保数据库结构正确
- **升级时**：验证数据库兼容性
- **故障时**：排查数据库问题
- **监控时**：定期健康检查

### 3. 验证结果处理
- 退出码0：记录日志，无需操作
- 退出码2-7：发送告警，人工介入
- 详细日志：保存验证日志供分析

### 4. 自动化集成
- 集成到CI/CD流水线
- 集成到监控告警系统
- 集成到备份验证流程

## 相关脚本

- `init-quota-db.sh` - 数据库初始化脚本
- `backup-quota-db.sh` - 数据库备份脚本
- `verify-backup-integrity.sh` - 备份完整性验证脚本
- `check-backup-freshness.sh` - 备份新鲜度检查脚本

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持数据库文件验证
- 支持表结构验证
- 支持索引验证
- 支持触发器验证
- 支持数据完整性验证
- 支持多种运行模式
- 提供详细的验证报告

## 技术支持

如有问题，请参考：
1. [数据库初始化指南](./quota-db-initialization.md)
2. [备份与恢复指南](./backup-and-recovery.md)
3. [API文档](../api/README.md)
4. 项目GitHub Issues