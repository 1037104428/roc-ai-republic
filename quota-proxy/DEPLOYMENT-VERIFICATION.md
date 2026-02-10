# quota-proxy 部署验证指南

本文档提供 quota-proxy 部署后的完整验证流程，确保服务正常运行。

## 1. 基础健康检查

### 1.1 服务状态检查
```bash
# 检查容器状态
docker compose ps

# 检查服务日志
docker compose logs quota-proxy

# 健康检查端点
curl -fsS http://127.0.0.1:8787/healthz
# 预期输出: {"ok":true}
```

### 1.2 端口监听检查
```bash
# 检查端口是否监听
netstat -tlnp | grep 8787
# 或
ss -tlnp | grep 8787

# 测试外部访问（如果配置了公网）
curl -fsS http://your-domain.com/healthz
```

## 2. 管理员功能验证

### 2.1 管理员认证测试
```bash
# 设置环境变量
export ADMIN_TOKEN="your_admin_token_here"
export QUOTA_URL="http://127.0.0.1:8787"

# 测试管理员认证
curl -fsS "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
# 预期: 空数组 [] 或现有密钥列表
```

### 2.2 创建试用密钥
```bash
# 创建新密钥
curl -fsS -X POST "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"test-user-001"}'

# 预期输出示例:
# {"key":"trial_xxx","label":"test-user-001","created_at":1700000000000}
```

### 2.3 查询使用情况
```bash
# 查询今日使用情况
curl -fsS "$QUOTA_URL/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查询特定密钥使用情况
curl -fsS "$QUOTA_URL/admin/usage?day=$(date +%F)&key=trial_xxx" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 3. 客户端功能验证

### 3.1 模型列表查询
```bash
# 使用创建的密钥查询模型
export TRIAL_KEY="trial_xxx"
curl -fsS "$QUOTA_URL/v1/models" \
  -H "Authorization: Bearer $TRIAL_KEY"

# 预期输出: DeepSeek 模型列表
```

### 3.2 API 调用测试
```bash
# 简单聊天请求
curl -fsS "$QUOTA_URL/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，请回复'测试成功'"}
    ],
    "max_tokens": 50
  }'

# 预期: 正常的 OpenAI 格式响应
```

### 3.3 配额限制测试
```bash
# 测试配额限制（需要超过限制）
for i in {1..210}; do
  echo "请求 $i"
  curl -s -o /dev/null -w "%{http_code}\n" \
    "$QUOTA_URL/v1/chat/completions" \
    -H "Authorization: Bearer $TRIAL_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}]}'
  sleep 0.1
done
# 预期: 前200次返回200，之后返回429
```

## 4. 数据库持久化验证

### 4.1 SQLite 数据库检查
```bash
# 检查数据库文件
ls -la /data/quota.db

# 检查数据库内容
sqlite3 /data/quota.db ".tables"
sqlite3 /data/quota.db "SELECT COUNT(*) FROM trial_keys;"
sqlite3 /data/quota.db "SELECT COUNT(*) FROM daily_usage;"
```

### 4.2 数据一致性验证
```bash
# 验证密钥创建后是否持久化
# 1. 创建密钥
KEY_DATA=$(curl -s -X POST "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"persistence-test"}')

# 2. 重启服务
docker compose restart quota-proxy

# 3. 验证密钥仍然存在
curl -fsS "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | grep "persistence-test"
```

## 5. 安全配置验证

### 5.1 访问控制检查
```bash
# 测试未授权访问
curl -s -o /dev/null -w "%{http_code}\n" \
  "$QUOTA_URL/admin/keys"
# 预期: 401 (未授权)

# 测试无效密钥
curl -s -o /dev/null -w "%{http_code}\n" \
  "$QUOTA_URL/v1/models" \
  -H "Authorization: Bearer invalid_key"
# 预期: 401
```

### 5.2 网络隔离检查
```bash
# 检查是否只监听本地（如果配置了）
netstat -tln | grep 8787
# 预期: 127.0.0.1:8787 而不是 0.0.0.0:8787
```

## 6. 性能与监控

### 6.1 响应时间测试
```bash
# 测试健康检查响应时间
time curl -fsS "$QUOTA_URL/healthz" > /dev/null

# 测试API响应时间
time curl -fsS "$QUOTA_URL/v1/models" \
  -H "Authorization: Bearer $TRIAL_KEY" > /dev/null
```

### 6.2 并发测试
```bash
# 简单并发测试（10个并发请求）
for i in {1..10}; do
  curl -s -o /dev/null -w "请求 $i: %{http_code}\n" \
    "$QUOTA_URL/healthz" &
done
wait
```

## 7. 自动化验证脚本

仓库提供了完整的验证脚本：

```bash
# 运行完整验证
./scripts/verify-sqlite-persistence.sh

# 快速管理员API验证
./scripts/verify-admin-api-quick.sh --host 127.0.0.1:8787 --token $ADMIN_TOKEN

# 管理界面验证
./scripts/verify-quota-proxy-admin-ui.sh
```

## 8. 常见问题排查

### 8.1 服务无法启动
```bash
# 检查日志
docker compose logs quota-proxy

# 常见问题:
# 1. DEEPSEEK_API_KEY 未设置
# 2. 端口被占用
# 3. 数据库文件权限问题
```

### 8.2 API 返回 401
```bash
# 检查密钥是否存在
sqlite3 /data/quota.db "SELECT key FROM trial_keys WHERE key='trial_xxx';"

# 检查管理员令牌
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
```

### 8.3 配额计数不准确
```bash
# 检查数据库连接
curl -fsS "$QUOTA_URL/healthz"

# 检查使用情况
curl -fsS "$QUOTA_URL/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 9. 验证结果记录

建议部署后记录验证结果：

| 测试项目 | 状态 | 备注 |
|---------|------|------|
| 健康检查 | ✅ | 响应 {"ok":true} |
| 管理员认证 | ✅ | 可以访问 /admin/keys |
| 密钥创建 | ✅ | 可以创建新密钥 |
| API 调用 | ✅ | 正常返回聊天响应 |
| 配额限制 | ✅ | 超过限制返回 429 |
| 数据持久化 | ✅ | 重启后数据保留 |
| 安全访问控制 | ✅ | 未授权访问返回 401 |

完成所有验证后，quota-proxy 即可投入生产使用。