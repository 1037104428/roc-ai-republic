# SQLite数据库备份指南

本指南介绍如何使用 `backup-sqlite-db.sh` 脚本进行 quota-proxy SQLite 数据库的备份、压缩和恢复管理。

## 快速开始

### 1. 授予执行权限
```bash
chmod +x backup-sqlite-db.sh
```

### 2. 查看帮助信息
```bash
./backup-sqlite-db.sh --help
```

### 3. 执行备份（默认配置）
```bash
./backup-sqlite-db.sh
```

### 4. 执行备份（自定义配置）
```bash
./backup-sqlite-db.sh \
  --db-path /opt/roc/quota-proxy/data/quota.db \
  --backup-dir /var/backups/quota \
  --keep-days 30
```

### 5. 干运行模式（预览操作）
```bash
./backup-sqlite-db.sh --dry-run
```

## 功能特性

### 核心功能
- **数据库备份**: 创建带时间戳的数据库备份文件
- **自动压缩**: 使用 gzip 压缩备份文件，节省存储空间
- **过期清理**: 自动清理超过指定天数的旧备份
- **完整性验证**: 验证数据库文件和备份文件的存在性

### 高级特性
- **彩色输出**: 使用颜色区分信息、警告和错误
- **干运行模式**: 预览将要执行的操作而不实际执行
- **详细日志**: 显示每个步骤的详细信息
- **备份统计**: 显示备份数量、大小和最新备份信息

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--db-path PATH` | 数据库文件路径 | `./data/quota.db` |
| `--backup-dir DIR` | 备份目录 | `./backups` |
| `--keep-days DAYS` | 保留天数 | `7` |
| `--dry-run` | 干运行模式 | `false` |
| `--help` | 显示帮助信息 | - |

## 使用示例

### 示例 1: 基本备份
```bash
# 使用默认配置备份
./backup-sqlite-db.sh
```

输出示例:
```
=== quota-proxy SQLite数据库备份脚本 ===
数据库文件存在: ./data/quota.db
创建备份目录: ./backups
创建数据库备份...
压缩备份文件...
备份创建成功: ./backups/quota_backup_20260211_192701.db.gz (1.2M)
清理过期备份 (保留 7 天)...
没有需要清理的过期备份

备份统计:
  总备份数: 1
  总大小: 1.2M
  最新备份: quota_backup_20260211_192701.db.gz (1.2M, 2026-02-11 19:27:01)

备份完成!
```

### 示例 2: 自定义配置备份
```bash
# 自定义数据库路径、备份目录和保留天数
./backup-sqlite-db.sh \
  --db-path /opt/roc/quota-proxy/data/quota.db \
  --backup-dir /var/backups/quota \
  --keep-days 30
```

### 示例 3: 干运行模式
```bash
# 预览备份操作
./backup-sqlite-db.sh --dry-run
```

输出示例:
```
=== quota-proxy SQLite数据库备份脚本 ===
[干运行] 数据库文件存在: ./data/quota.db
[干运行] 将创建备份目录: ./backups
[干运行] 将创建备份:
  源数据库: ./data/quota.db
  备份文件: ./backups/quota_backup_20260211_192701.db
  压缩文件: ./backups/quota_backup_20260211_192701.db.gz
[干运行] 将清理超过 7 天的备份
```

## CI/CD 集成

### 定时备份任务
在 CI/CD 流水线中添加定时备份任务:

```yaml
# GitHub Actions 示例
name: Database Backup

on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨2点
  workflow_dispatch:      # 手动触发

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        
      - name: Setup SQLite
        run: sudo apt-get install -y sqlite3
        
      - name: Run database backup
        run: |
          cd quota-proxy
          chmod +x backup-sqlite-db.sh
          ./backup-sqlite-db.sh \
            --db-path ./data/quota.db \
            --backup-dir ./backups \
            --keep-days 30
```

### 备份验证
在备份后验证备份文件的完整性:

```bash
# 验证备份文件存在且可解压
gzip -t ./backups/quota_backup_*.db.gz

# 验证备份数量
backup_count=$(find ./backups -name "quota_backup_*.db.gz" -type f | wc -l)
if [ $backup_count -eq 0 ]; then
  echo "错误: 没有找到备份文件"
  exit 1
fi
```

## 故障排除

### 常见问题

#### 1. 数据库文件不存在
```
错误: 数据库文件不存在: ./data/quota.db
```
**解决方案:**
- 检查数据库文件路径是否正确
- 确保数据库文件已创建
- 使用 `--db-path` 指定正确的路径

#### 2. sqlite3 未安装
```
错误: sqlite3 未安装
```
**解决方案:**
```bash
# Ubuntu/Debian
sudo apt-get install sqlite3

# CentOS/RHEL
sudo yum install sqlite

# macOS
brew install sqlite
```

#### 3. 权限不足
```
错误: 无法创建备份目录
```
**解决方案:**
```bash
# 创建备份目录
sudo mkdir -p /var/backups/quota
sudo chown -R $(whoami):$(whoami) /var/backups/quota
```

### 调试模式
启用详细输出以调试问题:

```bash
# 启用详细输出
set -x
./backup-sqlite-db.sh
set +x
```

## 恢复数据库

### 从备份恢复
```bash
# 解压备份文件
gzip -d ./backups/quota_backup_20260211_192701.db.gz

# 恢复数据库
cp ./backups/quota_backup_20260211_192701.db ./data/quota.db

# 验证恢复
sqlite3 ./data/quota.db "SELECT COUNT(*) FROM api_keys;"
```

### 自动化恢复脚本
创建恢复脚本 `restore-sqlite-db.sh`:

```bash
#!/bin/bash
set -euo pipefail

BACKUP_FILE="$1"
TARGET_DB="./data/quota.db"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "错误: 备份文件不存在: $BACKUP_FILE"
  exit 1
fi

echo "恢复数据库从: $BACKUP_FILE"
cp "$BACKUP_FILE" "$TARGET_DB"
echo "恢复完成: $TARGET_DB"
```

## 相关文档

- [INIT_SQLITE_DB.md](./INIT_SQLITE_DB.md) - SQLite数据库初始化指南
- [QUICK-HEALTH-CHECK.md](./QUICK-HEALTH-CHECK.md) - 快速健康检查指南
- [VERIFY_ADMIN_API_COMPLETE.md](./VERIFY_ADMIN_API_COMPLETE.md) - 管理API完整性验证指南

## 最佳实践

### 备份策略
1. **定期备份**: 每天至少备份一次
2. **异地备份**: 将备份文件复制到远程存储
3. **版本控制**: 保留多个版本的备份
4. **测试恢复**: 定期测试备份文件的恢复能力

### 存储管理
1. **监控存储空间**: 定期检查备份目录的磁盘使用情况
2. **清理策略**: 根据业务需求调整保留天数
3. **压缩优化**: 使用最高压缩级别节省空间

### 安全考虑
1. **权限控制**: 限制备份文件的访问权限
2. **加密存储**: 对敏感数据的备份进行加密
3. **访问日志**: 记录备份操作的访问日志

---

**最后更新**: 2026-02-11  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
