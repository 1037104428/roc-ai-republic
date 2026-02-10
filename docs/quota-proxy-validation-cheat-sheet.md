# Quota-Proxy 验证命令速查表

本文档提供 quota-proxy 相关验证命令的快速参考，帮助管理员快速执行常见验证任务。

## 快速验证命令

### 1. 基础健康检查
```bash
# 检查 Docker 容器状态
./scripts/check-quota-proxy-health.sh --quiet

# 检查 API 健康端点
curl -fsS http://localhost:8787/healthz

# 完整健康检查（详细模式）
./scripts/check-quota-proxy-health.sh --verbose
```

### 2. 部署验证
```bash
# 完整部署验证
./scripts/verify-quota-proxy-deployment.sh

# 模拟运行（不实际执行）
./scripts/verify-quota-proxy-deployment.sh --dry-run

# 安静模式（仅输出结果）
./scripts/verify-quota-proxy-deployment.sh --quiet
```

### 3. 数据库验证
```bash
# 数据库完整性验证
./scripts/verify-quota-db.sh

# 列出所有验证检查项
./scripts/verify-quota-db.sh --list

# 备份文件完整性验证
./scripts/verify-backup-integrity.sh

# 备份新鲜度检查（默认24小时）
./scripts/check-backup-freshness.sh
```

### 4. 配置验证
```bash
# 环境变量配置验证
./scripts/verify-quota-proxy-config.sh

# 列出所有配置检查项
./scripts/verify-quota-proxy-config.sh --list

# 模拟运行配置验证
./scripts/verify-quota-proxy-config.sh --dry-run
```

### 5. 接口测试
```bash
# 测试 POST /admin/keys 接口
./scripts/test-post-admin-keys.sh

# 测试 admin keys & usage 接口
./scripts/test-quota-proxy-admin-keys-usage.sh

# 模拟运行接口测试
./scripts/test-quota-proxy-admin-keys-usage.sh --dry-run
```

### 6. 监控与状态
```bash
# 实时状态监控（持续运行）
./scripts/monitor-quota-proxy.sh --interval 30

# 单次状态检查
./scripts/monitor-quota-proxy.sh --once

# 查看服务运行时间
./scripts/monitor-quota-proxy.sh --once --quiet
```

### 7. 数据库管理
```bash
# 数据库初始化
./scripts/init-quota-db.sh

# 数据库备份
./scripts/backup-quota-db.sh

# 数据库恢复
./scripts/restore-quota-db.sh --list

# 数据库迁移
./scripts/migrate-quota-db.sh --list

# 清理过期 trial keys
./scripts/cleanup-expired-trial-keys.sh --dry-run
```

### 8. 备份管理
```bash
# 备份 quota-proxy 数据库
./scripts/backup-quota-proxy-db.sh

# 查看备份版本
./scripts/backup-quota-proxy-db.sh --version

# 列出可用备份
./scripts/backup-quota-proxy-db.sh --list
```

## 常用组合命令

### 快速部署验证（5步）
```bash
# 1. 检查容器状态
./scripts/check-quota-proxy-health.sh --quiet

# 2. 验证部署完整性
./scripts/verify-quota-proxy-deployment.sh --quiet

# 3. 验证数据库
./scripts/verify-quota-db.sh --quiet

# 4. 验证配置
./scripts/verify-quota-proxy-config.sh --quiet

# 5. 测试核心接口
./scripts/test-quota-proxy-admin-keys-usage.sh --quiet
```

### 日常运维检查（3步）
```bash
# 1. 健康状态
./scripts/monitor-quota-proxy.sh --once --quiet

# 2. 备份状态
./scripts/check-backup-freshness.sh --max-age-hours 48

# 3. 数据库状态
./scripts/verify-quota-db.sh --quiet
```

### 故障排查流程
```bash
# 1. 基础检查
./scripts/check-quota-proxy-health.sh --verbose

# 2. 部署验证
./scripts/verify-quota-proxy-deployment.sh --verbose

# 3. 配置检查
./scripts/verify-quota-proxy-config.sh --list

# 4. 数据库检查
./scripts/verify-quota-db.sh --verbose
```

## 退出码说明

所有验证脚本使用标准化退出码：

- `0`: 成功，所有检查通过
- `1`: 通用错误
- `2`: 配置错误
- `3`: 依赖项缺失
- `4`: 网络错误
- `5`: 权限错误
- `6`: 文件系统错误
- `7`: 进程/服务错误
- `8`: 数据库错误
- `9`: API/接口错误
- `10`: 验证失败（一个或多个检查未通过）

## 环境变量覆盖

大多数脚本支持环境变量覆盖：

```bash
# 自定义主机和端口
QUOTA_PROXY_HOST=192.168.1.100 \
QUOTA_PROXY_PORT=8787 \
./scripts/check-quota-proxy-health.sh

# 自定义数据库路径
DATABASE_PATH=/custom/path/quota.db \
./scripts/verify-quota-db.sh

# 自定义管理员令牌
ADMIN_TOKEN=custom-token-here \
./scripts/test-post-admin-keys.sh
```

## 故障排除提示

1. **容器未运行**: 使用 `docker compose ps` 检查状态
2. **健康端点不可用**: 检查端口映射和防火墙
3. **数据库连接失败**: 验证数据库文件权限和路径
4. **接口测试失败**: 确认 ADMIN_TOKEN 环境变量设置正确
5. **备份验证失败**: 检查备份文件完整性和权限

## 相关文档

- [工具链概览](../docs/quota-proxy-toolchain-overview.md)
- [快速开始指南](../docs/quota-proxy-quick-start.md)
- [部署验证指南](../docs/quota-proxy-deployment-verification.md)
- [健康检查指南](../docs/quota-proxy-health-check.md)

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
