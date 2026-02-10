# API使用情况查询工具

`query-api-usage.sh` 是一个用于查询 quota-proxy API 密钥使用情况的命令行工具。它支持查询单个密钥或所有密钥的使用统计，为管理员提供便捷的监控和管理功能。

## 功能特性

- **查询单个密钥**: 查询指定 API 密钥的详细使用情况
- **查询所有密钥**: 获取所有 API 密钥的完整使用统计
- **结构化输出**: 使用 JSON 格式输出，支持 `jq` 进一步处理
- **摘要信息**: 显示总使用量、总剩余量等摘要信息
- **多种模式**: 支持安静模式、详细模式
- **错误处理**: 完善的错误处理和用户友好的提示信息

## 快速开始

### 基本用法

查询单个 API 密钥的使用情况：

```bash
./scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "your-admin-token" -k "test-key-123"
```

查询所有 API 密钥的使用统计：

```bash
./scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "your-admin-token" -a
```

使用环境变量：

```bash
export ADMIN_TOKEN="your-admin-token"
./scripts/query-api-usage.sh -a
```

### 参数说明

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--server` | `-s` | quota-proxy 服务器地址 | `127.0.0.1:8787` |
| `--token` | `-t` | 管理员令牌 | 从 `ADMIN_TOKEN` 环境变量读取 |
| `--key` | `-k` | 查询指定 API 密钥 | 无 |
| `--all` | `-a` | 查询所有 API 密钥 | `false` |
| `--quiet` | `-q` | 安静模式，只输出关键信息 | `false` |
| `--verbose` | `-v` | 详细模式，输出更多调试信息 | `false` |
| `--help` | `-h` | 显示帮助信息 | 无 |

## 使用示例

### 示例 1: 查询单个密钥

```bash
./scripts/query-api-usage.sh \
  -s 8.210.185.194:8787 \
  -t "admin-secret-token" \
  -k "roc-test-key-abc123"
```

输出示例：
```
[INFO] 开始查询quota-proxy API使用情况
[INFO] 检查服务器连接: http://8.210.185.194:8787/healthz
[SUCCESS] 服务器连接正常
[INFO] 查询API密钥使用情况: roc-test-...
[SUCCESS] 查询成功
API密钥使用统计:
=================
{
  "key": "roc-test-key-abc123",
  "used": 42,
  "remaining": 958,
  "total": 1000,
  "last_used": "2026-02-10T19:15:30.123Z"
}
[SUCCESS] 查询完成
```

### 示例 2: 查询所有密钥

```bash
export ADMIN_TOKEN="admin-secret-token"
./scripts/query-api-usage.sh -s 8.210.185.194:8787 -a
```

输出示例：
```
[INFO] 开始查询quota-proxy API使用情况
[INFO] 检查服务器连接: http://8.210.185.194:8787/healthz
[SUCCESS] 服务器连接正常
[INFO] 查询所有API密钥使用统计
[SUCCESS] 查询成功
所有API密钥使用统计 (共 3 个密钥):
==========================================
{
  "keys": [
    {
      "key": "roc-test-key-abc123",
      "used": 42,
      "remaining": 958,
      "total": 1000,
      "last_used": "2026-02-10T19:15:30.123Z"
    },
    {
      "key": "roc-test-key-def456",
      "used": 125,
      "remaining": 875,
      "total": 1000,
      "last_used": "2026-02-10T18:45:22.456Z"
    },
    {
      "key": "roc-admin-key-ghi789",
      "used": 5,
      "remaining": 995,
      "total": 1000,
      "last_used": "2026-02-10T17:30:15.789Z"
    }
  ]
}

使用情况摘要:
-------------
总使用量: 172
总剩余量: 2828
总配额: 3000
[SUCCESS] 查询完成
```

### 示例 3: 安静模式

```bash
./scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "token" -k "test-key" -q
```

输出示例（仅关键信息）：
```
API密钥使用统计:
=================
{
  "key": "test-key",
  "used": 42,
  "remaining": 958
}
```

### 示例 4: 详细模式

```bash
./scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "token" -a -v
```

输出示例（包含调试信息）：
```
[DEBUG] 参数: SERVER=127.0.0.1:8787, SHOW_ALL=true, API_KEY=
[INFO] 开始查询quota-proxy API使用情况
[INFO] 检查服务器连接: http://127.0.0.1:8787/healthz
[DEBUG] 健康检查响应: {"ok":true}
[SUCCESS] 服务器连接正常
[INFO] 查询所有API密钥使用统计
[DEBUG] 请求URL: http://127.0.0.1:8787/admin/usage
[SUCCESS] 查询成功
...
```

## 集成到监控系统

### 定时任务监控

创建定时任务，每小时检查 API 使用情况：

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每小时运行一次）
0 * * * * /path/to/roc-ai-republic/scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "admin-token" -a -q > /var/log/quota-proxy-usage.log 2>&1
```

### 告警配置

基于使用情况设置告警：

```bash
#!/bin/bash
# check-usage-alert.sh

USAGE_DATA=$(/path/to/roc-ai-republic/scripts/query-api-usage.sh -s 127.0.0.1:8787 -t "admin-token" -a -q)

# 解析使用率
TOTAL_USED=$(echo "$USAGE_DATA" | jq '[.keys[].used] | add')
TOTAL_QUOTA=$(echo "$USAGE_DATA" | jq '[.keys[].total] | add')
USAGE_PERCENT=$((TOTAL_USED * 100 / TOTAL_QUOTA))

# 如果使用率超过80%，发送告警
if [ "$USAGE_PERCENT" -gt 80 ]; then
    echo "警告: API使用率超过80% (当前: ${USAGE_PERCENT}%)" | mail -s "quota-proxy使用率告警" admin@example.com
fi
```

### CI/CD 集成

在部署流程中验证 API 使用情况：

```yaml
# .gitlab-ci.yml 示例
stages:
  - test
  - deploy

api-usage-check:
  stage: test
  script:
    - ./scripts/query-api-usage.sh -s $QUOTA_PROXY_SERVER -t $ADMIN_TOKEN -a
    - echo "API使用情况检查通过"
  only:
    - main
```

## 故障排除

### 常见问题

1. **连接失败**
   ```
   [ERROR] 无法连接到服务器: http://127.0.0.1:8787/healthz
   ```
   **解决方案**: 检查服务器是否运行，防火墙设置，以及端口是否正确。

2. **认证失败**
   ```
   [ERROR] 查询失败
   ```
   **解决方案**: 验证管理员令牌是否正确，检查 `ADMIN_TOKEN` 环境变量或 `-t` 参数。

3. **缺少依赖**
   ```
   [ERROR] 缺少必要的依赖: curl jq
   ```
   **解决方案**: 安装缺少的依赖：
   ```bash
   # Ubuntu/Debian
   sudo apt-get install curl jq
   
   # CentOS/RHEL
   sudo yum install curl jq
   
   # macOS
   brew install curl jq
   ```

### 调试技巧

1. **启用详细模式**: 使用 `-v` 参数查看详细日志
2. **手动测试连接**: 使用 `curl` 手动测试服务器连接
3. **检查权限**: 确保脚本有执行权限 (`chmod +x query-api-usage.sh`)
4. **验证令牌**: 使用 `echo $ADMIN_TOKEN` 检查环境变量

## 安全考虑

1. **令牌保护**: 管理员令牌应妥善保管，避免泄露
2. **最小权限**: 仅授予必要的访问权限
3. **日志安全**: 避免在日志中记录敏感信息
4. **网络隔离**: 确保管理接口仅在受信任的网络中可访问

## 相关工具

- [`generate-api-key.sh`](../scripts/generate-api-key.sh): API 密钥生成工具
- [`test-admin-api.sh`](../scripts/test-admin-api.sh): 管理员接口测试工具
- [`enhanced-health-check.sh`](../scripts/enhanced-health-check.sh): 增强版健康检查工具

## 更新日志

- **v1.0.0** (2026-02-10): 初始版本发布
  - 支持查询单个 API 密钥使用情况
  - 支持查询所有 API 密钥统计
  - 添加安静模式和详细模式
  - 完善的错误处理和用户提示

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个工具。在提交更改前，请确保：

1. 测试脚本功能正常
2. 更新相关文档
3. 遵循现有的代码风格
4. 添加适当的错误处理