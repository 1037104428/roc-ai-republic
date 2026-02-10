# 数据库备份新鲜度检查工具

## 概述

`check-backup-freshness.sh` 是一个用于验证数据库备份文件新鲜度的工具。它检查备份文件是否在指定时间内创建，确保备份系统正常工作，防止因备份失败导致数据丢失风险。

## 功能特性

- ✅ **新鲜度检查**：验证备份文件是否在指定时间范围内创建
- ✅ **文件大小检查**：检查备份文件大小是否合理
- ✅ **服务器连接验证**：自动检查与服务器的连接状态
- ✅ **详细报告**：生成包含检查结果的详细报告
- ✅ **多种运行模式**：支持dry-run、verbose模式
- ✅ **可配置阈值**：可自定义最大允许备份年龄

## 使用场景

1. **定期监控**：通过cron定时检查备份新鲜度
2. **故障排查**：当备份系统出现问题时快速诊断
3. **部署验证**：验证新部署的备份系统是否正常工作
4. **告警集成**：作为监控系统的一部分，触发告警

## 快速开始

### 基本用法

```bash
# 检查备份新鲜度（默认最大24小时）
./scripts/check-backup-freshness.sh

# 指定最大允许年龄（48小时）
./scripts/check-backup-freshness.sh --max-age-hours 48

# 模拟运行（不实际执行）
./scripts/check-backup-freshness.sh --dry-run

# 显示详细输出
./scripts/check-backup-freshness.sh --verbose
```

### 集成到监控系统

```bash
# 简单集成示例
if ! ./scripts/check-backup-freshness.sh --max-age-hours 24; then
  echo "备份新鲜度检查失败！" >&2
  # 发送告警邮件/短信
  # send-alert "数据库备份可能已停止"
fi
```

## 配置说明

### 默认配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `MAX_AGE_HOURS` | 24 | 最大允许备份年龄（小时） |
| `BACKUP_DIR` | `/opt/roc/quota-proxy/backups` | 服务器备份目录 |
| `SERVER_IP` | `8.210.185.194` | 服务器IP地址 |
| `SSH_KEY` | `~/.ssh/id_ed25519_roc_server` | SSH私钥路径 |

### 自定义配置

可以通过修改脚本中的变量或使用命令行参数来自定义配置：

```bash
# 使用命令行参数
./scripts/check-backup-freshness.sh --max-age-hours 12

# 修改脚本变量（永久配置）
# 编辑 scripts/check-backup-freshness.sh，修改以下变量：
# MAX_AGE_HOURS=12
# BACKUP_DIR="/custom/backup/path"
```

## 检查逻辑

### 1. 服务器连接检查
- 验证SSH连接是否正常
- 检查网络连通性和认证

### 2. 备份目录检查
- 验证备份目录是否存在
- 检查目录访问权限

### 3. 最新备份文件查找
- 查找备份目录中最新的备份文件
- 支持多种备份文件格式（.db, .db.backup, .sqlite）

### 4. 备份新鲜度检查
- 计算备份文件年龄（从修改时间到现在）
- 与最大允许年龄比较
- 输出人类可读的时间信息

### 5. 文件大小检查
- 检查备份文件大小是否合理
- 防止空文件或损坏文件

## 输出示例

### 成功检查
```
[INFO] 开始数据库备份新鲜度检查...
[INFO] 服务器: 8.210.185.194
[INFO] 备份目录: /opt/roc/quota-proxy/backups
[INFO] 最大允许年龄: 24小时
[INFO] 检查服务器连接...
[SUCCESS] 服务器连接正常
[INFO] 检查备份目录...
[SUCCESS] 备份目录存在: /opt/roc/quota-proxy/backups
[INFO] 查找最新的备份文件...
[SUCCESS] 找到最新备份文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260210-180000
[INFO] 检查备份文件新鲜度 (最大允许: 24小时)...
[INFO] 备份文件信息:
[INFO]   - 文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260210-180000
[INFO]   - 修改时间: 2026-02-10 18:00:00
[INFO]   - 年龄: 2小时 (7200秒)
[SUCCESS] 备份文件新鲜度检查通过 (2小时 ≤ 24小时)
[INFO] 检查备份文件大小...
[INFO] 备份文件大小: 5120 KB
[SUCCESS] 备份文件大小合理
[INFO] 生成备份新鲜度检查报告...
[SUCCESS] 检查报告已保存到: /tmp/backup-freshness-check-20260210-202359.txt
数据库备份新鲜度检查报告
生成时间: 2026-02-10 20:23:59
服务器: 8.210.185.194
最大允许年龄: 24小时

检查结果:
1. 服务器连接: ✓ 正常
2. 备份目录: ✓ 存在
3. 最新备份文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260210-180000
4. 备份新鲜度: ✓ 通过
5. 备份文件大小: ✓ 合理

建议:
- 备份系统工作正常，备份文件新鲜且大小合理

下次检查建议:
- 定期运行此脚本监控备份新鲜度
- 考虑设置告警（如备份超过24小时未更新）
- 集成到现有的监控系统中

[SUCCESS] 备份新鲜度检查全部通过
```

### 失败检查
```
[INFO] 开始数据库备份新鲜度检查...
[INFO] 服务器: 8.210.185.194
[INFO] 备份目录: /opt/roc/quota-proxy/backups
[INFO] 最大允许年龄: 24小时
[INFO] 检查服务器连接...
[SUCCESS] 服务器连接正常
[INFO] 检查备份目录...
[SUCCESS] 备份目录存在: /opt/roc/quota-proxy/backups
[INFO] 查找最新的备份文件...
[SUCCESS] 找到最新备份文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260209-010000
[INFO] 检查备份文件新鲜度 (最大允许: 24小时)...
[INFO] 备份文件信息:
[INFO]   - 文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260209-010000
[INFO]   - 修改时间: 2026-02-09 01:00:00
[INFO]   - 年龄: 43小时 (154800秒)
[ERROR] 备份文件过于陈旧 (43小时 > 24小时)
[INFO] 检查备份文件大小...
[INFO] 备份文件大小: 5120 KB
[SUCCESS] 备份文件大小合理
[INFO] 生成备份新鲜度检查报告...
[SUCCESS] 检查报告已保存到: /tmp/backup-freshness-check-20260210-202400.txt
数据库备份新鲜度检查报告
生成时间: 2026-02-10 20:24:00
服务器: 8.210.185.194
最大允许年龄: 24小时

检查结果:
1. 服务器连接: ✓ 正常
2. 备份目录: ✓ 存在
3. 最新备份文件: /opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260209-010000
4. 备份新鲜度: ✗ 失败
5. 备份文件大小: ✓ 合理

建议:
- 备份文件过于陈旧，请检查备份计划任务是否正常执行

下次检查建议:
- 定期运行此脚本监控备份新鲜度
- 考虑设置告警（如备份超过24小时未更新）
- 集成到现有的监控系统中

[WARNING] 备份新鲜度检查发现问题
```

## 退出码

| 退出码 | 说明 |
|--------|------|
| 0 | 检查通过，备份新鲜度正常 |
| 1 | 检查失败，备份存在问题 |
| 2 | 参数错误或脚本执行错误 |

## 集成建议

### 1. Cron定时检查
```bash
# 每天检查一次备份新鲜度
0 9 * * * /path/to/roc-ai-republic/scripts/check-backup-freshness.sh --max-age-hours 24
```

### 2. 监控系统集成
```bash
#!/bin/bash
# 监控脚本示例

CHECK_SCRIPT="/path/to/roc-ai-republic/scripts/check-backup-freshness.sh"
LOG_FILE="/var/log/backup-freshness.log"

# 运行检查
if ! $CHECK_SCRIPT --max-age-hours 24 >> "$LOG_FILE" 2>&1; then
  # 发送告警
  echo "$(date): 备份新鲜度检查失败" >> "$LOG_FILE"
  # send-alert "数据库备份可能已停止超过24小时"
fi
```

### 3. 与现有备份验证集成
```bash
#!/bin/bash
# 完整的备份验证流程

# 1. 验证备份完整性
./scripts/verify-db-backup.sh

# 2. 检查备份新鲜度
./scripts/check-backup-freshness.sh --max-age-hours 24

# 3. 生成综合报告
echo "备份系统状态: $(date)" > /tmp/backup-system-status.txt
./scripts/verify-db-backup.sh --quiet >> /tmp/backup-system-status.txt
./scripts/check-backup-freshness.sh --max-age-hours 24 --quiet >> /tmp/backup-system-status.txt
```

## 故障排除

### 常见问题

1. **连接失败**
   ```
   [ERROR] 无法连接到服务器
   ```
   **解决方案**：
   - 检查网络连接
   - 验证SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
   - 确认服务器IP地址正确

2. **备份目录不存在**
   ```
   [ERROR] 备份目录不存在: /opt/roc/quota-proxy/backups
   ```
   **解决方案**：
   - 检查备份目录路径
   - 确认备份脚本已创建目录
   - 手动创建目录：`mkdir -p /opt/roc/quota-proxy/backups`

3. **未找到备份文件**
   ```
   [WARNING] 未找到备份文件
   ```
   **解决方案**：
   - 检查备份脚本是否正常运行
   - 验证备份文件命名模式
   - 检查文件权限

4. **备份文件过于陈旧**
   ```
   [ERROR] 备份文件过于陈旧 (43小时 > 24小时)
   ```
   **解决方案**：
   - 检查cron任务是否正常执行
   - 验证备份脚本是否有错误
   - 检查磁盘空间是否充足

### 调试模式

使用`--verbose`参数获取详细输出：

```bash
./scripts/check-backup-freshness.sh --verbose
```

使用`--dry-run`参数模拟运行：

```bash
./scripts/check-backup-freshness.sh --dry-run --verbose
```

## 相关工具

- `verify-db-backup.sh` - 数据库备份完整性验证
- `backup-sqlite-db.sh` - 数据库备份脚本
- `setup-db-backup-cron.sh` - 备份cron设置脚本
- `verify-backup-integrity.sh` - 备份文件完整性验证

## 更新日志

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| v1.0 | 2026-02-10 | 初始版本，实现备份新鲜度检查功能 |

## 贡献

欢迎提交问题和改进建议。请通过GitHub Issues或Pull Requests参与贡献。