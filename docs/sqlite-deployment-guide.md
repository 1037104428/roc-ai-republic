# SQLite 版本 quota-proxy 部署指南

## 概述

SQLite 版本的 quota-proxy 提供了完整的数据持久化功能，支持：
- Trial key 的创建、管理和删除
- 每日使用量统计和持久化存储
- 管理员接口保护
- 数据持久化到 SQLite 数据库

## 快速部署

### 1. 环境准备

```bash
# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/quota-proxy

# 创建数据目录
mkdir -p /data
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# DeepSeek API 配置
DEEPSEEK_API_KEY=your_deepseek_api_key_here
DEEPSEEK_BASE_URL=https://api.deepseek.com/v1

# 配额限制
DAILY_REQ_LIMIT=200

# SQLite 数据库配置
SQLITE_PATH=/data/quota.db

# 管理员令牌（重要！）
ADMIN_TOKEN=your_secure_admin_token_here

# 服务器配置
PORT=8787
```

### 3. 启动服务

使用 Docker Compose：

```bash
# 使用 SQLite 版本
docker compose -f compose-sqlite.yaml up -d
```

或者直接使用 Node.js：

```bash
npm install
node server-better-sqlite.js
```

## 管理员接口使用

### 认证方式

所有管理员接口都需要 Bearer Token 认证：

```bash
curl -H "Authorization: Bearer ${ADMIN_TOKEN}" http://localhost:8787/admin/keys
```

### 1. 创建 Trial Key

```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"label":"用户-张三-20250209"}'
```

响应示例：
```json
{
  "key": "sk-test-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "label": "用户-张三-20250209",
  "created_at": 1739078400
}
```

### 2. 查看所有 Key

```bash
curl http://localhost:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 3. 查看使用情况

```bash
curl http://localhost:8787/admin/usage \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

响应示例：
```json
{
  "items": [
    {
      "day": "2025-02-09",
      "trial_key": "sk-test-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "label": "用户-张三-20250209",
      "requests": 15,
      "updated_at": 1739078400
    }
  ],
  "total": 1
}
```

### 4. 删除 Key

```bash
curl -X DELETE http://localhost:8787/admin/keys/sk-test-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 5. 重置使用量

```bash
curl -X POST http://localhost:8787/admin/usage/reset \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"key":"sk-test-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'
```

## 数据持久化验证

### 验证脚本

使用提供的验证脚本测试持久化功能：

```bash
# 设置环境变量
export ADMIN_TOKEN=your_admin_token_here
export QUOTA_PROXY_URL=http://localhost:8787

# 运行验证
./scripts/verify-sqlite-persistence.sh
```

### 手动验证步骤

1. **创建 key** 并记录
2. **重启服务**：`docker compose restart`
3. **验证 key 仍然存在**：调用 `/admin/keys`
4. **验证使用量持久化**：调用 `/admin/usage`

## 生产环境建议

### 1. 数据库备份

```bash
# 定期备份 SQLite 数据库
cp /data/quota.db /backup/quota-$(date +%Y%m%d).db

# 使用 sqlite3 命令行工具检查
sqlite3 /data/quota.db "SELECT COUNT(*) FROM trial_keys;"
```

### 2. 监控和日志

```bash
# 查看服务日志
docker compose logs -f

# 监控数据库大小
ls -lh /data/quota.db

# 检查服务健康
curl -fsS http://localhost:8787/healthz
```

### 3. 安全建议

1. **使用强 ADMIN_TOKEN**：至少 32 位随机字符
2. **限制管理员接口访问**：只允许本地或 VPN 访问
3. **定期轮换密钥**：每月更新 ADMIN_TOKEN
4. **启用 HTTPS**：在生产环境使用 HTTPS

## 故障排除

### 常见问题

1. **数据库权限问题**
   ```bash
   chown -R 1000:1000 /data
   ```

2. **ADMIN_TOKEN 未设置**
   ```bash
   export ADMIN_TOKEN=your_token
   docker compose up -d
   ```

3. **SQLite 文件损坏**
   ```bash
   sqlite3 /data/quota.db ".dump" | sqlite3 /data/quota-new.db
   mv /data/quota-new.db /data/quota.db
   ```

### 日志检查

```bash
# 查看详细日志
docker compose logs quota-proxy

# 检查数据库连接
docker exec -it quota-proxy-quota-proxy-1 sqlite3 /data/quota.db ".tables"
```

## 迁移指南

### 从内存版本迁移到 SQLite

1. 导出当前 keys（如果使用内存版本）：
   ```bash
   # 从内存版本获取 keys 列表
   curl http://localhost:8787/admin/keys -H "Authorization: Bearer ${ADMIN_TOKEN}" > keys.json
   ```

2. 部署 SQLite 版本
3. 导入 keys（如果需要）：
   ```bash
   # 批量创建 keys
   jq -c '.[]' keys.json | while read key_data; do
     curl -X POST http://localhost:8787/admin/keys \
       -H "Authorization: Bearer ${ADMIN_TOKEN}" \
       -H "Content-Type: application/json" \
       -d "$key_data"
   done
   ```

## 相关资源

- [quota-proxy 主页](https://clawdrepublic.cn/quota-proxy.html)
- [管理员接口规范](../docs/quota-proxy-v1-admin-spec.md)
- [验证脚本](../scripts/verify-sqlite-persistence.sh)
- [Docker Compose 配置](../quota-proxy/compose-sqlite.yaml)