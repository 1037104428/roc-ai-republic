# quota-proxy 管理员接口测试指南

本文档提供 quota-proxy 管理员接口的完整测试指南，包括测试脚本使用、接口验证、故障排除和生产环境集成。

## 概述

`test-admin-api.sh` 脚本是一个全面的 quota-proxy 管理员接口测试工具，支持：

- ✅ 健康检查接口验证
- ✅ 密钥生成和管理接口测试
- ✅ 使用统计接口验证
- ✅ 多种输出格式（JSON/文本）
- ✅ 详细/安静模式
- ✅ 环境变量配置
- ✅ 自动化集成支持

## 快速开始

### 1. 基本使用

```bash
# 进入项目目录
cd /path/to/roc-ai-republic

# 查看帮助信息
./scripts/test-admin-api.sh --help

# 使用默认配置测试所有接口
./scripts/test-admin-api.sh

# 指定管理员令牌和API地址
./scripts/test-admin-api.sh --token "your-admin-token" --url "http://api.example.com:8787"
```

### 2. 环境变量配置

```bash
# 设置环境变量（推荐）
export ADMIN_TOKEN="your-secret-admin-token"
export BASE_URL="http://127.0.0.1:8787"
export OUTPUT_FORMAT="json"

# 然后运行测试
./scripts/test-admin-api.sh
```

### 3. 测试特定接口

```bash
# 只测试健康检查
./scripts/test-admin-api.sh --test-health

# 只测试密钥管理接口
./scripts/test-admin-api.sh --test-keys

# 只测试使用统计接口
./scripts/test-admin-api.sh --test-usage

# 测试所有接口（默认）
./scripts/test-admin-api.sh --test-all
```

## 详细功能说明

### 健康检查测试

验证 quota-proxy 服务是否正常运行：

```bash
./scripts/test-admin-api.sh --test-health --verbose
```

**预期输出：**
```
[INFO] 测试健康检查接口: GET /healthz
[SUCCESS] 健康检查通过
端点: /healthz
响应: {"ok":true}
```

### 密钥管理测试

测试密钥生成和列表功能：

```bash
# 生成测试密钥
./scripts/test-admin-api.sh --test-keys --verbose

# 查看现有密钥列表
./scripts/test-admin-api.sh --test-keys --format text
```

**密钥生成请求示例：**
```json
{
  "name": "test-key-1707541200",
  "quota": 1000,
  "expires_in": 3600
}
```

**成功响应：**
```json
{
  "key": "test_key_abc123def456",
  "name": "test-key-1707541200",
  "quota": 1000,
  "remaining": 1000,
  "expires_at": "2026-02-10T19:00:00Z"
}
```

### 使用统计测试

获取系统使用统计信息：

```bash
./scripts/test-admin-api.sh --test-usage --format json
```

**预期响应：**
```json
{
  "total_requests": 1500,
  "active_keys": 5,
  "total_keys": 10,
  "requests_today": 120,
  "average_response_time_ms": 45.2
}
```

## 输出模式

### JSON 格式（默认）

```bash
./scripts/test-admin-api.sh --format json
```

适合自动化处理和脚本集成，可以使用 `jq` 进行进一步处理：

```bash
./scripts/test-admin-api.sh --quiet --format json | jq '.'
```

### 文本格式

```bash
./scripts/test-admin-api.sh --format text
```

适合人工阅读和快速检查。

### 详细模式

```bash
./scripts/test-admin-api.sh --verbose
```

显示详细的请求和响应信息，适合调试。

### 安静模式

```bash
./scripts/test-admin-api.sh --quiet
```

只输出测试结果，适合 CI/CD 流水线集成。

## 生产环境集成

### 1. 自动化测试脚本

创建自动化测试脚本 `run-admin-tests.sh`：

```bash
#!/bin/bash
# run-admin-tests.sh - 生产环境管理员接口自动化测试

set -e

# 加载环境配置
source /etc/roc-quota-proxy/env.conf

# 运行测试
cd /opt/roc/quota-proxy
./scripts/test-admin-api.sh \
  --token "$ADMIN_TOKEN" \
  --url "http://127.0.0.1:8787" \
  --quiet

# 检查退出码
if [ $? -eq 0 ]; then
    echo "$(date): 管理员接口测试通过" >> /var/log/roc-quota-proxy/test.log
else
    echo "$(date): 管理员接口测试失败" >> /var/log/roc-quota-proxy/test.log
    exit 1
fi
```

### 2. CI/CD 流水线集成

GitHub Actions 示例：

```yaml
name: Admin API Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-admin-api:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker
      run: |
        docker compose -f docker-compose.test.yml up -d
        sleep 10  # 等待服务启动
    
    - name: Run admin API tests
      run: |
        export ADMIN_TOKEN="${{ secrets.ADMIN_TOKEN }}"
        export BASE_URL="http://localhost:8787"
        ./scripts/test-admin-api.sh --quiet --test-all
        
        if [ $? -ne 0 ]; then
          echo "管理员接口测试失败"
          exit 1
        fi
    
    - name: Clean up
      run: docker compose -f docker-compose.test.yml down
```

### 3. 监控告警集成

结合监控系统进行定期健康检查：

```bash
#!/bin/bash
# monitor-admin-api.sh - 监控脚本

ADMIN_TOKEN="your-token"
BASE_URL="http://127.0.0.1:8787"
LOG_FILE="/var/log/roc-quota-proxy/monitor.log"
ALERT_THRESHOLD=3  # 连续失败次数阈值

# 运行测试
if ./scripts/test-admin-api.sh --token "$ADMIN_TOKEN" --url "$BASE_URL" --quiet; then
    echo "$(date): 管理员接口正常" >> "$LOG_FILE"
    # 重置失败计数器
    echo "0" > /tmp/admin-api-fail-count
else
    echo "$(date): 管理员接口测试失败" >> "$LOG_FILE"
    
    # 增加失败计数器
    fail_count=$(( $(cat /tmp/admin-api-fail-count 2>/dev/null || echo "0") + 1 ))
    echo "$fail_count" > /tmp/admin-api-fail-count
    
    # 检查是否达到告警阈值
    if [ "$fail_count" -ge "$ALERT_THRESHOLD" ]; then
        echo "$(date): 管理员接口连续失败 $fail_count 次，触发告警" >> "$LOG_FILE"
        # 发送告警通知
        send_alert "quota-proxy 管理员接口异常"
    fi
fi
```

## 故障排除

### 常见问题

#### 1. 连接超时

**症状：**
```
[ERROR] 健康检查失败
curl: (7) Failed to connect to 127.0.0.1 port 8787: Connection refused
```

**解决方案：**
```bash
# 检查服务状态
docker compose ps

# 检查端口监听
netstat -tlnp | grep 8787

# 重启服务
docker compose restart quota-proxy
```

#### 2. 管理员令牌无效

**症状：**
```
[ERROR] 密钥生成失败
{"error":"invalid admin token"}
```

**解决方案：**
```bash
# 验证令牌配置
echo "当前令牌: $ADMIN_TOKEN"

# 重新设置令牌
export ADMIN_TOKEN="正确的管理员令牌"

# 或者通过参数指定
./scripts/test-admin-api.sh --token "正确的管理员令牌"
```

#### 3. JSON 解析错误

**症状：**
```
jq: parse error: Invalid numeric literal at line 1, column 6
```

**解决方案：**
```bash
# 使用文本格式输出
./scripts/test-admin-api.sh --format text

# 或者安装 jq
sudo apt-get install jq  # Ubuntu/Debian
sudo yum install jq      # CentOS/RHEL
```

### 调试模式

启用详细输出进行调试：

```bash
# 启用详细输出
./scripts/test-admin-api.sh --verbose

# 查看原始curl命令
set -x
./scripts/test-admin-api.sh --test-health
set +x
```

### 网络诊断

如果遇到网络问题，使用网络诊断工具：

```bash
# 使用项目提供的网络诊断工具
./scripts/diagnose-network.sh --test-api "$BASE_URL"
```

## 安全考虑

### 1. 令牌管理

- 🔒 不要将管理员令牌硬编码在脚本中
- 🔒 使用环境变量或密钥管理系统
- 🔒 定期轮换管理员令牌
- 🔒 限制令牌的访问权限

### 2. 访问控制

- 🔒 确保管理员接口只在内网可访问
- 🔒 使用防火墙限制访问来源
- 🔒 启用HTTPS加密通信
- 🔒 记录所有管理员操作

### 3. 审计日志

启用详细日志记录：

```bash
# 在docker-compose.yml中添加日志配置
services:
  quota-proxy:
    environment:
      - LOG_LEVEL=debug
      - LOG_ADMIN_ACTIONS=true
```

## 性能测试

### 压力测试脚本

创建压力测试脚本 `stress-test-admin-api.sh`：

```bash
#!/bin/bash
# stress-test-admin-api.sh - 管理员接口压力测试

CONCURRENT_REQUESTS=10
TOTAL_REQUESTS=100
ADMIN_TOKEN="your-token"
BASE_URL="http://127.0.0.1:8787"

echo "开始压力测试: $CONCURRENT_REQUESTS 并发，总共 $TOTAL_REQUESTS 请求"

for i in $(seq 1 $TOTAL_REQUESTS); do
    # 并发执行测试
    ./scripts/test-admin-api.sh \
        --token "$ADMIN_TOKEN" \
        --url "$BASE_URL" \
        --test-health \
        --quiet &
    
    # 控制并发数
    if (( i % CONCURRENT_REQUESTS == 0 )); then
        wait
        echo "已完成 $i/$TOTAL_REQUESTS 请求"
    fi
done

wait
echo "压力测试完成"
```

### 性能监控

监控关键指标：

```bash
# 监控响应时间
time ./scripts/test-admin-api.sh --quiet

# 监控内存使用
/usr/bin/time -v ./scripts/test-admin-api.sh --quiet 2>&1 | grep -E "Maximum resident set size|Elapsed"
```

## 扩展功能

### 自定义测试用例

创建自定义测试脚本 `custom-admin-tests.sh`：

```bash
#!/bin/bash
# custom-admin-tests.sh - 自定义管理员接口测试

source ./scripts/test-admin-api.sh

# 自定义测试函数
test_custom_scenario() {
    echo "测试自定义场景..."
    
    # 生成多个测试密钥
    for i in {1..5}; do
        local test_data="{\"name\":\"batch-key-$i\",\"quota\":500,\"expires_in\":1800}"
        local response=$(send_request "POST" "/admin/keys" "$test_data")
        
        if echo "$response" | grep -q '"key"'; then
            echo "✓ 密钥 $i 生成成功"
        else
            echo "✗ 密钥 $i 生成失败"
            return 1
        fi
    done
    
    return 0
}

# 运行自定义测试
main() {
    parse_args "$@"
    check_dependencies
    
    # 运行标准测试
    run_tests
    
    # 运行自定义测试
    if test_custom_scenario; then
        log_success "自定义测试通过"
    else
        log_error "自定义测试失败"
        exit 1
    fi
}

main "$@"
```

## 总结

`test-admin-api.sh` 脚本为 quota-proxy 管理员接口提供了完整的测试解决方案：

- 🚀 **易于使用**：简单的命令行界面，清晰的帮助信息
- 🔧 **高度可配置**：支持环境变量、命令行参数多种配置方式
- 📊 **多种输出格式**：JSON 和文本格式，适合不同场景
- 🛡️ **安全可靠**：遵循安全最佳实践，支持安全令牌管理
- 🔄 **自动化友好**：适合 CI/CD 流水线和监控系统集成
- 🐛 **调试友好**：详细的错误信息和故障排除指南

通过定期运行管理员接口测试，可以确保 quota-proxy 服务的稳定性和可靠性，及时发现和解决问题。

## 相关资源

- [quota-proxy 快速入门指南](./quota-proxy-quickstart.md)
- [API 使用示例](./api-usage-examples.md)
- [自动化密钥管理](./automated-trial-key-management.md)
- [网络诊断工具](./network-diagnosis-tool.md)
- [安装验证指南](./install-verification.md)