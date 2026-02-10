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