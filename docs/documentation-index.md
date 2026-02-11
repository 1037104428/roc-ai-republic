# 项目文档索引和导航指南

## 概述
本文档提供中华AI共和国 / OpenClaw 小白中文包项目的完整文档索引和导航指南，帮助用户快速找到所需文档。

## 快速开始
- [README-QUICKSTART.md](../README-QUICKSTART.md) - 5分钟快速开始指南
- [安装脚本快速参考指南](install-cn-quick-reference.md) - 详细安装说明

## 核心功能文档

### 1. 安装部署
- **安装脚本**: `scripts/install-cn.sh` - 主安装脚本
- **验证工具**: `scripts/verify-install-cn.sh` - 安装验证脚本
- **网络测试**: `scripts/install-cn-network-test.sh` - 网络连接测试
- **自检工具**: `scripts/install-cn-self-check.sh` - 安装后自检
- **回退恢复**: `scripts/install-cn-fallback-recovery.sh` - 回退策略

### 2. Quota-Proxy API网关
- **核心服务**: `quota-proxy/server.js` - 主服务文件
- **Admin API**: `quota-proxy/admin-api.js` - 管理接口
- **数据库**: `quota-proxy/database.js` - SQLite数据库管理
- **中间件**: `quota-proxy/middleware/` - 中间件集合
- **速率限制**: `quota-proxy/rate-limit-middleware.js` - 速率限制中间件
- **JSON日志**: `quota-proxy/middleware/json-logger.js` - JSON格式日志

### 3. 验证工具链
- **验证索引**: `quota-proxy/VALIDATION-TOOLS-INDEX.md` - 验证工具完整索引
- **部署就绪**: `quota-proxy/verify-web-deployment-ready.sh` - Web站点部署就绪验证
- **数据库完整性**: `quota-proxy/verify-sqlite-integrity.sh` - SQLite数据库完整性验证
- **Admin API测试**: `quota-proxy/test-admin-api.sh` - Admin API自动化测试
- **验证文档**: `quota-proxy/verify-validation-docs-enhanced.sh` - 验证文档检查

### 4. 部署配置
- **Docker配置**: `quota-proxy/docker-compose.yml` - Docker Compose配置
- **环境变量**: `quota-proxy/.env.example` - 环境变量示例
- **Caddy配置**: `quota-proxy/Caddyfile` - Caddy反向代理配置
- **Nginx配置**: `quota-proxy/nginx.conf` - Nginx配置示例

### 5. 文档指南
- **日志控制**: `quota-proxy/LOG-LEVEL-CONTROL.md` - 日志级别控制指南
- **结构化日志**: `quota-proxy/STRUCTURED-LOG-EXAMPLES.md` - 结构化日志示例
- **性能监控**: `quota-proxy/PERFORMANCE-MONITORING-GUIDE.md` - 性能监控指南
- **数据库维护**: `quota-proxy/DATABASE-MAINTENANCE-GUIDE.md` - 数据库维护指南

## 脚本工具分类

### 安装部署脚本
```
scripts/install-cn.sh                    # 主安装脚本
scripts/install-cn-enhanced.sh           # 增强版安装脚本
scripts/install-cn-self-check.sh         # 自检工具
scripts/install-cn-fallback-recovery.sh  # 回退恢复
scripts/install-cn-network-test.sh       # 网络测试
```

### 验证检查脚本
```
scripts/verify-install-cn.sh             # 安装验证
scripts/verify-install-cn-complete.sh    # 完整验证
scripts/verify-install-cn-enhanced.sh    # 增强验证
scripts/quick-verify-install-cn.sh       # 快速验证
scripts/verify-web-deployment-ready.sh   # 部署就绪验证
```

### 数据库管理脚本
```
scripts/init-sqlite-db.sh                # 数据库初始化
scripts/backup-sqlite-db.sh              # 数据库备份
scripts/restore-quota-db.sh              # 数据库恢复
scripts/migrate-to-sqlite.sh             # 数据库迁移
scripts/verify-sqlite-integrity.sh       # 数据库完整性验证
```

### Admin API管理脚本
```
scripts/admin-quick-keygen.sh            # 快速密钥生成
scripts/admin-trial-key-manager.sh       # 试用密钥管理
scripts/automate-trial-key-generation.sh # 自动化密钥生成
scripts/test-admin-api.sh                # Admin API测试
scripts/verify-admin-api.sh              # Admin API验证
```

### 部署运维脚本
```
scripts/deploy-quota-proxy-persistent.sh # 持久化部署
scripts/deploy-quota-proxy-sqlite.sh     # SQLite部署
scripts/deploy-static-site.sh            # 静态站点部署
scripts/deploy-landing-page.sh           # 落地页部署
scripts/deploy-caddy-static-site.sh      # Caddy静态站点部署
```

### 监控维护脚本
```
scripts/monitor-quota-proxy.sh           # 服务监控
scripts/health-monitor-quota-proxy.sh    # 健康监控
scripts/status-monitor.sh                # 状态监控
scripts/check-quota-proxy-health.sh      # 健康检查
scripts/check-quota-proxy-status.sh      # 状态检查
```

## 使用场景导航

### 场景1: 首次安装
1. 阅读 [README-QUICKSTART.md](../README-QUICKSTART.md)
2. 运行 `scripts/install-cn.sh`
3. 验证安装: `scripts/verify-install-cn.sh`
4. 获取试用密钥: `scripts/admin-quick-keygen.sh`

### 场景2: 部署到服务器
1. 检查部署就绪: `quota-proxy/verify-web-deployment-ready.sh`
2. 部署服务: `scripts/deploy-quota-proxy-persistent.sh`
3. 配置反向代理: 参考 `quota-proxy/Caddyfile`
4. 验证部署: `scripts/verify-quota-proxy-deployment.sh`

### 场景3: 数据库维护
1. 检查数据库完整性: `quota-proxy/verify-sqlite-integrity.sh`
2. 备份数据库: `scripts/backup-sqlite-db.sh`
3. 查看数据库状态: `scripts/check-quota-proxy-status.sh`
4. 恢复数据库: `scripts/restore-quota-db.sh`

### 场景4: Admin API管理
1. 生成试用密钥: `scripts/admin-quick-keygen.sh`
2. 测试API: `quota-proxy/test-admin-api.sh`
3. 查看使用统计: `scripts/query-api-usage.sh`
4. 管理密钥: `scripts/admin-trial-key-manager.sh`

### 场景5: 故障排除
1. 检查服务状态: `scripts/check-quota-proxy-health.sh`
2. 查看日志: `scripts/ssh-logs-quota-proxy.sh`
3. 验证网络: `scripts/install-cn-network-test.sh`
4. 恢复服务: `scripts/deploy-quota-proxy-apply-fix.sh`

## 最佳实践

### 1. 安装最佳实践
- 始终先运行网络测试: `scripts/install-cn-network-test.sh`
- 使用验证脚本确认安装成功
- 备份重要配置和数据库

### 2. 部署最佳实践
- 使用持久化部署脚本确保数据安全
- 配置适当的日志级别和监控
- 定期验证部署状态

### 3. 维护最佳实践
- 定期备份数据库
- 监控服务健康状态
- 及时更新依赖和配置

### 4. 安全最佳实践
- 保护Admin API访问令牌
- 定期轮换密钥
- 监控异常访问模式

## 获取帮助

### 文档资源
- [GitHub仓库](https://github.com/1037104428/roc-ai-republic)
- [Gitee镜像](https://gitee.com/junkaiWang324/roc-ai-republic)
- [项目Wiki](https://github.com/1037104428/roc-ai-republic/wiki)

### 问题反馈
1. 检查相关验证脚本的输出
2. 查看服务日志获取详细信息
3. 在GitHub Issues提交问题报告
4. 提供详细的错误信息和环境信息

### 社区支持
- 加入项目Discord社区
- 参与GitHub Discussions
- 关注项目更新和公告

## 更新日志
- 2026-02-12: 创建文档索引和导航指南
- 定期更新以反映项目变化

---

**提示**: 本文档会定期更新，建议定期查看最新版本以获取最新的文档信息。