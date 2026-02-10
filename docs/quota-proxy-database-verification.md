# quota-proxy 数据库验证指南

## 概述

本文档提供 `quota-proxy` SQLite 数据库的验证方法和工具，确保数据库的健康状态和可用性。数据库验证是生产环境维护的重要环节，有助于及时发现和解决潜在问题。

## 验证脚本

### `verify-quota-proxy-db.sh`

这是一个全面的数据库验证脚本，提供以下检查功能：

#### 主要功能

1. **数据库文件检查**
   - 检查数据库文件是否存在
   - 验证文件权限和所有权
   - 检查文件大小

2. **数据库完整性验证**
   - 执行 SQLite 完整性检查
   - 验证数据库结构完整性

3. **表结构检查**
   - 检查 `api_keys` 表结构
   - 检查 `usage_stats` 表结构
   - 验证索引和约束

4. **数据检查**
   - 统计 API 密钥数量
   - 统计使用记录数量
   - 查看示例数据

5. **连接测试**
   - 测试数据库连接可用性
   - 验证查询响应时间

#### 使用方法

```bash
# 基本使用
./scripts/verify-quota-proxy-db.sh

# 详细模式
./scripts/verify-quota-proxy-db.sh --verbose

# 只显示命令不执行
./scripts/verify-quota-proxy-db.sh --dry-run

# 自定义数据库路径
./scripts/verify-quota-proxy-db.sh --db-path /custom/path/quota.db

# 自定义服务器地址
./scripts/verify-quota-proxy-db.sh --server 192.168.1.100
```

#### 输出示例

```
=== quota-proxy 数据库验证检查 ===
数据库路径: /opt/roc/quota-proxy/data/quota.db
服务器地址: 8.210.185.194
检查时间: 2026-02-10 18:32:15 CST

[1/7] 检查数据库文件是否存在
-rw-r--r-- 1 root root 24576 Feb 10 18:30 /opt/roc/quota-proxy/data/quota.db
✓ 数据库文件存在

[2/7] 检查数据库文件权限
✓ 文件权限: -rw-r--r-- root root 24576

[3/7] 验证数据库完整性
✓ 数据库完整性检查通过

[4/7] 检查表结构
✓ api_keys 表结构正常
✓ usage_stats 表结构正常

[5/7] 检查API密钥表数据
✓ API密钥数量: 5

[6/7] 检查使用统计表数据
✓ 使用统计记录数: 127

[7/7] 测试数据库连接
✓ 数据库连接测试通过

=== 检查完成 ===
总检查项: 7
失败项: 0
✅ 所有检查通过 - 数据库状态健康
```

## 验证流程

### 1. 定期验证

建议设置定时任务，定期执行数据库验证：

```bash
# 每天执行一次完整验证
0 2 * * * /home/kai/.openclaw/workspace/roc-ai-republic/scripts/verify-quota-proxy-db.sh

# 每小时执行一次快速检查
0 * * * * /home/kai/.openclaw/workspace/roc-ai-republic/scripts/verify-quota-proxy-db.sh --verbose
```

### 2. 部署前验证

在部署新版本前执行验证：

```bash
# 部署前验证
./scripts/verify-quota-proxy-db.sh --verbose

# 如果验证失败，停止部署
if [ $? -ne 0 ]; then
    echo "数据库验证失败，停止部署"
    exit 1
fi
```

### 3. 故障排除验证

当遇到数据库问题时执行验证：

```bash
# 详细诊断
./scripts/verify-quota-proxy-db.sh --verbose

# 检查特定问题
./scripts/verify-quota-proxy-db.sh --db-path /opt/roc/quota-proxy/data/quota.db
```

## 验证指标

### 健康指标

| 指标 | 健康值 | 警告值 | 危险值 |
|------|--------|--------|--------|
| 数据库文件存在 | ✓ | - | ✗ |
| 文件权限 | rw-r--r-- | 其他权限 | 无权限 |
| 完整性检查 | ok | - | 错误 |
| API密钥数量 | >0 | 0 | - |
| 连接响应时间 | <1s | 1-5s | >5s |

### 性能指标

1. **响应时间**
   - 连接测试: < 1秒
   - 查询测试: < 100毫秒

2. **数据完整性**
   - 完整性检查: 通过
   - 外键约束: 有效

3. **存储效率**
   - 数据库大小: 合理增长
   - 索引效率: 有效

## 故障排除

### 常见问题

#### 1. 数据库文件不存在

**症状**: 检查失败，数据库文件不存在

**解决方案**:
```bash
# 检查数据库目录
ssh root@8.210.185.194 "ls -la /opt/roc/quota-proxy/data/"

# 重新初始化数据库
./scripts/init-sqlite-db.sh
```

#### 2. 权限问题

**症状**: 无法访问数据库文件

**解决方案**:
```bash
# 修复权限
ssh root@8.210.185.194 "chmod 644 /opt/roc/quota-proxy/data/quota.db"
ssh root@8.210.185.194 "chown root:root /opt/roc/quota-proxy/data/quota.db"
```

#### 3. 数据库损坏

**症状**: 完整性检查失败

**解决方案**:
```bash
# 备份当前数据库
ssh root@8.210.185.194 "cp /opt/roc/quota-proxy/data/quota.db /opt/roc/quota-proxy/data/quota.db.backup.$(date +%Y%m%d)"

# 尝试修复
ssh root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db '.recover' | sqlite3 /opt/roc/quota-proxy/data/quota.db.new"

# 如果修复失败，重新初始化
./scripts/init-sqlite-db.sh
```

#### 4. 连接超时

**症状**: 连接测试失败

**解决方案**:
```bash
# 检查服务状态
ssh root@8.210.185.194 "docker compose ps"

# 检查端口监听
ssh root@8.210.185.194 "netstat -tlnp | grep 8787"

# 重启服务
ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose restart"
```

## 自动化集成

### CI/CD 集成

在 CI/CD 流水线中添加数据库验证：

```yaml
# .github/workflows/verify-db.yml
name: Database Verification

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-database:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Verify Database
      run: |
        chmod +x ./scripts/verify-quota-proxy-db.sh
        ./scripts/verify-quota-proxy-db.sh --dry-run
```

### 监控告警

配置监控告警规则：

```bash
# 监控脚本
#!/bin/bash
./scripts/verify-quota-proxy-db.sh

if [ $? -ne 0 ]; then
    # 发送告警
    echo "数据库验证失败" | mail -s "quota-proxy 数据库告警" admin@example.com
    # 或者使用其他告警方式
fi
```

## 最佳实践

### 1. 定期备份验证

```bash
# 备份前验证
./scripts/verify-quota-proxy-db.sh

# 如果验证通过，执行备份
if [ $? -eq 0 ]; then
    ./scripts/backup-database.sh
fi
```

### 2. 版本升级验证

```bash
# 升级前验证
./scripts/verify-quota-proxy-db.sh --verbose

# 升级后验证
./scripts/verify-quota-proxy-db.sh --verbose
```

### 3. 容量规划验证

```bash
# 检查数据库大小
ssh root@8.210.185.194 "du -h /opt/roc/quota-proxy/data/quota.db"

# 检查增长趋势
ssh root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db 'SELECT COUNT(*) FROM usage_stats;'"
```

## 相关工具

### 其他验证工具

1. **数据库初始化工具**: `init-sqlite-db.sh`
2. **数据库配置工具**: `configure-sqlite-persistence.sh`
3. **数据库状态工具**: `verify-sqlite-status.sh`
4. **备份监控工具**: `check-server-backup-status.sh`

### 集成验证

```bash
# 完整数据库健康检查
./scripts/init-sqlite-db.sh --check
./scripts/configure-sqlite-persistence.sh --check
./scripts/verify-quota-proxy-db.sh --verbose
./scripts/verify-sqlite-status.sh
```

## 总结

数据库验证是确保 `quota-proxy` 服务可靠性的关键环节。通过定期执行验证检查，可以：

1. **预防故障**: 提前发现潜在问题
2. **确保可用性**: 验证数据库连接和响应
3. **维护数据完整性**: 检查数据一致性和完整性
4. **支持监控告警**: 提供监控指标和告警依据

建议将数据库验证集成到日常运维流程中，确保服务的稳定运行。