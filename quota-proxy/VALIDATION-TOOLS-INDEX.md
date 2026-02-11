# 验证工具索引

本文档提供quota-proxy所有验证工具的快速索引，帮助您根据需求选择合适的验证脚本。

## 快速选择指南

### 1. 部署前验证
- **环境配置验证**：`verify-env-config.sh` - 检查必需和可选环境变量
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

### 4. 功能测试
- **试用密钥生成测试**：`test-trial-key-generation.sh` - 完整试用密钥功能测试
- **Admin API性能检查**：`check-admin-performance.sh` - API性能监控

### 5. 数据库工具
- **SQLite数据库初始化**：`init-sqlite-db.sh` - 初始化数据库表结构
- **SQLite数据库备份**：`backup-sqlite-db.sh` - 数据库备份和恢复

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

### 试用密钥生成测试
```bash
./test-trial-key-generation.sh [--dry-run] [--token ADMIN_TOKEN]
```
**用途**：测试试用密钥生成功能
**验证内容**：健康端点、管理员API密钥生成、试用密钥生成、试用密钥可用性
**输出**：功能测试报告、每个步骤的结果

## 使用建议

### 新部署流程
1. 部署前：运行 `verify-env-config.sh` 和 `verify-sqlite-config.sh`
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

## 贡献指南

如果您发现新的验证需求或工具改进建议：
1. 创建新的验证脚本并确保支持 `--dry-run` 模式
2. 更新本文档的相应部分
3. 在进度日志中记录验证工具的添加或改进

---

**提示**：所有验证脚本都支持 `--dry-run` 模式，可以在不实际调用服务的情况下测试脚本逻辑。