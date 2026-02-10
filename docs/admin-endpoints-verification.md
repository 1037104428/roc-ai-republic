# 管理端点验证指南

本文档介绍如何验证 quota-proxy 的管理端点功能，包括密钥管理、使用统计和系统监控。

## 概述

quota-proxy 提供了完整的管理 API 端点，用于：

1. **密钥管理** (`/admin/keys`) - 创建、查看、更新、删除 API 密钥
2. **使用统计** (`/admin/usage`) - 查看系统使用情况统计
3. **系统统计** (`/admin/stats`) - 查看服务器和数据库统计信息

## 快速开始

### 1. 验证脚本

使用提供的验证脚本一键测试所有管理端点：

```bash
# 查看帮助
./scripts/verify-admin-endpoints.sh --help

# 验证本地实例 (需要设置 ADMIN_TOKEN 环境变量)
export ADMIN_TOKEN="your-admin-token-here"
./scripts/verify-admin-endpoints.sh --local --verbose

# 验证远程实例
./scripts/verify-admin-endpoints.sh --remote 8.210.185.194 --admin-token your-token

# 干运行模式 (只显示命令)
./scripts/verify-admin-endpoints.sh --local --dry-run
```

### 2. 手动验证

#### 检查服务健康
```bash
curl -fsS http://localhost:8787/healthz
# 或远程
curl -fsS http://8.210.185.194:8787/healthz
```

#### 获取系统统计 (公开端点)
```bash
curl http://localhost:8787/admin/stats | jq .
```

响应示例：
```json
{
  "server": {
    "info": "quota-proxy v1.0.0",
    "uptime": 12345,
    "memoryUsage": "45.2 MB"
  },
  "database": {
    "totalKeys": 42,
    "activeKeys": 38,
    "quotaUsed": 12500
  },
  "requests": {
    "total": 1500,
    "lastHour": 120,
    "byEndpoint": {
      "/api/test": 800,
      "/api/chat": 700
    }
  }
}
```

#### 管理密钥 (需要管理令牌)

**获取密钥列表:**
```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/keys | jq .
```

**创建新密钥:**
```bash
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "测试用户",
    "quota": 1000,
    "expiresAt": "2026-02-17T12:00:00Z"
  }' \
  http://localhost:8787/admin/keys | jq .
```

响应包含生成的 API 密钥：
```json
{
  "key": "sk_test_abc123def456",
  "name": "测试用户",
  "quota": 1000,
  "remaining": 1000,
  "expiresAt": "2026-02-17T12:00:00Z",
  "createdAt": "2026-02-10T12:14:53Z"
}
```

**获取使用统计:**
```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/usage | jq .
```

## 端点详细说明

### GET /admin/stats
- **认证**: 不需要
- **功能**: 获取系统实时统计信息
- **响应字段**:
  - `server`: 服务器信息 (运行时间、内存使用、版本)
  - `database`: 数据库统计 (密钥数量、配额使用)
  - `requests`: 请求统计 (总量、按端点分布)

### GET /admin/keys
- **认证**: 需要管理令牌
- **功能**: 获取所有 API 密钥列表
- **查询参数**:
  - `limit`: 返回数量限制 (默认: 100)
  - `offset`: 偏移量 (默认: 0)
  - `activeOnly`: 只返回活跃密钥 (true/false)

### POST /admin/keys
- **认证**: 需要管理令牌
- **功能**: 创建新的 API 密钥
- **请求体**:
  ```json
  {
    "name": "密钥名称",
    "quota": 1000,
    "expiresAt": "2026-02-17T12:00:00Z"
  }
  ```
- **响应**: 包含生成的密钥字符串

### GET /admin/usage
- **认证**: 需要管理令牌
- **功能**: 获取系统使用情况统计
- **响应字段**:
  - `totalRequests`: 总请求数
  - `activeKeys`: 活跃密钥数量
  - `quotaUsed`: 已使用的配额总量
  - `requestsByDay`: 按天的请求统计
  - `topUsers`: 使用量最高的用户

### PUT /admin/keys/:key
- **认证**: 需要管理令牌
- **功能**: 更新密钥信息 (配额、过期时间等)

### DELETE /admin/keys/:key
- **认证**: 需要管理令牌
- **功能**: 删除指定的 API 密钥

## 验证脚本功能

`verify-admin-endpoints.sh` 脚本提供以下验证：

1. **服务健康检查** - 验证 `/healthz` 端点
2. **系统统计验证** - 验证 `/admin/stats` 端点
3. **密钥管理验证** - 测试完整的密钥生命周期:
   - 获取现有密钥列表
   - 创建测试密钥
   - 验证新密钥可用性
   - 清理测试密钥
4. **使用统计验证** - 验证 `/admin/usage` 端点

## 故障排除

### 常见问题

1. **认证失败**
   ```
   curl: (22) The requested URL returned error: 401
   ```
   **解决方案**: 确保提供了正确的管理令牌
   ```bash
   export ADMIN_TOKEN="正确的管理令牌"
   ```

2. **服务未运行**
   ```
   [ERROR] 服务未运行或无法访问
   ```
   **解决方案**: 启动 quota-proxy 服务
   ```bash
   cd /opt/roc/quota-proxy
   docker compose up -d
   ```

3. **端口被占用**
   ```
   curl: (7) Failed to connect to localhost port 8787
   ```
   **解决方案**: 检查端口占用或修改配置
   ```bash
   netstat -tlnp | grep 8787
   ```

### 调试模式

使用详细模式查看完整的请求和响应：

```bash
./scripts/verify-admin-endpoints.sh --local --verbose --admin-token your-token
```

## 集成测试

### 在 CI/CD 管道中使用

```yaml
# GitHub Actions 示例
jobs:
  verify-admin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: 验证管理端点
        run: |
          chmod +x ./scripts/verify-admin-endpoints.sh
          ./scripts/verify-admin-endpoints.sh --dry-run
        env:
          ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
```

### 定时健康检查

设置定时任务定期验证管理端点：

```bash
# 每天检查一次
0 2 * * * cd /path/to/roc-ai-republic && ./scripts/verify-admin-endpoints.sh --remote your-server.com >> /var/log/quota-proxy-verify.log 2>&1
```

## 相关文档

- [快速开始指南](./quickstart.md) - 完整的安装和配置指南
- [API 网关配置](./api-gateway-guide.md) - API 网关详细配置
- [验证脚本指南](./verification-scripts-guide.md) - 所有验证脚本的使用说明

## 更新日志

- **2026-02-10**: 创建管理端点验证脚本和文档
- **2026-02-09**: 新增 `/admin/stats` 端点
- **2026-02-08**: 完善密钥管理 API

---

**下一步**: 查看 [部署指南](./deployment-guide.md) 了解生产环境部署建议。