# quota-proxy 数据库备份指南

## 概述

`backup-quota-db.sh` 脚本是 quota-proxy 数据库管理工具链的重要组成部分，提供自动化、可靠的 SQLite 数据库备份解决方案。该脚本支持压缩备份、时间戳命名、保留策略和多种运行模式，确保数据库数据的安全性和可恢复性。

## 功能特性

### 核心功能
- **自动化备份**: 自动创建带时间戳的数据库备份
- **压缩支持**: 可选 gzip 压缩，节省存储空间
- **保留策略**: 基于天数的自动清理旧备份
- **完整性检查**: 备份前验证数据库完整性
- **多种模式**: 支持详细输出、安静模式、模拟运行

### 高级特性
- **灵活配置**: 支持自定义数据库路径、备份目录、保留天数
- **彩色输出**: 直观的状态和错误信息显示
- **标准化退出码**: 明确的脚本执行结果指示
- **故障安全**: 严格的错误处理和回退机制
- **生产就绪**: 适合生产环境的自动化部署

## 快速开始

### 基本用法
```bash
# 使用默认配置备份
./scripts/backup-quota-db.sh

# 指定数据库路径
./scripts/backup-quota-db.sh -d /opt/roc/quota.db

# 保留30天备份，不压缩
./scripts/backup-quota-db.sh -k 30 -n
```

### 模拟运行
```bash
# 查看备份计划而不实际执行
./scripts/backup-quota-db.sh --dry-run -v
```

## 详细配置

### 命令行选项

| 选项 | 缩写 | 默认值 | 描述 |
|------|------|--------|------|
| `--db-path` | `-d` | `./data/quota.db` | 数据库文件路径 |
| `--output-dir` | `-o` | `./backups` | 备份输出目录 |
| `--keep-days` | `-k` | `7` | 备份保留天数 |
| `--compress` | `-c` | 启用 | 启用 gzip 压缩 |
| `--no-compress` | `-n` | - | 禁用压缩 |
| `--verbose` | `-v` | 关闭 | 详细输出模式 |
| `--quiet` | `-q` | 关闭 | 安静模式，只输出错误 |
| `--dry-run` | - | 关闭 | 模拟运行，不实际执行 |
| `--help` | `-h` | - | 显示帮助信息 |

### 环境变量
脚本支持通过环境变量设置默认值：
```bash
export QUOTA_DB_PATH="/opt/roc/quota.db"
export QUOTA_BACKUP_DIR="/var/backups/quota"
export QUOTA_KEEP_DAYS=30
export QUOTA_COMPRESS=true
```

## 使用场景

### 1. 日常备份
```bash
# 每日定时备份，保留7天
0 2 * * * /opt/roc/scripts/backup-quota-db.sh -d /opt/roc/quota.db -o /var/backups/quota -k 7
```

### 2. 部署前备份
```bash
# 在部署新版本前创建备份
./scripts/backup-quota-db.sh -d /opt/roc/quota.db -k 0 --no-compress
```

### 3. 监控集成
```bash
# 检查备份是否成功
if ./scripts/backup-quota-db.sh -q; then
    echo "备份成功"
else
    echo "备份失败，退出码: $?"
fi
```

## 备份文件命名

备份文件使用以下命名约定：
```
quota_YYYYMMDD_HHMMSS.db[.gz]
```

示例：
```
quota_20260210_204752.db.gz
```

## 恢复备份

### 从压缩备份恢复
```bash
# 解压缩备份
gzip -d quota_20260210_204752.db.gz

# 恢复数据库
cp quota_20260210_204752.db /opt/roc/quota.db

# 设置正确权限
chown openclaw:openclaw /opt/roc/quota.db
chmod 644 /opt/roc/quota.db
```

### 验证恢复的数据库
```bash
# 使用验证脚本检查数据库完整性
./scripts/verify-quota-db.sh -d /opt/roc/quota.db
```

## 最佳实践

### 1. 定期备份计划
```bash
# crontab 配置示例
# 每天凌晨2点备份
0 2 * * * /opt/roc/scripts/backup-quota-db.sh -d /opt/roc/quota.db -o /var/backups/quota -k 30

# 每周日完整备份（保留90天）
0 3 * * 0 /opt/roc/scripts/backup-quota-db.sh -d /opt/roc/quota.db -o /var/backups/quota/weekly -k 90
```

### 2. 监控备份状态
```bash
# 检查最近备份
find /var/backups/quota -name "*.db*" -type f -mtime -1 | head -5

# 检查备份大小
du -sh /var/backups/quota/

# 验证备份完整性
for backup in /var/backups/quota/*.db.gz; do
    echo "检查: $backup"
    gzip -t "$backup" && echo "压缩包完整" || echo "压缩包损坏"
done
```

### 3. 存储策略
- **本地存储**: 快速恢复，用于日常备份
- **远程存储**: 异地容灾，用于重要备份
- **版本控制**: 保留多个时间点的备份
- **加密存储**: 敏感数据的额外保护

## 故障排除

### 常见问题

#### 1. 数据库文件不存在
```
错误: 数据库文件不存在: ./data/quota.db
```
**解决方案**:
```bash
# 指定正确的数据库路径
./scripts/backup-quota-db.sh -d /opt/roc/quota.db
```

#### 2. 权限不足
```
错误: 无法创建备份目录: ./backups
```
**解决方案**:
```bash
# 创建目录并设置权限
sudo mkdir -p /var/backups/quota
sudo chown -R $(whoami):$(whoami) /var/backups/quota
```

#### 3. 磁盘空间不足
```
错误: 备份复制失败
```
**解决方案**:
```bash
# 检查磁盘空间
df -h /var/backups

# 清理旧备份
find /var/backups/quota -name "*.db*" -type f -mtime +30 -delete
```

### 退出码说明

| 退出码 | 含义 | 建议操作 |
|--------|------|----------|
| 0 | 成功 | 无 |
| 1 | 参数错误 | 检查命令行参数 |
| 2 | 数据库文件不存在 | 验证数据库路径 |
| 3 | 备份目录创建失败 | 检查目录权限 |
| 4 | 备份失败 | 检查磁盘空间 |
| 5 | 清理旧备份失败 | 检查文件权限 |

## 集成指南

### 与现有工具链集成

#### 1. 与初始化脚本配合
```bash
# 初始化数据库后立即备份
./scripts/init-quota-db.sh && ./scripts/backup-quota-db.sh
```

#### 2. 与验证脚本配合
```bash
# 验证数据库后备份
./scripts/verify-quota-db.sh && ./scripts/backup-quota-db.sh
```

#### 3. 与监控脚本配合
```bash
# 监控使用情况后备份
./scripts/monitor-quota-usage.sh --quiet && ./scripts/backup-quota-db.sh -q
```

### 自动化工作流示例
```bash
#!/bin/bash
# 完整的数据库维护工作流

set -euo pipefail

# 1. 验证数据库完整性
echo "步骤1: 验证数据库完整性"
./scripts/verify-quota-db.sh -d /opt/roc/quota.db

# 2. 执行备份
echo "步骤2: 执行数据库备份"
./scripts/backup-quota-db.sh -d /opt/roc/quota.db -o /var/backups/quota -k 7

# 3. 验证备份文件
echo "步骤3: 验证备份文件"
latest_backup=$(find /var/backups/quota -name "*.db.gz" -type f | sort -r | head -1)
if [[ -n "$latest_backup" ]]; then
    gzip -t "$latest_backup"
    echo "最新备份验证通过: $(basename "$latest_backup")"
fi

# 4. 清理旧备份
echo "步骤4: 清理超过30天的旧备份"
find /var/backups/quota -name "*.db.gz" -type f -mtime +30 -delete

echo "数据库维护完成"
```

## 性能考虑

### 备份性能优化
1. **压缩级别**: 默认压缩在速度和大小间取得平衡
2. **并行处理**: 大型数据库可考虑并行压缩
3. **增量备份**: 未来可考虑实现增量备份功能

### 存储优化
1. **去重存储**: 相同内容的备份只存储一次
2. **压缩算法**: 评估不同压缩算法的效果
3. **分层存储**: 热数据、温数据、冷数据分层存储

## 安全注意事项

### 数据安全
1. **加密存储**: 敏感数据应加密存储
2. **访问控制**: 限制备份文件的访问权限
3. **传输安全**: 远程备份使用安全传输协议

### 操作安全
1. **测试恢复**: 定期测试备份恢复流程
2. **监控告警**: 监控备份失败情况
3. **审计日志**: 记录所有备份操作

## 未来扩展

### 计划功能
1. **增量备份**: 只备份变化的数据
2. **云存储集成**: 支持 AWS S3、Azure Blob 等
3. **加密备份**: 端到端加密备份文件
4. **Web界面**: 图形化的备份管理界面
5. **API接口**: 程序化备份管理接口

### 社区贡献
欢迎通过 GitHub Issues 和 Pull Requests 贡献改进建议。

## 相关文档

- [quota-proxy 数据库初始化指南](./quota-db-initialization.md)
- [quota-proxy 数据库验证指南](./quota-db-verification.md)
- [数据库备份完整性验证指南](./backup-integrity-verification.md)
- [数据库备份新鲜度检查指南](./backup-freshness-check.md)

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
