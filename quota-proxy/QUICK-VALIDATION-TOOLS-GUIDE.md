# 快速验证工具指南

本指南提供所有验证工具的快速使用方法和索引，帮助用户快速找到和使用合适的验证工具。

## 📋 工具分类索引

### 1. Admin API 验证工具
- **快速验证 Admin API**: `./quick-verify-admin-api.sh`
  - 用途：快速验证 Admin API 基本功能
  - 命令：`./quick-verify-admin-api.sh`
  
- **Admin 密钥生成和用量测试**: `./test-admin-keys-usage.sh`
  - 用途：测试 POST /admin/keys 和 GET /admin/usage 端点
  - 命令：`./test-admin-keys-usage.sh`
  
- **Admin 应用端点验证**: `./verify-admin-applications-endpoint.sh`
  - 用途：验证 Admin 应用管理端点
  - 命令：`./verify-admin-applications-endpoint.sh`
  
- **Admin 密钥端点验证**: `./verify-admin-keys-endpoint.sh`
  - 用途：验证 Admin 密钥管理端点
  - 命令：`./verify-admin-keys-endpoint.sh`

### 2. 数据库验证工具
- **SQLite 数据库初始化**: `./init-sqlite-db.sh`
  - 用途：初始化 SQLite 数据库
  - 命令：`./init-sqlite-db.sh`
  
- **数据库健康检查**: `./check-database-health.sh`
  - 用途：检查数据库连接和表结构
  - 命令：`./check-database-health.sh`
  
- **快速 SQLite 健康检查**: `./quick-sqlite-health-check.sh`
  - 用途：快速检查 SQLite 数据库状态
  - 命令：`./quick-sqlite-health-check.sh`

### 3. 环境验证工具
- **环境变量验证**: `./verify-env.sh`
  - 用途：验证环境变量配置
  - 命令：`./verify-env.sh`
  
- **环境示例文件验证**: `./verify-env-example.sh`
  - 用途：验证 .env.example 文件完整性
  - 命令：`./verify-env-example.sh`

### 4. 部署验证工具
- **部署状态检查**: `./check-deployment-status.sh`
  - 用途：检查 Docker 部署状态
  - 命令：`./check-deployment-status.sh`
  
- **部署验证**: `./deployment-verification.sh`
  - 用途：全面验证部署状态
  - 命令：`./deployment-verification.sh`

### 5. 监控验证工具
- **Prometheus 监控验证**: `./verify-prometheus-metrics.sh`
  - 用途：验证 Prometheus 监控指标
  - 命令：`./verify-prometheus-metrics.sh`
  
- **Prometheus 监控快速验证**: `./quick-verify-prometheus-monitoring.sh`
  - 用途：快速验证 Prometheus 监控集成
  - 命令：`./quick-verify-prometheus-monitoring.sh`

### 6. 文档验证工具
- **文档规范化检查**: `./document-normalization-check.sh`
  - 用途：检查文档规范化
  - 命令：`./document-normalization-check.sh`
  
- **验证文档增强检查**: `./verify-validation-docs-enhanced.sh`
  - 用途：增强版文档完整性检查
  - 命令：`./verify-validation-docs-enhanced.sh`

### 7. 性能验证工具
- **Admin 性能检查**: `./check-admin-performance.sh`
  - 用途：检查 Admin API 性能
  - 命令：`./check-admin-performance.sh`

### 8. 批量操作工具
- **批量密钥测试**: `./test-batch-keys.sh`
  - 用途：批量测试密钥生成
  - 命令：`./test-batch-keys.sh`

## 🚀 快速开始

### 场景 1：初次部署验证
```bash
# 1. 检查环境变量
./verify-env.sh

# 2. 初始化数据库
./init-sqlite-db.sh

# 3. 检查部署状态
./check-deployment-status.sh

# 4. 验证 Admin API
./quick-verify-admin-api.sh
```

### 场景 2：日常健康检查
```bash
# 1. 数据库健康检查
./check-database-health.sh

# 2. 部署状态检查
./deployment-verification.sh

# 3. 监控指标验证
./verify-prometheus-metrics.sh
```

### 场景 3：Admin API 测试
```bash
# 1. 测试密钥生成和用量
./test-admin-keys-usage.sh

# 2. 测试应用管理
./verify-admin-applications-endpoint.sh

# 3. 测试密钥管理
./verify-admin-keys-endpoint.sh
```

## 📊 验证报告

所有验证工具都会生成详细的验证报告，包括：
- ✅ 通过的项目
- ⚠️ 警告的项目
- ❌ 失败的项目
- 📋 建议的修复步骤

## 🔧 故障排除

### 常见问题 1：权限不足
```bash
# 为所有脚本添加执行权限
chmod +x *.sh
```

### 常见问题 2：环境变量未设置
```bash
# 复制环境示例文件
cp .env.example .env

# 编辑环境变量
nano .env
```

### 常见问题 3：数据库连接失败
```bash
# 检查数据库文件权限
ls -la quota-proxy.db

# 重新初始化数据库
./init-sqlite-db.sh
```

## 📁 文件结构

```
quota-proxy/
├── QUICK-VALIDATION-TOOLS-GUIDE.md    # 本指南
├── VALIDATION-QUICK-INDEX.md          # 快速索引
├── verify-validation-docs-enhanced.sh # 增强版检查脚本
├── quick-verify-admin-api.sh          # Admin API 快速验证
├── test-admin-keys-usage.sh           # Admin 密钥测试
├── verify-admin-applications-endpoint.sh # 应用端点验证
├── verify-admin-keys-endpoint.sh      # 密钥端点验证
├── init-sqlite-db.sh                  # 数据库初始化
├── check-database-health.sh           # 数据库健康检查
├── verify-env.sh                      # 环境变量验证
├── check-deployment-status.sh         # 部署状态检查
├── verify-prometheus-metrics.sh       # 监控指标验证
└── ... (其他验证工具)
```

## 🔄 更新和维护

### 添加新工具
1. 创建新的验证脚本
2. 更新 `VALIDATION-QUICK-INDEX.md`
3. 更新 `verify-validation-docs-enhanced.sh`
4. 更新本指南的相关章节

### 验证工具链完整性
```bash
# 运行增强版检查脚本
./verify-validation-docs-enhanced.sh

# 检查快速索引
grep -n "工具名称" VALIDATION-QUICK-INDEX.md
```

## 📞 支持

如果遇到问题：
1. 查看具体工具的详细文档
2. 检查 `VALIDATION-QUICK-INDEX.md` 中的分类
3. 运行 `./verify-validation-docs-enhanced.sh` 检查完整性
4. 参考相关工具的 `*-usage.md` 文档

---

**最后更新**: 2026-02-12  
**版本**: 1.0  
**维护者**: 中华AI共和国项目组