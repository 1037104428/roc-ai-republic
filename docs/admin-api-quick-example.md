# Admin API 快速使用示例

本文档提供 quota-proxy Admin API 的快速使用示例，帮助管理员快速上手密钥管理和用量统计功能。

## 前提条件

1. quota-proxy 服务已启动并运行在 `http://localhost:8787`
2. 已设置 `ADMIN_TOKEN` 环境变量（用于 API 认证）
3. 已安装 `curl` 工具

## 快速开始

### 1. 生成试用密钥

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token-here"

# 生成一个试用密钥（有效期7天）
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "trial",
    "valid_days": 7,
    "rate_limit": 1000,
    "quota": 10000,
    "notes": "试用用户"
  }' \
  http://localhost:8787/admin/keys
```

响应示例：
```json
{
  "key": "trial_abc123def456",
  "type": "trial",
  "valid_until": "2026-02-19T02:44:52Z",
  "rate_limit": 1000,
  "quota": 10000,
  "notes": "试用用户"
}
```

### 2. 查看密钥用量统计

```bash
# 查看所有密钥的用量统计
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/usage
```

响应示例：
```json
[
  {
    "key": "trial_abc123def456",
    "type": "trial",
    "requests_today": 42,
    "requests_total": 156,
    "quota_used": 1560,
    "quota_remaining": 8440,
    "last_used": "2026-02-12T02:30:15Z"
  }
]
```

### 3. 查看特定密钥详情

```bash
# 查看特定密钥的详细信息
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/keys/trial_abc123def456
```

### 4. 禁用/启用密钥

```bash
# 禁用密钥
curl -X PATCH \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  http://localhost:8787/admin/keys/trial_abc123def456

# 启用密钥
curl -X PATCH \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' \
  http://localhost:8787/admin/keys/trial_abc123def456
```

## 自动化脚本示例

### 批量生成试用密钥

```bash
#!/bin/bash
# generate-trial-keys.sh

ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token}"
API_URL="http://localhost:8787/admin/keys"

for i in {1..10}; do
  curl -X POST \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"type\": \"trial\",
      \"valid_days\": 7,
      \"rate_limit\": 1000,
      \"quota\": 10000,
      \"notes\": \"试用用户 $i\"
    }" \
    "$API_URL"
  echo ""
  sleep 0.5
done
```

### 每日用量报告

```bash
#!/bin/bash
# daily-usage-report.sh

ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token}"
API_URL="http://localhost:8787/admin/usage"
REPORT_FILE="/tmp/usage-report-$(date +%Y%m%d).txt"

echo "=== 用量统计报告 $(date) ===" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_URL" | \
  jq -r '.[] | "密钥: \(.key)\n类型: \(.type)\n今日请求: \(.requests_today)\n总请求: \(.requests_total)\n已用配额: \(.quota_used)\n剩余配额: \(.quota_remaining)\n最后使用: \(.last_used)\n---"' >> "$REPORT_FILE"

echo "报告已保存到: $REPORT_FILE"
cat "$REPORT_FILE"
```

## 故障排除

### 常见错误

1. **401 Unauthorized**
   - 原因：ADMIN_TOKEN 不正确或未设置
   - 解决：检查环境变量设置

2. **404 Not Found**
   - 原因：API 路径错误或服务未运行
   - 解决：检查服务状态和 API 路径

3. **429 Too Many Requests**
   - 原因：达到速率限制
   - 解决：等待一段时间后重试

### 验证服务状态

```bash
# 检查健康状态
curl -fsS http://localhost:8787/healthz && echo "服务正常"

# 检查 Admin API 可访问性
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/keys 2>/dev/null | \
  grep -q "\[\]" && echo "Admin API 正常"
```

## 最佳实践

1. **定期轮换 ADMIN_TOKEN**：每月更换一次管理员令牌
2. **监控用量趋势**：设置每日用量报告，及时发现异常
3. **密钥分类管理**：为不同用户类型使用不同的密钥配置
4. **备份密钥数据**：定期备份 SQLite 数据库文件

## 相关文档

- [Admin API 设计文档](../quota-proxy/README.md#admin-api)
- [quota-proxy 部署指南](../quota-proxy/DEPLOY.md)
- [验证工具链概览](../quota-proxy/VALIDATION-QUICK-INDEX.md)
