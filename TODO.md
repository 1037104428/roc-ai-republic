# TODO Tickets - 中华AI共和国项目

## 高优先级

### [TODO-001] 服务器SQLite3安装
**状态**: 已完成  
**创建时间**: 2026-02-10 15:13  
**最后更新**: 2026-02-10 15:45  
**描述**: 服务器(8.210.185.194)未安装sqlite3，导致无法进行数据库完整性检查和验证。  
**影响**: 数据库验证脚本无法在服务器上运行，影响监控和维护。  
**解决方案**: 
1. ✅ 创建单独的sqlite3安装脚本 (`scripts/install-sqlite3-on-server.sh`)
2. ✅ 添加安装文档 (`docs/sqlite3-server-installation.md`)
3. ✅ 在部署脚本中添加sqlite3安装步骤 (`scripts/deploy-quota-proxy-sqlite-with-auth.sh`)
4. ✅ 更新验证脚本以处理sqlite3未安装的情况 (`scripts/verify-sqlite-db.sh`)

**相关文件**:
- `scripts/install-sqlite3-on-server.sh` - 自动化安装脚本
- `docs/sqlite3-server-installation.md` - 安装指南
- `scripts/deploy-quota-proxy-sqlite-with-auth.sh` - 待更新
- `scripts/verify-sqlite-db.sh` - 待更新
- `docs/sqlite-db-verification.md` - 相关文档

**验证命令**:
```bash
# 检查当前状态
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "command -v sqlite3"

# 使用自动化脚本安装
./scripts/install-sqlite3-on-server.sh --dry-run  # 模拟运行
./scripts/install-sqlite3-on-server.sh            # 实际安装

# 验证安装结果
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "sqlite3 --version"
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "cd /opt/roc/quota-proxy && sqlite3 data/quota.db '.tables'"
```

**进展**:
- 2026-02-10 15:21: 创建自动化安装脚本和文档
- 下一步: 实际执行安装并验证

### [TODO-002] 数据库定期备份机制
**状态**: 处理中  
**创建时间**: 2026-02-10 15:13  
**最后更新**: 2026-02-10 15:53  
**描述**: 缺少数据库定期备份机制，存在数据丢失风险。  
**影响**: 数据库损坏或服务器故障时无法恢复数据。  
**解决方案**: 
1. ✅ 创建数据库备份脚本 (`scripts/backup-sqlite-db.sh`)
2. 🔄 设置cron定时备份任务 (`scripts/setup-db-backup-cron.sh`)
3. ⏳ 添加备份验证和恢复测试

**相关文件**:
- `scripts/backup-sqlite-db.sh` - 数据库备份脚本
- `scripts/setup-db-backup-cron.sh` - cron设置脚本
- `/opt/roc/quota-proxy/backups/` - 服务器备份目录

**验证命令**:
```bash
# 测试备份脚本
./scripts/backup-sqlite-db.sh --dry-run

# 设置cron任务（需要sudo）
sudo ./scripts/setup-db-backup-cron.sh --dry-run

# 检查现有备份
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "ls -la /opt/roc/quota-proxy/backups/ 2>/dev/null || echo '备份目录不存在'"
```

**进展**:
- 2026-02-10 15:53: 创建数据库备份脚本，支持完整备份、压缩、清理旧备份、生成报告
- 2026-02-10 15:53: 创建cron设置脚本，支持添加/移除定时任务
- 下一步: 实际设置cron任务并测试备份恢复功能

## 中优先级

### [TODO-003] 监控告警集成
**状态**: 待处理  
**创建时间**: 2026-02-10 15:13  
**描述**: 监控脚本缺少告警集成，无法及时通知问题。  
**影响**: 需要手动检查监控状态，无法实时响应问题。  
**解决方案**: 
1. 集成邮件/短信告警
2. 添加Webhook支持
3. 创建告警规则和阈值配置

### [TODO-004] 性能优化
**状态**: 待处理  
**创建时间**: 2026-02-10 15:13  
**描述**: 数据库查询性能需要优化，特别是usage_logs表。  
**影响**: 随着数据量增长，查询性能可能下降。  
**解决方案**: 
1. 添加索引优化
2. 实现数据分区/归档
3. 添加查询缓存

## 低优先级

### [TODO-005] 文档完善
**状态**: 待处理  
**创建时间**: 2026-02-10 15:13  
**描述**: 部分文档需要更新和完善。  
**影响**: 新用户上手难度增加。  
**解决方案**: 
1. 更新部署指南
2. 添加故障排除章节
3. 完善API文档

### [TODO-006] 测试覆盖率提升
**状态**: 待处理  
**创建时间**: 2026-02-10 15:13  
**描述**: 测试覆盖率不足，存在潜在bug风险。  
**影响**: 代码变更可能引入回归问题。  
**解决方案**: 
1. 添加单元测试
2. 集成测试自动化
3. 性能测试套件

---

## 处理流程

1. **创建**: 发现新问题或需求时创建TODO ticket
2. **分配**: 根据优先级分配处理顺序
3. **处理**: 实现解决方案并测试
4. **验证**: 验证解决方案有效性
5. **关闭**: 更新状态为已完成，记录解决详情

## 更新日志

| 日期 | 变更说明 |
|------|----------|
| 2026-02-10 | 初始创建，记录服务器SQLite3安装问题 |
| 2026-02-10 | 添加数据库备份、监控告警、性能优化等ticket |

---

**注意**: 定期审查和更新TODO列表，确保问题得到及时处理。