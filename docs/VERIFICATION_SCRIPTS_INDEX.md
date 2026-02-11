# 验证脚本索引

本文档提供中华AI共和国/OpenClaw小白中文包项目中所有验证脚本的快速索引，方便用户快速查找和使用。

## 快速查找表

| 类别 | 脚本名称 | 功能描述 | 使用命令 |
|------|----------|----------|----------|
| **安装验证** | `verify-install-cn-environment.sh` | 验证安装脚本环境兼容性 | `./scripts/verify-install-cn-environment.sh` |
| | `verify-install-cn-execution-modes.sh` | 验证安装脚本执行模式 | `./scripts/verify-install-cn-execution-modes.sh` |
| | `verify-install-cn-features.sh` | 验证安装脚本功能特性 | `./scripts/verify-install-cn-features.sh` |
| | `verify-install-cn.sh` | 验证安装脚本基本功能 | `./scripts/verify-install-cn.sh` |
| **quota-proxy验证** | `verify-admin-keys-usage.sh` | 验证管理密钥和使用统计端点 | `./quota-proxy/verify-admin-keys-usage.sh` |
| | `verify-admin-comprehensive.sh` | 验证管理API全面功能 | `./scripts/verify-admin-comprehensive.sh` |
| | `verify-admin-endpoints.sh` | 验证管理端点 | `./scripts/verify-admin-endpoints.sh` |
| | `verify-quota-proxy-deployment.sh` | 验证quota-proxy部署 | `./scripts/verify-quota-proxy-deployment.sh` |
| | `verify-quota-proxy-config.sh` | 验证quota-proxy配置 | `./scripts/verify-quota-proxy-config.sh` |
| | `verify-quota-proxy-persistent.sh` | 验证持久化部署 | `./scripts/verify-quota-proxy-persistent.sh` |
| **SQLite验证** | `verify-sqlite-example.sh` | 验证SQLite示例脚本 | `./quota-proxy/verify-sqlite-example.sh` |
| | `verify-sqlite-persistence.sh` | 验证SQLite持久化 | `./scripts/verify-sqlite-persistence.sh` |
| | `verify-sqlite-deployment.sh` | 验证SQLite部署 | `./scripts/verify-sqlite-deployment.sh` |
| | `verify-sqlite-quick-simple.sh` | 快速验证SQLite示例 | `./quota-proxy/verify-sqlite-quick-simple.sh` |
| **部署验证** | `verify-quick-deployment-guide.sh` | 验证快速部署指南 | `./quota-proxy/verify-quick-deployment-guide.sh` |
| | `verify-caddy-deployment.sh` | 验证Caddy部署 | `./scripts/verify-caddy-deployment.sh` |
| | `verify-site-deployment.sh` | 验证站点部署 | `./scripts/verify-site-deployment.sh` |
| | `verify-landing-deployment.sh` | 验证落地页部署 | `./scripts/verify-landing-deployment.sh` |
| **配置验证** | `verify-env-example.sh` | 验证环境变量配置文件 | `./quota-proxy/verify-env-example.sh` |
| | `verify-admin-env.sh` | 验证管理环境配置 | `./scripts/verify-admin-env.sh` |
| | `verify-node-env.sh` | 验证Node环境配置 | `./scripts/verify-node-env.sh` |
| **数据库验证** | `verify-db-performance-benchmark.sh` | 验证数据库性能基准测试 | `./scripts/verify-db-performance-benchmark.sh` |
| | `verify-db-backup-restore.sh` | 验证数据库备份恢复 | `./scripts/verify-db-backup-restore.sh` |
| | `verify-backup-sqlite-db.sh` | 验证SQLite数据库备份 | `./scripts/verify-backup-sqlite-db.sh` |
| | `verify-quota-db.sh` | 验证配额数据库 | `./scripts/verify-quota-db.sh` |
| **健康检查** | `verify-health-check-integration.sh` | 验证健康检查集成 | `./scripts/verify-health-check-integration.sh` |
| | `verify-admin-health-quick.sh` | 快速验证管理健康状态 | `./scripts/verify-admin-health-quick.sh` |
| | `verify-quota-proxy.sh` | 验证quota-proxy健康状态 | `./scripts/verify-quota-proxy.sh` |
| **快速验证** | `quick-test-basic.sh` | 快速基本功能测试 | `./quota-proxy/quick-test-basic.sh` |
| | `verify-all-quick.sh` | 快速验证所有核心服务 | `./scripts/verify-all-quick.sh` |
| | `verify-quick-config.sh` | 快速验证配置 | `./scripts/verify-quick-config.sh` |
| | `verify-quickstart.sh` | 快速验证快速开始 | `./scripts/verify-quickstart.sh` |
| **综合验证** | `verify-all-core-services.sh` | 验证所有核心服务 | `./scripts/verify-all-core-services.sh` |
| | `verify-full-deployment.sh` | 验证完整部署 | `./scripts/verify-full-deployment.sh` |
| | `verify-roc-full.sh` | 验证完整ROC系统 | `./scripts/verify-roc-full.sh` |
| | `verify-site-full-functionality.sh` | 验证站点完整功能 | `./scripts/verify-site-full-functionality.sh` |

## 使用建议

### 1. 新用户快速开始
```bash
# 1. 验证安装环境
./scripts/verify-install-cn-environment.sh --quick

# 2. 快速验证基本功能
./quota-proxy/quick-test-basic.sh

# 3. 验证快速部署指南
./quota-proxy/verify-quick-deployment-guide.sh --quick
```

### 2. 开发者全面验证
```bash
# 1. 验证所有核心服务
./scripts/verify-all-core-services.sh

# 2. 验证完整部署
./scripts/verify-full-deployment.sh

# 3. 验证数据库性能
./scripts/verify-db-performance-benchmark.sh
```

### 3. 运维人员监控验证
```bash
# 1. 验证健康检查
./scripts/verify-health-check-integration.sh

# 2. 验证数据库备份恢复
./scripts/verify-db-backup-restore.sh

# 3. 验证quota-proxy配置
./scripts/verify-quota-proxy-config.sh
```

## 脚本特点

### 标准化输出
所有验证脚本遵循统一的输出格式：
- ✅ 绿色表示成功
- ❌ 红色表示失败
- ℹ️ 蓝色表示信息
- ⚠️ 黄色表示警告

### 干运行模式
大多数脚本支持 `--dry-run` 或 `--quick` 参数，用于快速验证而不执行实际操作。

### 详细日志
所有脚本提供详细的执行日志，便于问题排查。

## 维护说明

### 添加新验证脚本
1. 在 `scripts/` 目录下创建新的验证脚本
2. 遵循现有的命名约定：`verify-<功能>-<描述>.sh`
3. 添加标准化输出函数
4. 更新本索引文档

### 更新索引
当添加新的验证脚本时，请更新本索引文档：
1. 在相应类别下添加新行
2. 提供脚本名称、功能描述和使用命令
3. 如有需要，添加新的类别

## 相关文档

- [快速部署指南](./quota-proxy/QUICK_DEPLOYMENT_GUIDE.md)
- [环境配置指南](./quota-proxy/ENV_CONFIGURATION_GUIDE.md)
- [快速基本功能测试](./quota-proxy/QUICK_TEST_BASIC.md)
- [管理密钥和使用统计验证](./quota-proxy/VERIFY_ADMIN_KEYS_USAGE.md)
- [SQLite示例快速验证](./quota-proxy/VERIFY_SQLITE_EXAMPLE_QUICK.md)

## 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0.0 | 2026-02-11 | 初始版本，包含60+验证脚本索引 |
| 1.0.1 | 2026-02-11 | 添加使用建议和维护说明 |

---

**提示**：使用 `grep -r "verify-" scripts/` 查找所有验证脚本，或使用 `find scripts/ -name "verify-*.sh" | sort` 按字母顺序列出。