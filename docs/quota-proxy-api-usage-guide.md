# Quota-Proxy API 使用指南

## 概述

本文档详细介绍了quota-proxy的API使用方法，包括API密钥管理、配额查询、使用统计和管理员接口。

## 基础信息

- **服务地址**: `http://127.0.0.1:8787` (本地) 或 `https://api.roc-ai-republic.com` (生产环境)
- **健康检查**: `GET /healthz`
- **API前缀**: `/api/v1`

## API密钥管理

### 1. 生成API密钥

#### 使用管理员接口 (需要ADMIN_TOKEN)

```bash
# 使用curl生成单个API密钥
curl -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prefix": "roc",
    "quota": 1000,
    "expiresAt": "2026-12-31T23:59:59Z"
  }'

# 使用脚本工具生成
cd /opt/roc/quota-proxy
./scripts/generate-api-key.sh --prefix roc --quota 1000 --expires 2026-12-31
```

#### 批量生成API密钥

```bash
# 生成5个API密钥
./scripts/generate-api-key.sh --prefix roc --quota 1000 --count 5 --output api-keys.json
```

#### 响应示例

```json
{
  "success": true,
  "key": "roc_abc123def456",
  "quota": 1000,
  "remaining": 1000,
  "expiresAt": "2026-12-31T23:59:59Z",
  "createdAt": "2026-02-10T19:08:53Z"
}
```

### 2. 验证API密钥

```bash
# 验证API密钥有效性
curl -X GET "http://127.0.0.1:8787/api/v1/validate" \
  -H "X-API-Key: roc_abc123def456"
```

响应示例：
```json
{
  "valid": true,
  "key": "roc_abc123def456",
  "quota": 1000,
  "remaining": 1000,
  "expiresAt": "2026-12-31T23:59:59Z"
}
```

## 配额使用

### 1. 使用配额（消耗点数）

```bash
# 消耗1个配额点
curl -X POST "http://127.0.0.1:8787/api/v1/use" \
  -H "X-API-Key: roc_abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1,
    "reason": "openclaw_api_call",
    "metadata": {
      "model": "deepseek-chat",
      "tokens": 100
    }
  }'
```

响应示例：
```json
{
  "success": true,
  "key": "roc_abc123def456",
  "amountUsed": 1,
  "remaining": 999,
  "totalQuota": 1000
}
```

### 2. 批量使用配额

```bash
# 批量消耗配额（适用于批量处理）
curl -X POST "http://127.0.0.1:8787/api/v1/use/batch" \
  -H "X-API-Key: roc_abc123def456" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "amount": 2,
      "reason": "openclaw_api_call_1"
    },
    {
      "amount": 3,
      "reason": "openclaw_api_call_2"
    }
  ]'
```

## 查询统计

### 1. 查询剩余配额

```bash
# 查询单个API密钥的剩余配额
curl -X GET "http://127.0.0.1:8787/api/v1/quota" \
  -H "X-API-Key: roc_abc123def456"
```

响应示例：
```json
{
  "key": "roc_abc123def456",
  "quota": 1000,
  "remaining": 995,
  "used": 5,
  "expiresAt": "2026-12-31T23:59:59Z",
  "lastUsed": "2026-02-10T19:08:53Z"
}
```

### 2. 查询使用历史

```bash
# 查询最近的使用记录
curl -X GET "http://127.0.0.1:8787/api/v1/usage/history" \
  -H "X-API-Key: roc_abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "limit": 10,
    "offset": 0
  }'
```

响应示例：
```json
{
  "history": [
    {
      "timestamp": "2026-02-10T19:08:53Z",
      "amount": 1,
      "reason": "openclaw_api_call",
      "remaining": 999,
      "metadata": {
        "model": "deepseek-chat",
        "tokens": 100
      }
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

## 管理员接口

### 1. 查询所有API密钥使用情况

```bash
# 需要ADMIN_TOKEN认证
curl -X GET "http://127.0.0.1:8787/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "startDate": "2026-02-01",
    "endDate": "2026-02-10"
  }'
```

响应示例：
```json
{
  "summary": {
    "totalKeys": 50,
    "totalQuota": 50000,
    "totalUsed": 1250,
    "totalRemaining": 48750,
    "activeKeys": 45,
    "expiredKeys": 5
  },
  "details": [
    {
      "key": "roc_abc123def456",
      "quota": 1000,
      "used": 5,
      "remaining": 995,
      "lastUsed": "2026-02-10T19:08:53Z",
      "createdAt": "2026-02-01T10:00:00Z",
      "expiresAt": "2026-12-31T23:59:59Z"
    }
  ]
}
```

### 2. 重置API密钥配额

```bash
# 重置特定API密钥的配额
curl -X POST "http://127.0.0.1:8787/admin/keys/reset" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "roc_abc123def456",
    "newQuota": 2000
  }'
```

### 3. 禁用/启用API密钥

```bash
# 禁用API密钥
curl -X POST "http://127.0.0.1:8787/admin/keys/disable" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "roc_abc123def456"
  }'

# 启用API密钥
curl -X POST "http://127.0.0.1:8787/admin/keys/enable" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "roc_abc123def456"
  }'
```

## 客户端集成示例

### Python客户端

```python
import requests
import json

class QuotaProxyClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.headers = {
            "X-API-Key": api_key,
            "Content-Type": "application/json"
        }
    
    def validate_key(self):
        """验证API密钥"""
        response = requests.get(
            f"{self.base_url}/api/v1/validate",
            headers=self.headers
        )
        return response.json()
    
    def use_quota(self, amount, reason, metadata=None):
        """使用配额"""
        data = {
            "amount": amount,
            "reason": reason
        }
        if metadata:
            data["metadata"] = metadata
        
        response = requests.post(
            f"{self.base_url}/api/v1/use",
            headers=self.headers,
            json=data
        )
        return response.json()
    
    def get_quota(self):
        """获取配额信息"""
        response = requests.get(
            f"{self.base_url}/api/v1/quota",
            headers=self.headers
        )
        return response.json()

# 使用示例
client = QuotaProxyClient("http://127.0.0.1:8787", "roc_abc123def456")
print(client.validate_key())
print(client.use_quota(1, "test_call", {"model": "gpt-4"}))
print(client.get_quota())
```

### Node.js客户端

```javascript
const axios = require('axios');

class QuotaProxyClient {
  constructor(baseUrl, apiKey) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.client = axios.create({
      baseURL: baseUrl,
      headers: {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json'
      }
    });
  }

  async validateKey() {
    const response = await this.client.get('/api/v1/validate');
    return response.data;
  }

  async useQuota(amount, reason, metadata = null) {
    const data = {
      amount,
      reason
    };
    if (metadata) {
      data.metadata = metadata;
    }
    
    const response = await this.client.post('/api/v1/use', data);
    return response.data;
  }

  async getQuota() {
    const response = await this.client.get('/api/v1/quota');
    return response.data;
  }
}

// 使用示例
const client = new QuotaProxyClient('http://127.0.0.1:8787', 'roc_abc123def456');
client.validateKey().then(console.log);
client.useQuota(1, 'test_call', { model: 'gpt-4' }).then(console.log);
client.getQuota().then(console.log);
```

## 错误处理

### 常见错误码

| 状态码 | 错误码 | 描述 | 解决方案 |
|--------|--------|------|----------|
| 400 | INVALID_REQUEST | 请求参数无效 | 检查请求参数格式 |
| 401 | UNAUTHORIZED | API密钥无效或缺失 | 提供有效的X-API-Key头 |
| 403 | FORBIDDEN | 权限不足 | 检查API密钥权限 |
| 404 | KEY_NOT_FOUND | API密钥不存在 | 使用有效的API密钥 |
| 429 | QUOTA_EXCEEDED | 配额不足 | 申请更多配额或等待重置 |
| 500 | INTERNAL_ERROR | 服务器内部错误 | 联系管理员 |

### 错误响应示例

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "配额不足，剩余配额：0，请求配额：1",
    "details": {
      "key": "roc_abc123def456",
      "remaining": 0,
      "requested": 1
    }
  }
}
```

## 最佳实践

### 1. 安全建议
- 将ADMIN_TOKEN存储在环境变量中，不要硬编码在代码中
- 定期轮换API密钥
- 为不同用途创建不同的API密钥
- 监控API密钥使用情况，及时发现异常

### 2. 性能优化
- 批量使用配额以减少API调用次数
- 缓存配额信息，避免频繁查询
- 使用连接池管理HTTP连接

### 3. 监控告警
- 设置配额使用阈值告警（如剩余配额低于20%）
- 监控API响应时间
- 记录所有配额使用操作

## 故障排除

### 1. API密钥无效
- 检查API密钥格式是否正确
- 确认API密钥是否已过期
- 验证API密钥是否被禁用

### 2. 配额不足
- 检查当前剩余配额
- 联系管理员申请更多配额
- 优化使用模式，减少不必要的配额消耗

### 3. 连接问题
- 检查服务是否正常运行（`GET /healthz`）
- 确认网络连接是否正常
- 验证防火墙设置

## 更新日志

| 版本 | 日期 | 变更说明 |
|------|------|----------|
| v1.0 | 2026-02-10 | 初始版本，包含基础API使用指南 |
| v1.1 | 2026-02-10 | 增加客户端集成示例和最佳实践 |

---

**注意**: 本文档会随着quota-proxy的更新而更新，请定期查看最新版本。