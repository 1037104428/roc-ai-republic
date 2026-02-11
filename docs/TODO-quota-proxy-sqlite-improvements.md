# TODO: Quota-Proxy SQLite 持久化改进清单

**创建时间**: 2026-02-10 00:21:53 CST  
**优先级**: 中等  
**状态**: 待处理  
**负责人**: 阿爪推进循环

## 背景
当前 quota-proxy 已具备基础 SQLite 数据库功能，但需要进一步完善持久化、管理接口和验证机制，以支持生产环境使用。

## 待办事项清单

### 1. SQLite 数据库持久化增强 ✅ 部分完成
- [x] 基础数据库连接和表结构 (server-sqlite.js)
- [x] 数据库连接池优化（防止连接泄漏） - 2026-02-10 01:40:00 CST 创建优化指南
- [x] 数据库备份和恢复机制 - 2026-02-10 01:52:00 CST 创建验证脚本和指南
- [x] 数据库迁移脚本（版本管理）
- [x] 数据库性能监控（查询耗时统计） - 2026-02-10 02:14 CST 完成，包含性能监控中间件和验证脚本

### 2. Admin API 端点完善 ✅ 部分完成
- [x] `POST /admin/keys` - 生成试用密钥
- [x] `GET /admin/usage` - 查看使用情况
- [x] `DELETE /admin/keys/:key` - 删除密钥 (2026-02-10 02:03 完成，包含验证脚本)
- [x] `PUT /admin/keys/:key` - 更新密钥标签 (2026-02-10 09:50 完成，包含验证脚本)
- [x] `GET /admin/keys` - 列出所有密钥 (2026-02-10 01:54)
- [x] `POST /admin/reset-usage` - 重置使用统计 (2026-02-10 10:06 完成，包含验证脚本)

### 3. 安全性增强
- [x] ADMIN_TOKEN 基础验证
- [x] 请求频率限制（防止暴力破解） - 已完成于 2026-02-10 01:11:02 CST
- [x] IP 白名单支持 - 2026-02-10 10:30 CST 完成，包含中间件和验证脚本
- [x] 操作日志记录（谁在何时做了什么） - 2026-02-10 10:41 CST 完成，包含中间件、API端点和验证脚本
- [x] 密钥过期时间支持 - 2026-02-10 11:18 CST 完成，包含API增强和验证脚本

### 4. 验证和测试
- [ ] 单元测试覆盖核心功能
- [x] 集成测试（完整 API 流程） - 2026-02-10 23:21:00 CST 完成，创建完整API流程集成测试脚本和文档
- [x] 压力测试（高并发场景） - 2026-02-11 09:05 CST 完成，创建压力测试脚本和指南
- [x] 数据库恢复测试 - 2026-02-11 09:53 CST 完成，创建数据库恢复测试脚本，支持备份、恢复和损坏恢复测试
- [ ] 安全渗透测试（基础）

### 5. 部署和运维
- [ ] Docker 容器数据卷持久化配置
- [ ] 数据库自动备份脚本
- [ ] 健康检查端点增强（包含数据库状态）
- [ ] 监控指标导出（Prometheus 格式）
- [ ] 日志结构化（JSON 格式）

## 实施优先级
1. **高优先级**: 数据库连接池优化、操作日志记录
2. **中优先级**: 完整 Admin API 端点、安全性增强
3. **低优先级**: 高级监控、压力测试

## 验证命令
```bash
# 检查当前数据库状态
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && sqlite3 /data/quota.db ".tables"'

# 测试 Admin API 端点
ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d
curl -H "Authorization: Bearer $ADMIN_TOKEN" http://8.210.185.194:8787/admin/usage
curl -X POST -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"label":"测试密钥"}' http://8.210.185.194:8787/admin/keys

# 检查容器状态
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose ps'

# 数据库恢复测试
chmod +x ./scripts/test-database-recovery.sh
./scripts/test-database-recovery.sh --help
./scripts/test-database-recovery.sh --dry-run --verbose
```

## 相关文件
- `quota-proxy/server-sqlite.js` - 主服务器文件
- `quota-proxy/server-better-sqlite.js` - 优化版本
- `scripts/check-admin-api-status.sh` - Admin API 验证脚本
- `scripts/test-admin-api-basic.sh` - 基础测试脚本
- `docs/admin-api-quick-guide.md` - API 使用指南

## 更新记录
- 2026-02-10 00:21:53 - 创建 TODO 清单，记录当前状态和待办事项