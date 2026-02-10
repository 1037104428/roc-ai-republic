# 数据库备份监控告警配置指南

本文档介绍中华AI共和国/OpenClaw小白中文包项目的数据库备份监控告警系统配置。

## 概述

数据库备份监控告警系统为quota-proxy数据库提供实时监控和告警功能，确保备份系统的可靠性和可用性。

### 主要功能

1. **实时监控**：每30分钟自动检查备份状态
2. **多维度检查**：
   - 备份文件时效性检查
   - 磁盘空间监控
   - quota-proxy服务健康检查
3. **智能告警**：
   - 系统日志记录
   - 控制台消息通知
   - 邮件告警（可选配置）
4. **自动化维护**：自动清理旧日志文件

## 快速开始

### 1. 检查当前状态

```bash
./scripts/configure-backup-alerts.sh --check
```

### 2. 配置监控告警系统

```bash
./scripts/configure-backup-alerts.sh --configure
```

### 3. 测试告警功能

```bash
./scripts/configure-backup-alerts.sh --test
```

## 详细配置

### 配置文件位置

- **告警脚本**：`/opt/roc/quota-proxy/scripts/backup-alert.sh`
- **Cron任务**：`/etc/cron.d/roc-backup-monitor`
- **监控日志**：`/var/log/roc-backup-monitor.log`
- **Cron日志**：`/var/log/roc-backup-monitor-cron.log`

### 监控参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `BACKUP_DIR` | `/opt/roc/quota-proxy/backups` | 备份文件目录 |
| `ALERT_THRESHOLD_HOURS` | 24 | 备份文件最大时效（小时） |
| `DISK_THRESHOLD_PERCENT` | 80 | 磁盘使用率告警阈值（%） |
| `MAX_LOG_SIZE` | 10MB | 日志文件最大大小 |
| `QUOTA_PROXY_URL` | `http://127.0.0.1:8787/healthz` | quota-proxy健康检查URL |

### 告警条件

系统会在以下情况下触发告警：

1. **备份文件过时**：超过24小时没有新的备份文件
2. **磁盘空间不足**：`/opt`分区使用率超过80%
3. **服务异常**：quota-proxy健康检查失败
4. **备份文件缺失**：备份目录中没有找到任何备份文件

## 告警机制

### 1. 系统日志告警

所有告警信息都会记录到系统日志：

```bash
# 查看监控日志
tail -f /var/log/roc-backup-monitor.log

# 查看系统日志中的告警
journalctl -t roc-backup-monitor
```

### 2. 控制台消息告警

如果系统支持`wall`命令，重要告警会发送到所有登录用户的控制台。

### 3. 邮件告警（可选）

如需配置邮件告警，修改`backup-alert.sh`脚本中的邮件配置部分：

```bash
# 取消注释并配置以下变量
# ALERT_EMAIL="admin@example.com"
# echo "$alert_message" | mail -s "[ROC备份监控告警] $alert_level" "$ALERT_EMAIL"
```

## 监控检查项

### 1. 磁盘空间检查

```bash
# 检查/opt分区使用率
df -h /opt
```

### 2. 备份文件检查

```bash
# 查找最新的备份文件
find /opt/roc/quota-proxy/backups -name "*.sqlite3" -type f -printf '%T@ %p\n' | sort -n | tail -1

# 检查备份文件数量
ls -la /opt/roc/quota-proxy/backups/*.sqlite3 2>/dev/null | wc -l
```

### 3. 服务健康检查

```bash
# 检查quota-proxy服务状态
curl -fsS http://127.0.0.1:8787/healthz

# 检查Docker容器状态
docker compose ps
```

## 故障排除

### 常见问题

#### 1. 监控脚本无法执行

**症状**：Cron任务没有运行，日志文件没有更新

**解决方案**：
```bash
# 检查脚本权限
chmod +x /opt/roc/quota-proxy/scripts/backup-alert.sh

# 手动测试脚本
/opt/roc/quota-proxy/scripts/backup-alert.sh

# 检查Cron服务状态
systemctl status cron
```

#### 2. 误报或漏报

**症状**：告警不准确，或者应该告警时没有告警

**解决方案**：
```bash
# 调整告警阈值
# 修改backup-alert.sh中的以下变量：
# ALERT_THRESHOLD_HOURS=36  # 延长备份时效阈值
# DISK_THRESHOLD_PERCENT=90 # 提高磁盘使用率阈值

# 重新部署脚本
./scripts/configure-backup-alerts.sh --configure
```

#### 3. 日志文件过大

**症状**：日志文件占用过多磁盘空间

**解决方案**：
```bash
# 手动清理旧日志
find /var/log/ -name 'roc-backup-*.log' -mtime +7 -delete

# 或等待自动清理（每日凌晨2点自动执行）
```

### 调试模式

要启用详细调试信息，可以修改监控脚本：

```bash
# 在backup-alert.sh中添加调试模式
DEBUG=true
if [ "$DEBUG" = "true" ]; then
    set -x
fi
```

## 集成与扩展

### 1. 集成到现有监控系统

监控脚本的输出格式兼容常见的监控系统：

```bash
# 输出格式示例
[2026-02-10 17:30:00] [INFO] 开始备份监控检查
[2026-02-10 17:30:01] [INFO] 磁盘空间正常: /opt 使用率 45%
[2026-02-10 17:30:02] [INFO] 最新备份: backup-20260210-170000.sqlite3 (0小时前, 12MB)
[2026-02-10 17:30:03] [INFO] quota-proxy服务运行正常
[2026-02-10 17:30:04] [INFO] 所有检查通过，系统正常
```

### 2. 扩展监控项

可以添加额外的监控检查：

```bash
# 示例：添加数据库连接检查
check_database_connection() {
    if sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT 1;" > /dev/null 2>&1; then
        log_message "INFO" "数据库连接正常"
        return 0
    else
        log_message "ERROR" "数据库连接失败"
        return 1
    fi
}
```

### 3. 自定义告警渠道

支持添加自定义告警渠道：

```bash
# 示例：添加Slack告警
send_slack_alert() {
    local message="$1"
    local webhook_url="https://hooks.slack.com/services/..."
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" \
        "$webhook_url" > /dev/null 2>&1
}
```

## 维护指南

### 定期维护任务

1. **每周检查**：
   ```bash
   # 检查日志文件大小
   du -h /var/log/roc-backup-*.log
   
   # 检查Cron任务状态
   systemctl status cron
   ```

2. **每月检查**：
   ```bash
   # 验证备份文件完整性
   ./scripts/verify-sqlite-status.sh
   
   # 测试告警功能
   ./scripts/configure-backup-alerts.sh --test
   ```

3. **季度检查**：
   ```bash
   # 更新监控阈值
   # 根据实际使用情况调整ALERT_THRESHOLD_HOURS和DISK_THRESHOLD_PERCENT
   
   # 审查告警历史
   grep -E "ERROR|WARN" /var/log/roc-backup-monitor.log | tail -50
   ```

### 性能优化

1. **减少监控频率**：
   ```bash
   # 修改Cron任务为每小时检查一次
   # 将 */30 * * * * 改为 0 * * * *
   ```

2. **优化日志输出**：
   ```bash
   # 减少INFO级别日志，只记录ERROR和WARN
   # 修改log_message函数中的日志级别过滤
   ```

3. **压缩旧日志**：
   ```bash
   # 添加日志压缩任务到Cron
   0 3 * * * root find /var/log/ -name 'roc-backup-*.log' -mtime +3 -exec gzip {} \;
   ```

## 安全考虑

### 1. 权限管理

- 监控脚本以root权限运行，确保能够访问所有必要资源
- 日志文件设置为644权限，防止未授权访问
- 敏感信息（如邮件服务器密码）不应硬编码在脚本中

### 2. 资源限制

- 监控脚本设置了执行超时保护
- 日志文件有大小限制，防止磁盘空间耗尽
- Cron任务有资源使用限制

### 3. 审计跟踪

所有监控操作都有详细日志记录，支持安全审计：

```bash
# 查看监控操作历史
grep -E "配置|部署|测试|移除" /var/log/roc-backup-monitor.log
```

## 相关文档

- [数据库备份系统设计](./database-backup-system.md)
- [SQLite数据库状态验证](./sqlite-status-verification.md)
- [服务器备份状态检查](./backup-status-check.md)
- [备份状态摘要工具](./backup-status-summary.md)

## 支持与反馈

如有问题或建议，请通过以下方式联系：

1. **GitHub Issues**: [roc-ai-repository/issues](https://github.com/1037104428/roc-ai-republic/issues)
2. **Gitee Issues**: [roc-ai-repository/issues](https://gitee.com/junkaiWang324/roc-ai-republic/issues)
3. **项目文档**: 查看项目根目录下的README.md

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**维护者**: 中华AI共和国/OpenClaw小白中文包项目组