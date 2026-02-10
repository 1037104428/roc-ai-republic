# TRIAL_KEY 申请指南

## 概述

TRIAL_KEY 是 Clawd Republic 提供的试用密钥，允许开发者免费体验 AI 调用服务。目前采用人工审核发放方式，确保资源合理使用。

## 申请流程

### 1. 准备申请信息
在申请前，请准备好以下信息：
- **用途说明**：学习、测试、项目开发等
- **预计使用频率**：每日/每周调用次数预估
- **联系方式**（可选）：邮箱或社交媒体账号

### 2. 提交申请
目前可通过以下方式提交申请：
1. **GitHub Issues**：在 [Clawd Republic Issues](https://github.com/your-repo/issues) 页面创建新 issue
2. **社区论坛**：在官方论坛的"密钥申请"板块发帖
3. **邮件申请**：发送邮件至 admin@clawdrepublic.cn

### 3. 申请模板
```
【TRIAL_KEY 申请】

用途：学习 AI 调用接口
预计频率：每日 10-20 次调用
联系方式：example@email.com
备注：希望测试不同模型的效果
```

### 4. 审核与发放
- 审核时间：通常在 24 小时内
- 发放方式：通过私信或邮件发送密钥
- 密钥格式：`trial_` + 随机字符（共 20-30 位）

## 密钥使用说明

### 有效期
- 试用期：30 天
- 调用限额：每日 100 次调用
- 可续期：试用期满后可申请续期

### 调用示例
使用 curl 调用 API：

```bash
# 基础调用示例
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下 Clawd Republic"}
    ]
  }'

# 流式响应示例
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "写一首关于AI的诗"}
    ],
    "stream": true
  }'

# 检查配额使用情况
curl -X GET https://api.clawdrepublic.cn/v1/quota/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
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

## 技术支持
- 文档：https://docs.clawdrepublic.cn
- 社区：https://forum.clawdrepublic.cn
- 邮箱：support@clawdrepublic.cn

---

**重要提醒**：请妥善保管你的 TRIAL_KEY，避免泄露。如发现异常使用，我们将立即停用该密钥。