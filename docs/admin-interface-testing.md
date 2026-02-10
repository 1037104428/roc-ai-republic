# Quota Proxy 管理接口测试指南

## 概述

本文档提供了 Quota Proxy 管理接口的完整测试方案，包括本地测试、远程测试和自动化验证脚本。

## 测试脚本

### 主要测试脚本

**`scripts/test-admin-interface.sh`** - 管理接口综合测试工具

```bash
# 基本用法
./scripts/test-admin-interface.sh

# 测试远程服务器
./scripts/test-admin-interface.sh --remote

# 使用自定义管理员令牌
ADMIN_TOKEN="your-secret-token" ./scripts/test-admin-interface.sh
./scripts/test-admin-interface.sh --admin-token "your-secret-token"

# 显示帮助
./scripts/test-admin-interface.sh --help
```

### 测试内容

脚本会自动测试以下管理接口：

1. **健康检查** (`GET /healthz`)
2. **创建试用密钥** (`POST /admin/keys`)
3. **获取密钥列表** (`GET /admin/keys`)
4. **查询使用情况** (`GET /admin/usage`)
5. **数据库性能统计** (`GET /admin/performance`)
6. **管理界面HTML** (`GET /admin`)

## 环境要求

### 本地测试
- Quota Proxy 服务运行在本地端口 8787
- 默认管理员令牌: `dev-admin-token-change-in-production`
- 可通过环境变量 `ADMIN_TOKEN` 覆盖

### 远程测试
- 需要 `/tmp/server.txt` 文件包含远程服务器IP
- 格式: `ip:8.210.185.194`
- 远程服务器必须开放 8787 端口

## 手动测试示例

### 1. 创建试用密钥

```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer dev-admin-token-change-in-production" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "测试用户",
    "totalQuota": 1000,
    "expiresAt": "2026-12-31T23:59:59Z"
  }'
```

### 2. 查看密钥列表

```bash
curl -X GET http://localhost:8787/admin/keys \
  -H "Authorization: Bearer dev-admin-token-change-in-production"
```

### 3. 查看使用情况

```bash
curl -X GET http://localhost:8787/admin/usage \
  -H "Authorization: Bearer dev-admin-token-change-in-production"
```

### 4. 查看数据库性能

```bash
curl -X GET http://localhost:8787/admin/performance \
  -H "Authorization: Bearer dev-admin-token-change-in-production"
```

## 测试验证点

### 功能验证
- [x] 管理员认证正常工作
- [x] 试用密钥创建功能正常
- [x] 密钥列表查询功能正常
- [x] 使用情况统计功能正常
- [x] 数据库性能监控功能正常
- [x] Web管理界面可访问

### 安全验证
- [x] 未授权访问被拒绝
- [x] 管理员令牌验证有效
- [x] 敏感操作需要认证

### 性能验证
- [x] 接口响应时间合理
- [x] 数据库查询性能正常
- [x] 并发处理能力足够

## 故障排除

### 常见问题

#### 1. 认证失败
```bash
# 错误: {"error":"Invalid admin token"}
# 解决方案: 检查 ADMIN_TOKEN 环境变量
export ADMIN_TOKEN="your-correct-token"
./scripts/test-admin-interface.sh
```

#### 2. 服务不可达
```bash
# 错误: curl_failed 或连接超时
# 解决方案: 检查服务状态
cd /opt/roc/quota-proxy
docker compose ps
curl http://localhost:8787/healthz
```

#### 3. 数据库错误
```bash
# 错误: {"error":"Database error"}
# 解决方案: 检查数据库连接
cd /opt/roc/quota-proxy
docker compose logs quota-proxy
```

#### 4. 远程测试失败
```bash
# 错误: /tmp/server.txt 文件不存在
# 解决方案: 创建服务器配置文件
echo "ip:8.210.185.194" > /tmp/server.txt
```

## 自动化集成

### CI/CD 集成示例

```yaml
# GitHub Actions 示例
name: Test Admin Interface

on: [push, pull_request]

jobs:
  test-admin:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Start Quota Proxy
      run: |
        cd quota-proxy
        docker compose up -d
        sleep 10
    
    - name: Run Admin Interface Tests
      run: |
        chmod +x scripts/test-admin-interface.sh
        ./scripts/test-admin-interface.sh --local
    
    - name: Cleanup
      run: |
        cd quota-proxy
        docker compose down
```

### 监控告警配置

```bash
# 定期健康检查
*/5 * * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/test-admin-interface.sh --remote > /tmp/admin-test.log 2>&1 || echo "Admin interface test failed" | mail -s "Quota Proxy Alert" admin@example.com
```

## 最佳实践

### 测试策略
1. **开发阶段**: 每次代码变更后运行本地测试
2. **部署阶段**: 部署前后运行远程测试
3. **监控阶段**: 定期运行自动化测试

### 安全建议
1. 生产环境使用强密码作为管理员令牌
2. 定期轮换管理员令牌
3. 记录所有管理操作日志
4. 限制管理接口的访问IP

### 性能优化
1. 使用连接池优化数据库查询
2. 缓存频繁访问的数据
3. 监控接口响应时间
4. 设置合理的请求限制

## 相关文档

- [ADMIN-INTERFACE.md](../quota-proxy/ADMIN-INTERFACE.md) - 管理接口详细说明
- [QUICKSTART.md](../quota-proxy/QUICKSTART.md) - 快速开始指南
- [DEPLOYMENT-VERIFICATION.md](../quota-proxy/DEPLOYMENT-VERIFICATION.md) - 部署验证指南