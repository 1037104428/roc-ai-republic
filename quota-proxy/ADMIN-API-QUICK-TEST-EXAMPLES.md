# Admin API快速测试示例

本文档提供Admin API的快速测试示例，使用curl命令一键测试所有核心功能。

## 环境准备

```bash
# 设置环境变量
export ADMIN_TOKEN="your-admin-token-here"
export BASE_URL="http://localhost:8787"
```

## 快速测试脚本

### 1. 健康检查
```bash
curl -s "$BASE_URL/healthz"
```

### 2. Admin API端点测试

#### 2.1 获取所有API密钥
```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys" | jq .
```

#### 2.2 创建试用密钥
```bash
curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-user","email":"test@example.com","quota":1000}' \
  "$BASE_URL/admin/keys" | jq .
```

#### 2.3 获取密钥用量统计
```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/usage" | jq .
```

#### 2.4 获取应用列表
```bash
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/applications" | jq .
```

### 3. 试用密钥API测试

#### 3.1 使用试用密钥调用API
```bash
# 首先获取一个试用密钥
TRIAL_KEY=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"quick-test","email":"quick@test.com","quota":10}' \
  "$BASE_URL/admin/keys" | jq -r '.key')

echo "试用密钥: $TRIAL_KEY"

# 使用试用密钥调用API
curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/test"
```

#### 3.2 检查试用密钥剩余配额
```bash
curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/quota"
```

### 4. 一键完整测试脚本

创建 `quick-admin-api-test.sh` 脚本：

```bash
#!/bin/bash
# Admin API一键完整测试脚本

set -e

# 配置
ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
BASE_URL="${BASE_URL:-http://localhost:8787}"

echo "🚀 Admin API一键完整测试开始"
echo "========================================"

# 1. 健康检查
echo "🔍 健康检查..."
curl -s "$BASE_URL/healthz" && echo " ✅ 健康检查通过"

# 2. 创建试用密钥
echo "🔑 创建试用密钥..."
RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"quick-test-user","email":"quick-test@example.com","quota":50}' \
  "$BASE_URL/admin/keys")

TRIAL_KEY=$(echo "$RESPONSE" | jq -r '.key')
echo "试用密钥创建成功: $TRIAL_KEY"

# 3. 测试试用密钥API
echo "🧪 测试试用密钥API..."
curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/test"

# 4. 检查配额
echo "📊 检查配额..."
curl -s -H "X-API-Key: $TRIAL_KEY" "$BASE_URL/api/quota"

# 5. 检查Admin API端点
echo "🔧 检查Admin API端点..."
echo "  - 所有密钥列表:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys" | jq 'length' && echo " ✅"

echo "  - 用量统计:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/usage" | jq . && echo " ✅"

echo "  - 应用列表:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/applications" | jq 'length' && echo " ✅"

echo "========================================"
echo "🎉 Admin API一键完整测试完成！"
```

### 5. 故障排除

#### 5.1 常见错误
- **401 Unauthorized**: Admin Token不正确
- **404 Not Found**: 服务器未运行或端口不正确
- **429 Too Many Requests**: 配额用尽

#### 5.2 调试命令
```bash
# 查看服务器日志
tail -f quota-proxy.log

# 检查服务器状态
curl -v "$BASE_URL/healthz"

# 检查数据库
sqlite3 quota.db "SELECT COUNT(*) FROM api_keys;"
```

#### 5.3 环境验证
```bash
# 验证环境变量
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
echo "BASE_URL: $BASE_URL"

# 验证服务器运行状态
ps aux | grep "node server-sqlite-admin.js"
```

## 使用建议

1. **开发环境**: 使用本地测试，设置 `BASE_URL="http://localhost:8787"`
2. **生产环境**: 使用HTTPS和正确的域名
3. **自动化测试**: 将测试脚本集成到CI/CD流程中
4. **监控**: 定期运行健康检查和配额监控

## 相关文档

- [Admin API指南](./ADMIN-API-GUIDE.md)
- [Admin API完整验证脚本](./verify-admin-api.sh)
- [Admin API快速验证脚本](./quick-verify-admin-api.sh)
- [SQLite数据库初始化](./init-sqlite-db.sh)