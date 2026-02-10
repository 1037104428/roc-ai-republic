# TRIAL_KEY 申请指南

## 概述

TRIAL_KEY 是 Clawd Republic 提供的试用密钥，允许开发者免费体验 AI 调用服务。我们提供 Web 自助申请界面，简化申请流程。

## 申请流程

### 1. Web 自助申请（推荐）

访问我们的在线申请页面，填写简单表单即可申请：

1. **访问申请页面**
   - 在线申请：`https://api.clawdrepublic.cn/apply/`
   - 本地部署：`http://localhost:8787/apply/`

2. **填写申请信息**
   - 邮箱地址（必填，用于接收密钥）
   - 姓名/昵称（可选）
   - 使用目的（必填，如：学习、开发、测试等）
   - 预计每日用量（可选）

3. **提交申请**
   - 点击"提交申请"按钮
   - 系统会显示申请已提交的确认信息
   - 管理员会在 24 小时内审核并发放密钥

4. **获取密钥**
   - 审核通过后，密钥将通过邮件发送给你
   - 密钥格式：`sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 2. 手动申请（备用方案）

如果自助申请系统暂时不可用，可通过以下方式申请：

1. **准备申请信息**
   - **用途说明**：学习、测试、项目开发等
   - **预计使用频率**：每日/每周调用次数预估
   - **联系方式**：邮箱或社交媒体账号

2. **提交申请**
   - **GitHub Issues**：在 [Clawd Republic Issues](https://github.com/your-repo/issues) 页面创建新 issue
   - **社区论坛**：在官方论坛的"密钥申请"板块发帖
   - **邮件申请**：发送邮件至 admin@clawdrepublic.cn

3. **申请模板**
   ```
   【TRIAL_KEY 申请】

   用途：学习 AI 调用接口
   预计频率：每日 10-20 次调用
   联系方式：example@email.com
   备注：希望测试不同模型的效果
   ```

### 3. 审核与发放
- 审核时间：通常在 24 小时内
- 发放方式：通过邮件发送密钥
- 密钥格式：`sk-` + 32位随机字符

## 密钥使用说明

### 有效期
- 试用期：30 天
- 调用限额：每日 100 次调用
- 可续期：试用期满后可申请续期

### 快速验证密钥
拿到密钥后，建议先进行快速验证：

```bash
# 设置环境变量（避免反复复制）
export TRIAL_KEY="YOUR_TRIAL_KEY_HERE"

# 1. 健康检查（不消耗额度）
curl -fsS https://api.clawdrepublic.cn/healthz

# 2. 查看可用模型（确认密钥生效）
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $TRIAL_KEY" \
  | head -20

# 3. 检查配额使用情况
curl -fsS https://api.clawdrepublic.cn/v1/quota/usage \
  -H "Authorization: Bearer $TRIAL_KEY" \
  | python3 -m json.tool
```

### 完整调用示例

#### 1. 基础调用示例（同步响应）

```bash
# 设置环境变量
export TRIAL_KEY="your_trial_key_here"

# 基础聊天调用
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下 Clawd Republic"}
    ]
  }'

# 或者使用本地部署
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下 Clawd Republic"}
    ]
  }'
```

#### 2. 流式响应示例（适合长文本）

```bash
# 流式调用（实时显示响应）
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "写一首关于AI的诗"}
    ],
    "stream": true
  }'

# 流式调用并格式化输出
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "解释一下量子计算的基本原理"}
    ],
    "stream": true
  }' | while IFS= read -r line; do
    if [[ $line == data:* ]]; then
        content="${line#data: }"
        if [[ $content != "[DONE]" ]]; then
            echo -n "$content" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'choices' in data and len(data['choices']) > 0:
        delta = data['choices'][0].get('delta', {})
        if 'content' in delta:
            print(delta['content'], end='', flush=True)
except:
    pass
"
        fi
    fi
done
```

#### 3. 带参数的调用示例

```bash
# 带系统消息和参数
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "system", "content": "你是一个有帮助的AI助手"},
      {"role": "user", "content": "帮我写一个Python函数，计算斐波那契数列"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'

# 多轮对话
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "system", "content": "你是一个代码专家"},
      {"role": "user", "content": "写一个快速排序算法"},
      {"role": "assistant", "content": "def quick_sort(arr):\n    if len(arr) <= 1:\n        return arr\n    pivot = arr[len(arr) // 2]\n    left = [x for x in arr if x < pivot]\n    middle = [x for x in arr if x == pivot]\n    right = [x for x in arr if x > pivot]\n    return quick_sort(left) + middle + quick_sort(right)"},
      {"role": "user", "content": "现在写一个测试用例"}
    ]
  }'
```

#### 4. 验证和检查示例

```bash
# 检查密钥有效性
curl -H "Authorization: Bearer $TRIAL_KEY" \
  https://api.clawdrepublic.cn/v1/models

# 查看可用模型
curl -s https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $TRIAL_KEY" | python3 -m json.tool

# 健康检查（不消耗配额）
curl -fsS https://api.clawdrepublic.cn/healthz
```

### 实际使用脚本示例

```bash
#!/bin/bash
# 示例：使用TRIAL_KEY调用AI API的完整脚本

TRIAL_KEY="YOUR_TRIAL_KEY_HERE"
API_URL="https://api.clawdrepublic.cn/v1/chat/completions"

# 函数：调用AI
call_ai() {
    local prompt="$1"
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TRIAL_KEY" \
        -d "{
            \"model\": \"deepseek-chat\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"temperature\": 0.7
        }" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except:
    print('调用失败')
"
}

# 示例调用
echo "测试AI调用..."
response=$(call_ai "用一句话介绍Clawd Republic")
echo "AI回复：$response"
```

### 使用限制
1. **禁止公开分享**：密钥仅限个人使用
2. **禁止商业用途**：试用期间禁止用于商业生产环境
3. **合理使用**：请勿进行压力测试或恶意调用

## 常见问题

### Q: 申请被拒绝的可能原因？
A: 信息不完整、用途不明确、已有活跃密钥等。

### Q: 密钥丢失怎么办？
A: 联系管理员重新发放，原密钥将失效。

### Q: 可以申请多个密钥吗？
A: 原则上每人限一个试用密钥，特殊情况需说明。

### Q: 试用期满后如何续期？
A: 提交使用报告和续期申请，说明使用情况和后续计划。

## 管理员功能

### 查看使用情况

管理员可以通过以下命令查看密钥使用情况：

```bash
# 查看所有密钥的配额使用情况
curl -H "Authorization: Bearer $ADMIN_KEY" \
  https://api.clawdrepublic.cn/admin/usage

# 查看特定密钥的使用详情
curl -H "Authorization: Bearer $ADMIN_KEY" \
  "https://api.clawdrepublic.cn/admin/usage?key=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 查看今日使用统计
curl -H "Authorization: Bearer $ADMIN_KEY" \
  "https://api.clawdrepublic.cn/admin/usage/today"
```

### 管理员API响应示例

#### 1. 所有密钥使用情况
```json
{
  "status": "success",
  "data": {
    "total_keys": 15,
    "active_keys": 12,
    "total_requests_today": 342,
    "total_tokens_today": 12567,
    "keys": [
      {
        "key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "owner": "user@example.com",
        "created_at": "2026-02-09T08:30:00Z",
        "total_requests": 45,
        "total_tokens": 1567,
        "requests_today": 12,
        "tokens_today": 345,
        "is_active": true,
        "last_used": "2026-02-10T14:30:15Z"
      },
      // ... 更多密钥
    ]
  }
}
```

#### 2. 特定密钥详情
```json
{
  "status": "success",
  "data": {
    "key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "owner": "user@example.com",
    "created_at": "2026-02-09T08:30:00Z",
    "total_requests": 45,
    "total_tokens": 1567,
    "daily_usage": [
      {
        "date": "2026-02-10",
        "requests": 12,
        "tokens": 345
      },
      {
        "date": "2026-02-09",
        "requests": 33,
        "tokens": 1222
      }
    ],
    "recent_requests": [
      {
        "timestamp": "2026-02-10T14:30:15Z",
        "endpoint": "/v1/chat/completions",
        "model": "deepseek-chat",
        "tokens": 45
      }
    ]
  }
}
```

#### 3. 今日统计
```json
{
  "status": "success",
  "data": {
    "date": "2026-02-10",
    "total_requests": 342,
    "total_tokens": 12567,
    "top_keys": [
      {
        "key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "requests": 45,
        "tokens": 1567
      }
    ],
    "endpoint_distribution": {
      "/v1/chat/completions": 280,
      "/v1/models": 62
    }
  }
}
```

### 管理操作

```bash
# 重置密钥配额（管理员操作）
curl -X POST -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  https://api.clawdrepublic.cn/admin/reset-quota \
  -d '{"key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'

# 停用/启用密钥
curl -X POST -H "Authorization: Bearer $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  https://api.clawdrepublic.cn/admin/toggle-key \
  -d '{"key": "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "active": false}'

# 删除密钥
curl -X DELETE -H "Authorization: Bearer $ADMIN_KEY" \
  "https://api.clawdrepublic.cn/admin/key/sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## 技术支持
- 文档：https://docs.clawdrepublic.cn
- 社区：https://forum.clawdrepublic.cn
- 邮箱：support@clawdrepublic.cn

---

**重要提醒**：请妥善保管你的 TRIAL_KEY，避免泄露。如发现异常使用，我们将立即停用该密钥。