# SQLite数据库验证指南

本文档介绍如何验证quota-proxy服务的SQLite数据库状态和完整性。

## 概述

quota-proxy使用SQLite数据库存储API密钥和使用日志。定期验证数据库状态对于确保服务可靠性至关重要。

## 验证脚本

我们提供了 `verify-sqlite-db.sh` 脚本用于自动化验证：

```bash
# 基本验证
./scripts/verify-sqlite-db.sh

# 生成详细报告
./scripts/verify-sqlite-db.sh --report

# 仅检查远程服务器
./scripts/verify-sqlite-db.sh --remote
```

## 验证内容

脚本检查以下内容：

### 1. SQLite3安装状态
- 检查本地和远程SQLite3是否安装
- 验证版本兼容性

### 2. 数据库文件状态
- 检查数据库文件是否存在
- 验证文件大小和修改时间
- 确保文件权限正确

### 3. 数据库完整性
- 运行SQLite完整性检查 (`PRAGMA integrity_check`)
- 验证数据库结构完整性

### 4. 表结构检查
- 验证关键表是否存在：`api_keys`, `usage_logs`
- 检查表行数统计
- 验证表结构符合预期

### 5. 远程服务器验证
- 通过SSH连接远程服务器
- 检查远程数据库状态
- 验证远程服务可用性

## 手动验证命令

如果脚本不可用，可以手动运行以下命令：

```bash
# 检查SQLite安装
sqlite3 --version

# 检查数据库文件
ls -la ./data/quota.db
du -h ./data/quota.db

# 检查数据库完整性
sqlite3 ./data/quota.db "PRAGMA integrity_check;"

# 查看表结构
sqlite3 ./data/quota.db ".tables"
sqlite3 ./data/quota.db ".schema api_keys"
sqlite3 ./data/quota.db ".schema usage_logs"

# 查看数据统计
sqlite3 ./data/quota.db "SELECT COUNT(*) FROM api_keys;"
sqlite3 ./data/quota.db "SELECT COUNT(*) FROM usage_logs;"
sqlite3 ./data/quota.db "SELECT * FROM api_keys LIMIT 5;"
```

## 远程服务器验证

对于已部署的服务器：

```bash
# 检查远程SQLite安装
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "command -v sqlite3"

# 检查远程数据库文件
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "ls -la /opt/roc/quota-proxy/data/quota.db"

# 检查远程数据库完整性
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db 'PRAGMA integrity_check;'"

# 查看远程表结构
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db '.tables'"
```

## 验证报告

脚本会生成详细的验证报告，包含：

1. **验证结果摘要** - 关键检查项的通过状态
2. **表结构检查** - 完整的数据库schema
3. **数据统计** - 各表的数据量统计
4. **建议** - 维护和改进建议
5. **验证命令** - 可重复验证的命令

报告保存位置：`/tmp/sqlite-db-verification-report.md`

## 常见问题

### 数据库文件不存在
```
错误：数据库文件不存在: ./data/quota.db
```
**解决方案**：
1. 确保已运行部署脚本：`./scripts/deploy-quota-proxy-sqlite-with-auth.sh`
2. 检查部署日志中的错误信息
3. 手动创建数据库目录：`mkdir -p ./data`

### 数据库完整性检查失败
```
错误：数据库完整性检查失败
```
**解决方案**：
1. 备份当前数据库：`cp ./data/quota.db ./data/quota.db.backup.$(date +%s)`
2. 尝试修复数据库：`sqlite3 ./data/quota.db "VACUUM;"`
3. 如果修复失败，从备份恢复或重新部署

### 远程连接失败
```
错误：SSH连接超时
```
**解决方案**：
1. 检查服务器IP是否正确：`cat /tmp/server.txt`
2. 验证SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
3. 检查网络连接：`ping 8.210.185.194`

## 自动化集成

### 定期验证
建议将数据库验证集成到监控系统中：

```bash
# 每日验证（添加到cron）
0 2 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-sqlite-db.sh >> /var/log/quota-db-verify.log 2>&1

# 验证失败时发送告警
if ! ./scripts/verify-sqlite-db.sh; then
    echo "数据库验证失败" | mail -s "quota-proxy数据库告警" admin@example.com
fi
```

### CI/CD集成
在部署流程中添加数据库验证：

```yaml
# GitHub Actions示例
name: Database Verification
on: [push, pull_request]

jobs:
  verify-db:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Verify SQLite Database
        run: |
          chmod +x ./scripts/verify-sqlite-db.sh
          ./scripts/verify-sqlite-db.sh
```

## 最佳实践

1. **定期验证** - 至少每周运行一次完整验证
2. **备份策略** - 验证前备份数据库
3. **监控告警** - 集成到监控系统，验证失败时告警
4. **版本控制** - 数据库schema变更应记录在版本控制中
5. **测试环境** - 在测试环境验证后再应用到生产

## 相关文档

- [quota-proxy SQLite部署指南](./quota-proxy-sqlite-auth-deployment.md)
- [数据库维护脚本](../scripts/)
- [监控和告警配置](./quota-usage-monitoring.md)

## 更新日志

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-02-10 | 1.0.0 | 初始版本，提供基础验证功能 |
| 2026-02-10 | 1.1.0 | 添加远程服务器验证支持 |
| 2026-02-10 | 1.2.0 | 增强报告生成和自动化集成指南 |

---

**验证是确保服务可靠性的关键步骤。定期运行验证脚本，及时发现并解决数据库问题。**