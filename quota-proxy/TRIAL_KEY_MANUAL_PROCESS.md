# TRIAL_KEY 手动发放流程

本文档详细说明如何手动为 quota-proxy 网关用户发放试用密钥。

## 1. 前提条件

在开始发放密钥前，确保：
- quota-proxy 服务已正常运行
- 管理员令牌（ADMIN_TOKEN）已设置
- 可以通过 HTTP 访问管理接口

## 2. 获取管理员令牌

管理员令牌在服务启动时通过环境变量设置：

```bash
# 在 .env 文件中设置
ADMIN_TOKEN=your-strong-admin-token-here

# 或在启动命令中设置
export ADMIN_TOKEN=your-strong-admin-token-here
docker compose up -d
```

## 3. 手动发放密钥的三种方式

### 3.1 方式一：通过 Web 管理界面（推荐）

1. 访问管理界面：`http://你的服务器IP:8787/admin`
2. 输入管理员令牌
3. 在"创建新密钥"部分：
   - 标签（可选）：填写用户标识，如 "用户A-2025-02-10"
   - 请求限制（可选）：设置每日请求次数，如 200
   - 点击"生成密钥"按钮
4. 复制生成的密钥并安全地发送给用户

### 3.2 方式二：通过 curl 命令行

#### 3.2.1 本地开发环境
```bash
# 生成新密钥（本地localhost）
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "用户A的试用密钥",
    "daily_limit": 200
  }'

# 响应示例
{
  "key": "trial-key-abc123def456",
  "label": "用户A的试用密钥",
  "daily_limit": 200,
  "created_at": "2025-02-10T15:20:00Z"
}
```

#### 3.2.2 Docker 容器环境
```bash
# 从宿主机访问容器（默认桥接网络）
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "docker-user-20250211",
    "daily_limit": 100
  }'

# 从其他容器访问（使用容器名）
curl -X POST http://quota-proxy:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "容器间用户",
    "daily_limit": 150
  }'
```

#### 3.2.3 Docker Compose 环境
```bash
# 在Docker Compose网络中访问
curl -X POST http://quota-proxy:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "compose-network-user",
    "daily_limit": 300
  }'
```

#### 3.2.4 生产服务器环境
```bash
# 使用域名访问
curl -X POST https://api.yourdomain.com/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "生产用户-20250211",
    "daily_limit": 500
  }'

# 使用服务器IP访问
curl -X POST http://192.168.1.100:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "内网用户",
    "daily_limit": 200
  }'
```

#### 3.2.5 Kubernetes 环境
```bash
# 通过Service访问
curl -X POST http://quota-proxy-service.default.svc.cluster.local:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "k8s-user",
    "daily_limit": 1000
  }'

# 通过Ingress访问
curl -X POST https://quota-proxy.yourdomain.com/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "ingress-user",
    "daily_limit": 800
  }'
```

### 3.3 方式三：通过 SQLite 数据库直接操作（高级）

```bash
# 进入数据库
sqlite3 quota.db

# 查看现有密钥
SELECT * FROM api_keys;

# 插入新密钥（不推荐，跳过审计日志）
INSERT INTO api_keys (key, label, daily_limit, created_at) 
VALUES ('trial-key-manual-123', '手动创建的密钥', 200, datetime('now'));

# 退出
.exit
```

## 4. 密钥发放最佳实践

### 4.1 密钥命名规范
- 格式：`trial-{用户标识}-{日期}-{随机后缀}`
- 示例：`trial-alice-20250210-abc123`

### 4.2 限制设置建议
- 试用用户：50-200 次/日
- 合作伙伴：500-1000 次/日
- 内部测试：无限制（设置为 0）

### 4.3 发放记录
建议记录每次密钥发放：
- 用户标识
- 发放日期
- 密钥（哈希值）
- 限制次数
- 发放人

## 5. 用户使用指南

将以下信息发送给用户：

### 5.1 基本使用
```bash
# 测试连接
curl http://你的服务器IP:8787/healthz

# 获取模型列表
curl http://你的服务器IP:8787/v1/models

# 发送请求
curl -X POST http://你的服务器IP:8787/v1/chat/completions \
  -H "Authorization: Bearer 你的TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好"}
    ]
  }'
```

### 5.2 OpenClaw 配置
```yaml
providers:
  - id: deepseek-trial
    name: DeepSeek 试用版
    baseUrl: "http://你的服务器IP:8787"
    apiKey: "你的TRIAL_KEY"
    models:
      - id: deepseek-chat
      - id: deepseek-reasoner
```

### 5.3 检查使用情况
```bash
# 用户可查看自己的使用情况
curl -H "Authorization: Bearer 你的TRIAL_KEY" \
  http://你的服务器IP:8787/usage
```

## 6. 管理操作

### 6.1 查看所有密钥
```bash
curl -H "Authorization: Bearer 管理员令牌" \
  http://localhost:8787/admin/keys
```

### 6.2 查看使用统计
```bash
curl -H "Authorization: Bearer 管理员令牌" \
  http://localhost:8787/admin/usage
```

### 6.3 重置使用次数
```bash
curl -X POST http://localhost:8787/admin/reset-usage \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{"key": "要重置的密钥"}'
```

### 6.4 删除密钥
```bash
curl -X DELETE http://localhost:8787/admin/keys/要删除的密钥 \
  -H "Authorization: Bearer 管理员令牌"
```

## 7. 安全注意事项

1. **不要通过不安全的渠道发送密钥** - 使用加密通信
2. **定期轮换管理员令牌** - 建议每月更换
3. **监控异常使用** - 设置告警机制
4. **记录所有管理操作** - 便于审计
5. **限制管理接口访问** - 只允许受信任的IP访问

## 8. 故障排除

### 8.1 密钥无效
- 检查密钥是否正确复制
- 检查密钥是否已被删除
- 检查服务器时间是否同步

### 8.2 达到限制
- 检查当日使用量：`curl -H "Authorization: Bearer 密钥" http://服务器/usage`
- 考虑是否增加限制或重置计数器

### 8.3 服务不可用
- 检查服务状态：`curl http://服务器/healthz`
- 查看服务器日志：`docker compose logs quota-proxy`

## 9. 自动化脚本示例

### 9.1 批量发放脚本
```bash
#!/bin/bash
# batch-create-keys.sh

ADMIN_TOKEN="你的管理员令牌"
BASE_URL="http://localhost:8787"

users=("alice" "bob" "charlie")

for user in "${users[@]}"; do
  key=$(curl -s -X POST "$BASE_URL/admin/keys" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"label\": \"$user-$(date +%Y%m%d)\", \"daily_limit\": 100}" | jq -r '.key')
  
  echo "用户 $user 的密钥: $key"
  echo "$user,$key" >> keys.csv
done
```

### 9.2 使用情况监控脚本
```bash
#!/bin/bash
# monitor-usage.sh

ADMIN_TOKEN="你的管理员令牌"
BASE_URL="http://localhost:8787"

usage=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/usage")

echo "当前使用情况："
echo "$usage" | jq '.'
```

---

**最后更新：** 2025-02-10  
**维护者：** Clawd 团队  
**相关文档：** [QUICKSTART.md](./QUICKSTART.md), [ADMIN-INTERFACE.md](./ADMIN-INTERFACE.md)