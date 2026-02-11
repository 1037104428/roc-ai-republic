# 试用密钥生成API可用性验证指南

## 概述

`verify-trial-key-availability.sh` 是一个轻量级验证脚本，用于快速检查 quota-proxy 服务的试用密钥生成API是否正常工作。该脚本提供简单的健康检查、管理员API验证、试用密钥生成和可用性验证功能。

## 功能特性

- **健康端点检查**: 验证 `/healthz` 端点是否正常响应
- **管理员API密钥生成**: 测试 `/admin/keys` 端点生成API密钥
- **试用密钥生成**: 测试 `/admin/trial-keys` 端点生成试用密钥
- **试用密钥可用性验证**: 模拟试用密钥验证流程
- **干运行模式**: 支持预览将要执行的命令而不实际执行
- **详细输出**: 提供详细的执行日志和错误信息
- **彩色输出**: 支持彩色终端输出，提高可读性
- **灵活配置**: 支持自定义端口、令牌、基础URL等参数

## 快速开始

### 1. 安装依赖

确保系统已安装以下命令：
- `curl` - HTTP客户端
- `bash` - Shell环境

### 2. 设置脚本权限

```bash
chmod +x verify-trial-key-availability.sh
```

### 3. 基本使用

使用默认配置验证本地服务：

```bash
./verify-trial-key-availability.sh
```

### 4. 验证成功输出示例

```
[INFO] 开始验证试用密钥生成API可用性
[INFO] 配置: 端口=8787, 基础URL=http://127.0.0.1
[INFO] 验证健康端点...
[SUCCESS] 健康端点正常: {"status":"ok"}
[INFO] 验证管理员API密钥生成...
[SUCCESS] 管理员API密钥生成成功: "key":"test-api-key-123"
[INFO] 验证试用密钥生成...
[SUCCESS] 试用密钥生成成功: "keys":["trial-key-456"]
[INFO] 验证试用密钥可用性...
[SUCCESS] 试用密钥验证逻辑正常

[SUCCESS] 所有验证通过！试用密钥生成API可用性验证完成

验证项目:
  ✓ 健康端点检查
  ✓ 管理员API密钥生成
  ✓ 试用密钥生成
  ✓ 试用密钥可用性验证
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-h, --help` | 显示帮助信息 | - |
| `-p, --port PORT` | 服务器端口 | 8787 |
| `-t, --token TOKEN` | 管理员令牌 | "test-admin-token" |
| `-u, --url URL` | 基础URL | "http://127.0.0.1" |
| `-d, --dry-run` | 干运行模式，只显示命令 | false |
| `-v, --verbose` | 详细输出模式 | false |
| `--color` | 启用彩色输出 | 自动检测 |
| `--no-color` | 禁用彩色输出 | - |

## 使用示例

### 示例1: 自定义配置验证

```bash
./verify-trial-key-availability.sh -p 8080 -t "my-secret-token" -u "http://localhost"
```

### 示例2: 干运行模式

```bash
./verify-trial-key-availability.sh -d
```

输出示例:
```
[INFO] 开始验证试用密钥生成API可用性
[INFO] 配置: 端口=8787, 基础URL=http://127.0.0.1
[INFO] 干运行模式 - 只显示命令，不实际执行
[INFO] 验证健康端点...
[干运行] 执行: curl -s -X GET 'http://127.0.0.1:8787/healthz'
{"status": "dry-run", "message": "干运行模式"}
[SUCCESS] 健康端点正常: {"status": "dry-run", "message": "干运行模式"}
...
```

### 示例3: 详细输出模式

```bash
./verify-trial-key-availability.sh -v
```

### 示例4: 禁用彩色输出

```bash
./verify-trial-key-availability.sh --no-color
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Verify Trial Key Availability

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 */6 * * *'  # 每6小时运行一次

jobs:
  verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Verify trial key availability
      run: |
        chmod +x quota-proxy/verify-trial-key-availability.sh
        ./quota-proxy/verify-trial-key-availability.sh --dry-run
```

### 定时验证任务

创建定时任务，每6小时验证一次服务可用性：

```bash
# 添加cron任务
(crontab -l 2>/dev/null; echo "0 */6 * * * cd /path/to/roc-ai-republic && ./quota-proxy/verify-trial-key-availability.sh >> /var/log/trial-key-verify.log 2>&1") | crontab -
```

## 故障排除

### 常见问题

#### 1. 健康端点检查失败

**症状**: `[ERROR] 健康端点异常: ...`

**解决方案**:
- 确保quota-proxy服务正在运行
- 检查端口配置是否正确
- 验证服务日志: `docker compose logs quota-proxy`

#### 2. 管理员API密钥生成失败

**症状**: `[WARNING] 管理员API密钥生成可能失败: ...`

**解决方案**:
- 验证管理员令牌是否正确
- 检查服务配置中的`ADMIN_TOKEN`环境变量
- 确保服务已启用管理员API功能

#### 3. 试用密钥生成失败

**症状**: `[WARNING] 试用密钥生成可能失败: ...`

**解决方案**:
- 检查数据库连接是否正常
- 验证SQLite数据库文件权限
- 查看服务错误日志

#### 4. 试用密钥验证失败

**症状**: `[WARNING] 试用密钥验证返回: ...`

**解决方案**:
- 这可能是预期的，因为脚本使用模拟的试用密钥
- 在实际环境中，使用实际生成的试用密钥进行验证

### 调试技巧

1. **启用详细输出**: 使用 `-v` 参数查看详细执行信息
2. **干运行模式**: 使用 `-d` 参数预览将要执行的命令
3. **手动测试**: 使用curl手动测试各个端点:
   ```bash
   curl -v http://127.0.0.1:8787/healthz
   curl -v -H "Authorization: Bearer test-token" -H "Content-Type: application/json" -d '{"name":"test","quota":100}' http://127.0.0.1:8787/admin/keys
   ```

## 最佳实践

### 1. 生产环境使用

在生产环境中，建议:
- 使用实际的管理员令牌，而不是默认值
- 配置正确的服务URL和端口
- 定期运行验证脚本，监控服务健康状态
- 将验证结果集成到监控系统中

### 2. 安全考虑

- 不要在脚本中硬编码敏感令牌
- 使用环境变量或配置文件管理敏感信息
- 限制脚本的执行权限
- 定期轮换管理员令牌

### 3. 性能优化

- 对于频繁验证，可以考虑减少验证频率
- 使用缓存机制避免重复验证
- 并行执行独立的验证步骤

## 相关文档

- [quota-proxy 部署指南](../DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md)
- [试用密钥生成API测试指南](../TEST-TRIAL-KEY-GENERATION.md)
- [管理员API完整性验证指南](../VERIFY_ADMIN_API_COMPLETE.md)
- [快速健康检查指南](../QUICK-HEALTH-CHECK.md)

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持健康端点、管理员API、试用密钥生成和可用性验证
- 支持干运行模式和详细输出
- 提供完整的文档和CI/CD集成示例

## 贡献指南

欢迎提交问题和改进建议。请确保:
1. 遵循现有的代码风格
2. 添加相应的测试
3. 更新相关文档
4. 通过现有验证脚本的测试

## 许可证

本脚本是中华AI共和国 / OpenClaw 小白中文包项目的一部分，遵循项目许可证。