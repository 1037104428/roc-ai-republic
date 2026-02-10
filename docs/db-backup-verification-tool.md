# 数据库备份验证工具

## 概述

`verify-db-backup.sh` 是一个用于验证 quota-proxy 数据库备份完整性和可用性的工具。该工具提供全面的备份验证功能，确保数据库备份的可靠性，完善 TODO-002 备份监控环节。

## 功能特性

### 核心功能
1. **服务器连接检查** - 验证与生产服务器的 SSH 连接
2. **备份目录验证** - 检查备份目录是否存在及其内容
3. **数据库文件检查** - 验证主数据库文件的状态
4. **备份文件验证** - 检查备份文件的完整性和可读性
5. **完整性验证** - 验证备份文件的表结构和数据完整性
6. **报告生成** - 生成详细的验证报告

### 运行模式
- **正常模式** - 执行完整的验证流程
- **Dry-run 模式** - 只显示将要执行的操作，不实际执行
- **详细模式** - 显示详细的执行日志
- **安静模式** - 只显示关键信息

## 使用方法

### 基本使用
```bash
# 执行完整验证
./scripts/verify-db-backup.sh

# Dry-run 模式（预览）
./scripts/verify-db-backup.sh --dry-run

# 详细输出
./scripts/verify-db-backup.sh --verbose

# 安静模式
./scripts/verify-db-backup.sh --quiet

# 显示帮助
./scripts/verify-db-backup.sh --help
```

### 验证步骤示例
```bash
# 1. 检查服务器连接
$ ./scripts/verify-db-backup.sh --dry-run
[INFO] 开始数据库备份验证...
[INFO] 服务器: 8.210.185.194
[INFO] 数据库: /opt/roc/quota-proxy/data/quota-proxy.db
[INFO] 备份目录: /opt/roc/quota-proxy/backups
[WARNING] DRY-RUN模式: 只显示将要执行的操作
[INFO] 检查服务器连接...
[VERBOSE] DRY-RUN: 将检查服务器连接: ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 'echo connected'
[INFO] 检查备份目录...
[VERBOSE] DRY-RUN: 将检查备份目录: /opt/roc/quota-proxy/backups
[INFO] 检查备份文件...
[VERBOSE] DRY-RUN: 将列出备份文件
[INFO] 检查数据库文件...
[VERBOSE] DRY-RUN: 将检查数据库文件: /opt/roc/quota-proxy/data/quota-proxy.db
[INFO] 验证备份完整性...
[VERBOSE] DRY-RUN: 将验证最新的备份文件
[INFO] 生成验证报告...
[SUCCESS] 验证报告已保存到: /tmp/db-backup-verification-20260210-185952.txt
```

## 配置说明

### 默认配置
```bash
# 服务器配置
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 路径配置
BACKUP_DIR="/opt/roc/quota-proxy/backups"
DB_FILE="/opt/roc/quota-proxy/data/quota-proxy.db"
```

### 自定义配置
要修改默认配置，可以直接编辑脚本中的变量：
```bash
# 修改服务器IP
SERVER_IP="your-server-ip"

# 修改SSH密钥路径
SSH_KEY="/path/to/your/ssh/key"

# 修改备份目录
BACKUP_DIR="/custom/backup/path"

# 修改数据库文件路径
DB_FILE="/custom/db/path"
```

## 验证流程

### 1. 服务器连接检查
- 使用 SSH 密钥连接服务器
- 验证连接超时设置（8秒）
- 检查连接状态

### 2. 备份目录检查
- 检查备份目录是否存在
- 列出目录中的文件数量
- 验证目录权限

### 3. 备份文件检查
- 查找最新的备份文件（*.db, *.db.backup, *.sqlite）
- 显示文件大小和修改时间
- 按时间排序显示前5个备份文件

### 4. 数据库文件检查
- 检查主数据库文件是否存在
- 获取文件大小
- 验证表结构（通过 sqlite3 .tables 命令）

### 5. 备份完整性验证
- 选择最新的备份文件进行验证
- 验证文件可读性（sqlite3 .schema）
- 检查必要的表结构（api_keys, usage_stats）
- 统计各表的数据行数

### 6. 报告生成
- 生成详细的验证报告
- 保存到临时文件（/tmp/db-backup-verification-*.txt）
- 包含时间戳和验证结果摘要

## 输出示例

### 成功验证
```
[INFO] 开始数据库备份验证...
[INFO] 服务器: 8.210.185.194
[INFO] 数据库: /opt/roc/quota-proxy/data/quota-proxy.db
[INFO] 备份目录: /opt/roc/quota-proxy/backups
[INFO] 检查服务器连接...
[SUCCESS] 服务器连接正常
[INFO] 检查备份目录...
[SUCCESS] 备份目录存在 (/opt/roc/quota-proxy/backups)，包含 3 个文件
[INFO] 检查备份文件...
[SUCCESS] 找到备份文件:
  - /opt/roc/quota-proxy/backups/quota-proxy-20260210-180000.db (512KB, 修改时间: 2026-02-10 18:00:00)
  - /opt/roc/quota-proxy/backups/quota-proxy-20260210-120000.db (480KB, 修改时间: 2026-02-10 12:00:00)
[INFO] 检查数据库文件...
[SUCCESS] 数据库文件存在 (/opt/roc/quota-proxy/data/quota-proxy.db, 1024KB, 2 个表)
[INFO] 验证备份完整性...
[INFO] 验证备份文件: /opt/roc/quota-proxy/backups/quota-proxy-20260210-180000.db
[SUCCESS] 备份文件可读取
[SUCCESS] 备份包含正确的表结构 (api_keys, usage_stats)
[INFO] 备份数据统计:
[INFO]   - api_keys 表: 150 行
[INFO]   - usage_stats 表: 1250 行
[INFO] 生成验证报告...
[SUCCESS] 验证报告已保存到: /tmp/db-backup-verification-20260210-185952.txt
[SUCCESS] 数据库备份验证完成
```

### 验证报告
```
数据库备份验证报告
生成时间: 2026-02-10 18:59:52
服务器: 8.210.185.194

验证结果:
1. 服务器连接: ✓ 正常
2. 备份目录: ✓ 存在
3. 数据库文件: ✓ 存在
4. 备份完整性: ✓ 验证通过

建议:
- 数据库运行正常，建议定期验证备份
```

## 集成与自动化

### 定时任务配置
```bash
# 每天凌晨2点执行验证
0 2 * * * /home/kai/.openclaw/workspace/roc-ai-republic/scripts/verify-db-backup.sh --quiet

# 每周一上午9点执行详细验证
0 9 * * 1 /home/kai/.openclaw/workspace/roc-ai-republic/scripts/verify-db-backup.sh --verbose
```

### CI/CD 集成
```yaml
# GitHub Actions 示例
name: Database Backup Verification
on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨2点
  workflow_dispatch:      # 手动触发

jobs:
  verify-backup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Verify Database Backup
        run: |
          chmod +x ./scripts/verify-db-backup.sh
          ./scripts/verify-db-backup.sh --quiet
```

### 监控告警
```bash
# 验证脚本与监控系统集成
#!/bin/bash
# monitor-db-backup.sh

# 执行验证
./scripts/verify-db-backup.sh --quiet > /tmp/backup-verify.log 2>&1

# 检查退出状态
if [ $? -ne 0 ]; then
  # 发送告警
  echo "数据库备份验证失败" | mail -s "备份验证告警" admin@example.com
  # 或者发送到监控系统
  curl -X POST https://monitor.example.com/alerts \
    -d '{"service":"db-backup","status":"failed","timestamp":"'"$(date -Iseconds)"'"}'
fi
```

## 故障排除

### 常见问题

#### 1. 服务器连接失败
**症状**: `[ERROR] 无法连接到服务器`
**解决方案**:
- 检查 SSH 密钥权限: `chmod 600 ~/.ssh/id_ed25519_roc_server`
- 验证服务器IP是否正确
- 检查网络连接: `ping 8.210.185.194`
- 确认 SSH 服务运行正常

#### 2. 备份目录不存在
**症状**: `[WARNING] 备份目录不存在`
**解决方案**:
- 检查备份目录路径配置
- 确认备份任务是否正常运行
- 手动创建备份目录: `mkdir -p /opt/roc/quota-proxy/backups`

#### 3. 数据库文件不存在
**症状**: `[ERROR] 数据库文件不存在`
**解决方案**:
- 检查数据库文件路径配置
- 确认 quota-proxy 服务是否正常运行
- 检查 Docker 容器状态: `docker compose ps`

#### 4. 备份文件损坏
**症状**: `[ERROR] 备份文件损坏或无法读取`
**解决方案**:
- 检查备份文件的权限
- 验证 SQLite 数据库完整性: `sqlite3 backup.db "PRAGMA integrity_check;"`
- 重新创建备份

### 调试模式
```bash
# 启用详细日志
./scripts/verify-db-backup.sh --verbose

# 检查脚本语法
bash -n ./scripts/verify-db-backup.sh

# 逐步执行（调试模式）
bash -x ./scripts/verify-db-backup.sh --dry-run
```

## 安全考虑

### 访问控制
- 脚本使用 SSH 密钥认证，确保安全的服务器访问
- 建议使用专用服务账户而非 root 账户
- SSH 密钥应设置适当的文件权限（600）

### 数据保护
- 验证过程中不会修改或删除任何数据
- 只读访问数据库和备份文件
- 临时报告文件在 /tmp 目录，系统会自动清理

### 审计跟踪
- 所有验证操作都有日志记录
- 生成的时间戳报告可用于审计
- 建议定期审查验证日志

## 性能优化

### 资源使用
- 脚本设计为轻量级，内存占用小
- 网络连接使用超时控制（8秒）
- 数据库查询优化，避免全表扫描

### 执行时间
- 正常验证: 5-10秒
- 详细模式: 10-15秒
- 受网络延迟和服务器负载影响

## 扩展功能

### 自定义验证规则
可以通过修改脚本添加额外的验证规则：
```bash
# 添加备份时效性检查
check_backup_freshness() {
  local backup_file="$1"
  local max_age_hours=24
  
  # 检查备份文件是否在指定时间内创建
  # ...
}

# 添加备份大小验证
check_backup_size() {
  local backup_file="$1"
  local min_size_kb=100
  
  # 检查备份文件是否达到最小大小
  # ...
}
```

### 多服务器支持
可以扩展脚本以支持多个服务器的验证：
```bash
# 服务器列表
SERVERS=(
  "server1:192.168.1.100:/opt/roc/quota-proxy"
  "server2:192.168.1.101:/opt/roc/quota-proxy"
)

# 遍历所有服务器进行验证
for server in "${SERVERS[@]}"; do
  IFS=':' read -r name ip path <<< "$server"
  echo "验证服务器: $name ($ip)"
  # 执行验证...
done
```

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 基础验证功能：服务器连接、备份目录、数据库文件、备份完整性
- 支持多种运行模式：dry-run、verbose、quiet
- 自动报告生成

## 相关文档

- [数据库备份配置指南](../docs/database-backup-configuration.md)
- [quota-proxy 快速入门](../docs/quota-proxy-quickstart.md)
- [TODO-002 备份监控](../docs/TODO-002-backup-monitoring.md)
- [生产环境部署指南](../docs/production-deployment-guide.md)

---

**维护者**: 中华AI共和国项目组  
**最后更新**: 2026-02-10  
**状态**: 生产就绪 ✅