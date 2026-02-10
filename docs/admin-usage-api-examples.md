# GET /admin/usage API 使用示例

## 概述

`GET /admin/usage` 接口用于查询API密钥的使用统计信息。该接口需要管理员认证，支持按时间范围、特定密钥等条件筛选。

## 接口详情

**端点**: `GET /admin/usage`

**认证**: Bearer Token (管理员令牌)

**查询参数**:
- `key` (可选): 指定要查询的API密钥
- `days` (可选, 默认7): 查询最近N天的使用数据
- `limit` (可选): 限制返回结果数量
- `offset` (可选): 分页偏移量

## 使用示例

### 1. 基本使用 - 查询所有密钥最近7天的使用情况

```bash
# 使用环境变量设置认证信息
export CLAWD_ADMIN_TOKEN="your-admin-token-here"
export BASE_URL="http://127.0.0.1:8787"

# 使用curl直接调用
curl -sS "${BASE_URL}/admin/usage" \
  -H "Authorization: Bearer ${CLAWD_ADMIN_TOKEN}" | jq .
```

**响应示例**:
```json
{
  "success": true,
  "data": [
    {
      "key": "sk-1707571200000-abc123def",
      "label": "测试密钥",
      "total_quota": 1000,
      "used_quota": 150,
      "created_at": "2026-02-10T10:00:00.000Z",
      "request_count": 150,
      "avg_response_time": 45.2
    },
    {
      "key": "sk-1707571200001-xyz789uvw",
      "label": "生产密钥",
      "total_quota": 10000,
      "used_quota": 3250,
      "created_at": "2026-02-09T14:30:00.000Z",
      "request_count": 3250,
      "avg_response_time": 38.7
    }
  ]
}
```

### 2. 查询特定密钥的使用情况

```bash
# 查询特定密钥
curl -sS "${BASE_URL}/admin/usage?key=sk-1707571200000-abc123def" \
  -H "Authorization: Bearer ${CLAWD_ADMIN_TOKEN}" | jq .
```

### 3. 查询最近30天的使用数据

```bash
# 扩展查询时间范围
curl -sS "${BASE_URL}/admin/usage?days=30" \
  -H "Authorization: Bearer ${CLAWD_ADMIN_TOKEN}" | jq .
```

### 4. 使用辅助脚本 (推荐)

```bash
# 使用提供的curl-admin-usage.sh脚本
CLAWD_ADMIN_TOKEN="your-admin-token-here" \
  BASE_URL="http://127.0.0.1:8787" \
  bash scripts/curl-admin-usage.sh --pretty

# 查询特定日期的使用情况
CLAWD_ADMIN_TOKEN="your-admin-token-here" \
  bash scripts/curl-admin-usage.sh \
    --day "2026-02-10" \
    --limit 10 \
    --pretty

# 安全模式（隐藏敏感信息）
CLAWD_ADMIN_TOKEN="your-admin-token-here" \
  bash scripts/curl-admin-usage.sh --pretty --mask
```

### 5. 服务器端查询

```bash
# 在服务器上直接查询
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 \
  "curl -sS http://127.0.0.1:8787/admin/usage \
    -H 'Authorization: Bearer your-admin-token-here' | jq ."
```

## 响应字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `key` | string | API密钥 |
| `label` | string | 密钥标签/描述 |
| `total_quota` | integer | 总配额限制 |
| `used_quota` | integer | 已使用配额 |
| `created_at` | string | 密钥创建时间 (ISO 8601) |
| `request_count` | integer | 指定时间范围内的请求次数 |
| `avg_response_time` | number | 平均响应时间 (毫秒) |

## 使用场景

### 监控配额使用情况
```bash
# 检查哪些密钥接近配额限制
CLAWD_ADMIN_TOKEN="your-token" bash scripts/curl-admin-usage.sh --pretty | \
  jq '.data[] | select(.used_quota / .total_quota > 0.8)'
```

### 识别异常使用模式
```bash
# 查找响应时间异常的密钥
CLAWD_ADMIN_TOKEN="your-token" bash scripts/curl-admin-usage.sh --pretty | \
  jq '.data[] | select(.avg_response_time > 1000)'
```

### 生成使用报告
```bash
# 生成简单的使用报告
CLAWD_ADMIN_TOKEN="your-token" bash scripts/curl-admin-usage.sh --pretty | \
  jq '{
    total_keys: .data | length,
    total_requests: (.data | map(.request_count) | add),
    avg_response_time: (.data | map(.avg_response_time) | add) / (.data | length),
    quota_usage: (.data | map(.used_quota / .total_quota) | add) / (.data | length) * 100
  }'
```

## 集成到监控系统

### 1. 定期收集使用数据
```bash
#!/bin/bash
# collect-usage-stats.sh

TOKEN="${CLAWD_ADMIN_TOKEN}"
BASE_URL="http://127.0.0.1:8787"
OUTPUT_DIR="/var/log/quota-proxy/stats"

mkdir -p "$OUTPUT_DIR"

# 收集每日使用统计
curl -sS "${BASE_URL}/admin/usage?days=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  > "${OUTPUT_DIR}/usage-$(date +%Y%m%d).json"
```

### 2. 设置告警阈值
```bash
#!/bin/bash
# check-quota-alerts.sh

TOKEN="${CLAWD_ADMIN_TOKEN}"
BASE_URL="http://127.0.0.1:8787"

response=$(curl -sS "${BASE_URL}/admin/usage" \
  -H "Authorization: Bearer ${TOKEN}")

# 检查是否有密钥使用超过90%
echo "$response" | jq -r '.data[] | 
  select(.used_quota / .total_quota > 0.9) | 
  "警告: 密钥 \(.label) (\(.key[0:8]...)) 使用率 \((.used_quota/.total_quota*100)|round)%"'
```

## 故障排除

### 常见问题

1. **401 Unauthorized**
   ```bash
   # 检查管理员令牌
   echo "当前令牌: ${CLAWD_ADMIN_TOKEN:0:10}..."
   
   # 验证令牌有效性
   curl -v "${BASE_URL}/admin/keys" \
     -H "Authorization: Bearer ${CLAWD_ADMIN_TOKEN}"
   ```

2. **空结果集**
   ```bash
   # 检查数据库是否有数据
   ssh root@your-server "sqlite3 /opt/roc/quota-proxy/data/quota.db \
     'SELECT COUNT(*) FROM api_keys; SELECT COUNT(*) FROM usage_log;'"
   
   # 扩展查询时间范围
   curl -sS "${BASE_URL}/admin/usage?days=30" \
     -H "Authorization: Bearer ${CLAWD_ADMIN_TOKEN}"
   ```

3. **连接失败**
   ```bash
   # 检查服务状态
   curl -fsS "${BASE_URL}/healthz"
   
   # 检查服务器连接
   ssh root@your-server "docker compose -f /opt/roc/quota-proxy/docker-compose-persistent.yml ps"
   ```

## 最佳实践

1. **定期监控**: 建议每天至少检查一次使用情况
2. **设置告警**: 对高使用率密钥设置自动告警
3. **数据归档**: 定期归档历史使用数据
4. **权限管理**: 严格控制管理员令牌的访问权限
5. **日志记录**: 记录所有管理操作

## 相关资源

- [管理员接口完整文档](../quota-proxy/ADMIN-INTERFACE.md)
- [curl-admin-usage.sh 脚本](../../scripts/curl-admin-usage.sh)
- [quota-proxy 部署指南](../quota-proxy/QUICKSTART.md)
- [数据库管理工具](../../scripts/migrate-quota-db.sh)