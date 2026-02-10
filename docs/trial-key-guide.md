# TRIAL_KEY 获取与使用指南

## 什么是 TRIAL_KEY？

TRIAL_KEY 是 Clawd 国度提供的免费试用密钥，用于访问 DeepSeek API 网关服务。每个密钥每日有 200 次请求限制。

## 如何获取 TRIAL_KEY？

### 方式一：论坛申请（推荐）

1. 访问我们的论坛：https://clawdrepublic.cn/forum/
2. 注册账号并登录
3. 在「TRIAL_KEY 申请」板块发帖
4. 按照模板填写申请信息：
   - 使用场景（学习/开发/测试）
   - 预计使用频率
   - 联系方式（可选）
5. 管理员会在 24 小时内审核并发放密钥

### 方式二：管理员直接发放（内部使用）

如果你是项目贡献者或内部成员，可以通过管理员接口获取：

```bash
# 在服务器本地执行（需要管理员权限）
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "贡献者-你的名字-202502",
    "dailyLimit": 200,
    "expiresAt": "2026-12-31T23:59:59Z"
  }'
```

## 如何使用 TRIAL_KEY？

### 1. 设置环境变量

```bash
# Linux/macOS
export CLAWD_TRIAL_KEY="sk-your-trial-key-here"
echo "export CLAWD_TRIAL_KEY=\"sk-your-trial-key-here\"" >> ~/.bashrc

# Windows PowerShell
$env:CLAWD_TRIAL_KEY = "sk-your-trial-key-here"
[System.Environment]::SetEnvironmentVariable('CLAWD_TRIAL_KEY', 'sk-your-trial-key-here', 'User')
```

### 2. 验证密钥是否有效

```bash
# 检查 API 网关健康状态
curl -fsS https://api.clawdrepublic.cn/healthz

# 验证密钥权限（返回 200 表示有效）
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY"
```

### 3. 调用 DeepSeek API

```bash
# 简单对话
curl https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下自己"}
    ],
    "max_tokens": 100
  }'
```

## 查看使用情况

### 用户查看自己的用量

```bash
curl https://api.clawdrepublic.cn/v1/usage \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY"
```

### 管理员查看所有密钥用量

```bash
# 需要管理员权限
curl http://127.0.0.1:8787/admin/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 常见问题

### Q: 密钥失效了怎么办？
A: 检查是否超过每日限制（200次）或已过期。如需续期，请在论坛申请。

### Q: 收到 401/403 错误？
A: 确保：
1. 密钥正确（无多余空格）
2. 环境变量已设置（echo $CLAWD_TRIAL_KEY）
3. 密钥未过期

### Q: 如何重置用量？
A: 个人用户无法重置，每日 0 点自动重置。如有特殊需求，请联系管理员。

### Q: 可以分享密钥吗？
A: 不可以。每个密钥绑定个人使用，分享会导致双方都被封禁。

## 安全提醒

1. **不要公开密钥**：不要在 GitHub、论坛、聊天中公开你的 TRIAL_KEY
2. **定期更换**：建议每 3 个月申请新密钥
3. **监控用量**：定期检查使用情况，避免超限
4. **举报滥用**：发现密钥被盗用，立即联系管理员

## 技术支持

- 论坛：https://clawdrepublic.cn/forum/
- 问题反馈：在论坛「问题求助」板块发帖
- 紧急联系：admin@clawdrepublic.cn

---

**最后更新：2026-02-10**  
**文档版本：v1.0**