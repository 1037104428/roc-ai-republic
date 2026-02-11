# 验证工具索引

本文档提供quota-proxy所有验证工具的快速索引，帮助您根据需求选择合适的验证脚本。

## 快速选择指南

### 1. 部署前验证
- **环境配置验证**：`verify-env-config.sh` - 检查必需和可选环境变量
- **环境变量验证**：`verify-env-vars.sh` - 验证关键环境变量配置
- **SQLite配置验证**：`verify-sqlite-config.sh` - 验证数据库配置和连接
- **安装兼容性验证**：`../scripts/verify-install-compatibility.sh` - 验证OpenClaw安装完整性

### 2. 部署后验证
- **快速健康检查**：`quick-health-check.sh` - 基础健康状态检查（最快）
- **部署完整性验证**：`deploy-verification.sh` - 完整部署验证
- **SQLite持久化部署验证**：`verify-sqlite-persistence-deployment.sh` - 完整SQLite部署验证

### 3. API端点验证
- **Admin Keys API端点**：`verify-admin-keys-endpoints.sh` - 验证密钥管理API
- **Admin API完整性**：`verify-admin-api-complete.sh` - 验证所有管理API端点
- **管理员应用列表**：`verify-admin-applications-endpoint.sh` - 验证应用管理API
- **试用密钥生成API**：`verify-trial-key-availability.sh` - 验证试用密钥功能
- **Admin API完整功能验证**：`verify-admin-api-complete.sh` - 验证POST /admin/keys和GET /admin/usage端点的完整功能

### 4. 功能测试
- **试用密钥生成测试**：`test-trial-key-generation.sh` - 完整试用密钥功能测试
- **Admin API性能检查**：`check-admin-performance.sh` - API性能监控
- **Admin API快速测试**：`quick-admin-api-test.sh` - 一键测试Admin API所有核心功能
- **Admin API自动化测试套件**：`test-admin-api.sh` - 完整的Admin API自动化测试，支持健康检查、认证、Keys管理、Usage统计、错误处理等完整测试

### 5. 数据库工具
- **SQLite数据库初始化**：`init-sqlite-db.sh` - 初始化数据库表结构
- **SQLite数据库备份**：`backup-sqlite-db.sh` - 数据库备份和恢复
- **SQLite数据库完整性验证**：`verify-sqlite-integrity.sh` - 验证数据库完整性、一致性和基本功能
- **SQLite数据库健康检查**：`check-database-health.sh` - 检查数据库连接和表结构健康状态

### 6. 维护工具
- **验证脚本备份清理**：`cleanup-validation-backups.sh` - 清理验证工具脚本的备份文件，保持仓库整洁

### 7. 安装验证工具
- **安装失败恢复脚本**：`../scripts/install-cn-fallback-recovery.sh` - 安装失败时的清理、诊断和重试功能
- **安装失败恢复指南**：`../docs/install-cn-fallback-recovery-guide.md` - 详细的安装故障排除指南
- **安装自检脚本**：`../scripts/install-cn-self-check.sh` - 安装完成后自动验证安装是否成功，包括版本验证、功能测试和兼容性检查
  - **快速验证模式**：`./install-cn-self-check.sh --quick` - 仅检查核心功能（命令存在性、版本、帮助）
  - **完整验证模式**：`./install-cn-self-check.sh --full` - 完整功能验证（默认模式）
  - **版本验证模式**：`./install-cn-self-check.sh --version <version>` - 验证特定版本

### 7. 测试环境配置
- **Admin API测试环境配置指南**：`ADMIN-API-TEST-ENV-SETUP.md` - Admin API测试环境的快速配置指南，包含环境变量设置、服务启动、测试脚本使用和故障排除
- **Admin API快速测试示例**：`ADMIN-API-QUICK-TEST-EXAMPLES.md` - Admin API的快速测试示例，包含curl命令一键测试所有核心功能

### 8. 日志增强工具
- **JSON格式日志增强验证**：`verify-json-logger-enhanced.sh` - 验证JSON格式日志增强功能，包括日志级别控制、结构化日志输出等
- **日志级别控制指南**：`LOG-LEVEL-CONTROL.md` - 日志级别控制系统指南，包含日志级别定义、配置方法和使用示例
- **结构化日志示例**：`STRUCTURED-LOG-EXAMPLES.md` - 结构化日志示例文档，展示不同场景下的日志格式和最佳实践

## 快速使用示例

### 场景1：新部署环境快速验证
```bash
# 1. 验证环境配置
./verify-env-config.sh --env-file .env.example

# 2. 验证SQLite配置（如果使用持久化）
./verify-sqlite-config.sh --dry-run

# 3. 部署后快速健康检查
./quick-health-check.sh --url http://localhost:8787

# 4. 完整部署验证
./deploy-verification.sh --token $ADMIN_TOKEN
```

### 场景2：日常监控和故障排查
```bash
# 1. 快速健康状态检查（最快）
./quick-health-check.sh

# 2. 验证试用密钥功能是否正常
./verify-trial-key-availability.sh --token $ADMIN_TOKEN

# 3. 检查API性能
./check-admin-performance.sh --token $ADMIN_TOKEN --timeout 10
```

### 场景3：CI/CD流水线集成
```bash
# 在CI/CD脚本中添加验证步骤
./verify-env-config.sh --env-file .env.production
./deploy-verification.sh --token $DEPLOY_TOKEN --url $SERVICE_URL
./verify-admin-api-complete.sh --token $DEPLOY_TOKEN --url $SERVICE_URL
```

### 场景4：数据库维护
```bash
# 1. 初始化新数据库
./init-sqlite-db.sh --db-path /data/quota.db

# 2. 定期备份数据库
./backup-sqlite-db.sh --db-path /data/quota.db --backup-dir /backups

# 3. 验证数据库配置
./verify-sqlite-config.sh --db-path /data/quota.db
```

## 详细工具说明

### 环境配置验证
```bash
./verify-env-config.sh [--dry-run] [--verbose] [--env-file .env]
```
**用途**：部署前验证环境变量配置
**验证内容**：必需环境变量、可选环境变量、格式验证
**输出**：配置验证报告、建议和错误诊断

### 环境变量验证
```bash
./verify-env-vars.sh [--quick]
```
**用途**：快速验证关键环境变量是否设置
**验证内容**：
- 必需环境变量（ADMIN_TOKEN, DATABASE_URL, PORT）
- 可选环境变量（仅在完整模式下）
**模式**：
- 完整验证：`./verify-env-vars.sh` - 包含必需和可选环境变量检查
- 快速验证：`./verify-env-vars.sh --quick` - 仅检查必需环境变量，适合CI/CD流水线
**输出**：彩色验证报告、通过/警告/失败状态、设置建议

### 快速健康检查
```bash
./quick-health-check.sh [--dry-run] [--url http://localhost:8787]
```
**用途**：部署后快速检查服务状态
**验证内容**：健康端点、状态端点、API密钥基本检查
**输出**：通过/失败状态、错误诊断

### Admin API完整性验证
```bash
./verify-admin-api-complete.sh [--dry-run] [--token ADMIN_TOKEN]
```
**用途**：验证所有管理API端点功能
**验证内容**：8个API端点（健康、状态、密钥、试用、统计、重置、系统、模型）
**输出**：详细验证报告、每个端点的测试结果

### SQLite持久化部署验证
```bash
./verify-sqlite-persistence-deployment.sh [--dry-run] [--token ADMIN_TOKEN]
```
**用途**：验证完整SQLite持久化部署
**验证内容**：8个验证类别（环境、数据库、服务器、核心API、试用密钥、使用统计、文档、脚本）
**输出**：完整部署验证报告、每个类别的详细结果

### SQLite数据库完整性验证
```bash
./verify-sqlite-integrity.sh
```
**用途**：验证SQLite数据库文件的完整性、一致性和基本功能
**验证内容**：
- 数据库文件存在性和权限
- SQLite文件头有效性
- 数据库完整性检查（PRAGMA integrity_check）
- 表结构和数量
- 示例数据查询
**输出**：彩色验证报告、数据库文件统计、修复建议
**特点**：支持多个数据库文件批量验证，提供详细的修复指导

### Admin API自动化测试套件
```bash
./test-admin-api.sh [--verbose] [--url URL] [--token TOKEN] [--timeout SECONDS]
```
**用途**：完整的Admin API自动化测试，支持所有API端点的功能测试和集成测试
**验证内容**：
- 健康检查端点验证
- Admin API认证验证（有效/无效令牌）
- Admin Keys管理（创建、获取、更新、删除）
- Admin Usage统计查询
- 错误处理（无效端点、无效JSON、缺失字段）
**输出**：彩色测试报告、详细的测试结果汇总、通过率统计
**特点**：支持命令行参数和环境变量配置，提供详细的错误诊断，支持测试环境自动清理

### 试用密钥生成测试
```bash
./test-trial-key-generation.sh [--dry-run] [--token ADMIN_TOKEN]
```
**用途**：测试试用密钥生成功能
**验证内容**：健康端点、管理员API密钥生成、试用密钥生成、试用密钥可用性
**输出**：功能测试报告、每个步骤的结果

## 使用建议

### 新部署流程
1. 部署前：运行 `verify-env-vars.sh` 快速检查环境变量，然后运行 `verify-env-config.sh` 和 `verify-sqlite-config.sh`
2. 部署后：运行 `quick-health-check.sh` 确认服务启动
3. 功能验证：运行 `verify-admin-api-complete.sh` 验证所有API

### 日常监控
- 定时任务：使用 `quick-health-check.sh` 进行周期性健康检查
- 性能监控：使用 `check-admin-performance.sh` 监控API响应时间
- 数据备份：使用 `backup-sqlite-db.sh` 定期备份数据库

### 故障排查
1. 快速诊断：`quick-health-check.sh` 确认基础服务状态
2. 详细诊断：`verify-admin-api-complete.sh` 检查具体API问题
3. 环境检查：`verify-env-config.sh` 验证配置是否正确

## CI/CD集成示例

### GitHub Actions
```yaml
name: Validate Quota-Proxy Deployment
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Validate Environment
        run: ./quota-proxy/verify-env-config.sh --dry-run
      - name: Validate SQLite Config
        run: ./quota-proxy/verify-sqlite-config.sh --dry-run
      - name: Validate Admin API
        run: ./quota-proxy/verify-admin-api-complete.sh --dry-run --token "test-token"
```

### 本地开发验证
```bash
# 一键验证所有配置
./quota-proxy/verify-env-config.sh --dry-run && \
./quota-proxy/verify-sqlite-config.sh --dry-run && \
./quota-proxy/verify-admin-api-complete.sh --dry-run --token "test-token"
```

## 相关文档

- [部署指南 - SQLite持久化](DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md)
- [Admin API调用示例](ADMIN-API-EXAMPLES.md)
- [环境变量配置验证指南](VERIFY-ENV-CONFIG.md)
- [SQLite配置验证指南](VERIFY-SQLITE-CONFIG.md)
- [Admin API完整性验证指南](VERIFY_ADMIN_API_COMPLETE.md)

## 更新日志

- **2026-02-11**：创建验证工具索引文档，整理所有验证工具
- **2026-02-11**：添加快速选择指南和使用建议
- **2026-02-11**：提供CI/CD集成示例和故障排查流程
- **2026-02-12**：添加环境变量验证脚本 `verify-env-vars.sh`
- **2026-02-12**：添加Admin API自动化测试套件 `test-admin-api.sh`

## 贡献指南

如果您发现新的验证需求或工具改进建议：
1. 创建新的验证脚本并确保支持 `--dry-run` 模式
2. 更新本文档的相应部分
3. 在进度日志中记录验证工具的添加或改进

---

**提示**：所有验证脚本都支持 `--dry-run` 模式，可以在不实际调用服务的情况下测试脚本逻辑。
## 安装失败恢复工具

### install-cn-fallback-recovery.sh
**位置**: `scripts/install-cn-fallback-recovery.sh`
**用途**: OpenClaw CN 安装失败恢复工具，提供清理、诊断和重试功能
**功能**:
- 清理失败的安装残留
- 诊断安装环境问题
- 多层重试策略（国内镜像优先）
- 网络连通性测试
- 磁盘空间检查
**使用**: `bash install-cn-fallback-recovery.sh [--cleanup | --retry | --diagnose]`
**文档**: [安装失败恢复指南](../docs/install-cn-fallback-recovery-guide.md)

### install-cn-fallback-recovery-guide.md
**位置**: `docs/install-cn-fallback-recovery-guide.md`
**用途**: 安装失败恢复工具的详细使用指南
**内容**:
- 功能特性说明
- 使用场景示例
- 故障排除指南
- 最佳实践建议
- 集成到 CI/CD 的示例
**相关**: `install-cn-fallback-recovery.sh`, `install-cn.sh`

### Web站点部署就绪验证
- [verify-web-deployment-ready.sh](verify-web-deployment-ready.sh) - 验证quota-proxy + landing page部署就绪状态
**用途**: 验证项目是否准备好进行公开部署
**验证内容**:
- quota-proxy核心文件完整性
- 数据库持久化就绪状态
- Admin API功能完整性
- 部署配置就绪状态
- Web站点文件完整性
- HTTPS配置就绪状态
- 安装脚本就绪状态
- 验证工具链完整性
**使用**: `bash verify-web-deployment-ready.sh`
**输出**: 详细的验证报告和下一步行动指南

### 环境变量验证
- [verify-env-vars.sh](verify-env-vars.sh) - 验证quota-proxy关键环境变量是否已正确设置
