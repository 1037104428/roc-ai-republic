# quota-proxy 数据库恢复指南

## 概述

`restore-quota-db.sh` 脚本是 quota-proxy 数据库管理工具链的重要组成部分，用于从备份文件恢复 SQLite 数据库。该脚本提供了安全、可靠的数据库恢复解决方案，支持多种恢复模式和完整性验证。

## 功能特性

### 核心功能
- **备份文件选择**: 自动选择最新备份文件或手动指定备份文件
- **完整性验证**: 检查备份文件的完整性和有效性
- **安全恢复**: 提供交互式确认和强制恢复模式
- **模拟运行**: 支持 dry-run 模式预览恢复过程
- **彩色输出**: 提供清晰的彩色输出和状态指示

### 高级功能
- **备份文件列表**: 列出可用的备份文件及其详细信息
- **完整性检查**: 独立检查备份文件的完整性
- **年龄过滤**: 根据备份年龄过滤可用的备份文件
- **依赖检查**: 自动检查并报告缺失的系统依赖
- **错误处理**: 提供详细的错误信息和故障排除指南

## 使用场景

### 1. 数据恢复场景
- **灾难恢复**: 数据库损坏或丢失时的数据恢复
- **版本回滚**: 恢复到之前的数据库版本
- **测试环境**: 将生产数据复制到测试环境
- **迁移操作**: 在不同服务器间迁移数据库

### 2. 维护场景
- **备份验证**: 定期验证备份文件的可用性
- **恢复演练**: 定期进行恢复演练确保恢复流程有效
- **容量规划**: 评估恢复后的数据库大小和性能

## 快速开始

### 基本用法

```bash
# 列出可用的备份文件
./scripts/restore-quota-db.sh --list

# 检查最新备份文件的完整性
./scripts/restore-quota-db.sh --check

# 模拟恢复过程
./scripts/restore-quota-db.sh --dry-run

# 强制恢复最新备份
./scripts/restore-quota-db.sh --force

# 恢复指定备份文件
./scripts/restore-quota-db.sh --backup-file /path/to/backup.sql.gz
```

### 恢复流程示例

```bash
# 1. 查看可用的备份
./scripts/restore-quota-db.sh --list

# 2. 检查备份完整性
./scripts/restore-quota-db.sh --check

# 3. 模拟恢复
./scripts/restore-quota-db.sh --dry-run

# 4. 执行恢复（交互式确认）
./scripts/restore-quota-db.sh

# 5. 验证恢复结果
./scripts/verify-quota-db.sh
```

## 详细配置

### 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 详细输出模式 | true |
| `--quiet` | `-q` | 安静模式 | false |
| `--dry-run` | `-d` | 模拟运行 | false |
| `--force` | `-f` | 强制恢复模式 | false |
| `--backup-dir` | `-b` | 备份目录路径 | `/opt/roc/quota-proxy/backups` |
| `--target-db` | `-t` | 目标数据库路径 | `/opt/roc/quota-proxy/data/quota.db` |
| `--backup-file` | `-s` | 指定备份文件路径 | - |
| `--list` | `-l` | 列出可用的备份文件 | false |
| `--check` | `-c` | 检查备份文件完整性 | false |
| `--age-hours` | `-a` | 最大备份年龄（小时） | 24 |
| `--no-color` | - | 禁用彩色输出 | - |

### 环境变量

```bash
# 覆盖默认配置
export QUOTA_BACKUP_DIR="/custom/backup/path"
export QUOTA_TARGET_DB="/custom/db/path/quota.db"
export QUOTA_MAX_BACKUP_AGE_HOURS=48
```

## 恢复流程详解

### 1. 备份文件选择
脚本按以下优先级选择备份文件：
1. 用户通过 `--backup-file` 指定的文件
2. 备份目录中最新的备份文件（按修改时间排序）
3. 支持的文件格式：`.gz`、`.db`、`.sqlite`

### 2. 完整性验证
恢复前执行以下完整性检查：
- **文件存在性**: 确保备份文件存在且可读
- **gzip完整性**: 检查压缩文件的完整性
- **SQLite完整性**: 验证数据库文件的完整性
- **表结构验证**: 检查必需的表结构是否存在

### 3. 安全确认
除非使用 `--force` 选项，否则在覆盖现有数据库时会要求用户确认：
```bash
警告: 这将覆盖现有的数据库文件
是否继续? (y/N):
```

### 4. 恢复执行
根据备份文件类型执行相应的恢复操作：
- **gzip压缩文件**: 解压到目标位置
- **普通数据库文件**: 复制到目标位置

### 5. 恢复后验证
恢复完成后自动验证：
- **数据库完整性**: 执行 `PRAGMA integrity_check`
- **表结构验证**: 检查必需的表是否存在

## 错误处理与故障排除

### 常见错误

| 错误代码 | 描述 | 解决方案 |
|----------|------|----------|
| 1 | 参数错误或用户取消 | 检查命令行参数，确认操作 |
| 2 | 备份文件不存在或无效 | 检查备份文件路径和权限 |
| 3 | 恢复过程失败 | 检查磁盘空间和文件权限 |
| 4 | 系统依赖缺失 | 安装缺失的依赖包 |

### 故障排除步骤

```bash
# 1. 检查脚本权限
chmod +x ./scripts/restore-quota-db.sh

# 2. 检查依赖
which sqlite3 gzip

# 3. 检查备份目录
ls -la /opt/roc/quota-proxy/backups/

# 4. 手动测试备份文件
gzip -t /path/to/backup.sql.gz
sqlite3 /path/to/backup.db "PRAGMA integrity_check;"

# 5. 检查磁盘空间
df -h /opt/roc/quota-proxy/

# 6. 检查文件权限
ls -la /opt/roc/quota-proxy/data/
```

### 调试模式

```bash
# 启用详细输出
./scripts/restore-quota-db.sh -v

# 结合其他调试工具
bash -x ./scripts/restore-quota-db.sh --dry-run
```

## 集成与自动化

### 1. 与备份脚本集成

```bash
#!/bin/bash
# 自动化备份和恢复验证脚本

# 执行备份
./scripts/backup-quota-db.sh

# 验证备份完整性
./scripts/restore-quota-db.sh --check

# 定期恢复演练（每月一次）
if [[ $(date +%d) == "01" ]]; then
    ./scripts/restore-quota-db.sh --dry-run
    echo "恢复演练完成: $(date)"
fi
```

### 2. CI/CD 集成

```yaml
# GitHub Actions 示例
jobs:
  backup-recovery-test:
    runs-on: ubuntu-latest
    steps:
      - name: 检查备份恢复流程
        run: |
          ./scripts/restore-quota-db.sh --list
          ./scripts/restore-quota-db.sh --check
          ./scripts/restore-quota-db.sh --dry-run
```

### 3. 监控集成

```bash
#!/bin/bash
# 监控脚本：检查备份可用性

# 检查是否有可用的备份
if ./scripts/restore-quota-db.sh --list --quiet 2>&1 | grep -q "可用的备份文件"; then
    echo "OK: 有可用的备份文件"
else
    echo "CRITICAL: 没有可用的备份文件"
    exit 2
fi

# 检查最新备份的完整性
if ./scripts/restore-quota-db.sh --check --quiet; then
    echo "OK: 备份文件完整性检查通过"
else
    echo "CRITICAL: 备份文件完整性检查失败"
    exit 2
fi
```

## 最佳实践

### 1. 恢复策略
- **定期演练**: 每月至少进行一次恢复演练
- **版本控制**: 保留多个时间点的备份版本
- **异地备份**: 考虑将备份存储在不同位置
- **恢复测试**: 在实际恢复前总是先进行 dry-run

### 2. 安全考虑
- **权限管理**: 确保只有授权用户可以执行恢复操作
- **审计日志**: 记录所有恢复操作的详细信息
- **数据验证**: 恢复后验证数据的完整性和一致性
- **回滚计划**: 准备恢复失败时的回滚方案

### 3. 性能优化
- **增量备份**: 考虑实现增量备份减少恢复时间
- **并行恢复**: 对于大型数据库考虑并行恢复策略
- **压缩优化**: 根据存储和恢复速度需求调整压缩级别
- **缓存策略**: 优化数据库缓存配置提高恢复后性能

## 相关工具

### 数据库管理工具链
- **初始化**: `init-quota-db.sh` - 数据库初始化
- **验证**: `verify-quota-db.sh` - 数据库完整性验证
- **备份**: `backup-quota-db.sh` - 数据库备份
- **恢复**: `restore-quota-db.sh` - 数据库恢复（本文档）
- **完整性检查**: `verify-backup-integrity.sh` - 备份文件完整性检查
- **新鲜度检查**: `check-backup-freshness.sh` - 备份新鲜度检查

### 测试工具
- **接口测试**: `test-quota-proxy-admin-keys-usage.sh` - 管理接口测试
- **健康检查**: 直接调用 `/healthz` 端点

## 退出码说明

| 退出码 | 描述 | 建议操作 |
|--------|------|----------|
| 0 | 成功 | 无需操作 |
| 1 | 参数错误或用户取消 | 检查命令行参数 |
| 2 | 备份文件不存在或无效 | 检查备份文件 |
| 3 | 恢复过程失败 | 检查磁盘空间和权限 |
| 4 | 系统依赖缺失 | 安装缺失的依赖 |

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持基本恢复功能
- 提供完整性验证
- 支持多种运行模式
- 完整的错误处理

## 支持与反馈

如有问题或建议，请：
1. 查看详细错误信息
2. 检查相关日志文件
3. 参考故障排除指南
4. 联系维护团队

---

**重要提示**: 数据库恢复是高风险操作，请在非生产环境充分测试后再在生产环境使用。建议定期进行恢复演练以确保恢复流程的有效性。