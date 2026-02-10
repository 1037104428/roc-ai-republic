# 备份文件完整性验证工具

## 概述

`verify-backup-integrity.sh` 是一个用于验证 quota-proxy 备份文件完整性的工具脚本。它提供了全面的备份文件检查功能，确保备份文件在需要恢复时可用。

## 功能特性

- **多维度验证**: 检查文件类型、gzip压缩完整性、SQLite数据库完整性
- **灵活配置**: 支持指定备份文件、备份目录、检查类型
- **多种模式**: 支持详细模式、模拟运行模式、列表模式
- **标准化退出码**: 提供清晰的执行结果指示
- **彩色输出**: 直观的彩色终端输出，便于识别问题

## 快速开始

### 验证最新备份文件

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-backup-integrity.sh
```

### 验证指定备份文件

```bash
./scripts/verify-backup-integrity.sh backups/quota-backup-2026-02-10.sql.gz
```

### 列出所有备份文件

```bash
./scripts/verify-backup-integrity.sh --list
```

### 模拟运行验证

```bash
./scripts/verify-backup-integrity.sh --dry-run
```

## 详细用法

### 命令行选项

| 选项 | 描述 | 示例 |
|------|------|------|
| `-h, --help` | 显示帮助信息 | `./verify-backup-integrity.sh --help` |
| `-v, --verbose` | 详细输出模式 | `./verify-backup-integrity.sh --verbose` |
| `-d, --dry-run` | 模拟运行，不实际验证 | `./verify-backup-integrity.sh --dry-run` |
| `-l, --list` | 列出可用的备份文件 | `./verify-backup-integrity.sh --list` |
| `--backup-dir DIR` | 指定备份目录 | `./verify-backup-integrity.sh --backup-dir /custom/backups` |
| `--check-sqlite` | 仅检查SQLite数据库完整性 | `./verify-backup-integrity.sh --check-sqlite` |
| `--check-gzip` | 仅检查gzip压缩文件完整性 | `./verify-backup-integrity.sh --check-gzip` |
| `--check-all` | 检查所有完整性（默认） | `./verify-backup-integrity.sh --check-all` |

### 验证流程

脚本执行以下验证步骤：

1. **文件存在性检查**: 确保备份文件存在且非空
2. **文件类型检查**: 验证文件是否为gzip压缩格式
3. **gzip完整性检查**: 使用 `gzip -t` 检查压缩文件完整性
4. **SQLite完整性检查**: 解压文件并使用 `PRAGMA integrity_check` 验证数据库完整性
5. **表结构检查**: 验证数据库包含必要的表结构

### 退出码说明

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 验证成功 | 备份文件完整，可用于恢复 |
| 1 | 验证失败 | 备份文件损坏，不建议用于恢复 |
| 2 | 参数错误 | 文件不存在或参数错误 |
| 3 | 缺少工具 | 缺少必要的系统工具 |

## 使用示例

### 示例1：基本验证

```bash
# 验证最新备份文件
./scripts/verify-backup-integrity.sh

# 输出示例：
# [INFO] 未指定备份文件，使用最新备份
# [INFO] 开始验证备份文件: backups/quota-backup-2026-02-10.sql.gz
# [INFO] 文件大小: 1.2M
# [INFO] 检查文件类型: backups/quota-backup-2026-02-10.sql.gz
# [INFO] ✓ 文件类型正确: gzip压缩文件
# [INFO] 检查gzip压缩文件完整性: backups/quota-backup-2026-02-10.sql.gz
# [INFO] ✓ gzip压缩文件完整
# [INFO] 检查SQLite数据库完整性: backups/quota-backup-2026-02-10.sql.gz
# [INFO] ✓ SQLite数据库完整
# [INFO] ✓ 数据库包含表: api_keys usage_logs
# [INFO] ✅ 备份文件验证成功: backups/quota-backup-2026-02-10.sql.gz
# [INFO]    文件完整，可用于恢复
```

### 示例2：详细模式验证

```bash
# 详细模式验证指定文件
./scripts/verify-backup-integrity.sh backups/quota-backup-2026-02-09.sql.gz --verbose

# 输出示例（包含调试信息）：
# [DEBUG] 文件类型: gzip compressed data, last modified: Tue Feb 10 20:00:00 2026, from Unix, original size modulo 2^32 1048576
# [DEBUG] 数据库表: api_keys
# usage_logs
```

### 示例3：仅检查SQLite完整性

```bash
# 仅检查SQLite数据库完整性
./scripts/verify-backup-integrity.sh --check-sqlite --verbose
```

### 示例4：模拟运行

```bash
# 模拟运行验证
./scripts/verify-backup-integrity.sh --dry-run --verbose

# 输出示例：
# [INFO] [DRY-RUN] 将检查gzip完整性: backups/quota-backup-2026-02-10.sql.gz
# [INFO] [DRY-RUN] 将解压并检查SQLite数据库: backups/quota-backup-2026-02-10.sql.gz
```

## 集成到备份流程

### 在备份脚本后自动验证

可以在备份脚本执行后自动调用验证脚本：

```bash
#!/bin/bash
# 备份后验证示例

# 执行备份
./scripts/backup-sqlite-db.sh

# 获取最新备份文件
latest_backup=$(find backups -name "*.sql.gz" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)

# 验证备份
if ./scripts/verify-backup-integrity.sh "$latest_backup"; then
    echo "备份验证成功"
else
    echo "备份验证失败，需要重新备份"
    exit 1
fi
```

### 定时任务集成

可以在cron任务中添加验证步骤：

```bash
# 每天凌晨2点执行备份并验证
0 2 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/backup-sqlite-db.sh && ./scripts/verify-backup-integrity.sh --quiet
```

## 故障排除

### 常见问题

#### 问题1：缺少必要工具

**错误信息**：
```
[ERROR] 缺少必要工具: sqlite3
[INFO] 请安装缺少的工具后重试
```

**解决方案**：
```bash
# 安装sqlite3
sudo apt-get install sqlite3

# 安装gzip（通常已安装）
sudo apt-get install gzip
```

#### 问题2：备份文件不存在

**错误信息**：
```
[ERROR] 备份文件不存在: backups/quota-backup-2026-02-10.sql.gz
```

**解决方案**：
1. 检查备份目录是否存在：`ls -la backups/`
2. 列出可用备份文件：`./scripts/verify-backup-integrity.sh --list`
3. 确保备份脚本已正确执行

#### 问题3：gzip压缩文件损坏

**错误信息**：
```
[ERROR] ✗ gzip压缩文件损坏
```

**解决方案**：
1. 尝试手动解压：`gzip -t backup-file.sql.gz`
2. 如果解压失败，需要重新备份
3. 检查磁盘空间和权限

#### 问题4：SQLite数据库损坏

**错误信息**：
```
[ERROR] ✗ SQLite数据库损坏
```

**解决方案**：
1. 尝试手动修复：`sqlite3 database.db ".dump" | sqlite3 repaired.db`
2. 从其他备份恢复
3. 检查数据库文件权限

### 调试技巧

1. **使用详细模式**：添加 `--verbose` 参数获取更多信息
2. **模拟运行**：使用 `--dry-run` 参数测试脚本逻辑
3. **手动验证**：手动执行各个检查步骤：
   ```bash
   # 检查文件类型
   file backups/quota-backup-2026-02-10.sql.gz
   
   # 检查gzip完整性
   gzip -t backups/quota-backup-2026-02-10.sql.gz
   
   # 检查SQLite完整性
   gzip -dc backups/quota-backup-2026-02-10.sql.gz > temp.db
   sqlite3 temp.db "PRAGMA integrity_check;"
   rm temp.db
   ```

## 最佳实践

### 1. 定期验证备份

建议在以下时机验证备份文件：
- 备份完成后立即验证
- 定期（如每周）验证所有备份文件
- 在计划恢复操作前验证目标备份文件

### 2. 集成到CI/CD流程

可以将备份验证集成到持续集成流程中：

```yaml
# GitHub Actions 示例
name: Verify Backups
on:
  schedule:
    - cron: '0 3 * * *'  # 每天凌晨3点
  workflow_dispatch:

jobs:
  verify-backups:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: sudo apt-get install sqlite3
      - name: Verify latest backup
        run: ./scripts/verify-backup-integrity.sh
```

### 3. 监控和告警

设置监控和告警，当备份验证失败时及时通知：

```bash
#!/bin/bash
# 监控脚本示例

if ! ./scripts/verify-backup-integrity.sh --quiet; then
    # 发送告警
    echo "备份验证失败！" | mail -s "备份告警" admin@example.com
    # 或者使用其他通知方式
    ./scripts/send-alert.sh "备份验证失败"
fi
```

### 4. 保留验证日志

记录验证结果以便审计：

```bash
#!/bin/bash
# 验证并记录日志

LOG_FILE="backup-verification.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== 备份验证开始: $TIMESTAMP ===" >> "$LOG_FILE"
./scripts/verify-backup-integrity.sh --verbose 2>&1 | tee -a "$LOG_FILE"
echo "=== 备份验证结束: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
```

## 相关工具

- `backup-sqlite-db.sh` - 数据库备份脚本
- `backup-restore-quota-db.sh` - 数据库备份与恢复脚本
- `verify-db-backup.sh` - 数据库备份验证脚本
- `test-db-backup-recovery.sh` - 数据库备份恢复测试脚本

## 更新日志

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| 1.0.0 | 2026-02-10 | 初始版本，提供完整的备份文件完整性验证功能 |

## 支持与反馈

如有问题或建议，请：
1. 检查本文档的故障排除部分
2. 使用详细模式运行脚本获取更多信息：`./scripts/verify-backup-integrity.sh --verbose`
3. 提交issue到项目仓库