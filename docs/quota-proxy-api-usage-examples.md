# quota-proxy API 使用示例

本文档提供 quota-proxy 核心管理接口的详细使用示例，包括 `POST /admin/keys` 和 `GET /admin/usage` 接口的实际调用方法、参数说明和常见使用场景。

## 环境准备

### 1. 获取管理员令牌
```bash
# 查看当前配置的管理员令牌
echo $ADMIN_TOKEN

# 或从环境文件加载
source /opt/roc/quota-proxy/.env
echo $ADMIN_TOKEN
```

### 2. 确认服务地址
```bash
# 本地开发环境
BASE_URL="http://localhost:8787"

# 生产环境（根据实际部署调整）
BASE_URL="https://api.your-domain.com"
```

## POST /admin/keys - 创建试用密钥

### 基本用法
```bash
# 创建单个试用密钥（默认7天有效期）
curl -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "expiry_days": 7,
    "max_requests_per_day": 100,
    "notes": "测试用户 - 张三"
  }'
```

### 批量创建
```bash
# 批量创建5个试用密钥
for i in {1..5}; do
  curl -X POST "${BASE_URL}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"expiry_days\": 30,
      \"max_requests_per_day\": 500,
      \"notes\": \"批量创建 - 用户${i}\"
    }" &
done
wait
```

### 高级配置
```bash
# 创建长期有效的密钥（90天）
curl -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "expiry_days": 90,
    "max_requests_per_day": 1000,
    "notes": "VIP用户 - 长期有效",
    "metadata": {
      "user_id": "user_12345",
      "plan": "premium",
      "contact_email": "user@example.com"
    }
  }'
```

### 错误处理示例
```bash
# 缺少授权令牌
curl -X POST "${BASE_URL}/admin/keys" \
  -H "Content-Type: application/json" \
  -d '{"expiry_days": 7}' \
  -w "\nHTTP Status: %{http_code}\n"

# 无效参数
curl -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"expiry_days": -1}' \
  -w "\nHTTP Status: %{http_code}\n"
```

## GET /admin/usage - 查询使用统计

### 基本查询
```bash
# 查询所有密钥的使用统计
curl -X GET "${BASE_URL}/admin/usage" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 按时间范围查询
```bash
# 查询最近7天的使用统计
curl -X GET "${BASE_URL}/admin/usage?days=7" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 查询指定日期范围
curl -X GET "${BASE_URL}/admin/usage?start_date=2026-02-01&end_date=2026-02-10" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 按密钥查询
```bash
# 查询特定密钥的使用情况
curl -X GET "${BASE_URL}/admin/usage?api_key=trial_abc123def456" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 查询多个密钥的使用情况
curl -X GET "${BASE_URL}/admin/usage?api_keys=trial_key1,trial_key2,trial_key3" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 详细统计
```bash
# 获取详细统计信息（包含每日使用量）
curl -X GET "${BASE_URL}/admin/usage?detailed=true" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

## 实际使用场景

### 场景1：新用户注册流程
```bash
#!/bin/bash
# 新用户注册时创建试用密钥

USER_EMAIL="$1"
USER_NAME="$2"

# 创建试用密钥
RESPONSE=$(curl -s -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"expiry_days\": 7,
    \"max_requests_per_day\": 100,
    \"notes\": \"新用户注册 - ${USER_NAME}\",
    \"metadata\": {
      \"email\": \"${USER_EMAIL}\",
      \"registration_date\": \"$(date +%Y-%m-%d)\"
    }
  }")

# 提取生成的密钥
API_KEY=$(echo "$RESPONSE" | jq -r '.api_key')

# 发送欢迎邮件（示例）
echo "欢迎 ${USER_NAME}！您的试用密钥已生成：${API_KEY}"
echo "有效期：7天，每日限制：100次请求"
```

### 场景2：每日使用报告
```bash
#!/bin/bash
# 生成每日使用报告

# 查询昨日使用统计
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

REPORT=$(curl -s -X GET "${BASE_URL}/admin/usage?start_date=${YESTERDAY}&end_date=${TODAY}&detailed=true" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

# 解析报告数据
TOTAL_REQUESTS=$(echo "$REPORT" | jq '.total_requests')
ACTIVE_KEYS=$(echo "$REPORT" | jq '.active_keys')
NEAR_LIMIT_KEYS=$(echo "$REPORT" | jq '.near_limit_keys')

# 生成报告
cat << EOR
=== 每日使用报告 ===
日期: ${YESTERDAY}
总请求数: ${TOTAL_REQUESTS}
活跃密钥数: ${ACTIVE_KEYS}
接近限制密钥数: ${NEAR_LIMIT_KEYS}

详细统计:
$(echo "$REPORT" | jq -r '.daily_usage[] | "\(.date): \(.requests) 次请求"')
EOR
```

### 场景3：配额监控告警
```bash
#!/bin/bash
# 监控接近配额限制的密钥

THRESHOLD=80  # 使用率阈值（百分比）

# 获取所有密钥的使用情况
USAGE_DATA=$(curl -s -X GET "${BASE_URL}/admin/usage?detailed=true" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

# 检查每个密钥的使用率
echo "$USAGE_DATA" | jq -c '.key_usage[]' | while read -r KEY_DATA; do
  API_KEY=$(echo "$KEY_DATA" | jq -r '.api_key')
  USED=$(echo "$KEY_DATA" | jq -r '.used')
  LIMIT=$(echo "$KEY_DATA" | jq -r '.limit')
  
  if [ "$LIMIT" -gt 0 ]; then
    USAGE_PERCENT=$((USED * 100 / LIMIT))
    
    if [ "$USAGE_PERCENT" -ge "$THRESHOLD" ]; then
      echo "警告: 密钥 ${API_KEY} 使用率 ${USAGE_PERCENT}% (${USED}/${LIMIT})"
    fi
  fi
done
```

## 集成示例

### Python 集成
```python
import requests
import json

class QuotaProxyClient:
    def __init__(self, base_url, admin_token):
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer {admin_token}",
            "Content-Type": "application/json"
        }
    
    def create_trial_key(self, expiry_days=7, max_requests=100, notes=""):
        """创建试用密钥"""
        data = {
            "expiry_days": expiry_days,
            "max_requests_per_day": max_requests,
            "notes": notes
        }
        
        response = requests.post(
            f"{self.base_url}/admin/keys",
            headers=self.headers,
            json=data
        )
        response.raise_for_status()
        return response.json()
    
    def get_usage_stats(self, days=None, api_key=None, detailed=False):
        """获取使用统计"""
        params = {}
        if days:
            params["days"] = days
        if api_key:
            params["api_key"] = api_key
        if detailed:
            params["detailed"] = "true"
        
        response = requests.get(
            f"{self.base_url}/admin/usage",
            headers=self.headers,
            params=params
        )
        response.raise_for_status()
        return response.json()

# 使用示例
client = QuotaProxyClient(
    base_url="http://localhost:8787",
    admin_token="your_admin_token_here"
)

# 创建试用密钥
new_key = client.create_trial_key(
    expiry_days=30,
    max_requests=500,
    notes="Python SDK 测试"
)
print(f"创建的密钥: {new_key['api_key']}")

# 获取使用统计
stats = client.get_usage_stats(days=7, detailed=True)
print(f"最近7天总请求数: {stats['total_requests']}")
```

### Node.js 集成
```javascript
const axios = require('axios');

class QuotaProxyClient {
  constructor(baseUrl, adminToken) {
    this.client = axios.create({
      baseURL: baseUrl,
      headers: {
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    });
  }

  async createTrialKey(options = {}) {
    const { expiryDays = 7, maxRequestsPerDay = 100, notes = '' } = options;
    
    const response = await this.client.post('/admin/keys', {
      expiry_days: expiryDays,
      max_requests_per_day: maxRequestsPerDay,
      notes: notes
    });
    
    return response.data;
  }

  async getUsageStats(options = {}) {
    const { days, apiKey, detailed } = options;
    const params = {};
    
    if (days) params.days = days;
    if (apiKey) params.api_key = apiKey;
    if (detailed) params.detailed = 'true';
    
    const response = await this.client.get('/admin/usage', { params });
    return response.data;
  }
}

// 使用示例
async function main() {
  const client = new QuotaProxyClient(
    'http://localhost:8787',
    'your_admin_token_here'
  );

  // 创建试用密钥
  const newKey = await client.createTrialKey({
    expiryDays: 14,
    maxRequestsPerDay: 200,
    notes: 'Node.js 测试用户'
  });
  console.log(`创建的密钥: ${newKey.api_key}`);

  // 获取使用统计
  const stats = await client.getUsageStats({
    days: 30,
    detailed: true
  });
  console.log(`最近30天总请求数: ${stats.total_requests}`);
}

main().catch(console.error);
```

## 最佳实践

### 1. 密钥管理
- **定期轮换**: 建议每3-6个月轮换管理员令牌
- **最小权限**: 只为必要的人员分配管理员权限
- **安全存储**: 将管理员令牌存储在安全的位置（如密钥管理服务）

### 2. 监控告警
- **使用率监控**: 设置使用率阈值告警（如80%）
- **异常检测**: 监控异常的请求模式
- **定期审计**: 定期审计密钥使用情况

### 3. 性能优化
- **批量操作**: 批量创建密钥时使用并发请求
- **缓存结果**: 频繁查询的使用统计可以缓存
- **合理分页**: 大量数据时使用分页查询

### 4. 错误处理
- **重试机制**: 实现指数退避重试
- **优雅降级**: 在API不可用时提供备用方案
- **详细日志**: 记录所有API调用和错误

## 故障排除

### 常见问题

1. **401 Unauthorized**
   - 检查管理员令牌是否正确
   - 确认令牌是否已过期
   - 验证Authorization头格式

2. **400 Bad Request**
   - 检查请求参数格式
   - 验证参数值范围（如expiry_days必须为正数）
   - 确认Content-Type头为application/json

3. **503 Service Unavailable**
   - 检查quota-proxy服务是否运行
   - 验证数据库连接
   - 检查系统资源使用情况

### 调试命令
```bash
# 验证服务健康状态
curl -fsS http://localhost:8787/healthz

# 查看服务日志
docker compose logs quota-proxy

# 检查数据库状态
sqlite3 /opt/roc/quota-proxy/data/quota.db ".tables"
```

## 下一步

1. **自动化部署**: 使用CI/CD管道自动化密钥创建和监控
2. **集成监控**: 将使用统计集成到现有的监控系统
3. **用户界面**: 开发管理界面简化操作
4. **API文档**: 使用OpenAPI/Swagger生成交互式文档

如需更多帮助，请参考：
- [quota-proxy 快速开始指南](./quota-proxy-quick-start.md)
- [quota-proxy 工具链概览](./quota-proxy-toolchain-overview.md)
- [quota-proxy 验证命令速查表](./quota-proxy-validation-cheat-sheet.md)
