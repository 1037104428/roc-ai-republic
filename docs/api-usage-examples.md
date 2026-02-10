# quota-proxy API 使用示例

本文档提供 quota-proxy API 的完整使用示例，帮助用户快速上手。

## 基础配置

### 1. 服务地址
- 本地开发：`http://localhost:8787`
- 生产环境：`https://your-domain.com` (配置HTTPS后)

### 2. 环境变量
```bash
# 管理员令牌（用于管理接口）
export ADMIN_TOKEN="your-admin-token-here"

# 用户API密钥（用于普通接口）
export API_KEY="your-api-key-here"
```

## API 示例

### 1. 健康检查
```bash
# 检查服务是否正常运行
curl -fsS http://localhost:8787/healthz
```

### 2. 获取使用情况（需要API密钥）
```bash
# 使用API密钥获取当前使用情况
curl -H "Authorization: Bearer $API_KEY" \
  http://localhost:8787/usage
```

### 3. 管理员接口

#### 3.1 生成试用密钥
```bash
# 生成一个新的试用密钥（有效期7天，1000次调用限制）
curl -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"trial-user-001","max_calls":1000,"valid_days":7}' \
  http://localhost:8787/admin/keys
```

#### 3.2 查看所有密钥
```bash
# 查看所有已生成的密钥及其使用情况
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/keys
```

#### 3.3 查看使用统计
```bash
# 查看所有用户的使用统计
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/usage
```

### 4. 代理请求示例

#### 4.1 代理OpenAI API请求
```bash
# 通过quota-proxy转发到OpenAI API
curl -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello!"}]}' \
  http://localhost:8787/v1/chat/completions
```

#### 4.2 代理DeepSeek API请求
```bash
# 通过quota-proxy转发到DeepSeek API
curl -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好！"}]}' \
  http://localhost:8787/v1/chat/completions
```

## 脚本示例

### 1. 自动化测试脚本
```bash
#!/bin/bash
# test-quota-proxy.sh

API_URL="http://localhost:8787"
API_KEY="${API_KEY:-test-key}"
ADMIN_TOKEN="${ADMIN_TOKEN:-admin-token}"

echo "=== quota-proxy API 测试 ==="

# 1. 健康检查
echo "1. 健康检查..."
curl -fsS "$API_URL/healthz" && echo " ✓ 服务正常"

# 2. 生成试用密钥
echo "2. 生成试用密钥..."
KEY_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-script","max_calls":10,"valid_days":1}' \
  "$API_URL/admin/keys")

echo "生成的密钥：$KEY_RESPONSE"

# 3. 测试API调用
echo "3. 测试API调用..."
curl -s -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Test message"}]}' \
  "$API_URL/v1/chat/completions" | jq '.choices[0].message.content'

echo "=== 测试完成 ==="
```

### 2. 监控脚本
```bash
#!/bin/bash
# monitor-quota-proxy.sh

API_URL="http://localhost:8787"
ADMIN_TOKEN="${ADMIN_TOKEN}"

# 检查服务健康
if curl -fsS "$API_URL/healthz" > /dev/null; then
  echo "[$(date)] 服务正常"
else
  echo "[$(date)] 警告：服务不可用"
  exit 1
fi

# 获取使用统计
if [ -n "$ADMIN_TOKEN" ]; then
  USAGE=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$API_URL/admin/usage")
  echo "当前使用统计："
  echo "$USAGE" | jq .
fi
```

## 故障排除

### 常见问题

1. **401 Unauthorized**
   - 检查API密钥是否正确
   - 确认密钥是否已过期
   - 验证Authorization头格式：`Bearer <token>`

2. **429 Too Many Requests**
   - 检查调用频率是否超过限制
   - 查看当前使用情况：`curl -H "Authorization: Bearer $API_KEY" http://localhost:8787/usage`

3. **503 Service Unavailable**
   - 检查quota-proxy服务是否运行：`docker compose ps`
   - 检查后端API服务是否可用

### 调试命令
```bash
# 查看服务日志
docker compose logs quota-proxy

# 查看数据库状态（如果使用SQLite）
docker compose exec quota-proxy sqlite3 /data/quota.db ".tables"

# 检查网络连接
curl -v http://localhost:8787/healthz
```

## 集成示例

### 1. Python客户端
```python
import requests

class QuotaProxyClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
    
    def chat_completion(self, messages, model="gpt-3.5-turbo"):
        response = requests.post(
            f"{self.base_url}/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": model,
                "messages": messages
            }
        )
        response.raise_for_status()
        return response.json()
```

### 2. Node.js客户端
```javascript
const axios = require('axios');

class QuotaProxyClient {
  constructor(baseUrl, apiKey) {
    this.client = axios.create({
      baseURL: baseUrl,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }
  
  async chatCompletion(messages, model = 'gpt-3.5-turbo') {
    const response = await this.client.post('/v1/chat/completions', {
      model,
      messages
    });
    return response.data;
  }
}
```

## 最佳实践

1. **密钥管理**
   - 将API密钥存储在环境变量中
   - 定期轮换密钥
   - 为不同应用使用不同密钥

2. **错误处理**
   - 实现重试机制（指数退避）
   - 监控API调用成功率
   - 设置告警阈值

3. **性能优化**
   - 使用连接池
   - 启用HTTP/2
   - 缓存频繁请求

---

*本文档最后更新：2026-02-10*
