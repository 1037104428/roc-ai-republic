# Quota-Proxy 管理 API 快速指南

## 概述

Quota-Proxy 提供了一套完整的管理 API，用于管理试用密钥、查看使用情况、重置统计等操作。所有管理 API 都需要 `ADMIN_TOKEN` 认证。

## 快速开始

### 1. 环境准备

确保 quota-proxy 已启动并配置了正确的环境变量：

```bash
# 检查服务状态
cd /opt/roc/quota-proxy
docker compose ps

# 检查健康状态
curl -fsS http://127.0.0.1:8787/healthz
```

### 2. 获取 ADMIN_TOKEN

ADMIN_TOKEN 在 `.env` 文件中配置：

```bash
# 查看当前配置
grep ADMIN_TOKEN /opt/roc/quota-proxy/.env

# 如果没有配置，可以生成一个
echo "ADMIN_TOKEN=$(openssl rand -hex 32)" >> /opt/roc/quota-proxy/.env
```

### 3. 设置认证头

所有管理 API 请求都需要在 Header 中包含认证信息：

```bash
export ADMIN_TOKEN="your-admin-token-here"
export AUTH_HEADER="Authorization: Bearer $ADMIN_TOKEN"
```

## API 端点

### 1. 生成试用密钥

**POST** `/admin/keys`

生成新的试用密钥，可以指定有效期和配额限制。

```bash
# 生成默认密钥（7天有效期，1000次配额）
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{}'

# 生成自定义密钥
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "valid_days": 30,
    "quota_limit": 5000,
    "note": "VIP客户试用"
  }'
```

**响应示例：**
```json
{
  "key": "trial_abc123def456",
  "valid_until": "2026-03-13T10:47:53.000Z",
  "quota_limit": 1000,
  "note": "VIP客户试用"
}
```

### 2. 查看使用情况

**GET** `/admin/usage`

查看所有密钥的使用统计。

```bash
# 查看所有使用情况
curl -X GET http://127.0.0.1:8787/admin/usage \
  -H "$AUTH_HEADER"

# 查看特定密钥使用情况
curl -X GET "http://127.0.0.1:8787/admin/usage?key=trial_abc123def456" \
  -H "$AUTH_HEADER"
```

**响应示例：**
```json
{
  "total_keys": 15,
  "active_keys": 12,
  "expired_keys": 3,
  "total_requests": 12500,
  "usage_by_key": [
    {
      "key": "trial_abc123def456",
      "requests_today": 45,
      "requests_total": 320,
      "quota_limit": 1000,
      "remaining_quota": 680,
      "valid_until": "2026-03-13T10:47:53.000Z",
      "is_active": true
    }
  ]
}
```

### 3. 列出所有密钥

**GET** `/admin/keys`

列出所有已生成的密钥。

```bash
# 列出所有密钥
curl -X GET http://127.0.0.1:8787/admin/keys \
  -H "$AUTH_HEADER"

# 分页查询
curl -X GET "http://127.0.0.1:8787/admin/keys?page=1&limit=10" \
  -H "$AUTH_HEADER"
```

**响应示例：**
```json
{
  "keys": [
    {
      "key": "trial_abc123def456",
      "created_at": "2026-02-11T10:47:53.000Z",
      "valid_until": "2026-03-13T10:47:53.000Z",
      "quota_limit": 1000,
      "note": "VIP客户试用",
      "is_active": true
    }
  ],
  "total": 15,
  "page": 1,
  "limit": 10
}
```

### 4. 重置使用统计

**POST** `/admin/reset-usage`

重置指定密钥的使用统计。

```bash
# 重置特定密钥
curl -X POST http://127.0.0.1:8787/admin/reset-usage \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "trial_abc123def456"
  }'

# 重置所有密钥
curl -X POST http://127.0.0.1:8787/admin/reset-usage \
  -H "$AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{
    "all": true
  }'
```

**响应示例：**
```json
{
  "message": "使用统计已重置",
  "reset_count": 1
}
```

## 实用脚本

### 1. 快速验证脚本

```bash
#!/bin/bash
# admin-api-quick-test.sh

ADMIN_TOKEN=${ADMIN_TOKEN:-"your-admin-token"}
BASE_URL="http://127.0.0.1:8787"

echo "=== Quota-Proxy 管理 API 快速测试 ==="
echo ""

# 测试健康检查
echo "1. 测试健康检查..."
curl -fsS "$BASE_URL/healthz" && echo " ✓ 服务正常" || echo " ✗ 服务异常"

echo ""

# 生成试用密钥
echo "2. 生成试用密钥..."
KEY_RESPONSE=$(curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"note": "快速测试生成"}')
echo "$KEY_RESPONSE" | jq -r '.key' | xargs -I {} echo "生成的密钥: {}"

echo ""

# 查看使用情况
echo "3. 查看使用情况..."
curl -s -X GET "$BASE_URL/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.total_keys' | xargs -I {} echo "总密钥数: {}"

echo ""
echo "=== 测试完成 ==="
```

### 2. 批量生成密钥

```bash
#!/bin/bash
# generate-batch-keys.sh

ADMIN_TOKEN=${ADMIN_TOKEN:-"your-admin-token"}
BASE_URL="http://127.0.0.1:8787"
COUNT=5

for i in $(seq 1 $COUNT); do
  echo "生成第 $i 个密钥..."
  curl -s -X POST "$BASE_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"note\": \"批量生成 $i\"}" | jq -r '.key'
done
```

## 故障排除

### 常见问题

1. **认证失败**
   - 检查 ADMIN_TOKEN 是否正确
   - 确认 Header 格式：`Authorization: Bearer <token>`

2. **服务未响应**
   - 检查 quota-proxy 是否运行：`docker compose ps`
   - 检查端口是否正确：默认 8787

3. **数据库错误**
   - 检查 SQLite 数据库文件权限
   - 查看日志：`docker compose logs quota-proxy`

### 日志查看

```bash
# 查看实时日志
docker compose logs -f quota-proxy

# 查看特定时间段的日志
docker compose logs --since 10m quota-proxy

# 查看错误日志
docker compose logs quota-proxy 2>&1 | grep -i error
```

## 安全建议

1. **保护 ADMIN_TOKEN**
   - 不要将 ADMIN_TOKEN 提交到版本控制
   - 定期轮换 ADMIN_TOKEN
   - 使用环境变量或密钥管理服务

2. **访问控制**
   - 仅允许受信任的 IP 访问管理 API
   - 考虑添加额外的认证层

3. **监控审计**
   - 记录所有管理操作
   - 定期审计密钥使用情况
   - 设置异常使用告警

## 下一步

- [ ] 集成到管理面板
- [ ] 添加更细粒度的权限控制
- [ ] 实现密钥吊销功能
- [ ] 添加使用情况报表导出

---

**文档版本：** v1.0.0  
**最后更新：** 2026-02-11  
**维护者：** 中华AI共和国项目组