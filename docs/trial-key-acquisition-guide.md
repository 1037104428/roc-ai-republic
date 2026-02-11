# TRIAL_KEY 获取与使用指南

## 概述

TRIAL_KEY 是 Clawd 国度提供的试用密钥，允许用户在配额代理服务（quota-proxy）中进行有限次数的 API 调用测试。本文档详细说明如何获取和使用 TRIAL_KEY。

## 获取 TRIAL_KEY

### 方式一：通过管理员手动发放（当前主要方式）

1. **联系管理员**：
   - 发送邮件至：admin@clawd.ai
   - 或在论坛中发帖申请：https://forum.clawd.ai/t/trial-key-request

2. **提供必要信息**：
   - 您的姓名或昵称
   - 使用目的（学习/测试/开发）
   - 预计使用量（测试次数）
   - 联系方式（邮箱）

3. **等待审核**：
   - 管理员会在 24 小时内审核您的申请
   - 审核通过后，TRIAL_KEY 将通过邮件发送给您

### 方式二：自助申请表单（计划中）

我们正在开发自助申请系统，未来您将可以通过以下方式申请：

1. 访问 https://clawd.ai/trial-key
2. 填写申请表单
3. 自动获取 TRIAL_KEY

## 使用 TRIAL_KEY

### 基本使用示例

```bash
# 设置环境变量
export TRIAL_KEY="your_trial_key_here"

# 测试验证端点
curl -X POST "https://quota-proxy.clawd.ai/verify" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": "ping"}'

# 使用配额代理调用 OpenAI API
curl -X POST "https://quota-proxy.clawd.ai/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### 查看使用情况

```bash
# 查看剩余配额
curl -X GET "https://quota-proxy.clawd.ai/quota" \
  -H "Authorization: Bearer $TRIAL_KEY"
```

## TRIAL_KEY 限制

1. **有效期**：30天
2. **调用次数**：1000次/月
3. **速率限制**：10次/分钟
4. **模型限制**：仅支持 gpt-3.5-turbo 和 gpt-4o-mini

## 常见问题

### Q: TRIAL_KEY 过期后怎么办？
A: 您可以重新申请新的 TRIAL_KEY，或升级到付费套餐。

### Q: 可以同时使用多个 TRIAL_KEY 吗？
A: 不可以，每个用户同一时间只能有一个有效的 TRIAL_KEY。

### Q: TRIAL_KEY 可以用于生产环境吗？
A: 不建议，TRIAL_KEY 仅用于测试和评估。生产环境请使用正式 API 密钥。

### Q: 如何升级到付费套餐？
A: 请联系管理员或访问 https://clawd.ai/pricing

## 技术支持

- 文档：https://docs.clawd.ai
- 论坛：https://forum.clawd.ai
- 邮箱：support@clawd.ai

## 更新日志

- 2026-02-11：创建初始版本
