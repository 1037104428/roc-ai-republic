# quota-proxy 数据库备份与恢复指南

## 概述

本文档详细介绍了 quota-proxy 数据库的备份与恢复策略，包括自动化备份脚本的使用方法、最佳实践和故障排除指南。数据库备份是生产环境数据安全的重要保障，确保在意外情况下能够快速恢复服务。

## 备份脚本功能

`backup-quota-proxy-db.sh` 脚本提供以下核心功能：

### 1. 数据库备份
- 自动创建时间戳命名的备份文件
- 支持压缩备份以节省存储空间
- 备份文件完整性验证
- 多种运行模式（详细/安静/模拟）

### 2. 备份管理
- 自动清理过期备份（可配置保留天数）
- 备份文件列表查看
- 备份文件完整性验证
- 灵活的备份目录配置

### 3. 数据库恢复
- 从指定备份文件恢复数据库
- 恢复前自动创建当前数据库备份
- 恢复后数据库验证
- 安全恢复流程

### 4. 监控与维护
- 详细的日志输出
- 标准化退出码
- 彩色输出增强可读性
- 完整的错误处理

## 快速开始

### 安装脚本

```bash
# 确保脚本有执行权限
chmod +x /path/to/roc-ai-republic/scripts/backup-quota-proxy-db.sh

# 创建符号链接到系统路径（可选）
sudo ln -sf /path/to/roc-ai-republic/scripts/backup-quota-proxy-db.sh /usr/local/bin/backup-quota-proxy-db
```

### 基本使用

#### 执行默认备份
```bash
cd /path/to/roc-ai-republic
./scripts/backup-quota-proxy-db.sh
```

#### 模拟运行（不实际执行）
```bash
./scripts/backup-quota-proxy-db.sh --dry-run
```

#### 列出所有备份
```bash
./scripts/backup-quota-proxy-db.sh --list
```

#### 从备份恢复
```bash
./scripts/backup-quota-proxy-db.sh --restore backups/backup-2026-02-10-22-40-00.db
```

#### 验证备份文件
```bash
./scripts/backup-quota-proxy-db.sh --verify backups/backup-2026-02-10-22-40-00.db
```

## 详细配置

### 脚本参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--db-path PATH` | 数据库文件路径 | `/opt/roc/quota-proxy/data/quota.db` |
| `--backup-dir DIR` | 备份目录 | `/opt/roc/quota-proxy/backups` |
| `--retention DAYS` | 备份保留天数 | `30` |
| `--dry-run` | 模拟运行，不实际执行 | `false` |
| `--list` | 列出备份文件 | `false` |
| `--restore FILE` | 从指定备份文件恢复 | - |
| `--verify FILE` | 验证备份文件完整性 | - |
| `--quiet` | 安静模式，仅输出必要信息 | `false` |
| `--help` | 显示帮助信息 | - |
| `--version` | 显示版本信息 | - |

### 环境变量配置

可以通过环境变量覆盖默认配置：

```bash
# 设置数据库路径
export QUOTA_PROXY_DB_PATH="/custom/path/quota.db"

# 设置备份目录
export QUOTA_PROXY_BACKUP_DIR="/custom/backups"

# 设置保留天数
export QUOTA_PROXY_RETENTION_DAYS=90
```

### 配置文件（高级）

创建配置文件 `/etc/quota-proxy/backup.conf`：

```bash
# quota-proxy 数据库备份配置
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
RETENTION_DAYS=30
COMPRESS_BACKUPS=true
BACKUP_SCHEDULE="0 2 * * *"  # 每天凌晨2点
```

## 备份策略

### 1. 全量备份
- 每次备份都创建完整的数据库副本
- 备份文件包含时间戳，便于版本管理
- 支持手动触发和定时任务

### 2. 增量备份（计划中）
- 仅备份自上次备份以来的变化
- 减少备份文件大小和备份时间
- 需要更复杂的恢复流程

### 3. 备份保留策略
- 默认保留30天内的备份
- 可配置保留天数
- 自动清理过期备份

### 4. 备份验证
- 备份后立即验证文件完整性
- 定期抽查备份文件可恢复性
- 记录备份验证结果

## 自动化部署

### 1. 定时备份（Cron Job）

创建定时任务，每天凌晨2点执行备份：

```bash
# 编辑 crontab
crontab -e

# 添加以下行
0 2 * * * /path/to/roc-ai-republic/scripts/backup-quota-proxy-db.sh --quiet
```

### 2. 系统服务（Systemd）

创建 systemd 服务文件 `/etc/systemd/system/quota-proxy-backup.service`：

```ini
[Unit]
Description=quota-proxy Database Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/path/to/roc-ai-republic/scripts/backup-quota-proxy-db.sh --quiet
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

创建定时器 `/etc/systemd/system/quota-proxy-backup.timer`：

```ini
[Unit]
Description=Daily quota-proxy Database Backup Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

启用服务：
```bash
sudo systemctl enable quota-proxy-backup.timer
sudo systemctl start quota-proxy-backup.timer
```

## 恢复流程

### 1. 紧急恢复步骤

当数据库损坏或丢失时，按以下步骤恢复：

```bash
# 1. 停止 quota-proxy 服务
cd /opt/roc/quota-proxy
docker compose stop quota-proxy

# 2. 列出可用备份
./scripts/backup-quota-proxy-db.sh --list

# 3. 选择最近的备份文件恢复
./scripts/backup-quota-proxy-db.sh --restore backups/backup-2026-02-10-22-40-00.db

# 4. 验证恢复后的数据库
./scripts/backup-quota-proxy-db.sh --verify /opt/roc/quota-proxy/data/quota.db

# 5. 启动 quota-proxy 服务
docker compose start quota-proxy

# 6. 验证服务健康状态
curl -fsS http://127.0.0.1:8787/healthz
```

### 2. 测试恢复流程

定期测试恢复流程，确保备份可用：

```bash
# 创建测试环境
mkdir -p /tmp/test-restore
cp backups/backup-2026-02-10-22-40-00.db /tmp/test-restore/

# 在测试环境恢复
./scripts/backup-quota-proxy-db.sh \
  --db-path /tmp/test-restore/quota.db \
  --backup-dir /tmp/test-restore \
  --restore /tmp/test-restore/backup-2026-02-10-22-40-00.db

# 验证测试数据库
sqlite3 /tmp/test-restore/quota.db "SELECT COUNT(*) FROM api_keys;"
```

## 监控与告警

### 1. 备份状态监控

创建监控脚本 `/opt/roc/quota-proxy/scripts/monitor-backup.sh`：

```bash
#!/bin/bash

# 检查最近备份时间
LAST_BACKUP=$(find /opt/roc/quota-proxy/backups -name "backup-*.db" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)
LAST_BACKUP_TIME=$(stat -c%Y "$LAST_BACKUP" 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
BACKUP_AGE=$((CURRENT_TIME - LAST_BACKUP_TIME))

# 如果超过24小时没有备份，发送告警
if [ $BACKUP_AGE -gt 86400 ]; then
    echo "WARNING: 数据库备份已超过24小时"
    # 发送告警通知
    # notify-send "quota-proxy 备份告警" "数据库备份已超过24小时"
fi

# 检查备份文件大小
BACKUP_SIZE=$(stat -c%s "$LAST_BACKUP" 2>/dev/null || echo 0)
if [ $BACKUP_SIZE -lt 1024 ]; then
    echo "ERROR: 备份文件大小异常"
fi
```

### 2. 日志分析

备份脚本输出结构化日志，便于监控系统收集：

```bash
# 查看备份日志
journalctl -u quota-proxy-backup.service

# 分析备份成功率
grep -c "数据库备份成功" /var/log/quota-proxy/backup.log
grep -c "数据库备份失败" /var/log/quota-proxy/backup.log
```

## 最佳实践

### 1. 备份策略优化

- **频率**：生产环境建议每天备份，测试环境可每周备份
- **保留时间**：根据存储空间和合规要求调整
- **异地备份**：重要数据应进行异地备份
- **加密备份**：敏感数据备份应加密存储

### 2. 恢复测试

- 每月至少进行一次恢复测试
- 测试不同时间点的备份文件
- 记录恢复时间和成功率
- 更新恢复文档和脚本

### 3. 容量规划

```bash
# 估算备份存储需求
du -sh /opt/roc/quota-proxy/backups/
du -sh /opt/roc/quota-proxy/data/quota.db

# 计算30天备份所需空间
DAILY_SIZE=$(du -s /opt/roc/quota-proxy/data/quota.db | cut -f1)
TOTAL_SIZE=$((DAILY_SIZE * 30))
echo "30天备份预计需要: $((TOTAL_SIZE / 1024)) MB"
```

### 4. 安全考虑

- 备份文件权限设置为 `600`（仅所有者可读写）
- 备份目录权限设置为 `700`
- 定期轮换备份加密密钥
- 审计备份访问日志

## 故障排除

### 常见问题

#### 1. 备份失败：数据库文件不存在
```
[ERROR] 数据库文件不存在: /opt/roc/quota-proxy/data/quota.db
```

**解决方案**：
- 检查数据库文件路径是否正确
- 确认 quota-proxy 服务正在运行
- 检查文件权限

#### 2. 备份失败：备份目录不可写
```
[ERROR] 备份目录不可写: /opt/roc/quota-proxy/backups
```

**解决方案**：
```bash
# 创建备份目录并设置权限
sudo mkdir -p /opt/roc/quota-proxy/backups
sudo chown -R $(whoami):$(whoami) /opt/roc/quota-proxy/backups
sudo chmod 700 /opt/roc/quota-proxy/backups
```

#### 3. 恢复失败：备份文件损坏
```
[ERROR] 备份文件验证失败: backups/backup-2026-02-10-22-40-00.db
```

**解决方案**：
- 尝试使用其他备份文件
- 检查备份文件完整性：`sqlite3 backup-file.db "PRAGMA integrity_check;"`
- 检查存储介质健康状态

#### 4. 性能问题：备份时间过长
**解决方案**：
- 在低峰期执行备份
- 考虑增量备份策略
- 优化数据库索引和清理旧数据

### 调试模式

启用详细日志输出进行调试：

```bash
# 启用调试输出
export DEBUG=true
./scripts/backup-quota-proxy-db.sh

# 查看详细日志
./scripts/backup-quota-proxy-db.sh 2>&1 | tee backup-debug.log
```

## 集成与扩展

### 1. 与监控系统集成

将备份状态集成到现有监控系统：

```bash
# Prometheus 指标导出
cat << 'EOF' > /opt/roc/quota-proxy/scripts/backup-metrics.sh
#!/bin/bash

LAST_BACKUP_TIME=$(find /opt/roc/quota-proxy/backups -name "backup-*.db" -type f -printf "%T@\n" | sort -nr | head -1)
CURRENT_TIME=$(date +%s)
BACKUP_AGE=$((CURRENT_TIME - ${LAST_BACKUP_TIME:-0}))

echo "# HELP quota_proxy_backup_age_seconds Age of last backup in seconds"
echo "# TYPE quota_proxy_backup_age_seconds gauge"
echo "quota_proxy_backup_age_seconds $BACKUP_AGE"

BACKUP_COUNT=$(find /opt/roc/quota-proxy/backups -name "backup-*.db" -type f | wc -l)
echo "# HELP quota_proxy_backup_count Total number of backup files"
echo "# TYPE quota_proxy_backup_count gauge"
echo "quota_proxy_backup_count $BACKUP_COUNT"
EOF
```

### 2. 云存储集成

扩展脚本支持云存储备份：

```bash
# AWS S3 备份示例
aws s3 cp /opt/roc/quota-proxy/backups/backup-*.db s3://your-bucket/quota-proxy/backups/

# 阿里云 OSS 备份示例
ossutil cp /opt/roc/quota-proxy/backups/backup-*.db oss://your-bucket/quota-proxy/backups/
```

### 3. 邮件通知

添加备份结果邮件通知：

```bash
# 在备份脚本中添加邮件通知
if [ $? -eq 0 ]; then
    echo "数据库备份成功" | mail -s "quota-proxy 备份成功" admin@example.com
else
    echo "数据库备份失败" | mail -s "quota-proxy 备份失败" admin@example.com
fi
```

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0.0 | 2026-02-10 | 初始版本，包含基本备份和恢复功能 |
| v1.1.0 | 计划中 | 添加增量备份支持 |
| v1.2.0 | 计划中 | 添加云存储集成 |
| v1.3.0 | 计划中 | 添加加密备份功能 |

## 支持与反馈

如有问题或建议，请通过以下方式联系：

- GitHub Issues: [roc-ai-repository/issues](https://github.com/1037104428/roc-ai-republic/issues)
- 文档更新：提交 Pull Request 到文档目录
- 紧急支持：查看故障排除章节或联系管理员

---

**重要提示**：定期测试备份恢复流程是确保数据安全的关键。建议至少每月执行一次完整的恢复测试，并记录测试结果。