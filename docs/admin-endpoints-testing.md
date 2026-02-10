# quota-proxy管理员接口测试指南

本文档介绍如何使用`test-admin-endpoints.sh`脚本测试quota-proxy的管理员接口，包括`POST /admin/keys`和`GET /admin/usage`接口。

## 概述

`test-admin-endpoints.sh`脚本为quota-proxy管理员接口提供完整的测试验证工具，支持：

1. **健康检查** - 验证quota-proxy服务状态
2. **API密钥创建** - 测试`POST /admin/keys`接口
3. **使用情况查询** - 测试`GET /admin/usage`接口
4. **API密钥验证** - 测试生成的API密钥是否可用

## 快速开始

### 1. 基本使用

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 查看帮助信息
./scripts/test-admin-endpoints.sh --help

# 执行完整测试流程
./scripts/test-admin-endpoints.sh
```

### 2. 指定服务器和令牌

```bash
# 指定quota-proxy URL和管理员令牌
./scripts/test-admin-endpoints.sh \
  --url http://8.210.185.194:8787 \
  --token your-admin-token-here

# 使用环境变量
export QUOTA_PROXY_URL="http://8.210.185.194:8787"
export ADMIN_TOKEN="your-admin-token-here"
./scripts/test-admin-endpoints.sh
```

### 3. 特定功能测试

```bash
# 只创建API密钥
./scripts/test-admin-endpoints.sh --create-key

# 只检查API使用情况
./scripts/test-admin-endpoints.sh --check-usage

# 创建密钥并检查使用情况
./scripts/test-admin-endpoints.sh --create-key --check-usage
```

## 脚本选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-h, --help` | 显示帮助信息 | - |
| `-u, --url URL` | quota-proxy服务URL | `http://127.0.0.1:8787` |
| `-t, --token TOKEN` | 管理员令牌 | `test-admin-token` |
| `-d, --dry-run` | 干运行模式，只显示命令 | `false` |
| `-v, --verbose` | 详细输出模式 | `false` |
| `-q, --quiet` | 安静模式，只输出关键信息 | `false` |
| `--create-key` | 创建测试API密钥 | `false` |
| `--check-usage` | 检查API使用情况 | `false` |

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `QUOTA_PROXY_URL` | quota-proxy服务URL | `http://127.0.0.1:8787` |
| `ADMIN_TOKEN` | 管理员令牌 | `test-admin-token` |

## 测试流程详解

### 1. 健康检查

脚本首先检查quota-proxy的健康状态：

```bash
curl -fsS "http://127.0.0.1:8787/healthz"
```

期望响应：
```json
{"ok":true}
```

### 2. API密钥创建

测试`POST /admin/keys`接口：

```bash
curl -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prefix":"test","quota":1000}'
```

成功响应示例：
```json
{
  "key": "test_abc123def456",
  "prefix": "test",
  "quota": 1000,
  "createdAt": "2026-02-10T19:50:00Z"
}
```

生成的API密钥会保存到`/tmp/test-api-key.txt`文件中。

### 3. API使用情况查询

测试`GET /admin/usage`接口：

```bash
curl -X GET "http://127.0.0.1:8787/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

响应示例：
```json
{
  "totalKeys": 5,
  "activeKeys": 3,
  "totalUsage": 1250,
  "keys": [
    {
      "key": "test_abc123def456",
      "prefix": "test",
      "quota": 1000,
      "used": 150,
      "remaining": 850,
      "createdAt": "2026-02-10T19:50:00Z"
    }
  ]
}
```

### 4. API密钥验证

使用生成的API密钥测试基本功能：

```bash
curl -X GET "http://127.0.0.1:8787/test" \
  -H "Authorization: Bearer $API_KEY"
```

## 使用示例

### 示例1：本地测试

```bash
# 启动本地quota-proxy服务
cd /opt/roc/quota-proxy
docker compose up -d

# 运行测试脚本
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/test-admin-endpoints.sh --verbose
```

### 示例2：远程服务器测试

```bash
# 设置远程服务器配置
export QUOTA_PROXY_URL="http://8.210.185.194:8787"
export ADMIN_TOKEN="your-actual-admin-token"

# 运行测试
./scripts/test-admin-endpoints.sh --create-key --check-usage
```

### 示例3：干运行模式

```bash
# 查看将要执行的命令
./scripts/test-admin-endpoints.sh --dry-run --verbose

# 输出示例：
# curl -fsS "http://127.0.0.1:8787/healthz"
# curl -X POST "http://127.0.0.1:8787/admin/keys" \
#   -H "Authorization: Bearer test-admin-token" \
#   -H "Content-Type: application/json" \
#   -d '{"prefix":"test","quota":1000}'
# curl -X GET "http://127.0.0.1:8787/admin/usage" \
#   -H "Authorization: Bearer test-admin-token"
```

### 示例4：自动化测试

```bash
#!/bin/bash
# 自动化测试脚本示例

set -e

# 配置
QUOTA_PROXY_URL="http://8.210.185.194:8787"
ADMIN_TOKEN="your-admin-token"

# 运行测试
cd /home/kai/.openclaw/workspace/roc-ai-republic

echo "=== 开始quota-proxy管理员接口测试 ==="
echo "时间: $(date)"
echo "服务器: $QUOTA_PROXY_URL"

# 执行测试
if ./scripts/test-admin-endpoints.sh \
  --url "$QUOTA_PROXY_URL" \
  --token "$ADMIN_TOKEN" \
  --create-key \
  --check-usage; then
    echo "=== 测试通过 ==="
    exit 0
else
    echo "=== 测试失败 ==="
    exit 1
fi
```

## 故障排除

### 常见问题

#### 1. 健康检查失败

**症状**：
```
[ERROR] 健康检查失败
```

**解决方案**：
- 检查quota-proxy服务是否运行：`docker compose ps`
- 检查端口是否正确：`netstat -tlnp | grep 8787`
- 检查防火墙设置

#### 2. 管理员令牌无效

**症状**：
```
[ERROR] API密钥创建失败 (HTTP 401)
```

**解决方案**：
- 确认管理员令牌正确：检查`ADMIN_TOKEN`环境变量或`--token`参数
- 验证令牌格式：应为有效的JWT或API密钥
- 检查quota-proxy配置中的管理员令牌设置

#### 3. 网络连接问题

**症状**：
```
[ERROR] 创建API密钥请求失败
```

**解决方案**：
- 检查网络连接：`ping 8.210.185.194`
- 检查端口访问：`telnet 8.210.185.194 8787`
- 检查服务器防火墙规则

#### 4. JSON解析错误

**症状**：
```
jq: error: syntax error, unexpected ...
```

**解决方案**：
- 安装jq工具：`sudo apt-get install jq` (Ubuntu/Debian)
- 或使用`--quiet`模式跳过JSON格式化

### 调试技巧

1. **启用详细模式**：
   ```bash
   ./scripts/test-admin-endpoints.sh --verbose
   ```

2. **查看原始响应**：
   ```bash
   # 手动测试
   curl -v -X POST "http://127.0.0.1:8787/admin/keys" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"prefix":"test","quota":1000}'
   ```

3. **检查服务日志**：
   ```bash
   # 查看quota-proxy日志
   docker compose logs quota-proxy
   ```

## 集成到CI/CD

### GitHub Actions示例

```yaml
name: Test quota-proxy admin endpoints

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-admin-endpoints:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup environment
      run: |
        sudo apt-get update
        sudo apt-get install -y curl jq
    
    - name: Run admin endpoints test
      env:
        QUOTA_PROXY_URL: ${{ secrets.QUOTA_PROXY_URL }}
        ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
      run: |
        chmod +x scripts/test-admin-endpoints.sh
        ./scripts/test-admin-endpoints.sh \
          --create-key \
          --check-usage \
          --verbose
```

### 定时监控任务

```bash
#!/bin/bash
# 定时监控脚本

LOG_FILE="/var/log/quota-proxy-admin-test.log"
CONFIG_FILE="/etc/quota-proxy-test.conf"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# 默认配置
QUOTA_PROXY_URL="${QUOTA_PROXY_URL:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

# 运行测试
cd /home/kai/.openclaw/workspace/roc-ai-republic

echo "=== $(date) ===" >> "$LOG_FILE"

if ./scripts/test-admin-endpoints.sh \
  --url "$QUOTA_PROXY_URL" \
  --token "$ADMIN_TOKEN" \
  --quiet; then
    echo "测试通过" >> "$LOG_FILE"
else
    echo "测试失败" >> "$LOG_FILE"
    # 发送告警
    echo "quota-proxy管理员接口测试失败" | mail -s "quota-proxy告警" admin@example.com
fi

echo "" >> "$LOG_FILE"
```

## 安全考虑

1. **令牌保护**：
   - 不要将管理员令牌硬编码在脚本中
   - 使用环境变量或配置文件
   - 定期轮换管理员令牌

2. **访问控制**：
   - 确保管理员接口只能从可信网络访问
   - 使用防火墙限制访问IP
   - 考虑使用VPN或私有网络

3. **日志记录**：
   - 记录所有管理员操作
   - 监控异常访问模式
   - 定期审计日志

4. **最小权限**：
   - 为测试使用专用的测试令牌
   - 限制测试令牌的权限
   - 测试完成后及时清理测试数据

## 相关文档

- [quota-proxy快速入门指南](../docs/quota-proxy-quickstart.md)
- [quota-proxy API使用指南](../docs/quota-proxy-api-usage-guide.md)
- [管理员接口测试脚本](../scripts/test-admin-endpoints.sh)
- [quota-proxy部署验证](../scripts/verify-full-deployment.sh)

## 更新日志

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02-10 | 初始版本，支持基本管理员接口测试 |
| 1.0.1 | 2026-02-10 | 添加干运行模式、详细输出和安静模式 |

## 支持

如有问题或建议，请：
1. 查看[故障排除](#故障排除)章节
2. 检查quota-proxy服务日志
3. 提交GitHub Issue

---

**注意**：本脚本仅用于测试环境，生产环境使用时请确保遵循安全最佳实践。