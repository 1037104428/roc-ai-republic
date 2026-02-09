# Admin API 快速使用指南

## 概述
quota-proxy 提供了管理员 API，用于管理试用密钥、查看使用情况和审批应用申请。

## 环境变量
```bash
# 管理员令牌（部署时设置）
export ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d
```

## API 端点

### 1. 创建试用密钥
```bash
# 创建带标签的试用密钥
curl -X POST http://localhost:8787/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "用户张三试用"}' \
  | jq .
```

响应示例：
```json
{
  "key": "sk-5f4dcc3b5aa765d61d8327deb882cf99",
  "label": "用户张三试用",
  "created_at": 1749600000000,
  "message": "Trial key created successfully"
}
```

### 2. 列出所有试用密钥
```bash
curl -X GET http://localhost:8787/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  | jq .
```

### 3. 查看使用情况
```bash
# 查看所有密钥的使用统计
curl -X GET http://localhost:8787/admin/usage \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  | jq .
```

### 4. 重置使用统计
```bash
# 重置指定密钥的使用统计
curl -X POST http://localhost:8787/admin/usage/reset \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key": "sk-5f4dcc3b5aa765d61d8327deb882cf99"}' \
  | jq .
```

### 5. 删除试用密钥
```bash
# 删除指定密钥
curl -X DELETE http://localhost:8787/admin/keys/sk-5f4dcc3b5aa765d61d8327deb882cf99 \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  | jq .
```

### 6. 查看应用申请
```bash
# 列出所有待审批的应用申请
curl -X GET http://localhost:8787/admin/applications \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  | jq .
```

### 7. 审批应用申请
```bash
# 批准申请并分配密钥
curl -X PUT http://localhost:8787/admin/applications/1 \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "approved", "key": "sk-5f4dcc3b5aa765d61d8327deb882cf99"}' \
  | jq .
```

## 验证脚本
使用 `scripts/check-admin-api-status.sh` 验证 admin API 状态：

```bash
# 本地验证
ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d ./scripts/check-admin-api-status.sh

# 远程服务器验证
ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d ./scripts/check-admin-api-status.sh --remote
```

## 常见问题

### Q: 如何获取 ADMIN_TOKEN？
A: 部署 quota-proxy 时通过环境变量设置：
```bash
ADMIN_TOKEN=your-secret-token-here node server-with-applications.js
```

### Q: API 返回 403 错误？
A: 检查 X-Admin-Token 头是否正确，确保与部署时设置的 ADMIN_TOKEN 一致。

### Q: 如何测试 API 而不影响生产数据？
A: 使用测试数据库或开发环境进行测试。

## 安全建议
1. **保护 ADMIN_TOKEN**：不要提交到版本控制
2. **限制访问**：确保 admin API 只能从可信网络访问
3. **定期轮换**：定期更换 ADMIN_TOKEN
4. **监控日志**：监控 admin API 的访问日志