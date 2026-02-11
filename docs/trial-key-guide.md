# TRIAL_KEY 获取指南

本文档详细说明如何获取 Clawd 国度的试用密钥（TRIAL_KEY），包含手动发放流程和自动化API调用示例。

## 概述

TRIAL_KEY 是 Clawd 国度提供的试用访问令牌，允许用户在有限时间内体验核心功能。目前采用手动审核发放机制，未来将逐步实现自动化申请流程。

## 手动发放流程（管理员）

### 1. 生成试用密钥

管理员可以通过以下命令生成新的试用密钥：

```bash
# 进入 quota-proxy 目录
cd roc-ai-republic/quota-proxy

# 生成试用密钥（有效期7天）
node scripts/generate-trial-key.js --duration 7d --user "example@email.com" --notes "试用用户申请"
```

参数说明：
- `--duration`: 有效期（如 7d、30d、1h）
- `--user`: 申请用户标识（邮箱或用户名）
- `--notes`: 备注信息
- `--quota`: 配额限制（默认：1000次调用）

### 2. 审核申请

管理员需要审核申请信息，确保：
- 申请用户提供真实有效的联系方式
- 申请用途符合 Clawd 国度服务条款
- 无重复申请或滥用行为

### 3. 发放密钥

审核通过后，管理员通过安全渠道（加密邮件、私信等）将生成的密钥发送给用户：

```
TRIAL_KEY: trial_abc123def456ghi789jkl012mno345pqr678stu901
有效期：2026-02-18 23:59:59
配额：1000次调用
```

### 4. 记录发放

管理员应在 `docs/admin/trial-keys-log.md` 中记录发放信息：

```markdown
## 试用密钥发放记录

| 日期 | 密钥ID | 用户 | 有效期 | 配额 | 状态 | 备注 |
|------|--------|------|--------|------|------|------|
| 2026-02-11 | trial_abc123... | example@email.com | 7天 | 1000 | 已发放 | 开发者试用 |
```

## 用户使用指南

### 1. 获取试用密钥

用户可以通过以下方式申请试用密钥：

1. **官网申请**：访问 Clawd 国度官网，填写试用申请表单
2. **社区申请**：在 Clawd 国度社区论坛发帖申请
3. **直接联系**：通过官方联系方式申请

### 2. 使用试用密钥

获得 TRIAL_KEY 后，用户可以通过以下方式使用：

#### cURL 示例

```bash
# 设置试用密钥
export TRIAL_KEY="trial_abc123def456ghi789jkl012mno345pqr678stu901"

# 调用 API 服务
curl -X POST "https://api.clawd.ai/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-chat",
    "messages": [
      {"role": "user", "content": "你好，Clawd！"}
    ]
  }'
```

#### Python 示例

```python
import os
import requests

TRIAL_KEY = os.getenv("TRIAL_KEY", "trial_abc123def456ghi789jkl012mno345pqr678stu901")

headers = {
    "Authorization": f"Bearer {TRIAL_KEY}",
    "Content-Type": "application/json"
}

data = {
    "model": "clawd-chat",
    "messages": [
        {"role": "user", "content": "你好，Clawd！"}
    ]
}

response = requests.post(
    "https://api.clawd.ai/v1/chat/completions",
    headers=headers,
    json=data
)

print(response.json())
```

#### JavaScript 示例

```javascript
const TRIAL_KEY = process.env.TRIAL_KEY || "trial_abc123def456ghi789jkl012mno345pqr678stu901";

const response = await fetch("https://api.clawd.ai/v1/chat/completions", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${TRIAL_KEY}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    model: "clawd-chat",
    messages: [
      { role: "user", content: "你好，Clawd！" }
    ]
  })
});

const data = await response.json();
console.log(data);
```

### 3. 检查配额使用情况

用户可以通过以下命令检查试用密钥的配额使用情况：

```bash
# 使用 admin/usage 端点
curl -H "Authorization: Bearer $TRIAL_KEY" \
  "https://api.clawd.ai/admin/usage"
```

响应示例：
```json
{
  "key_id": "trial_abc123def456ghi789jkl012mno345pqr678stu901",
  "user": "example@email.com",
  "total_quota": 1000,
  "used_quota": 42,
  "remaining_quota": 958,
  "valid_until": "2026-02-18T23:59:59Z",
  "status": "active",
  "created_at": "2026-02-11T21:17:51Z"
}
```

## admin/usage 输出说明

`admin/usage` 端点返回详细的试用密钥使用信息：

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `key_id` | string | 试用密钥的唯一标识符 |
| `user` | string | 关联的用户标识（邮箱或用户名） |
| `total_quota` | integer | 总配额（调用次数） |
| `used_quota` | integer | 已使用的配额 |
| `remaining_quota` | integer | 剩余配额 |
| `valid_until` | string | 密钥有效期截止时间（ISO 8601格式） |
| `status` | string | 密钥状态：`active`（活跃）、`expired`（已过期）、`revoked`（已撤销）、`exhausted`（配额耗尽） |
| `created_at` | string | 密钥创建时间（ISO 8601格式） |
| `last_used` | string | 最后一次使用时间（ISO 8601格式，可选） |
| `notes` | string | 管理员备注信息（可选） |

### 状态说明

- **active**: 密钥有效，配额充足
- **expired**: 密钥已超过有效期
- **revoked**: 密钥已被管理员手动撤销
- **exhausted**: 配额已用完

### 错误响应

当密钥无效或无权访问时，会返回错误信息：

```json
{
  "error": "invalid_key",
  "message": "试用密钥无效或已过期"
}
```

或
```json
{
  "error": "insufficient_permissions",
  "message": "无权访问此信息"
}
```

## 常见问题

### Q1: 试用密钥可以续期吗？
A: 目前试用密钥不支持自动续期。如需继续使用，请重新申请或升级到正式套餐。

### Q2: 试用密钥有调用频率限制吗？
A: 是的，试用密钥通常有每分钟/每小时调用频率限制，具体限制请参考密钥发放时的说明。

### Q3: 试用密钥可以用于生产环境吗？
A: 不建议。试用密钥主要用于测试和评估，生产环境请使用正式API密钥。

### Q4: 如何报告试用密钥问题？
A: 请通过以下方式报告问题：
- 发送邮件至：support@clawd.ai
- 在社区论坛发帖：https://community.clawd.ai
- 通过官网联系表单

## 安全注意事项

1. **不要公开分享**：试用密钥包含在代码或公开仓库中
2. **使用环境变量**：建议通过环境变量管理密钥
3. **定期轮换**：如果怀疑密钥泄露，请立即联系管理员撤销并重新发放
4. **监控使用**：定期检查配额使用情况，避免意外超额

## 下一步计划

1. **自动化申请系统**：开发在线试用申请表单和自动审核流程
2. **自助服务门户**：创建用户自助服务门户，允许用户查看使用情况和申请续期
3. **多层级试用**：提供不同层级的试用套餐（基础试用、开发者试用、企业试用）
4. **集成支付**：为试用转正式用户提供无缝支付集成

---

*最后更新：2026-02-11*
*文档版本：v1.0*