# DEPLOY-VERIFICATION.md - quota-proxy部署验证指南

## 概述

`deploy-verification.sh` 脚本用于验证 quota-proxy 服务是否正常运行。它提供了一套标准化的验证流程，包括健康检查、状态检查和可选的API端点验证。

## 功能特性

- ✅ **健康检查验证** - 验证 `/healthz` 端点
- ✅ **状态检查验证** - 验证 `/status` 端点  
- ✅ **管理员端点验证** - 验证管理员API端点（需要有效令牌）
- ✅ **可配置参数** - 支持自定义主机、端口、超时时间
- ✅ **干运行模式** - 预览将要执行的命令而不实际运行
- ✅ **详细输出** - 提供详细的验证过程和结果
- ✅ **彩色输出** - 使用颜色区分不同级别的信息
- ✅ **错误诊断** - 提供详细的错误信息和诊断建议

## 快速开始

### 基本使用

```bash
# 授予执行权限
chmod +x quota-proxy/deploy-verification.sh

# 基本验证（使用默认配置）
./quota-proxy/deploy-verification.sh

# 指定端口和主机
./quota-proxy/deploy-verification.sh -p 8787 -H localhost

# 指定管理员令牌
./quota-proxy/deploy-verification.sh --admin-token "your-admin-token-here"

# 干运行模式（预览命令）
./quota-proxy/deploy-verification.sh --dry-run

# 详细输出模式
./quota-proxy/deploy-verification.sh --verbose
```

### 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-h, --help` | 显示帮助信息 | - |
| `-p, --port PORT` | 指定quota-proxy端口 | 8787 |
| `-H, --host HOST` | 指定quota-proxy主机 | 127.0.0.1 |
| `-t, --timeout SECONDS` | 指定超时时间(秒) | 5 |
| `-a, --admin-token TOKEN` | 指定管理员令牌 | test-token |
| `-d, --dry-run` | 干运行模式，只显示将要执行的命令 | false |
| `-v, --verbose` | 详细输出模式 | false |
| `--no-color` | 禁用彩色输出 | false |

## 验证步骤

脚本按以下顺序执行验证：

1. **健康检查端点** (`/healthz`)
   - 验证服务是否响应
   - 期望HTTP状态码：200

2. **状态端点** (`/status`)
   - 验证服务状态信息
   - 期望HTTP状态码：200

3. **管理员端点**（如果提供了有效令牌）
   - `/admin/keys` - 管理员密钥列表
   - `/admin/usage` - 使用统计
   - 期望HTTP状态码：200或201

## 使用示例

### 示例1：基本验证

```bash
./quota-proxy/deploy-verification.sh
```

输出示例：
```
[INFO] 开始quota-proxy部署验证
[INFO] 配置: 主机=127.0.0.1, 端口=8787, 超时=5s
[INFO] 1. 检查健康端点...
[SUCCESS] 健康检查端点: HTTP 200
[INFO] 2. 检查状态端点...
[SUCCESS] 状态端点: HTTP 200
[WARNING] 使用默认测试令牌，跳过管理员端点验证
[INFO] 要测试管理员端点，请使用: ./deploy-verification.sh --admin-token YOUR_TOKEN

[INFO] 验证完成
[SUCCESS] 所有检查通过！quota-proxy服务正常运行
```

### 示例2：带管理员令牌的验证

```bash
./quota-proxy/deploy-verification.sh --admin-token "admin-secret-token-123"
```

### 示例3：干运行模式

```bash
./quota-proxy/deploy-verification.sh --dry-run
```

输出示例：
```
[INFO] 开始quota-proxy部署验证
[INFO] 配置: 主机=127.0.0.1, 端口=8787, 超时=5s
[INFO] 1. 检查健康端点...
[INFO] 干运行: 检查 健康检查端点 (http://127.0.0.1:8787/healthz)
curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout 5 'http://127.0.0.1:8787/healthz'
[INFO] 2. 检查状态端点...
[INFO] 干运行: 检查 状态端点 (http://127.0.0.1:8787/status)
curl -s -o /dev/null -w '%{http_code}' -f --connect-timeout 5 'http://127.0.0.1:8787/status'
[WARNING] 使用默认测试令牌，跳过管理员端点验证
[INFO] 要测试管理员端点，请使用: ./deploy-verification.sh --admin-token YOUR_TOKEN

[INFO] 验证完成
[SUCCESS] 所有检查通过！quota-proxy服务正常运行
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Deploy Verification

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-deployment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Verify quota-proxy deployment
        run: |
          chmod +x quota-proxy/deploy-verification.sh
          ./quota-proxy/deploy-verification.sh --host localhost --port 8787
```

### 定时验证任务

创建定时任务定期验证服务状态：

```bash
# 每天凌晨2点验证服务状态
0 2 * * * cd /path/to/roc-ai-republic && ./quota-proxy/deploy-verification.sh >> /var/log/quota-proxy-verification.log 2>&1
```

## 故障排除

### 常见问题

#### 1. 连接被拒绝

```
[ERROR] 健康检查端点: 连接失败
```

**可能原因：**
- quota-proxy服务未启动
- 防火墙阻止了端口访问
- 主机或端口配置错误

**解决方案：**
1. 检查quota-proxy服务状态：`docker compose ps` 或 `systemctl status quota-proxy`
2. 检查端口监听：`netstat -tlnp | grep 8787`
3. 验证主机和端口配置

#### 2. HTTP状态码不正确

```
[ERROR] 健康检查端点: 期望 HTTP 200，实际 HTTP 503
```

**可能原因：**
- 服务正在启动中
- 依赖服务不可用
- 配置错误

**解决方案：**
1. 检查服务日志：`docker compose logs quota-proxy`
2. 等待服务完全启动
3. 检查配置文件

#### 3. 管理员令牌无效

```
[ERROR] 管理员密钥列表: HTTP 401
```

**可能原因：**
- 管理员令牌不正确
- 令牌已过期
- 权限配置错误

**解决方案：**
1. 验证管理员令牌是否正确
2. 检查令牌有效期
3. 检查权限配置

### 调试技巧

1. **使用详细模式**：添加 `--verbose` 参数查看详细执行过程
2. **增加超时时间**：使用 `--timeout 10` 增加超时时间
3. **检查网络连接**：使用 `curl -v http://host:port/healthz` 手动测试
4. **查看服务日志**：检查quota-proxy服务日志获取更多信息

## 相关文档

- [QUICK-HEALTH-CHECK.md](./QUICK-HEALTH-CHECK.md) - 快速健康检查指南
- [VERIFY-ADMIN-API-COMPLETE.md](./VERIFY-ADMIN-API-COMPLETE.md) - 完整API验证指南
- [INIT-SQLITE-DB.md](./INIT-SQLITE-DB.md) - SQLite数据库初始化指南
- [BACKUP-SQLITE-DB.md](./BACKUP-SQLITE-DB.md) - SQLite数据库备份指南

## 最佳实践

1. **生产环境验证**：在生产部署后立即运行验证脚本
2. **监控集成**：将验证脚本集成到监控系统中
3. **自动化测试**：在CI/CD流水线中自动运行验证
4. **定期检查**：设置定时任务定期验证服务状态
5. **文档更新**：随着服务更新，及时更新验证脚本和文档

## 贡献指南

欢迎提交问题和改进建议。请确保：
1. 遵循现有的代码风格
2. 添加相应的测试
3. 更新相关文档
4. 保持向后兼容性

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。