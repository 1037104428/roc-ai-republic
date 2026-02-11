# 验证脚本快速索引

本文档提供 quota-proxy 所有验证脚本的快速索引，帮助用户根据需求快速找到合适的验证工具。

## 📋 按功能分类

### 1. 数据库验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `verify-db.js` | 数据库结构完整性验证 | 检查表结构、列定义、索引 |
| `quick-verify-db.sh` | 快速数据库健康检查 | 一键验证数据库文件存在性和基本结构 |
| `init-db.cjs` | 数据库初始化 | 首次部署时创建数据库表 |
| `check-database-health.sh` | 数据库健康监控 | 定期检查数据库状态 |
| `init-db.sql` | SQLite数据库初始化脚本 | 创建完整的数据库表结构和视图 |
| `check-db.sh` | 数据库初始化检查脚本 | 初始化、验证、备份和清理数据库 |
| `DATABASE-INIT-GUIDE.md` | 数据库初始化指南 | 详细的数据库初始化、使用和管理文档 |
| `verify-sqlite-persistence.sh` | SQLite持久化验证脚本 | 验证SQLite持久化功能完整性，检查相关文件和实现 |

### 2. Admin API 验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `quick-start-verify.sh` | Admin API 快速开始验证 | 5分钟上手测试所有Admin API功能 |
| `verify-admin-api.sh` | 完整Admin API验证 | 全面测试所有Admin API端点 |
| `test-batch-keys.sh` | 批量密钥生成测试 | 测试批量生成试用密钥功能 |
| `verify-admin-keys-endpoint.sh` | 密钥端点验证 | 专门测试 `/admin/keys` 相关功能 |
| `server-sqlite-admin.js` | Admin API 服务器 | 完整的SQLite持久化Admin API服务器 |
| `ADMIN-API-GUIDE.md` | Admin API 使用指南 | 详细的Admin API使用、部署和运维文档 |
| `verify-admin-api.sh` | Admin API 验证脚本 | 验证Admin API所有端点的功能完整性 |
| `quick-verify-admin-api.sh` | Admin API快速验证脚本 | 一键验证Admin API所有核心功能，包含自动服务器启动和完整测试流程 |
| `test-admin-api-quick.js` | Admin API快速测试用例 | Node.js测试脚本，快速验证Admin API核心功能，支持模块化导入和独立运行 |

### 3. 部署验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `check-deployment-status.sh` | 部署状态检查 | 检查服务运行状态和健康检查 |
| `verify-full-deployment.sh` | 完整部署验证 | 验证所有部署组件正常运行 |
| `verify-sqlite-persistence.sh` | SQLite持久化验证 | 验证数据库持久化功能 |

### 4. 环境配置验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `verify-env-config.sh` | 环境配置验证 | 检查环境变量配置正确性 |
| `verify-sqlite-config.sh` | SQLite配置验证 | 验证SQLite相关配置 |
| `verify-config.sh` | 配置验证脚本 | 验证必需环境变量、格式、端口可用性、数据库文件和管理员令牌 |
| `verify-env.sh` | 环境变量验证脚本 | 验证必需和可选环境变量，检查格式和完整性 |

### 5. 性能验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `check-admin-performance.sh` | Admin API性能测试 | 测试Admin API响应时间和吞吐量 |
| `verify-admin-usage-pagination.sh` | 分页性能验证 | 验证使用统计分页功能 |

### 6. 文档完整性验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `verify-validation-docs.sh` | 验证文档完整性检查 | 检查核心验证文档的存在性和基本完整性 |
| `verify-validation-docs-enhanced.sh` | 增强版文档完整性检查 | 全面评估验证文档体系完整性，包括引用关系和README集成 |
| `quick-docs-check.sh` | 快速文档完整性检查 | 一键检查所有核心文档的存在性和互引用关系 |
| `QUICK-DOCS-CHECK-GUIDE.md` | 快速文档检查指南 | 提供快速文档检查脚本的详细使用指南和最佳实践 |

### 7. 安装脚本验证
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `verify-install-cn.sh` | 安装脚本完整性验证 | 全面验证 install-cn.sh 脚本的功能和完整性 |
| `quick-verify-install-cn.sh` | 安装脚本快速验证 | 快速检查 install-cn.sh 脚本的基本功能和完整性 |
| `install-cn-script-verification-guide.md` | 安装脚本验证指南 | 提供安装脚本验证的完整指南和最佳实践 |

### 8. 快速命令参考
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `QUICK-VERIFICATION-COMMANDS.md` | 快速验证命令集合文档 | 提供日常运维、故障排查和CI/CD集成的快速命令参考 |
| `CONFIG-VERIFICATION-GUIDE.md` | 配置验证指南 | 提供配置验证脚本的详细使用指南和最佳实践 |

### 8. 项目管理
| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `TODO-TICKETS.md` | 开发任务跟踪系统 | 跟踪项目开发任务、功能需求和改进计划 |

### 9. 部署指南
| 文档 | 功能 | 使用场景 |
|------|------|----------|
| `QUICK-DEPLOY-ADMIN-API.md` | Admin API快速部署指南 | 提供Admin API的快速部署指南，包含一键部署脚本和Docker部署 |

## 🚀 快速开始推荐

### 新用户快速验证
```bash
# 1. 数据库初始化验证
./quick-verify-db.sh

# 2. Admin API快速验证
./quick-start-verify.sh

# 3. 部署状态检查
./check-deployment-status.sh
```

### 开发者完整验证
```bash
# 1. 运行所有验证
./run-all-verifications.sh

# 2. 或按顺序执行
./verify-db.js
./verify-admin-api.sh
./verify-full-deployment.sh
```

## 📊 验证结果解读

### 成功标志
- ✅ 脚本执行完成无错误
- ✅ 输出中包含"验证通过"或"成功"字样
- ✅ HTTP状态码为200/201
- ✅ 数据库查询返回预期数据

### 常见问题排查
1. **数据库连接失败**：检查数据库文件权限和路径
2. **Admin API访问失败**：检查ADMIN_TOKEN配置
3. **服务未运行**：检查Docker容器状态
4. **环境变量缺失**：检查.env文件配置

## 🔄 维护建议

### 定期验证
- **每日**：运行 `quick-verify-db.sh` 和 `check-deployment-status.sh`
- **每周**：运行完整验证套件 `run-all-verifications.sh`
- **部署后**：立即运行 `verify-full-deployment.sh`

### 验证脚本更新
当添加新功能时：
1. 创建对应的验证脚本
2. 更新本文档索引
3. 添加到 `run-all-verifications.sh`

## 📁 相关文档

- [ADMIN-API-EXAMPLES.md](./ADMIN-API-EXAMPLES.md) - Admin API详细示例
- [DATABASE-INIT-GUIDE.md](./DATABASE-INIT-GUIDE.md) - 数据库初始化指南
- [DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md](./DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md) - 部署指南
- [VALIDATION-TOOLS-INDEX.md](./VALIDATION-TOOLS-INDEX.md) - 验证工具详细索引
- [VALIDATION-DECISION-TREE.md](./VALIDATION-DECISION-TREE.md) - 验证脚本选择决策树
- [VALIDATION-EXAMPLES.md](./VALIDATION-EXAMPLES.md) - 验证脚本使用示例
- [ENHANCED-VALIDATION-DOCS-CHECK.md](./ENHANCED-VALIDATION-DOCS-CHECK.md) - 增强版验证文档完整性检查指南
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - 故障排除指南
- [QUICK-VERIFICATION-COMMANDS.md](./QUICK-VERIFICATION-COMMANDS.md) - 快速验证命令集合
- [CONFIG-VERIFICATION-GUIDE.md](./CONFIG-VERIFICATION-GUIDE.md) - 配置验证指南
- [QUICK-DOCS-CHECK-GUIDE.md](./QUICK-DOCS-CHECK-GUIDE.md) - 快速文档检查指南
- [TODO-TICKETS.md](./TODO-TICKETS.md) - 开发任务跟踪系统
- [install-cn-script-verification-guide.md](../docs/install-cn-script-verification-guide.md) - 安装脚本验证指南

---

**最后更新**: 2026-02-12  
**维护者**: 中华AI共和国项目组  
**版本**: 1.0.5