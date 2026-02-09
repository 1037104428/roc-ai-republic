# Quota-Proxy API 快速上手指南

本文档提供 quota-proxy API 的快速使用示例，帮助开发者快速集成。

## 基础信息

- **API 网关地址**: `https://clawdrepublic.cn/api`
- **健康检查**: `GET /healthz`
- **API 版本**: v1

## 获取试用密钥

### 方式1：通过管理界面（需要 ADMIN_TOKEN）

```bash
# 生成试用密钥（有效期30天）
curl -X POST https://clawdrepublic.cn/api/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "trial-user-001",
    "quota": 1000,
    "expiresInDays": 30
  }'

# 响应示例
{
  "key": "sk-trial-abc123def456",
  "name": "trial-user-001",
  "quota": 1000,
  "remaining": 1000,
  "expiresAt": "2026-03-12T01:35:00Z"
}
```

### 方式2：通过脚本自动获取

```bash
# 使用部署脚本中的工具
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/generate-trial-key.sh --name "my-app" --quota 500
```

## API 使用示例

### 1. 基础请求（带配额检查）

```bash
# 设置环境变量
export TRIAL_KEY="sk-trial-abc123def456"
export API_BASE="https://clawdrepublic.cn/api"

# 发送请求（自动扣除配额）
curl -X POST "$API_BASE/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'

# 响应包含配额信息
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "choices": [...],
  "usage": {...},
  "quota": {
    "remaining": 999,
    "total": 1000,
    "resetAt": "2026-03-12T01:35:00Z"
  }
}
```

### 2. 检查配额状态

```bash
# 查看当前配额使用情况
curl -X GET "$API_BASE/v1/quota" \
  -H "Authorization: Bearer $TRIAL_KEY"

# 响应示例
{
  "key": "sk-trial-abc123def456",
  "name": "trial-user-001",
  "totalQuota": 1000,
  "remainingQuota": 999,
  "usedQuota": 1,
  "expiresAt": "2026-03-12T01:35:00Z",
  "createdAt": "2026-02-10T01:35:00Z"
}
```

### 3. 错误处理

#### 配额不足
```json
{
  "error": {
    "message": "Insufficient quota",
    "type": "quota_exceeded",
    "code": 429,
    "remaining": 0
  }
}
```

#### 密钥无效或过期
```json
{
  "error": {
    "message": "Invalid or expired API key",
    "type": "authentication_error",
    "code": 401
  }
}
```

## 客户端集成示例

### Python

```python
import requests
import os

class QuotaProxyClient:
    def __init__(self, api_key=None, base_url="https://clawdrepublic.cn/api"):
        self.api_key = api_key or os.getenv("TRIAL_KEY")
        self.base_url = base_url
        
    def chat_completion(self, messages, model="gpt-3.5-turbo"):
        url = f"{self.base_url}/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": model,
            "messages": messages
        }
        
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        return response.json()
    
    def get_quota(self):
        url = f"{self.base_url}/v1/quota"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json()

# 使用示例
client = QuotaProxyClient(api_key="sk-trial-abc123def456")

# 检查配额
quota = client.get_quota()
print(f"剩余配额: {quota['remainingQuota']}/{quota['totalQuota']}")

# 发送消息
response = client.chat_completion([
    {"role": "user", "content": "What is AI?"}
])
print(response["choices"][0]["message"]["content"])
```

### JavaScript/Node.js

```javascript
const axios = require('axios');

class QuotaProxyClient {
  constructor(apiKey, baseUrl = 'https://clawdrepublic.cn/api') {
    this.apiKey = apiKey || process.env.TRIAL_KEY;
    this.baseUrl = baseUrl;
    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
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

  async getQuota() {
    const response = await this.client.get('/v1/quota');
    return response.data;
  }
}

// 使用示例
async function main() {
  const client = new QuotaProxyClient('sk-trial-abc123def456');
  
  try {
    // 检查配额
    const quota = await client.getQuota();
    console.log(`配额: ${quota.remainingQuota}/${quota.totalQuota}`);
    
    // 发送请求
    const response = await client.chatCompletion([
      { role: 'user', content: 'Explain quantum computing in simple terms' }
    ]);
    console.log(response.choices[0].message.content);
  } catch (error) {
    console.error('API错误:', error.response?.data || error.message);
  }
}

main();
```

## 最佳实践

1. **环境变量管理**: 将 `TRIAL_KEY` 存储在环境变量中，不要硬编码在代码里
2. **错误重试**: 对于配额不足错误（429），建议等待配额重置或联系管理员
3. **配额监控**: 定期检查配额使用情况，避免服务中断
4. **密钥轮换**: 定期更新密钥，增强安全性
5. **请求批处理**: 对于大量请求，考虑批处理以减少API调用次数

## 故障排除

### 常见问题

1. **502 Bad Gateway**: 检查服务是否正常运行 `curl -fsS https://clawdrepublic.cn/api/healthz`
2. **401 Unauthorized**: 验证API密钥是否正确且未过期
3. **429 Too Many Requests**: 配额已用完，需要等待重置或申请更多配额
4. **连接超时**: 检查网络连接，或尝试使用国内镜像源

### 调试命令

```bash
# 检查服务健康
curl -v https://clawdrepublic.cn/api/healthz

# 验证密钥有效性
curl -H "Authorization: Bearer $TRIAL_KEY" https://clawdrepublic.cn/api/v1/quota

# 查看详细错误信息
curl -v -H "Authorization: Bearer $TRIAL_KEY" \
  -X POST https://clawdrepublic.cn/api/v1/chat/completions \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"test"}]}'
```

## 支持与反馈

- **文档**: [https://github.com/1037104428/roc-ai-republic](https://github.com/1037104428/roc-ai-republic)
- **问题反馈**: GitHub Issues
- **社区**: [https://clawdrepublic.cn/forum/](https://clawdrepublic.cn/forum/)

---

*最后更新: 2026-02-10*