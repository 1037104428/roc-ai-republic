# quota-proxy 环境变量配置验证

## 概述

`verify-quota-proxy-config.sh` 脚本用于验证 quota-proxy Docker 容器的环境变量配置是否正确。该脚本检查必需和可选的环境变量，确保配置符合预期规则，帮助运维人员快速发现配置问题。

## 功能特性

- **全面验证**: 检查所有必需和可选环境变量
- **智能验证规则**: 使用正则表达式验证变量值格式
- **多种运行模式**: 支持详细模式、安静模式、模拟运行、列表模式
- **彩色输出**: 使用颜色区分信息、成功、警告和错误
- **标准化退出码**: 明确的退出码表示不同验证结果
- **故障排除指南**: 提供详细的错误信息和修复建议

## 环境变量说明

### 必需环境变量

| 变量名 | 描述 | 验证规则 | 示例值 |
|--------|------|----------|--------|
| `ADMIN_TOKEN` | 管理员令牌，用于保护 `/admin` 接口 | `^[a-zA-Z0-9_-]{32,128}$` | `supersecretadmintoken1234567890abcdef` |
| `DATABASE_PATH` | SQLite 数据库文件路径 | `^/.*\.db$` | `/data/quota.db` |
| `PORT` | quota-proxy 服务监听端口 | `^[0-9]{2,5}$` | `8787` |
| `LOG_LEVEL` | 日志级别 | `^(debug\|info\|warn\|error)$` | `info` |
| `MAX_REQUESTS_PER_DAY` | 每个 API 密钥每日最大请求数 | `^[0-9]+$` | `1000` |
| `TRIAL_KEY_EXPIRY_DAYS` | 试用密钥过期天数 | `^[0-9]+$` | `7` |

### 可选环境变量

| 变量名 | 描述 | 默认值 | 验证规则 | 示例值 |
|--------|------|--------|----------|--------|
| `CORS_ORIGIN` | CORS 允许的源 | `*` | `^(\*\|https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._-]*)*)?$` | `*` 或 `https://example.com` |
| `REQUEST_TIMEOUT_MS` | 请求超时时间（毫秒） | `30000` | `^[0-9]+$` | `30000` |
| `RATE_LIMIT_WINDOW_MS` | 速率限制窗口时间（毫秒） | `60000` | `^[0-9]+$` | `60000` |
| `ENABLE_METRICS` | 是否启用指标收集 | `false` | `^(true\|false)$` | `false` |
| `METRICS_PORT` | 指标服务端口（如果启用） | `9090` | `^[0-9]{2,5}$` | `9090` |

## 使用方法

### 基本使用

```bash
# 检查当前配置
./scripts/verify-quota-proxy-config.sh

# 详细模式
./scripts/verify-quota-proxy-config.sh --verbose

# 安静模式（只输出错误）
./scripts/verify-quota-proxy-config.sh --quiet

# 模拟运行
./scripts/verify-quota-proxy-config.sh --dry-run

# 列出所有环境变量
./scripts/verify-quota-proxy-config.sh --list
```

### 指定容器

```bash
# 检查指定容器
./scripts/verify-quota-proxy-config.sh --container my-quota-proxy-container
```

### 严格模式

```bash
# 警告也视为失败
./scripts/verify-quota-proxy-config.sh --fail-on-warning
```

## 退出码

| 退出码 | 含义 | 说明 |
|--------|------|------|
| `0` | 成功 | 所有配置验证通过 |
| `1` | 验证失败 | 配置验证失败（包括警告，如果启用 --fail-on-warning） |
| `2` | 参数错误 | 命令行参数错误 |
| `3` | 容器未运行 | Docker 容器未运行 |
| `4` | 环境变量问题 | 环境变量缺失或无效 |

## 示例输出

### 成功验证

```bash
$ ./scripts/verify-quota-proxy-config.sh --verbose
[INFO] 开始验证quota-proxy环境变量配置
[INFO] 容器名称: quota-proxy-quota-proxy-1
[INFO] 模式: 实际检查
[INFO] 详细模式: 是
[INFO] 安静模式: 否

[DEBUG] 检查Docker容器: quota-proxy-quota-proxy-1
[SUCCESS] Docker容器 'quota-proxy-quota-proxy-1' 正在运行
[DEBUG] 获取容器环境变量
[DEBUG] 获取到的环境变量:
ADMIN_TOKEN=supersecretadmintoken1234567890abcdef
DATABASE_PATH=/data/quota.db
PORT=8787
LOG_LEVEL=info
MAX_REQUESTS_PER_DAY=1000
TRIAL_KEY_EXPIRY_DAYS=7
CORS_ORIGIN=*
REQUEST_TIMEOUT_MS=30000
RATE_LIMIT_WINDOW_MS=60000
ENABLE_METRICS=false
METRICS_PORT=9090

[DEBUG] 检查必需的环境变量
[SUCCESS] 必需环境变量验证通过: ADMIN_TOKEN=supersecretadmintoken1234567890abcdef
[SUCCESS] 必需环境变量验证通过: DATABASE_PATH=/data/quota.db
[SUCCESS] 必需环境变量验证通过: PORT=8787
[SUCCESS] 必需环境变量验证通过: LOG_LEVEL=info
[SUCCESS] 必需环境变量验证通过: MAX_REQUESTS_PER_DAY=1000
[SUCCESS] 必需环境变量验证通过: TRIAL_KEY_EXPIRY_DAYS=7

[DEBUG] 检查可选的环境变量
[SUCCESS] 可选环境变量验证通过: CORS_ORIGIN=*
[SUCCESS] 可选环境变量验证通过: REQUEST_TIMEOUT_MS=30000
[SUCCESS] 可选环境变量验证通过: RATE_LIMIT_WINDOW_MS=60000
[SUCCESS] 可选环境变量验证通过: ENABLE_METRICS=false
[SUCCESS] 可选环境变量验证通过: METRICS_PORT=9090

[SUCCESS] 所有环境变量配置验证通过！
[INFO] quota-proxy配置正确，服务可以正常运行。
```

### 验证失败

```bash
$ ./scripts/verify-quota-proxy-config.sh
[INFO] 开始验证quota-proxy环境变量配置
[INFO] 容器名称: quota-proxy-quota-proxy-1
[INFO] 模式: 实际检查
[INFO] 详细模式: 否
[INFO] 安静模式: 否

[ERROR] Docker容器 'quota-proxy-quota-proxy-1' 未运行
```

## 集成到 CI/CD

### GitHub Actions 示例

```yaml
name: Verify quota-proxy config

on:
  push:
    paths:
      - 'docker-compose.yml'
      - '.env.example'
      - 'scripts/verify-quota-proxy-config.sh'

jobs:
  verify-config:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Verify configuration script
        run: |
          bash -n scripts/verify-quota-proxy-config.sh
          ./scripts/verify-quota-proxy-config.sh --dry-run --verbose
```

### 本地开发检查

```bash
# 在开发环境中快速检查配置
./scripts/verify-quota-proxy-config.sh --dry-run

# 验证脚本语法
bash -n scripts/verify-quota-proxy-config.sh

# 运行完整测试
./scripts/verify-quota-proxy-config.sh --verbose --fail-on-warning
```

## 故障排除

### 常见问题

1. **容器未运行**
   ```
   [ERROR] Docker容器 'quota-proxy-quota-proxy-1' 未运行
   ```
   **解决方案**: 启动 quota-proxy 容器
   ```bash
   cd /opt/roc/quota-proxy
   docker compose up -d
   ```

2. **必需环境变量缺失**
   ```
   [ERROR] 必需环境变量缺失: ADMIN_TOKEN
   ```
   **解决方案**: 在 `.env` 文件中设置缺失的环境变量
   ```bash
   echo "ADMIN_TOKEN=$(openssl rand -hex 32)" >> .env
   ```

3. **环境变量值无效**
   ```
   [ERROR] 变量 'PORT' 验证失败: abc (规则: ^[0-9]{2,5}$)
   ```
   **解决方案**: 修正环境变量值
   ```bash
   # 在 .env 文件中
   PORT=8787  # 改为有效的端口号
   ```

4. **可选环境变量警告**
   ```
   [WARNING] 可选环境变量未设置 'CORS_ORIGIN'，将使用默认值: *
   ```
   **解决方案**: 可以忽略（使用默认值）或显式设置
   ```bash
   CORS_ORIGIN=https://your-domain.com
   ```

### 调试技巧

```bash
# 查看容器当前环境变量
docker inspect quota-proxy-quota-proxy-1 --format='{{range .Config.Env}}{{println .}}{{end}}'

# 查看容器日志
docker logs quota-proxy-quota-proxy-1

# 进入容器检查环境
docker exec -it quota-proxy-quota-proxy-1 env
```

## 最佳实践

1. **开发环境**: 使用 `--dry-run` 模式验证配置脚本
2. **测试环境**: 使用 `--verbose --fail-on-warning` 严格验证
3. **生产环境**: 定期运行验证脚本，监控配置健康状态
4. **CI/CD**: 集成到部署流程，确保配置正确性

## 环境变量配置文件示例

创建 `.env` 文件：

```bash
# 必需环境变量
ADMIN_TOKEN=supersecretadmintoken1234567890abcdef
DATABASE_PATH=/data/quota.db
PORT=8787
LOG_LEVEL=info
MAX_REQUESTS_PER_DAY=1000
TRIAL_KEY_EXPIRY_DAYS=7

# 可选环境变量（使用默认值）
# CORS_ORIGIN=*
# REQUEST_TIMEOUT_MS=30000
# RATE_LIMIT_WINDOW_MS=60000
# ENABLE_METRICS=false
# METRICS_PORT=9090
```

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [quota-proxy 健康检查](../docs/quota-proxy-health-check.md)
- [quota-proxy 数据库管理](../docs/quota-db-management.md)
- [Docker Compose 配置](../docker-compose.yml)

## 更新日志

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02-10 | 初始版本，提供完整的环境变量验证功能 |

---

**注意**: 定期运行此脚本可以确保 quota-proxy 配置正确，避免因配置问题导致的服务异常。