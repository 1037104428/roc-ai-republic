# 服务器备份状态检查指南

## 概述

`check-server-backup-status.sh` 脚本用于快速检查服务器上的数据库备份状态，包括备份目录、文件、cron任务和数据库健康状态。

## 功能

1. **服务器连接检查** - 验证SSH连接是否正常
2. **备份目录检查** - 检查备份目录是否存在
3. **备份文件列表** - 列出最新的备份文件
4. **备份文件详情** - 显示备份文件大小和时间
5. **Cron任务检查** - 检查是否配置了定时备份任务
6. **数据库状态检查** - 验证数据库可访问性
7. **状态报告生成** - 生成详细的检查报告

## 使用方法

### 基本检查
```bash
./scripts/check-server-backup-status.sh
```

### 模拟运行（不实际执行）
```bash
./scripts/check-server-backup-status.sh --dry-run
```

### 详细输出模式
```bash
./scripts/check-server-backup-status.sh --verbose
```

### 安静模式（只显示关键信息）
```bash
./scripts/check-server-backup-status.sh --quiet
```

### 查看帮助
```bash
./scripts/check-server-backup-status.sh --help
```

## 输出示例

```
[INFO] 开始检查服务器备份状态...
[INFO] 服务器: 8.210.185.194
[INFO] 备份目录: /opt/roc/quota-proxy/backups
[SUCCESS] 服务器连接正常
[SUCCESS] 备份目录存在
total 12K
drwxr-xr-x 2 root root 4.0K Feb 10 16:30 .
drwxr-xr-x 5 root root 4.0K Feb 10 16:30 ..
-rw-r--r-- 1 root root 2.5K Feb 10 16:30 quota-backup-20260210-1630.db.gz
[SUCCESS] 找到备份文件:
/opt/roc/quota-proxy/backups/quota-backup-20260210-1630.db.gz
[SUCCESS] 备份文件详情:
-rw-r--r-- 1 root root 2.5K Feb 10 16:30 /opt/roc/quota-proxy/backups/quota-backup-20260210-1630.db.gz
[SUCCESS] 找到备份相关的cron任务:
0 2 * * * /opt/roc/quota-proxy/scripts/backup-sqlite-db.sh
[SUCCESS] 数据库表结构正常:
api_keys
usage_logs
[SUCCESS] 状态报告已生成: /tmp/backup-status-report-20260210-1638.txt
[INFO] 检查完成
```

## 检查项目说明

### 1. 服务器连接
- 验证SSH密钥是否正确
- 检查网络连接是否正常
- 确认服务器是否可访问

### 2. 备份目录
- 检查 `/opt/roc/quota-proxy/backups` 目录是否存在
- 验证目录权限是否正确

### 3. 备份文件
- 查找最新的备份文件（.db, .db.gz, .sql）
- 显示文件大小和修改时间
- 验证备份文件是否完整

### 4. Cron任务
- 检查crontab中是否有备份相关的任务
- 验证任务执行时间是否合理
- 确认脚本路径是否正确

### 5. 数据库状态
- 验证数据库文件可访问性
- 检查表结构是否完整
- 确认数据库连接正常

## 故障排除

### 常见问题

#### 1. 服务器连接失败
```bash
# 检查SSH密钥权限
chmod 600 ~/.ssh/id_ed25519_roc_server

# 测试SSH连接
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "echo test"
```

#### 2. 备份目录不存在
```bash
# 手动创建备份目录
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "mkdir -p /opt/roc/quota-proxy/backups"
```

#### 3. 没有备份文件
```bash
# 手动运行备份脚本
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "cd /opt/roc/quota-proxy && ./scripts/backup-sqlite-db.sh"
```

#### 4. Cron任务未配置
```bash
# 设置cron任务
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "cd /opt/roc/quota-proxy && ./scripts/setup-db-backup-cron.sh"
```

## 自动化集成

### 定期检查
可以将此脚本添加到cron任务中，定期检查备份状态：

```bash
# 每天检查一次备份状态
0 9 * * * /path/to/roc-ai-republic/scripts/check-server-backup-status.sh --quiet > /var/log/backup-status.log 2>&1
```

### 监控告警
脚本可以集成到监控系统中，当发现问题时发送告警：

```bash
# 检查并发送告警
if ! ./scripts/check-server-backup-status.sh --quiet; then
    # 发送告警邮件或通知
    echo "备份状态检查失败" | mail -s "备份告警" admin@example.com
fi
```

## 相关脚本

- `backup-sqlite-db.sh` - 数据库备份脚本
- `setup-db-backup-cron.sh` - Cron任务设置脚本
- `verify-db-backup.sh` - 备份验证脚本
- `test-db-backup-recovery.sh` - 备份恢复测试脚本

## 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-02-10 | 1.0.0 | 初始版本，提供完整的备份状态检查功能 |

---

**注意**: 定期运行此脚本可以确保备份系统的可靠性，及时发现并解决问题。