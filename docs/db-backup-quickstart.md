# 数据库备份恢复快速指南

## 概述

本仓库提供了 quota-proxy 数据库的备份与恢复工具，支持 SQLite 和文件模式。

## 快速开始

### 1. 备份数据库

```bash
# 备份当前数据库
./scripts/verify-db-backup-restore.sh --backup

# 或使用简化版本
./scripts/verify-db-backup-restore-simple.sh
```

备份文件将保存在 `quota-proxy/backups/` 目录下，命名格式为 `backup_YYYYMMDD_HHMMSS.txt`。

### 2. 恢复数据库

```bash
# 查看可用备份
ls -la quota-proxy/backups/

# 恢复指定备份
./scripts/verify-db-backup-restore.sh --restore quota-proxy/backups/backup_20260210_015121.txt
```

### 3. 验证备份完整性

```bash
# 验证备份文件格式
./scripts/verify-db-backup-restore.sh --verify quota-proxy/backups/backup_20260210_015121.txt
```

## 备份内容

备份文件包含：
- 数据库模式（表结构）
- 密钥数据（keys 表）
- 使用记录（usage 表）
- 备份时间戳

## 注意事项

1. **权限要求**：运行脚本需要读取 quota-proxy 数据库文件的权限
2. **服务状态**：建议在 quota-proxy 服务停止时进行恢复操作
3. **备份频率**：建议定期备份，特别是密钥发放频繁时
4. **存储安全**：备份文件包含敏感数据，请妥善保管

## 故障排除

### 备份失败
- 检查数据库文件路径是否正确
- 确认有足够的磁盘空间
- 验证数据库连接权限

### 恢复失败
- 确保目标数据库文件可写
- 检查备份文件格式是否正确
- 确认数据库服务已停止

## 相关脚本

- `scripts/verify-db-backup-restore.sh`：完整备份恢复脚本
- `scripts/verify-db-backup-restore-simple.sh`：简化版本
- `quota-proxy/backups/`：备份文件目录

## 下一步

- [ ] 自动化定期备份（cron 任务）
- [ ] 添加备份加密功能
- [ ] 支持远程备份存储
- [ ] 实现增量备份