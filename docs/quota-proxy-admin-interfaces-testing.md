# quota-proxy 管理接口测试指南

本文档提供 quota-proxy 管理接口（POST /admin/keys 和 GET /admin/usage）的详细测试指南，包括测试脚本的使用方法、测试用例说明和故障排除。

## 概述

quota-proxy 提供了两个核心管理接口：

1. **POST /admin/keys** - 创建 trial key
2. **GET /admin/usage** - 获取使用情况统计

这些接口受管理员 token 保护，需要正确的授权才能访问。

## 测试脚本

我们提供了一个专门的测试脚本 `test-quota-proxy-admin-interfaces.sh`，用于验证这些接口的功能。

### 脚本功能

测试脚本包含以下测试用例：

1. **健康检查** - 验证 /healthz 端点
2. **未授权访问保护** - 验证管理接口的安全保护
3. **创建 trial key** - 测试 POST /admin/keys 接口
4. **获取 keys 列表** - 测试 GET /admin/keys 接口
5. **获取使用情况统计** - 测试 GET /admin/usage 接口
6. **清理测试数据** - 自动清理测试过程中创建的 keys

### 安装与使用

#### 1. 下载脚本

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 确保脚本可执行
chmod +x scripts/test-quota-proxy-admin-interfaces.sh
```

#### 2. 基本用法

```bash
# 显示帮助信息
./scripts/test-quota-proxy-admin-interfaces.sh --help

# 列出所有测试用例
./scripts/test-quota-proxy-admin-interfaces.sh --list

# 基本测试（使用默认配置）
./scripts/test-quota-proxy-admin-interfaces.sh

# 详细输出模式
./scripts/test-quota-proxy-admin-interfaces.sh --verbose

# 模拟运行（不实际发送请求）
./scripts/test-quota-proxy-admin-interfaces.sh --dry-run
```

#### 3. 自定义配置

```bash
# 指定主机和端口
./scripts/test-quota-proxy-admin-interfaces.sh --host localhost --port 8787

# 指定管理员 token
./scripts/test-quota-proxy-admin-interfaces.sh --token "your-admin-token-here"

# 组合使用
./scripts/test-quota-proxy-admin-interfaces.sh \
  --host 8.210.185.194 \
  --port 8787 \
  --token "your-admin-token" \
  --verbose
```

#### 4. 使用环境变量

```bash
# 设置环境变量
export QUOTA_PROXY_HOST="8.210.185.194"
export QUOTA_PROXY_PORT="8787"
export QUOTA_ADMIN_TOKEN="your-admin-token"
export VERBOSE="true"

# 运行测试
./scripts/test-quota-proxy-admin-interfaces.sh
```

### 测试用例详解

#### 测试 1: 健康检查
- **目的**: 验证 quota-proxy 服务是否正常运行
- **测试端点**: GET /healthz
- **期望响应**: HTTP 200 OK
- **验证内容**: 服务基础健康状态

#### 测试 2: 未授权访问保护
- **目的**: 验证管理接口的安全保护机制
- **测试端点**: GET /admin/keys（不带授权头）
- **期望响应**: HTTP 401 Unauthorized 或错误消息
- **验证内容**: 未授权用户无法访问管理接口

#### 测试 3: 创建 trial key
- **目的**: 测试 POST /admin/keys 接口的功能
- **测试端点**: POST /admin/keys
- **请求体**: 
  ```json
  {
    "label": "测试密钥",
    "totalQuota": 500
  }
  ```
- **期望响应**: HTTP 200 OK，包含创建的 key 信息
- **验证内容**: key 创建成功，返回正确的 key 值

#### 测试 4: 获取 keys 列表
- **目的**: 测试 GET /admin/keys 接口的功能
- **测试端点**: GET /admin/keys
- **期望响应**: HTTP 200 OK，包含 keys 列表
- **验证内容**: 返回的列表包含创建的测试 key

#### 测试 5: 获取使用情况统计
- **目的**: 测试 GET /admin/usage 接口的功能
- **测试端点**: GET /admin/usage
- **期望响应**: HTTP 200 OK，包含使用统计信息
- **验证内容**: 返回格式正确的使用统计数据

#### 测试 6: 清理测试数据
- **目的**: 清理测试过程中创建的 keys
- **测试端点**: DELETE /admin/keys/{key}
- **期望响应**: HTTP 200 OK
- **验证内容**: 测试 key 被成功删除

## 服务器端测试

### 1. 本地测试（开发环境）

```bash
# 确保 quota-proxy 在本地运行
cd /opt/roc/quota-proxy
docker compose up -d

# 运行测试
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/test-quota-proxy-admin-interfaces.sh \
  --host localhost \
  --port 8787 \
  --token "$(grep ADMIN_TOKEN /opt/roc/quota-proxy/.env | cut -d= -f2)" \
  --verbose
```

### 2. 远程服务器测试

```bash
# 从本地测试远程服务器
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/test-quota-proxy-admin-interfaces.sh \
  --host 8.210.185.194 \
  --port 8787 \
  --token "your-remote-admin-token" \
  --verbose
```

### 3. 在服务器上直接测试

```bash
# SSH 到服务器
ssh root@8.210.185.194

# 在服务器上运行测试
cd /opt/roc/quota-proxy
curl -s -f http://localhost:8787/healthz

# 测试管理接口（需要管理员 token）
ADMIN_TOKEN="$(cat .env | grep ADMIN_TOKEN | cut -d= -f2)"
curl -s -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  http://localhost:8787/admin/keys
```

## 故障排除

### 常见问题

#### 1. 连接失败
```
错误: 健康检查失败
```
**解决方案**:
- 检查 quota-proxy 服务是否运行: `docker compose ps`
- 检查端口是否正确: `netstat -tlnp | grep 8787`
- 检查防火墙设置

#### 2. 授权失败
```
错误: 未授权访问保护失败
```
**解决方案**:
- 检查管理员 token 是否正确
- 检查 .env 文件中的 ADMIN_TOKEN 设置
- 验证 token 格式: 应该是有效的字符串

#### 3. 接口返回错误
```
错误: HTTP状态码不匹配
```
**解决方案**:
- 检查 quota-proxy 日志: `docker compose logs quota-proxy`
- 验证数据库连接: 检查 SQLite 数据库文件是否存在
- 检查环境变量配置

### 调试技巧

#### 1. 启用详细日志
```bash
# 查看 quota-proxy 容器日志
docker compose logs -f quota-proxy

# 启用详细输出
export VERBOSE=true
./scripts/test-quota-proxy-admin-interfaces.sh --verbose
```

#### 2. 手动测试接口
```bash
# 测试健康端点
curl -v http://localhost:8787/healthz

# 测试管理接口（带授权）
curl -v -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  http://localhost:8787/admin/keys

# 创建测试 key
curl -v -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"label":"手动测试","totalQuota":100}' \
  http://localhost:8787/admin/keys
```

#### 3. 检查数据库状态
```bash
# 检查 SQLite 数据库
sqlite3 /opt/roc/quota-proxy/data/quota.db ".tables"
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT * FROM api_keys LIMIT 5;"
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT * FROM usage_log LIMIT 5;"
```

## 集成测试

### 1. CI/CD 集成

将测试脚本集成到 CI/CD 流程中：

```yaml
# GitHub Actions 示例
name: Test quota-proxy interfaces

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Test quota-proxy interfaces
      run: |
        chmod +x scripts/test-quota-proxy-admin-interfaces.sh
        ./scripts/test-quota-proxy-admin-interfaces.sh \
          --host localhost \
          --port 8787 \
          --dry-run \
          --verbose
```

### 2. 监控集成

将接口测试集成到监控系统中：

```bash
# 定期测试脚本
*/5 * * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && \
  ./scripts/test-quota-proxy-admin-interfaces.sh \
    --host localhost \
    --port 8787 \
    --token "${ADMIN_TOKEN}" \
    --skip-cleanup >> /var/log/quota-proxy-test.log 2>&1
```

## 最佳实践

### 1. 测试环境管理
- 使用不同的 token 用于测试和生产环境
- 定期清理测试数据
- 记录测试结果用于审计

### 2. 安全注意事项
- 不要将管理员 token 硬编码在脚本中
- 使用环境变量或密钥管理服务
- 定期轮换管理员 token

### 3. 性能考虑
- 测试脚本设计为轻量级，避免对生产环境造成压力
- 支持 dry-run 模式用于预检查
- 提供详细的日志记录用于问题诊断

## 总结

quota-proxy 的管理接口测试是确保服务可靠性的重要环节。通过使用提供的测试脚本，您可以：

1. **快速验证**接口功能是否正常
2. **自动化测试**流程，减少人工操作
3. **集成监控**，及时发现服务问题
4. **确保安全**，验证授权保护机制

定期运行这些测试可以帮助您及时发现和解决问题，确保 quota-proxy 服务的稳定运行。