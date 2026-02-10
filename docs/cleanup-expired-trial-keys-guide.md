# 清理过期的trial keys指南

## 概述

`cleanup-expired-trial-keys.sh` 脚本用于定期清理quota-proxy数据库中过期的trial keys，保持数据库整洁，防止数据库膨胀。

## 功能特性

### 核心功能
- **过期keys检测**：自动识别数据库中已过期的trial keys
- **安全清理**：支持模拟运行、交互确认、强制清理多种模式
- **详细报告**：提供清理前后的统计信息和详细报告
- **灵活配置**：支持自定义数据库路径、多种输出模式

### 安全特性
- **模拟运行模式**：先查看会清理哪些数据，再实际执行
- **交互确认**：默认需要用户确认后才执行删除操作
- **事务保护**：使用SQLite事务确保数据一致性
- **备份建议**：建议在执行清理前备份数据库

### 输出特性
- **彩色输出**：使用颜色区分不同级别的信息
- **多种模式**：支持详细模式、安静模式、列表模式
- **标准化退出码**：明确的退出码表示不同状态

## 使用场景

### 1. 定期维护
```bash
# 每周执行一次清理
0 2 * * 1 /path/to/scripts/cleanup-expired-trial-keys.sh --verbose
```

### 2. 手动检查
```bash
# 检查过期keys情况
./scripts/cleanup-expired-trial-keys.sh --list

# 模拟运行查看效果
./scripts/cleanup-expired-trial-keys.sh --dry-run --verbose
```

### 3. 紧急清理
```bash
# 强制清理所有过期keys（无需确认）
./scripts/cleanup-expired-trial-keys.sh --force --verbose
```

## 命令行选项

| 选项 | 缩写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--database` | `-d` | SQLite数据库路径 | `/opt/roc/quota-proxy/data/quota.db` |
| `--dry-run` | - | 模拟运行，不实际删除 | `false` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--quiet` | `-q` | 安静模式，只输出关键信息 | `false` |
| `--force` | `-f` | 强制清理，不进行交互确认 | `false` |
| `--list` | - | 列出所有trial keys | `false` |

## 使用示例

### 示例1：基本使用
```bash
# 查看帮助
./scripts/cleanup-expired-trial-keys.sh --help

# 列出所有trial keys
./scripts/cleanup-expired-trial-keys.sh --list

# 模拟清理
./scripts/cleanup-expired-trial-keys.sh --dry-run --verbose

# 实际清理（需要确认）
./scripts/cleanup-expired-trial-keys.sh --verbose
```

### 示例2：生产环境使用
```bash
# 使用自定义数据库路径
./scripts/cleanup-expired-trial-keys.sh \
  --database /opt/roc/quota-proxy/data/quota.db \
  --verbose

# 强制清理（自动化脚本中使用）
./scripts/cleanup-expired-trial-keys.sh \
  --database /opt/roc/quota-proxy/data/quota.db \
  --force \
  --quiet
```

### 示例3：集成到监控系统
```bash
# 检查过期keys数量
expired_count=$(./scripts/cleanup-expired-trial-keys.sh --list --quiet | grep "过期keys数" | awk '{print $NF}')

if [[ $expired_count -gt 100 ]]; then
  echo "警告：发现 $expired_count 个过期keys，建议清理"
  ./scripts/cleanup-expired-trial-keys.sh --force --quiet
fi
```

## 退出码

| 退出码 | 描述 | 处理建议 |
|--------|------|----------|
| 0 | 成功 | 任务完成 |
| 1 | 参数错误 | 检查命令行参数 |
| 2 | 数据库文件不存在 | 检查数据库路径 |
| 3 | 数据库连接失败 | 检查数据库权限和完整性 |
| 4 | SQL执行错误 | 检查数据库结构和SQL语句 |
| 5 | 用户取消操作 | 用户主动取消 |

## 最佳实践

### 1. 定期清理策略
```bash
# 每周一凌晨2点执行清理（crontab）
0 2 * * 1 cd /path/to/roc-ai-republic && ./scripts/cleanup-expired-trial-keys.sh --force --quiet
```

### 2. 清理前备份
```bash
# 清理前备份数据库
backup_file="/opt/roc/quota-proxy/backups/quota_$(date +%Y%m%d_%H%M%S).db"
cp /opt/roc/quota-proxy/data/quota.db "$backup_file"

# 执行清理
./scripts/cleanup-expired-trial-keys.sh --force --quiet
```

### 3. 监控清理效果
```bash
# 记录清理日志
log_file="/var/log/quota-proxy/cleanup_$(date +%Y%m%d).log"
./scripts/cleanup-expired-trial-keys.sh --verbose 2>&1 | tee -a "$log_file"
```

### 4. 与备份脚本集成
```bash
#!/bin/bash
# cleanup-and-backup.sh

# 备份数据库
./scripts/backup-quota-db.sh --verbose

# 清理过期keys
./scripts/cleanup-expired-trial-keys.sh --force --quiet

# 优化数据库
sqlite3 /opt/roc/quota-proxy/data/quota.db "VACUUM;"
```

## 故障排除

### 常见问题

#### 问题1：数据库文件不存在
```
[ERROR] 数据库文件不存在: /opt/roc/quota-proxy/data/quota.db
```
**解决方案：**
1. 检查数据库路径是否正确
2. 确认quota-proxy服务已启动并创建了数据库
3. 运行数据库初始化脚本：`./scripts/init-quota-db.sh`

#### 问题2：trial_keys表不存在
```
[ERROR] trial_keys表不存在
```
**解决方案：**
1. 运行数据库初始化脚本：`./scripts/init-quota-db.sh`
2. 检查数据库版本：`./scripts/migrate-quota-db.sh --list`

#### 问题3：权限不足
```
[ERROR] 无法连接到数据库: /opt/roc/quota-proxy/data/quota.db
```
**解决方案：**
1. 检查文件权限：`ls -la /opt/roc/quota-proxy/data/quota.db`
2. 确保脚本有读取权限：`chmod +r /opt/roc/quota-proxy/data/quota.db`
3. 使用正确的用户运行脚本

### 调试技巧

#### 启用详细输出
```bash
./scripts/cleanup-expired-trial-keys.sh --verbose --dry-run
```

#### 检查数据库状态
```bash
# 检查数据库完整性
./scripts/verify-quota-db.sh --verbose

# 检查表结构
sqlite3 /opt/roc/quota-proxy/data/quota.db ".schema trial_keys"
```

#### 手动查询过期keys
```bash
sqlite3 /opt/roc/quota-proxy/data/quota.db <<EOF
SELECT 
    COUNT(*) as expired_count,
    MIN(expires_at) as oldest_expiry,
    MAX(expires_at) as newest_expiry
FROM trial_keys 
WHERE expires_at < datetime('now');
EOF
```

## 集成指南

### 与CI/CD集成
```yaml
# .gitlab-ci.yml 示例
cleanup_expired_keys:
  stage: cleanup
  script:
    - ./scripts/cleanup-expired-trial-keys.sh --dry-run --verbose
  only:
    - schedules  # 仅定时任务执行
```

### 与监控系统集成
```bash
# Prometheus metrics 示例
expired_keys_count=$(sqlite3 /opt/roc/quota-proxy/data/quota.db \
  "SELECT COUNT(*) FROM trial_keys WHERE expires_at < datetime('now');")

echo "# HELP quota_proxy_expired_keys_count Number of expired trial keys"
echo "# TYPE quota_proxy_expired_keys_count gauge"
echo "quota_proxy_expired_keys_count $expired_keys_count"
```

### 与告警系统集成
```bash
#!/bin/bash
# check-expired-keys-alert.sh

EXPIRED_THRESHOLD=50
expired_count=$(./scripts/cleanup-expired-trial-keys.sh --list --quiet | \
  grep "过期keys数" | awk '{print $NF}')

if [[ $expired_count -gt $EXPIRED_THRESHOLD ]]; then
  # 发送告警
  curl -X POST -H "Content-Type: application/json" \
    -d "{\"text\":\"警告：quota-proxy有 $expired_count 个过期trial keys，建议立即清理\"}" \
    https://hooks.slack.com/services/...
fi
```

## 性能考虑

### 清理频率
- **推荐频率**：每周一次
- **高峰时段避免**：避免在业务高峰时段执行清理
- **监控影响**：首次执行时监控数据库性能

### 数据库优化
```bash
# 清理后优化数据库
sqlite3 /opt/roc/quota-proxy/data/quota.db "VACUUM;"

# 重新分析统计信息
sqlite3 /opt/roc/quota-proxy/data/quota.db "ANALYZE;"
```

### 批量处理
对于大量过期keys的情况：
```bash
# 分批处理（每次1000条）
./scripts/cleanup-expired-trial-keys.sh --force --quiet
sqlite3 /opt/roc/quota-proxy/data/quota.db "VACUUM;"
```

## 安全注意事项

### 数据保护
1. **备份优先**：始终在执行清理前备份数据库
2. **权限控制**：确保只有授权用户能执行清理操作
3. **审计日志**：记录所有清理操作的时间、用户和影响

### 操作安全
1. **模拟运行**：首次使用前务必先模拟运行
2. **交互确认**：生产环境默认需要用户确认
3. **回滚计划**：准备好数据库恢复方案

### 访问控制
```bash
# 限制脚本执行权限
chmod 750 ./scripts/cleanup-expired-trial-keys.sh
chown root:quota-admin ./scripts/cleanup-expired-trial-keys.sh
```

## 相关工具

### 数据库管理工具链
- `init-quota-db.sh` - 数据库初始化
- `verify-quota-db.sh` - 数据库验证
- `backup-quota-db.sh` - 数据库备份
- `restore-quota-db.sh` - 数据库恢复
- `migrate-quota-db.sh` - 数据库迁移

### 运维监控工具链
- `check-quota-proxy-health.sh` - 健康检查
- `monitor-quota-proxy.sh` - 状态监控
- `verify-quota-proxy-config.sh` - 配置验证

### 接口测试工具链
- `test-post-admin-keys.sh` - POST /admin/keys接口测试
- `test-quota-proxy-admin-keys-usage.sh` - 管理接口测试

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持过期keys检测和清理
- 支持模拟运行和交互确认
- 提供详细统计和报告功能

## 支持与反馈

如有问题或建议，请：
1. 查看详细文档：`./scripts/cleanup-expired-trial-keys.sh --help`
2. 检查故障排除章节
3. 提交Issue到项目仓库

---

**注意**：本脚本是quota-proxy工具链的一部分，建议与其他工具配合使用以获得最佳效果。