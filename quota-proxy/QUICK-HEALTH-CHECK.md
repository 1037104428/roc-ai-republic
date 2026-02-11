# quota-proxy 快速健康检查指南

## 概述

`quick-health-check.sh` 脚本提供 quota-proxy 服务的快速健康检查功能，用于验证服务状态和基本功能是否正常。

## 功能特性

- ✅ **健康端点检查** - 验证 `/healthz` 端点
- ✅ **状态端点检查** - 验证 `/status` 端点  
- ✅ **API密钥基本检查** - 验证API网关功能
- ✅ **干运行模式** - 支持模拟测试，无需实际服务
- ✅ **彩色输出** - 清晰的彩色日志输出
- ✅ **可配置参数** - 支持自定义URL、超时等参数
- ✅ **错误诊断** - 提供详细的故障排除建议

## 快速开始

### 1. 基本使用

```bash
# 进入 quota-proxy 目录
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy

# 运行健康检查（需要 quota-proxy 服务正在运行）
./quick-health-check.sh
```

### 2. 干运行模式（无需实际服务）

```bash
# 干运行模式，模拟所有检查
./quick-health-check.sh --dry-run

# 或使用环境变量
DRY_RUN=true ./quick-health-check.sh
```

### 3. 自定义配置

```bash
# 指定不同的服务地址
./quick-health-check.sh --base-url http://localhost:8787

# 指定超时时间
./quick-health-check.sh --timeout 10

# 组合使用
./quick-health-check.sh --base-url http://192.168.1.100:8787 --timeout 15 --dry-run
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--base-url URL` | quota-proxy 基础URL | `http://127.0.0.1:8787` |
| `--admin-token TOKEN` | 管理员令牌 | `test-admin-token` |
| `--timeout SECONDS` | 请求超时时间 | `5` |
| `--dry-run` | 干运行模式 | `false` |
| `--help` | 显示帮助信息 | - |

## 环境变量

| 变量名 | 描述 | 对应选项 |
|--------|------|----------|
| `BASE_URL` | quota-proxy 基础URL | `--base-url` |
| `ADMIN_TOKEN` | 管理员令牌 | `--admin-token` |
| `TIMEOUT` | 请求超时时间 | `--timeout` |
| `DRY_RUN` | 干运行模式 | `--dry-run` |

## 使用示例

### 示例1：基本健康检查

```bash
# 检查本地运行的 quota-proxy
./quick-health-check.sh

# 输出示例：
# [INFO] 开始 quota-proxy 快速健康检查
# [INFO] 配置: BASE_URL=http://127.0.0.1:8787, TIMEOUT=5s, DRY_RUN=false
# [INFO] 检查健康端点: http://127.0.0.1:8787/healthz
# [SUCCESS] 健康检查通过: {"status":"healthy","timestamp":"2026-02-11T19:20:00+08:00"}
# [INFO] 检查状态端点: http://127.0.0.1:8787/status
# [SUCCESS] 状态检查通过: {"version":"1.0.0","uptime":3600,"requests":1000}
# [INFO] 检查API密钥端点（如果可用）
# [WARNING] API密钥检查: 密钥无效或配额已用完（正常状态）
# [SUCCESS] 所有健康检查通过！quota-proxy 服务运行正常
```

### 示例2：干运行测试

```bash
# 在部署前测试脚本
./quick-health-check.sh --dry-run

# 输出示例：
# [INFO] 开始 quota-proxy 快速健康检查
# [INFO] 配置: BASE_URL=http://127.0.0.1:8787, TIMEOUT=5s, DRY_RUN=true
# [INFO] 检查健康端点: http://127.0.0.1:8787/healthz
# [WARNING] 干运行模式 - 跳过实际HTTP请求
# 模拟响应: {"status":"healthy","timestamp":"2026-02-11T19:20:00+08:00"}
# [SUCCESS] 健康检查通过: {"status":"healthy","timestamp":"2026-02-11T19:20:00+08:00"}
# ...（其他检查类似）
```

### 示例3：远程服务检查

```bash
# 检查远程服务器上的 quota-proxy
./quick-health-check.sh --base-url https://api.example.com --timeout 10
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: quota-proxy Health Check

on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 */6 * * *'  # 每6小时运行一次

jobs:
  health-check:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Run health check
      run: |
        cd quota-proxy
        chmod +x quick-health-check.sh
        ./quick-health-check.sh --dry-run
```

### 定时验证任务

```bash
# 添加到 crontab，每小时检查一次
0 * * * * cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy && ./quick-health-check.sh >> /var/log/quota-proxy-health.log 2>&1
```

## 故障排除

### 常见问题

1. **健康检查失败**
   ```
   [ERROR] 健康检查失败
   ```
   **解决方案：**
   - 检查 quota-proxy 服务是否运行：`docker compose ps`
   - 查看服务日志：`docker compose logs quota-proxy`
   - 验证网络连接：`curl -v http://127.0.0.1:8787/healthz`

2. **curl 命令未找到**
   ```
   [ERROR] 命令 'curl' 未找到，请先安装
   ```
   **解决方案：**
   - Ubuntu/Debian: `sudo apt install curl`
   - CentOS/RHEL: `sudo yum install curl`
   - macOS: `brew install curl`

3. **连接超时**
   ```
   [ERROR] 健康检查失败
   ```
   **解决方案：**
   - 增加超时时间：`./quick-health-check.sh --timeout 15`
   - 检查防火墙设置
   - 验证服务端口是否监听：`netstat -tlnp | grep 8787`

### 调试模式

```bash
# 启用详细日志
set -x
./quick-health-check.sh
set +x
```

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [管理员API验证指南](./VERIFY_ADMIN_API_COMPLETE.md)
- [API密钥管理指南](./VERIFY_ADMIN_KEYS_ENDPOINT.md)
- [使用统计验证指南](./QUICK-VERIFY-ADMIN-USAGE.md)

## 贡献

欢迎提交问题和改进建议！

1. 发现问题？请提交 [Issue](https://github.com/1037104428/roc-ai-republic/issues)
2. 有改进建议？请提交 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](../LICENSE) 文件了解详情。