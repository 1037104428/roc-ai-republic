# POST /admin/keys 接口测试指南

本文档提供POST /admin/keys接口的测试指南，包括测试脚本使用说明、测试场景、故障排除和最佳实践。

## 概述

`test-post-admin-keys.sh` 脚本是一个专门用于测试quota-proxy的POST /admin/keys接口的工具。它提供了完整的测试流程，包括健康检查、trial key创建和keys列表获取。

## 功能特性

- ✅ **健康检查**：验证quota-proxy服务是否正常运行
- ✅ **POST /admin/keys测试**：测试trial key创建功能
- ✅ **GET /admin/keys测试**：测试keys列表获取功能
- ✅ **多种运行模式**：支持详细模式、模拟运行模式
- ✅ **灵活的配置**：支持命令行参数和环境变量配置
- ✅ **彩色输出**：提供直观的彩色输出，便于识别测试结果
- ✅ **标准化退出码**：提供标准化的退出码，便于自动化集成

## 快速开始

### 1. 基本使用

```bash
# 查看帮助信息
./scripts/test-post-admin-keys.sh --help

# 使用默认配置测试本地服务
./scripts/test-post-admin-keys.sh

# 测试远程服务
./scripts/test-post-admin-keys.sh -H 8.210.185.194 -p 8787 -t "your-admin-token"

# 详细输出模式
./scripts/test-post-admin-keys.sh -v

# 模拟运行（不实际发送请求）
./scripts/test-post-admin-keys.sh -d
```

### 2. 使用环境变量

```bash
# 设置环境变量
export QUOTA_PROXY_HOST="8.210.185.194"
export QUOTA_PROXY_PORT="8787"
export ADMIN_TOKEN="your-admin-token"

# 运行测试
./scripts/test-post-admin-keys.sh
```

## 测试场景

### 场景1：本地开发环境测试

```bash
# 假设本地quota-proxy运行在默认端口
./scripts/test-post-admin-keys.sh -v
```

### 场景2：生产环境测试

```bash
# 测试生产环境，使用生产环境的ADMIN_TOKEN
ADMIN_TOKEN="production-secret-token" ./scripts/test-post-admin-keys.sh -H api.example.com -p 443
```

### 场景3：CI/CD集成测试

```bash
# 在CI/CD流水线中使用
if ./scripts/test-post-admin-keys.sh -H "$QUOTA_PROXY_HOST" -t "$ADMIN_TOKEN"; then
    echo "✅ API测试通过"
else
    echo "❌ API测试失败"
    exit 1
fi
```

## 测试流程

脚本执行以下测试步骤：

1. **健康检查**：验证`/healthz`端点是否正常响应
2. **POST /admin/keys测试**：创建新的trial key
   - 验证HTTP 201状态码
   - 验证响应包含有效的key_id
3. **GET /admin/keys测试**：获取keys列表
   - 验证HTTP 200状态码
   - 验证响应为有效的JSON格式

## 预期响应

### 成功创建trial key (HTTP 201)

```json
{
  "key_id": "trial_1234567890abcdef",
  "api_key": "ak_1234567890abcdef",
  "name": "测试用户",
  "email": "test@example.com",
  "company": "测试公司",
  "notes": "这是测试创建的trial key",
  "created_at": "2026-02-10T21:50:52Z",
  "expires_at": "2026-03-12T21:50:52Z",
  "max_requests_per_day": 1000,
  "requests_today": 0
}
```

### 成功获取keys列表 (HTTP 200)

```json
{
  "keys": [
    {
      "key_id": "trial_1234567890abcdef",
      "name": "测试用户",
      "email": "test@example.com",
      "company": "测试公司",
      "created_at": "2026-02-10T21:50:52Z",
      "expires_at": "2026-03-12T21:50:52Z",
      "max_requests_per_day": 1000,
      "requests_today": 0,
      "total_requests": 0
    }
  ],
  "total": 1,
  "page": 1,
  "per_page": 50
}
```

## 故障排除

### 常见问题

#### 1. 连接失败

**症状**：脚本无法连接到quota-proxy服务

**解决方案**：
- 检查服务是否运行：`docker compose ps`
- 检查端口是否正确：`netstat -tlnp | grep 8787`
- 检查防火墙设置

#### 2. 未授权错误 (HTTP 401)

**症状**：收到HTTP 401状态码

**解决方案**：
- 检查ADMIN_TOKEN是否正确
- 验证token格式：应该是Bearer token
- 检查服务配置中的ADMIN_TOKEN环境变量

#### 3. 请求参数错误 (HTTP 400)

**症状**：收到HTTP 400状态码

**解决方案**：
- 检查请求体JSON格式
- 验证必填字段（name, email）
- 检查字段类型和长度限制

### 调试技巧

1. **启用详细模式**：使用`-v`参数查看详细输出
2. **模拟运行**：使用`-d`参数查看将要发送的请求
3. **手动测试**：使用curl手动测试接口

```bash
# 手动测试健康端点
curl -v http://127.0.0.1:8787/healthz

# 手动测试POST /admin/keys
curl -v -X POST http://127.0.0.1:8787/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-token" \
  -d '{"name":"测试","email":"test@example.com"}'
```

## 最佳实践

### 1. 安全实践

- **保护ADMIN_TOKEN**：不要在脚本中硬编码token，使用环境变量
- **最小权限**：测试环境使用测试token，生产环境使用生产token
- **定期轮换**：定期更换ADMIN_TOKEN

### 2. 测试实践

- **自动化测试**：将测试集成到CI/CD流水线中
- **定期测试**：定期运行测试，确保API功能正常
- **环境隔离**：为不同环境（开发、测试、生产）使用不同的配置

### 3. 监控实践

- **监控测试结果**：记录测试成功/失败率
- **告警机制**：测试失败时发送告警
- **性能监控**：监控API响应时间

## 集成指南

### 与CI/CD集成

```yaml
# GitHub Actions示例
name: API Tests
on: [push, pull_request]
jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test POST /admin/keys API
        run: |
          chmod +x ./scripts/test-post-admin-keys.sh
          ./scripts/test-post-admin-keys.sh \
            -H "${{ secrets.QUOTA_PROXY_HOST }}" \
            -t "${{ secrets.ADMIN_TOKEN }}"
        env:
          QUOTA_PROXY_PORT: "${{ secrets.QUOTA_PROXY_PORT }}"
```

### 与监控系统集成

```bash
# 定期测试并记录结果
#!/bin/bash
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
LOG_FILE="/var/log/quota-proxy-api-test.log"

if ./scripts/test-post-admin-keys.sh -H api.example.com -t "$ADMIN_TOKEN"; then
    echo "$TIMESTAMP - SUCCESS - API测试通过" >> "$LOG_FILE"
else
    echo "$TIMESTAMP - ERROR - API测试失败" >> "$LOG_FILE"
    # 发送告警
    send_alert "quota-proxy API测试失败"
fi
```

## 相关文档

- [quota-proxy工具链概览](../docs/quota-proxy-toolchain-overview.md)
- [admin keys & usage接口测试指南](../docs/quota-proxy-admin-keys-usage-testing.md)
- [GET /admin/usage API使用示例](../docs/admin-usage-api-examples.md)

## 支持与反馈

如果在使用过程中遇到问题，请：

1. 检查本文档的故障排除部分
2. 查看脚本的详细输出（使用`-v`参数）
3. 在项目仓库中提交Issue

---

**最后更新**：2026-02-10  
**版本**：1.0.0  
**维护者**：中华AI共和国项目组