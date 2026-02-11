# Admin API 调用示例集合

本文档提供 quota-proxy Admin API 的完整调用示例，帮助管理员快速上手和使用所有管理功能。

## 环境准备

```bash
# 设置环境变量
export BASE_URL="http://localhost:8787"
export ADMIN_TOKEN="your-admin-token-here"

# 验证环境
echo "BASE_URL: $BASE_URL"
echo "ADMIN_TOKEN: ${ADMIN_TOKEN:0:8}..."
```

## 1. 健康检查

```bash
# 基本健康检查
curl -s "$BASE_URL/healthz"

# 详细健康检查（包含数据库状态）
curl -s "$BASE_URL/healthz?detailed=true"

# 带超时的健康检查
curl -s --max-time 5 "$BASE_URL/healthz"
```

## 2. 试用密钥管理

### 2.1 生成试用密钥

```bash
# 生成单个试用密钥
curl -s -X POST "$BASE_URL/admin/keys/trial" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "新用户试用",
    "quota": 100,
    "expiresIn": "7d"
  }'

# 批量生成试用密钥
curl -s -X POST "$BASE_URL/admin/keys/trial/batch" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "count": 5,
    "namePrefix": "批量试用",
    "quota": 50,
    "expiresIn": "3d"
  }'
```

### 2.2 查询试用密钥

```bash
# 查询所有试用密钥
curl -s "$BASE_URL/admin/keys/trial" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 分页查询试用密钥
curl -s "$BASE_URL/admin/keys/trial?page=1&limit=10" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 按状态查询试用密钥
curl -s "$BASE_URL/admin/keys/trial?status=active" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 3. 管理员密钥管理

### 3.1 生成管理员密钥

```bash
# 生成普通管理员密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "运维管理员",
    "permissions": ["read", "write", "delete"],
    "expiresIn": "30d"
  }'

# 生成只读管理员密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "监控只读",
    "permissions": ["read"],
    "expiresIn": "90d"
  }'
```

### 3.2 管理管理员密钥

```bash
# 列出所有管理员密钥
curl -s "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查询特定管理员密钥
curl -s "$BASE_URL/admin/keys/key_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 撤销管理员密钥
curl -s -X DELETE "$BASE_URL/admin/keys/key_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 更新管理员密钥
curl -s -X PATCH "$BASE_URL/admin/keys/key_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "更新后的名称",
    "permissions": ["read", "write"]
  }'
```

## 4. 应用管理

### 4.1 应用列表

```bash
# 获取所有应用列表
curl -s "$BASE_URL/admin/applications" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 分页获取应用列表
curl -s "$BASE_URL/admin/applications?page=2&limit=20" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 按状态筛选应用
curl -s "$BASE_URL/admin/applications?status=active" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 4.2 应用详情

```bash
# 获取应用详情
curl -s "$BASE_URL/admin/applications/app_123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取应用使用统计
curl -s "$BASE_URL/admin/applications/app_123/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取应用密钥列表
curl -s "$BASE_URL/admin/applications/app_123/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 5. 使用情况统计

### 5.1 总体使用情况

```bash
# 获取总体使用统计
curl -s "$BASE_URL/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 按时间范围查询使用统计
curl -s "$BASE_URL/admin/usage?start=2026-02-01&end=2026-02-11" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 按应用查询使用统计
curl -s "$BASE_URL/admin/usage?applicationId=app_123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 5.2 详细使用记录

```bash
# 查询使用记录
curl -s "$BASE_URL/admin/usage/records" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 分页查询使用记录
curl -s "$BASE_URL/admin/usage/records?page=1&limit=50" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 按密钥查询使用记录
curl -s "$BASE_URL/admin/usage/records?keyId=key_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 6. 系统管理

### 6.1 系统状态

```bash
# 获取系统状态
curl -s "$BASE_URL/admin/system/status" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取数据库状态
curl -s "$BASE_URL/admin/system/database" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取缓存状态
curl -s "$BASE_URL/admin/system/cache" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 6.2 系统配置

```bash
# 获取当前配置
curl -s "$BASE_URL/admin/system/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 更新配置项
curl -s -X PATCH "$BASE_URL/admin/system/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rateLimit": 100,
    "logLevel": "info"
  }'
```

## 7. 批量操作

### 7.1 批量密钥操作

```bash
# 批量启用/禁用密钥
curl -s -X POST "$BASE_URL/admin/keys/batch/status" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "keyIds": ["key_1", "key_2", "key_3"],
    "status": "disabled"
  }'

# 批量删除密钥
curl -s -X POST "$BASE_URL/admin/keys/batch/delete" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "keyIds": ["key_expired_1", "key_expired_2"]
  }'
```

### 7.2 批量应用操作

```bash
# 批量更新应用配额
curl -s -X POST "$BASE_URL/admin/applications/batch/quota" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "applicationIds": ["app_1", "app_2"],
    "quota": 1000
  }'
```

## 8. 监控与告警

### 8.1 监控端点

```bash
# 获取监控指标
curl -s "$BASE_URL/admin/monitoring/metrics" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取性能统计
curl -s "$BASE_URL/admin/monitoring/performance" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 获取错误统计
curl -s "$BASE_URL/admin/monitoring/errors" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 8.2 告警配置

```bash
# 获取告警配置
curl -s "$BASE_URL/admin/alerts/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 更新告警配置
curl -s -X PUT "$BASE_URL/admin/alerts/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "quotaThreshold": 80,
    "errorThreshold": 10,
    "notificationEmail": "admin@example.com"
  }'
```

## 9. 实用脚本示例

### 9.1 自动化部署检查

```bash
#!/bin/bash
# deploy-check.sh

BASE_URL="${1:-http://localhost:8787}"
ADMIN_TOKEN="${2:-$ADMIN_TOKEN}"

echo "=== 部署检查开始 ==="

# 检查健康状态
health=$(curl -s --max-time 5 "$BASE_URL/healthz")
if [[ "$health" == "OK" ]]; then
  echo "✓ 健康检查通过"
else
  echo "✗ 健康检查失败: $health"
  exit 1
fi

# 检查数据库连接
db_status=$(curl -s "$BASE_URL/healthz?detailed=true" | jq -r '.database')
if [[ "$db_status" == "connected" ]]; then
  echo "✓ 数据库连接正常"
else
  echo "✗ 数据库连接异常: $db_status"
  exit 1
fi

# 检查Admin API访问
api_status=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys" | jq -r '.status')
if [[ "$api_status" == "success" ]]; then
  echo "✓ Admin API访问正常"
else
  echo "✗ Admin API访问异常"
  exit 1
fi

echo "=== 部署检查完成 ==="
```

### 9.2 每日使用报告

```bash
#!/bin/bash
# daily-report.sh

BASE_URL="http://localhost:8787"
ADMIN_TOKEN="your-admin-token"
REPORT_DATE=$(date +%Y-%m-%d)

echo "=== 每日使用报告 ($REPORT_DATE) ==="
echo ""

# 获取总体使用统计
total_usage=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/admin/usage?start=$REPORT_DATE&end=$REPORT_DATE")

echo "今日总请求数: $(echo $total_usage | jq -r '.totalRequests')"
echo "今日活跃密钥数: $(echo $total_usage | jq -r '.activeKeys')"
echo "今日活跃应用数: $(echo $total_usage | jq -r '.activeApplications')"
echo ""

# 获取Top 5应用
top_apps=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/admin/applications?limit=5&sort=usage")

echo "Top 5 应用:"
echo "$top_apps" | jq -r '.applications[] | "  \(.name): \(.usageCount) 次请求"'
```

## 10. 故障排除

### 10.1 常见错误处理

```bash
# 401 Unauthorized - 检查token
echo "检查token格式: Bearer $ADMIN_TOKEN"
echo "检查token是否过期"

# 403 Forbidden - 检查权限
echo "检查密钥权限是否足够"
echo "检查IP白名单配置"

# 404 Not Found - 检查端点
echo "检查API端点路径是否正确"
echo "检查服务版本是否匹配"

# 429 Too Many Requests - 限流
echo "等待限流恢复"
echo "调整请求频率"
```

### 10.2 调试模式

```bash
# 启用详细日志
curl -v -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys"

# 查看请求头
curl -I -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys"

# 查看响应时间
time curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys" > /dev/null
```

## 11. 快速开始（5分钟上手）

### 11.1 第一步：环境设置

```bash
# 1. 设置环境变量
export BASE_URL="http://localhost:8787"
export ADMIN_TOKEN="your-admin-token-here"

# 2. 验证环境
echo "BASE_URL: $BASE_URL"
echo "ADMIN_TOKEN: ${ADMIN_TOKEN:0:8}..."
```

### 11.2 第二步：快速验证

```bash
# 1. 检查服务是否运行
curl -s "$BASE_URL/healthz"

# 2. 测试Admin API访问
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys" | jq -r '.status'

# 3. 生成第一个试用密钥
curl -s -X POST "$BASE_URL/admin/keys/trial" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "快速开始测试",
    "quota": 10,
    "expiresIn": "1d"
  }' | jq -r '.key'
```

### 11.3 第三步：常用操作速查

```bash
# 查看所有试用密钥
curl -s "$BASE_URL/admin/keys/trial" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.keys[].key'

# 查看使用统计
curl -s "$BASE_URL/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.totalRequests'

# 查看系统状态
curl -s "$BASE_URL/admin/system/status" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.uptime'
```

### 11.4 第四步：一键验证脚本

```bash
#!/bin/bash
# quick-start-verify.sh

BASE_URL="${1:-http://localhost:8787}"
ADMIN_TOKEN="${2:-$ADMIN_TOKEN}"

echo "=== Admin API 快速验证 ==="
echo ""

# 1. 健康检查
echo "1. 健康检查:"
health=$(curl -s --max-time 3 "$BASE_URL/healthz")
if [[ "$health" == "OK" ]]; then
  echo "   ✓ 服务正常"
else
  echo "   ✗ 服务异常: $health"
  exit 1
fi

# 2. Admin API 访问
echo "2. Admin API 访问:"
api_resp=$(curl -s --max-time 3 -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys")
if echo "$api_resp" | grep -q "success"; then
  echo "   ✓ Admin API 访问正常"
else
  echo "   ✗ Admin API 访问失败"
  exit 1
fi

# 3. 生成试用密钥
echo "3. 试用密钥生成:"
key_resp=$(curl -s -X POST "$BASE_URL/admin/keys/trial" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"验证测试","quota":5,"expiresIn":"1h"}')
if echo "$key_resp" | grep -q "key"; then
  trial_key=$(echo "$key_resp" | jq -r '.key')
  echo "   ✓ 试用密钥生成成功: ${trial_key:0:16}..."
else
  echo "   ✗ 试用密钥生成失败"
  exit 1
fi

echo ""
echo "=== 验证完成 ==="
echo "服务状态: 正常"
echo "Admin API: 可用"
echo "试用密钥功能: 正常"
```

## 总结

本文档提供了 quota-proxy Admin API 的完整调用示例，涵盖：
- 健康检查与系统状态
- 密钥管理（试用密钥、管理员密钥）
- 应用管理
- 使用情况统计
- 系统配置与监控
- 批量操作
- 实用脚本
- 故障排除
- 快速开始指南

所有示例都经过测试，可以直接复制使用。根据实际环境调整 `BASE_URL` 和 `ADMIN_TOKEN` 即可。

**新用户建议**：从第11章"快速开始"开始，5分钟内完成环境设置和基本功能验证。
