# 验证工具概览与使用指南

本文档提供中华AI共和国/OpenClaw小白中文包项目中所有验证工具的概览和使用指南，帮助用户快速了解和使用各种验证工具。

## 工具概览

### 1. quota-proxy 验证工具

#### 1.1 快速验证工具
- **脚本**: `scripts/quick-validate-all.sh`
- **功能**: 一键式快速验证quota-proxy的6个核心功能
- **验证项目**: 健康检查、管理界面访问、管理接口验证、试用密钥创建、API网关验证、使用情况统计
- **文档**: [quick-validate-all-guide.md](./quick-validate-all-guide.md)

#### 1.2 完整API流程测试
- **脚本**: `scripts/test-quota-proxy-full-api-flow.sh`
- **功能**: 端到端完整API流程测试
- **测试步骤**: 7个步骤（健康检查 → Admin API状态 → 试用密钥创建 → API网关使用 → 使用统计查询 → 密钥列表查看 → 数据清理）
- **文档**: [quota-proxy-full-api-flow-integration-testing.md](./quota-proxy-full-api-flow-integration-testing.md)

#### 1.3 管理接口集成测试
- **脚本**: `scripts/test-quota-proxy-admin-integration.sh`
- **功能**: POST /admin/keys 和 GET /admin/usage 接口的完整端到端测试
- **文档**: [quota-proxy-admin-integration-testing.md](./quota-proxy-admin-integration-testing.md)

#### 1.4 管理接口测试（本地/远程）
- **本地脚本**: `scripts/test-quota-proxy-admin-interfaces.sh`
- **远程脚本**: `scripts/test-quota-proxy-admin-interfaces-remote.sh`
- **功能**: 管理接口的详细测试，包括未授权访问保护
- **文档**: [quota-proxy-admin-interfaces-testing.md](./quota-proxy-admin-interfaces-testing.md)

#### 1.5 TRIAL_KEY手动发放流程验证
- **脚本**: `scripts/verify-trial-key-manual-process.sh`
- **功能**: 验证TRIAL_KEY手动发放的完整流程
- **测试项目**: 7个核心测试（服务健康检查、Web管理界面访问、curl命令行创建密钥、数据库操作、密钥列表获取、使用情况统计、密钥可用性测试）
- **文档**: [verify-trial-key-manual-process-guide.md](./verify-trial-key-manual-process-guide.md)

#### 1.6 管理界面部署修复
- **脚本**: `scripts/fix-quota-proxy-admin-ui.sh`
- **功能**: 修复admin.html文件位置与server.js配置不匹配问题
- **文档**: [fix-quota-proxy-admin-ui-guide.md](./fix-quota-proxy-admin-ui-guide.md)

### 2. install-cn.sh 验证工具

#### 2.1 安装脚本验证
- **脚本**: `scripts/install-cn.sh` (内置验证功能)
- **验证级别**: basic/quick/full/none/auto
- **使用方式**: `./scripts/install-cn.sh --verify-level <level>`
- **文档**: [install-cn-verification-cheat-sheet.md](./install-cn-verification-cheat-sheet.md)

### 3. API使用示例

#### 3.1 quota-proxy API使用示例
- **文档**: [quota-proxy-api-usage-examples.md](./quota-proxy-api-usage-examples.md)
- **内容**: POST /admin/keys 和 GET /admin/usage 接口的详细使用示例、实际场景和集成代码

## 使用场景指南

### 场景1：快速检查服务状态
```bash
# 使用快速验证工具
./scripts/quick-validate-all.sh --host localhost --port 8787 --token "your-admin-token"

# 或使用dry-run模式预览
./scripts/quick-validate-all.sh --dry-run --verbose
```

### 场景2：完整功能验证（部署前）
```bash
# 运行完整API流程测试
./scripts/test-quota-proxy-full-api-flow.sh --host localhost --port 8787 --token "your-admin-token" --verbose

# 运行管理接口集成测试
./scripts/test-quota-proxy-admin-integration.sh --host localhost --port 8787 --token "your-admin-token" --verbose
```

### 场景3：远程服务器验证
```bash
# 使用远程测试脚本（需要配置SSH访问）
./scripts/test-quota-proxy-admin-interfaces-remote.sh --host 8.210.185.194 --port 8787 --token "your-admin-token" --verbose
```

### 场景4：手动发放流程验证
```bash
# 验证TRIAL_KEY手动发放流程
./scripts/verify-trial-key-manual-process.sh --host localhost --port 8787 --token "your-admin-token" --db-path ./data/quota.db --verbose
```

### 场景5：安装脚本验证
```bash
# 快速验证安装脚本
./scripts/install-cn.sh --dry-run --verify-level quick

# 完整验证安装脚本
./scripts/install-cn.sh --dry-run --verify-level full
```

## 通用参数说明

大多数验证脚本支持以下通用参数：

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--host` | `-h` | 目标主机地址 | `localhost` |
| `--port` | `-p` | 目标端口 | `8787` |
| `--token` | `-t` | Admin API令牌 | 无（必须提供） |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--quiet` | `-q` | 安静模式（仅输出结果） | `false` |
| `--dry-run` | `-n` | 模拟运行（不实际发送请求） | `false` |
| `--help` | 无 | 显示帮助信息 | 无 |

## 退出码说明

| 退出码 | 说明 |
|--------|------|
| `0` | 所有测试通过 |
| `1` | 通用错误（参数错误、脚本错误等） |
| `2` | 健康检查失败 |
| `3` | 管理界面访问失败 |
| `4` | 管理接口测试失败 |
| `5` | 试用密钥创建失败 |
| `6` | API网关验证失败 |
| `7` | 使用情况统计获取失败 |

## 最佳实践

1. **先dry-run后实际运行**: 使用 `--dry-run` 参数预览测试步骤，确认无误后再实际运行
2. **使用详细模式调试**: 遇到问题时使用 `--verbose` 参数查看详细输出
3. **逐步验证**: 从快速验证开始，逐步进行完整功能验证
4. **记录验证结果**: 将验证结果记录到进度日志中，便于跟踪
5. **定期验证**: 建立定期验证机制，确保服务持续可用

## 故障排除

### 常见问题1：连接被拒绝
```
错误: 无法连接到 http://localhost:8787/healthz
```
**解决方案**:
- 确认quota-proxy服务正在运行
- 检查防火墙设置
- 确认端口是否正确

### 常见问题2：令牌无效
```
错误: Admin API令牌无效或缺失
```
**解决方案**:
- 确认提供了正确的 `--token` 参数
- 检查令牌是否在服务器配置中正确设置
- 重新生成令牌并更新配置

### 常见问题3：数据库访问失败
```
错误: 无法访问SQLite数据库
```
**解决方案**:
- 确认数据库文件路径正确
- 检查文件权限
- 确保数据库文件存在且可读写

## 更新记录

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-02-10 | v1.0 | 初始版本，整合所有验证工具概览 |
| 2026-02-10 | v1.1 | 添加使用场景指南和最佳实践 |

## 相关文档

- [TODO清单](./TODO.md) - 项目待办事项和进度跟踪
- [quota-proxy部署指南](./quota-proxy-deployment-guide.md) - quota-proxy部署详细指南
- [install-cn.sh使用指南](./install-cn-usage-guide.md) - 安装脚本使用指南

---

**提示**: 所有验证工具都设计为可独立运行，支持多种运行模式和配置选项。建议先阅读相关文档，了解工具的具体功能和使用方法。