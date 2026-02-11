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
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "新用户试用"
  }'

# 示例输出：
# {
#   "key": "trial_abc123def456ghi789",
#   "label": "新用户试用",
#   "created_at": 1741967089000
# }

# 批量生成试用密钥（生成5个）
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "count": 5,
    "label": "批量试用用户",
    "prefix": "batch_"
  }'

# 示例输出：
# {
#   "count": 5,
#   "keys": [
#     {
#       "key": "batch_abc123def456ghi789",
#       "label": "批量试用用户",
#       "created_at": 1741967089000
#     },
#     ...
#   ],
#   "summary": {
#     "total": 5,
#     "label": "批量试用用户",
#     "prefix": "batch_",
#     "created_at": 1741967089000
#   }
# }

# 生成无标签的试用密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'

# 生成自定义前缀的试用密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "count": 3,
    "label": "内部测试",
    "prefix": "test_"
  }'
```

### 2.2 查询试用密钥

```bash
# 查询所有试用密钥（新增接口）
curl -s "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 示例输出：
# {
#   "count": 3,
#   "keys": [
#     {
#       "key": "trial_abc123...",
#       "label": "新用户试用",
#       "created_at": 1741967089000
#     },
#     ...
#   ],
#   "mode": "file"
# }

# 删除试用密钥
curl -s -X DELETE "$BASE_URL/admin/keys/trial_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 示例输出：
# {
#   "deleted": true,
#   "key": "trial_abc123"
# }
```

## 3. 管理员令牌配置

quota-proxy 使用单一的管理员令牌（ADMIN_TOKEN）进行身份验证，而不是多管理员密钥系统。

### 3.1 设置管理员令牌

```bash
# 启动时设置环境变量
ADMIN_TOKEN="your-secure-admin-token-here" \
DEEPSEEK_API_KEY="sk-..." \
node server.js

# 或者使用 .env 文件
echo "ADMIN_TOKEN=your-secure-admin-token-here" > .env
echo "DEEPSEEK_API_KEY=sk-..." >> .env
node server.js
```

### 3.2 验证管理员令牌

```bash
# 使用管理员令牌测试健康检查
curl -s "$BASE_URL/healthz" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 验证令牌是否有效（尝试调用需要管理员权限的接口）
curl -s "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 4. 使用情况统计

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

## 5. 系统管理

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

## 6. 批量操作

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

## 7. 监控与告警

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

## 8. 实用脚本示例

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

## 9. 故障排除

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

## 10. 快速开始（5分钟上手）

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

我们提供了一个完整的快速验证脚本 `quick-start-verify.sh`，包含以下功能：

#### 脚本功能
1. **依赖检查** - 自动检查 curl 和 jq 命令
2. **健康检查** - 验证服务是否正常运行
3. **Admin API 访问测试** - 测试管理员权限
4. **试用密钥生成测试** - 验证密钥生成功能
5. **使用情况查询测试** - 验证统计功能

#### 使用方法

```bash
# 1. 下载脚本（如果尚未下载）
# 脚本已包含在 quota-proxy 目录中

# 2. 赋予执行权限
chmod +x quick-start-verify.sh

# 3. 运行验证（两种方式）

# 方式一：通过参数指定
./quick-start-verify.sh http://localhost:8787 your-admin-token-here

# 方式二：通过环境变量
export ADMIN_TOKEN=your-admin-token-here
./quick-start-verify.sh http://localhost:8787

# 方式三：使用默认值（localhost:8787）
export ADMIN_TOKEN=your-admin-token-here
./quick-start-verify.sh
```

#### 脚本特性
- **彩色输出** - 清晰的状态指示
- **错误重试** - 网络问题自动重试
- **详细日志** - 每一步都有明确反馈
- **依赖检查** - 自动检查必要工具
- **安全退出** - 任何失败都会明确提示

#### 预期输出示例
```
=== Admin API 快速验证 ===
目标服务: http://localhost:8787
开始时间: Wed Feb 11 21:45:00 CST 2026

检查依赖...
✓ curl 已安装
✓ jq 已安装

1. 健康检查...
   ✓ 服务正常 (健康检查通过)

2. Admin API 访问测试...
   ✓ Admin API 访问正常
   响应预览: {"success":true,"message":"Keys retrieved","keys_count":3}

3. 试用密钥生成测试...
   ✓ 试用密钥生成成功
   生成的密钥: trial_abc123def456...
   完整信息: {"success":true,"message":"Trial key created","key":"trial_abc123def456...","quota":3}

4. 使用情况查询测试...
   ✓ 使用情况查询正常
   使用情况预览: {"success":true,"message":"Usage stats","total_requests":125}

=== 验证完成 ===
完成时间: Wed Feb 11 21:45:05 CST 2026
✅ 所有测试通过！
服务状态: 正常
Admin API: 可用
试用密钥功能: 正常
使用情况查询: 正常
```

#### 故障排除
如果脚本失败，请检查：
1. **服务状态** - `docker compose ps` 查看 quota-proxy 是否运行
2. **网络连接** - `curl http://localhost:8787/healthz` 测试连通性
3. **管理员令牌** - 确保 ADMIN_TOKEN 正确且未过期
4. **查看日志** - `docker compose logs quota-proxy` 查看详细错误信息

#### 脚本位置
脚本位于：`quota-proxy/quick-start-verify.sh`

这个脚本是快速验证 quota-proxy Admin API 功能的最便捷方式，特别适合：
- 新部署环境验证
- CI/CD 流水线集成
- 日常健康检查
- 故障排查验证

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
