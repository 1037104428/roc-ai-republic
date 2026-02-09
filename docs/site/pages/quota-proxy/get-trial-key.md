# 获取试用密钥 (TRIAL_KEY)

## 概述

Quota-Proxy 是一个轻量级配额代理服务，用于管理 API 调用配额。要使用该服务，您需要获取一个试用密钥 (TRIAL_KEY)。

## 获取方式

### 1. 手动申请（当前方式）

目前 TRIAL_KEY 由管理员手动发放。以下是管理员发放 TRIAL_KEY 的完整流程：

#### 管理员操作步骤：

**前提条件：**
- Quota-Proxy 服务已启动并运行在 SQLite 模式下
- 已设置 `ADMIN_TOKEN` 环境变量
- 管理接口仅在内网可访问（建议监听 127.0.0.1）

**步骤 1：生成 TRIAL_KEY**

使用仓库提供的管理脚本（推荐）：
```bash
# 进入项目目录
cd /path/to/roc-ai-republic/quota-proxy

# 设置管理员令牌
export ADMIN_TOKEN='your_admin_token_here'

# 生成新的 TRIAL_KEY（可指定标签用于标识用户）
./scripts/quota-proxy-admin.sh keys-create --label 'forum-user:alice'
```

或使用 curl 命令：
```bash
export ADMIN_TOKEN='your_admin_token_here'
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'
```

**响应示例：**
```json
{
  "key": "trial_abc123def456",
  "label": "forum-user:alice", 
  "created_at": 1741781220000
}
```

**步骤 2：将 TRIAL_KEY 安全地发送给用户**

将生成的 `trial_abc123def456` 通过安全渠道发送给用户，例如：
- 加密邮件
- 安全消息应用
- 用户账户系统

**步骤 3：告知用户使用方法**

提供以下使用说明给用户：
```bash
# 方法1：使用环境变量
export CLAWD_TRIAL_KEY="trial_abc123def456"

# 方法2：在代码中直接使用
headers = {
    "Authorization": "Bearer trial_abc123def456",
    "Content-Type": "application/json"
}
```

#### 用户验证密钥是否有效：

用户可以使用以下命令验证密钥：
```bash
# 验证密钥是否有效
curl -s -o /dev/null -w "%{http_code}\n" \
  http://127.0.0.1:8787/v1/chat/completions \
  -H 'content-type: application/json' \
  -H 'Authorization: Bearer trial_abc123def456' \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}]}'
# 预期返回 200 或 429（配额用尽）
```

### 2. 自动申请（计划中）

我们正在开发自助申请系统，届时您将可以通过网页表单直接申请。

## 使用示例

### 使用 TRIAL_KEY 调用 DeepSeek API

```bash
# 方法1：使用环境变量
export CLAWD_TRIAL_KEY="trial_abc123def456"

# 调用聊天接口
curl -X POST "http://127.0.0.1:8787/v1/chat/completions" \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好！请介绍一下你自己。"}
    ],
    "stream": false
  }'

# 方法2：直接在请求头中使用
curl -X POST "http://127.0.0.1:8787/v1/chat/completions" \
  -H "Authorization: Bearer trial_abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-reasoner",
    "messages": [
      {"role": "user", "content": "请帮我解决这个数学问题..."}
    ]
  }'
```

### 检查配额使用情况

**用户自查：**
```bash
# 查看今日使用量（需要管理员权限，通常用户无法直接查询）
# 请联系管理员查询您的使用情况
```

**管理员查询用户使用情况：**
```bash
# 查询特定用户今日使用量
export ADMIN_TOKEN='your_admin_token_here'
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=trial_abc123def456" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 查询所有用户今日使用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 响应示例
{
  "day": "2026-02-09",
  "mode": "sqlite",
  "items": [
    {
      "key": "trial_abc123def456",
      "req_count": 15,
      "updated_at": 1741782000000
    },
    {
      "key": "trial_xyz789",
      "req_count": 42,
      "updated_at": 1741781500000
    }
  ]
}
```

### 列出所有已签发的密钥

```bash
# 管理员查看所有已签发的 TRIAL_KEY
export ADMIN_TOKEN='your_admin_token_here'
curl -fsS http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 响应示例
[
  {
    "key": "trial_abc123def456",
    "label": "forum-user:alice",
    "created_at": 1741781220000
  },
  {
    "key": "trial_xyz789",
    "label": "developer:beta-test",
    "created_at": 1741778000000
  }
]
```

## 配额限制

- **每日请求数**：每个 TRIAL_KEY 有每日请求上限
- **并发限制**：防止滥用
- **过期时间**：试用密钥可能有有效期限制

## 注意事项

1. **保密性**：请妥善保管您的 TRIAL_KEY，不要泄露给他人
2. **环境变量**：建议使用 `CLAWD_TRIAL_KEY` 环境变量存储密钥
3. **配额监控**：定期检查使用情况，避免超出限制
4. **问题反馈**：如遇问题，请联系管理员或提交 GitHub Issue

## 相关链接

- [Quota-Proxy 项目主页](../)
- [管理员接口文档](../../quota-proxy/ADMIN-INTERFACE.md)
- [GitHub 仓库](https://gitee.com/junkaiWang324/roc-ai-republic/tree/main/quota-proxy)