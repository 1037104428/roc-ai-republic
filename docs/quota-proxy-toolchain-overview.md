# Quota-Proxy 工具链概览

本文档提供 quota-proxy 相关工具链的完整概览，帮助用户快速了解和使用所有工具。

## 工具链分类

### 1. 数据库管理工具链
提供完整的数据库生命周期管理解决方案。

| 工具 | 功能 | 文档 |
|------|------|------|
| `init-quota-db.sh` | 数据库初始化：创建表结构、索引、触发器 | [quota-db-init.md](../docs/quota-db-init.md) |
| `verify-quota-db.sh` | 数据库验证：完整性检查、表结构验证 | [quota-db-verification.md](../docs/quota-db-verification.md) |
| `backup-quota-db.sh` | 数据库备份：自动化备份、压缩、保留策略 | [quota-db-backup.md](../docs/quota-db-backup.md) |
| `restore-quota-db.sh` | 数据库恢复：备份恢复、完整性验证 | [quota-db-restore.md](../docs/quota-db-restore.md) |
| `migrate-quota-db.sh` | 数据库迁移：版本管理、自动化迁移 | [quota-db-migration.md](../docs/quota-db-migration.md) |

### 2. 配置管理工具链
确保服务配置的正确性和一致性。

| 工具 | 功能 | 文档 |
|------|------|------|
| `verify-quota-proxy-config.sh` | 环境变量验证：必需/可选变量检查 | [quota-proxy-config-verification.md](../docs/quota-proxy-config-verification.md) |

### 3. 部署运维工具链
提供部署和运维的完整解决方案。

| 工具 | 功能 | 文档 |
|------|------|------|
| `verify-quota-proxy-deployment.sh` | 部署验证：容器状态、API健康、数据库文件 | [quota-proxy-deployment-verification.md](../docs/quota-proxy-deployment-verification.md) |
| `check-quota-proxy-health.sh` | 健康检查：容器状态、API端点、数据库连接 | [quota-proxy-health-check.md](../docs/quota-proxy-health-check.md) |

### 4. 接口测试工具链
确保核心接口的可靠性和正确性。

| 工具 | 功能 | 文档 |
|------|------|------|
| `test-quota-proxy-admin-keys-usage.sh` | 管理接口测试：POST /admin/keys + GET /admin/usage | [quota-proxy-admin-keys-usage-test.md](../docs/quota-proxy-admin-keys-usage-test.md) |

## 使用流程

### 新环境部署流程
1. **数据库初始化**：`./scripts/init-quota-db.sh`
2. **配置验证**：`./scripts/verify-quota-proxy-config.sh`
3. **部署验证**：`./scripts/verify-quota-proxy-deployment.sh`
4. **健康检查**：`./scripts/check-quota-proxy-health.sh`

### 日常运维流程
1. **定期备份**：`./scripts/backup-quota-db.sh`
2. **健康监控**：`./scripts/check-quota-proxy-health.sh`
3. **配置检查**：`./scripts/verify-quota-proxy-config.sh`

### 数据库升级流程
1. **备份当前数据库**：`./scripts/backup-quota-db.sh`
2. **执行迁移**：`./scripts/migrate-quota-db.sh`
3. **验证升级**：`./scripts/verify-quota-db.sh`

## 工具特性

所有工具都具备以下特性：

### 标准化特性
- **彩色输出**：绿色表示成功，红色表示错误，黄色表示警告
- **标准化退出码**：0=成功，1=一般错误，2=配置错误，3=依赖错误
- **详细日志**：支持 `--verbose` 模式获取详细信息
- **安静模式**：支持 `--quiet` 模式仅输出关键信息

### 安全特性
- **模拟运行**：支持 `--dry-run` 或 `--simulate` 模式预览操作
- **交互式确认**：关键操作前请求用户确认
- **事务安全**：数据库操作在事务中执行
- **备份保护**：关键操作前自动创建备份

### 灵活性
- **自定义配置**：支持环境变量或命令行参数覆盖默认配置
- **多种运行模式**：详细/安静/模拟/列表等模式
- **可集成性**：设计用于 CI/CD 流水线集成

## 快速开始

### 查看所有工具帮助
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
for script in scripts/*.sh; do
    echo "=== $(basename $script) ==="
    ./$script --help 2>&1 | head -5
    echo
done
```

### 运行完整验证流程
```bash
# 1. 验证配置
./scripts/verify-quota-proxy-config.sh --verbose

# 2. 验证部署
./scripts/verify-quota-proxy-deployment.sh --verbose

# 3. 检查健康状态
./scripts/check-quota-proxy-health.sh --verbose

# 4. 测试管理接口
./scripts/test-quota-proxy-admin-keys-usage.sh --verbose
```

## 故障排除

### 常见问题
1. **权限问题**：确保脚本有执行权限 `chmod +x scripts/*.sh`
2. **依赖问题**：确保已安装 `bash`, `curl`, `jq` 等工具
3. **环境变量**：设置正确的环境变量或使用配置文件

### 获取帮助
```bash
# 查看具体工具的帮助
./scripts/<tool-name>.sh --help

# 查看详细文档
cat docs/<tool-doc>.md
```

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-02-10 | v1.0.0 | 创建工具链概览文档，整合所有现有工具 |

## 贡献指南

欢迎贡献新工具或改进现有工具：

1. **工具开发**：遵循现有工具的代码风格和模式
2. **文档更新**：同步更新工具文档和本概览文档
3. **测试验证**：确保新工具通过基本功能测试
4. **提交规范**：使用 `feat:` 前缀提交新工具

---

**工具链目标**：为 quota-proxy 提供生产级别的完整工具链支持，确保服务的可靠性、可维护性和可观测性。