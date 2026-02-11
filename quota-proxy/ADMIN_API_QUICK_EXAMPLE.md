# 管理API快速使用示例

本文档提供quota-proxy管理API的快速使用示例，帮助管理员快速上手管理功能。

## 前提条件

1. 已部署quota-proxy服务
2. 已设置`ADMIN_TOKEN`环境变量
3. 服务运行在`http://localhost:8787`（或相应地址）

## 快速开始

### 1. 创建试用密钥

```bash
# 创建试用密钥（无需管理员认证）
curl -X POST http://localhost:8787/admin/keys/trial \
  -H "Content-Type: application/json" \
  -d '{
    "label": "试用用户",
    "daily_limit": 100,
    "expires_in_days": 7
  }'
```

**响应示例：**
```json
{
  "success": true,
  "key": "roc_trial_abc123def456",
  "label": "试用用户",
  "total_quota": 100,
  "expires_at": "2026-02-18T17:56:51.000Z",
  "usageUrl": "http://localhost:8787/admin/usage?key=roc_trial_abc123def456"
}
```

### 2. 创建正式API密钥（需要管理员认证）

```bash
# 创建正式API密钥
curl -X POST http://localhost:8787/admin/keys \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: your-admin-token-here" \
  -d '{
    "label": "生产环境API密钥",
    "total_quota": 10000,
    "expires_in_days": 365
  }'
```

### 3. 查看使用统计

```bash
# 查看所有密钥的使用统计（最近7天）
curl -X GET "http://localhost:8787/admin/usage?days=7&page=1&limit=10" \
  -H "X-Admin-Token: your-admin-token-here"

# 查看特定密钥的使用统计
curl -X GET "http://localhost:8787/admin/usage?key=roc_trial_abc123def456&days=30" \
  -H "X-Admin-Token: your-admin-token-here"
```

**响应示例：**
```json
{
  "success": true,
  "data": [
    {
      "key": "roc_trial_abc123def456",
      "label": "试用用户",
      "total_quota": 100,
      "used_quota": 25,
      "created_at": "2026-02-11T17:56:51.000Z",
      "request_count": 15,
      "avg_response_time": 45.2
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 1,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPrevPage": false
  }
}
```

### 4. 列出所有API密钥

```bash
# 列出所有API密钥
curl -X GET "http://localhost:8787/admin/keys?page=1&limit=20" \
  -H "X-Admin-Token: your-admin-token-here"
```

### 5. 更新API密钥配额

```bash
# 更新API密钥配额
curl -X PUT http://localhost:8787/admin/keys/roc_trial_abc123def456 \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: your-admin-token-here" \
  -d '{
    "total_quota": 500,
    "label": "升级后的试用用户"
  }'
```

### 6. 删除API密钥

```bash
# 删除API密钥
curl -X DELETE http://localhost:8787/admin/keys/roc_trial_abc123def456 \
  -H "X-Admin-Token: your-admin-token-here"
```

### 7. 重置使用统计

```bash
# 重置特定密钥的使用统计
curl -X POST http://localhost:8787/admin/reset-usage \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: your-admin-token-here" \
  -d '{
    "key": "roc_trial_abc123def456"
  }'

# 重置所有密钥的使用统计
curl -X POST http://localhost:8787/admin/reset-usage \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: your-admin-token-here" \
  -d '{
    "reset_all": true
  }'
```

### 8. 查看数据库性能统计

```bash
# 查看数据库查询性能统计
curl -X GET http://localhost:8787/admin/performance \
  -H "X-Admin-Token: your-admin-token-here"
```

## 环境变量配置

在`.env`文件中配置管理功能：

```bash
# 管理配置
ADMIN_TOKEN=your-secure-admin-token-here
ADMIN_IP_WHITELIST=127.0.0.1,192.168.1.0/24

# 试用密钥配置
TRIAL_KEY_PREFIX=roc_trial_
DEFAULT_TRIAL_DAILY_LIMIT=100
DEFAULT_TRIAL_EXPIRY_DAYS=7

# 数据库配置
DB_PATH=./data/quota.db
```

## 安全建议

1. **保护ADMIN_TOKEN**：使用强密码，定期更换
2. **IP白名单**：在生产环境中配置`ADMIN_IP_WHITELIST`
3. **HTTPS**：在生产环境中启用HTTPS
4. **审计日志**：启用审计日志功能监控管理操作
5. **速率限制**：管理端点已内置速率限制

## 故障排除

### 常见问题

1. **401 Unauthorized**：检查`X-Admin-Token`头是否正确
2. **404 Not Found**：检查API密钥是否存在
3. **429 Too Many Requests**：管理端点请求过于频繁
4. **500 Internal Server Error**：检查数据库连接和日志

### 调试命令

```bash
# 检查服务状态
curl -f http://localhost:8787/healthz

# 检查管理端点是否可访问
curl -I http://localhost:8787/admin/keys -H "X-Admin-Token: your-admin-token-here"

# 查看服务日志
tail -f quota-proxy.log
```

## 相关文档

- [快速部署指南](./QUICK_DEPLOYMENT_GUIDE.md)
- [环境变量配置指南](./ENV_CONFIGURATION_GUIDE.md)
- [管理密钥和使用统计验证脚本](./verify-admin-keys-usage.sh)
- [部署状态检查脚本](./check-deployment-status.sh)

---

**版本历史**
- v1.0.0 (2026-02-11): 初始版本，提供管理API快速使用示例