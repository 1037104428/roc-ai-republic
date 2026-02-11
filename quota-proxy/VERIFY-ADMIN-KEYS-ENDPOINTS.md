# Admin Keys API 端点验证指南

## 概述

本文档提供 `verify-admin-keys-endpoints.sh` 脚本的使用指南，该脚本用于验证 quota-proxy 服务中的 Admin Keys API 端点是否正常工作。脚本支持健康检查、试用密钥生成、管理员密钥生成、密钥列表和使用情况查询等端点的验证。

## 快速开始

### 1. 前提条件

- 已安装 `curl` 命令
- quota-proxy 服务正在运行
- 管理员令牌（ADMIN_TOKEN）已配置

### 2. 基本使用

```bash
# 授予执行权限
chmod +x verify-admin-keys-endpoints.sh

# 基本验证（使用默认配置）
./verify-admin-keys-endpoints.sh

# 干运行模式（只显示步骤，不实际执行）
./verify-admin-keys-endpoints.sh --dry-run

# 详细输出模式
./verify-admin-keys-endpoints.sh --verbose
```

### 3. 环境变量配置

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token-here"

# 设置自定义主机和端口
export HOST="192.168.1.100"
export PORT="8080"

# 运行验证
./verify-admin-keys-endpoints.sh
```

## 功能特性

### 验证的端点

1. **健康检查** (`GET /healthz`)
   - 验证服务是否正常运行
   - 检查数据库连接状态

2. **试用密钥生成** (`POST /admin/keys/trial`)
   - 验证试用密钥生成功能
   - 检查密钥格式和响应结构
   - 验证IP限制机制（每小时3次）

3. **管理员密钥生成** (`POST /admin/keys`)
   - 验证管理员密钥生成功能
   - 检查认证机制（Bearer Token）
   - 验证请求参数处理

4. **管理员密钥列表** (`GET /admin/keys`)
   - 验证密钥列表查询功能
   - 检查分页和过滤参数

5. **管理员使用情况** (`GET /admin/usage`)
   - 验证使用情况统计功能
   - 检查数据聚合和分页

### 脚本特性

- **彩色输出**：不同级别的日志使用不同颜色
- **干运行模式**：预览将要执行的步骤，不实际调用API
- **详细输出**：显示完整的请求和响应信息
- **灵活配置**：支持命令行参数和环境变量
- **错误处理**：详细的错误信息和故障排除建议
- **验证总结**：清晰的测试结果汇总

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--dry-run` | `-d` | 干运行模式，只显示步骤 | `false` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--host` | - | 服务器主机地址 | `127.0.0.1` |
| `--port` | - | 服务器端口 | `8787` |
| `--token` | - | 管理员令牌 | 从环境变量读取 |
| `--timeout` | - | 请求超时时间(秒) | `10` |
| `--skip-health` | - | 跳过健康检查 | `false` |
| `--skip-trial` | - | 跳过试用密钥测试 | `false` |
| `--skip-admin` | - | 跳过管理员密钥测试 | `false` |

## 使用示例

### 示例 1：基本验证

```bash
# 使用默认配置验证所有端点
./verify-admin-keys-endpoints.sh
```

输出示例：
```
[INFO] 开始验证 Admin Keys API 端点
[INFO] 服务器: http://127.0.0.1:8787
[INFO] 管理员令牌: dev-admin-t...
[INFO] 超时设置: 10秒
[INFO] 检查服务器是否运行在 http://127.0.0.1:8787
[SUCCESS] 服务器正在运行
[INFO] 执行健康检查
[SUCCESS] 健康检查通过
[INFO] 测试试用密钥生成端点: POST http://127.0.0.1:8787/admin/keys/trial
[SUCCESS] 试用密钥生成端点测试通过
[INFO] 生成的管理员密钥: roc_trial_1740313612345-abc123def
[SUCCESS] 试用密钥格式正确
[INFO] 测试管理员密钥生成端点: POST http://127.0.0.1:8787/admin/keys
[SUCCESS] 管理员密钥生成端点测试通过
[INFO] 生成的管理员密钥: roc_1740313612345-xyz789uvw
[SUCCESS] 管理员密钥格式正确
[INFO] 测试管理员密钥列表端点: GET http://127.0.0.1:8787/admin/keys
[SUCCESS] 管理员密钥列表端点测试通过
[INFO] 找到 5 个密钥
[INFO] 测试管理员使用情况端点: GET http://127.0.0.1:8787/admin/usage
[SUCCESS] 管理员使用情况端点测试通过
[INFO] === 验证总结 ===
[INFO] 测试通过: 5
[INFO] 测试失败: 0
[INFO] 测试跳过: 0
[SUCCESS] 所有测试通过！Admin Keys API 端点验证成功
[SUCCESS] ✅ Admin Keys API 端点验证完成，所有端点正常工作
```

### 示例 2：自定义配置验证

```bash
# 验证远程服务器
./verify-admin-keys-endpoints.sh \
  --host 192.168.1.100 \
  --port 8080 \
  --token "my-production-token" \
  --timeout 15 \
  --verbose
```

### 示例 3：部分验证

```bash
# 只验证健康检查和试用密钥端点
./verify-admin-keys-endpoints.sh \
  --skip-admin \
  --dry-run
```

### 示例 4：CI/CD 集成

```bash
# 在CI/CD流水线中使用
export ADMIN_TOKEN="${SECRET_ADMIN_TOKEN}"
if ./verify-admin-keys-endpoints.sh --host "${DEPLOY_HOST}" --port "${DEPLOY_PORT}"; then
  echo "API端点验证通过，可以继续部署"
else
  echo "API端点验证失败，停止部署"
  exit 1
fi
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: Verify Admin Keys API Endpoints

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-api:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: |
        cd quota-proxy
        npm ci
        
    - name: Start quota-proxy server
      run: |
        cd quota-proxy
        ADMIN_TOKEN="ci-test-token" npm start &
        sleep 5
        
    - name: Verify API endpoints
      run: |
        cd quota-proxy
        chmod +x verify-admin-keys-endpoints.sh
        ./verify-admin-keys-endpoints.sh \
          --token "ci-test-token" \
          --timeout 30
```

### GitLab CI 示例

```yaml
stages:
  - test

verify-api:
  stage: test
  image: node:18-alpine
  script:
    - cd quota-proxy
    - npm ci
    - ADMIN_TOKEN="ci-test-token" npm start &
    - sleep 5
    - chmod +x verify-admin-keys-endpoints.sh
    - ./verify-admin-keys-endpoints.sh --token "ci-test-token" --timeout 30
```

## 故障排除

### 常见问题

#### 1. 服务器无法访问

**症状**：
```
[ERROR] 服务器未运行或无法访问
```

**解决方案**：
- 检查 quota-proxy 服务是否正在运行
- 验证主机和端口配置是否正确
- 检查防火墙设置

#### 2. 管理员令牌无效

**症状**：
```
[ERROR] 管理员密钥生成端点测试失败
[ERROR] 管理员令牌无效，请检查 ADMIN_TOKEN 配置
```

**解决方案**：
- 确认 ADMIN_TOKEN 环境变量已正确设置
- 检查服务器端的令牌配置
- 使用 `--verbose` 选项查看详细错误信息

#### 3. 试用密钥生成限制

**症状**：
```
[ERROR] 试用密钥生成端点测试失败
```

**解决方案**：
- 检查是否达到每小时3次的IP限制
- 等待限制重置或使用不同的IP地址
- 检查服务器日志了解具体错误

#### 4. 数据库连接问题

**症状**：
```
[ERROR] 健康检查失败
```

**解决方案**：
- 检查数据库配置
- 验证数据库文件权限
- 查看服务器日志中的数据库错误

### 诊断命令

```bash
# 检查服务状态
curl -s http://127.0.0.1:8787/healthz | python3 -m json.tool

# 检查服务基本信息
curl -s http://127.0.0.1:8787/status | python3 -m json.tool

# 手动测试试用密钥生成
curl -X POST -H "Content-Type: application/json" http://127.0.0.1:8787/admin/keys/trial

# 手动测试管理员密钥生成
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"label":"测试密钥","totalQuota":100}' \
  http://127.0.0.1:8787/admin/keys
```

## 最佳实践

### 1. 生产环境部署

- 使用强密码生成器创建安全的 ADMIN_TOKEN
- 定期轮换管理员令牌
- 启用 IP 白名单保护 Admin API
- 配置适当的日志级别和日志轮转

### 2. 监控和告警

- 将健康检查集成到监控系统
- 设置试用密钥生成频率告警
- 监控数据库性能和连接数
- 定期审计密钥使用情况

### 3. 安全建议

- 不要在代码中硬编码管理员令牌
- 使用环境变量或密钥管理服务
- 限制 Admin API 的访问权限
- 启用 HTTPS 加密通信
- 定期进行安全审计

### 4. 性能优化

- 为高频使用的端点添加缓存
- 优化数据库查询性能
- 使用连接池管理数据库连接
- 监控端点响应时间

## 扩展和定制

### 添加新的测试用例

要添加新的测试用例，可以修改 `verify-admin-keys-endpoints.sh` 脚本，添加新的测试函数：

```bash
# 示例：添加新的端点测试
test_new_endpoint() {
    log_info "测试新的端点: GET ${BASE_URL}/admin/new-endpoint"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "干运行模式：将执行 curl 命令"
        return 0
    fi
    
    # 实际的测试逻辑
    # ...
}
```

### 集成到现有系统

脚本可以轻松集成到现有的 DevOps 流程中：

```bash
# 在部署脚本中集成
deploy_and_verify() {
    echo "开始部署..."
    # 部署逻辑...
    
    echo "验证 API 端点..."
    if ./verify-admin-keys-endpoints.sh --host "${NEW_HOST}" --port "${NEW_PORT}"; then
        echo "验证成功，切换流量"
        # 切换流量逻辑...
    else
        echo "验证失败，回滚部署"
        # 回滚逻辑...
    fi
}
```

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持健康检查、试用密钥生成、管理员密钥生成等端点验证
- 支持干运行模式和详细输出
- 提供完整的文档和示例

## 支持与反馈

如果在使用过程中遇到问题或有改进建议：

1. 查看本文档的故障排除部分
2. 检查服务器日志获取详细错误信息
3. 使用 `--verbose` 选项获取详细输出
4. 提交 Issue 或 Pull Request 到项目仓库

---

**注意**：本验证脚本仅用于测试目的，请勿在生产环境中直接使用测试生成的密钥。生产环境应使用正式的管理流程生成和管理密钥。