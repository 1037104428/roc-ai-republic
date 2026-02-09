# 小白一条龙：从拿到 Key 到第一次调用

## 🎯 你将获得什么

- 1 个可用的 TRIAL_KEY（试用密钥）
- 1 条可直接复制运行的 curl 命令
- 1 个能看懂的“用量/额度”查询方式
- 完成你的第一次 AI 调用！

## 📋 你需要准备

- 一台能上网的电脑
- 安装 curl（Mac/Linux 通常自带；Windows 建议用 Git Bash 或 WSL）
- 5 分钟时间

## 1️⃣ 获取 TRIAL_KEY（试用密钥）

### 当前流程：人工发放（后续会改为自助申请）

1. **访问官网文档**：查看 [官网文档 - TRIAL_KEY 申请](../website/quota-proxy-trial-key.md)
2. **留言申请**：在指定帖子留言，说明：
   - 你的用途（学习/测试/项目）
   - 预计使用频率
   - 联系方式（可选）
3. **等待发放**：管理员会在 24 小时内通过私信/邮件发放 TRIAL_KEY
4. **保存密钥**：你会收到类似 `sk-abc123def456` 的字符串
   - ⚠️ **重要**：不要公开分享你的密钥！

### 密钥格式说明
```
sk-前缀 + 随机字符（共 20-30 位）
示例：sk-7x9y2z8w5v4u3t6s1r0q
```

## 2️⃣ 第一次调用（复制运行）

把下面的 `YOUR_TRIAL_KEY` 换成你的 key：

```bash
curl -sS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "messages": [{"role": "user", "content": "你好，给我一个 3 步学习计划"}]
  }'
```

## 3) 查看用量/额度（示例）

```bash
curl -sS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
```

> 说明：字段含义与常见问题，会在 quota-proxy 文档里解释。

## 3️⃣ 查看用量/额度

```bash
curl -sS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
```

### 响应示例
```json
{
  "status": "active",
  "total_quota": 1000,
  "used": 42,
  "remaining": 958,
  "reset_at": "2026-02-10T00:00:00Z"
}
```

### 字段说明
- `status`: 密钥状态（active-活跃，expired-过期，suspended-暂停）
- `total_quota`: 总调用次数额度
- `used`: 已使用次数
- `remaining`: 剩余次数
- `reset_at`: 额度重置时间（UTC）

## 4️⃣ 进阶使用

### 使用不同的模型
```bash
curl -sS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-fast",  # 快速模型
    "messages": [{"role": "user", "content": "用一句话总结量子计算"}]
  }'
```

### 流式响应（适合长文本）
```bash
curl -sS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "stream": true,
    "messages": [{"role": "user", "content": "写一个关于AI的短故事"}]
  }'
```

## 5️⃣ 常见问题（FAQ）

### Q: 返回 401 错误？
A: 检查 key 是否正确，或是否已过期（试用期通常 7 天）。

### Q: 返回 429 限制？
A: 试用 key 有每分钟/每日调用限制，请稍后再试。

### Q: 想申请正式额度？
A: 联系管理员，说明使用场景和预期用量。

### Q: 教程里的 API 地址会变吗？
A: 如果变了，会在官网公告和论坛置顶帖更新。

### Q: 支持哪些编程语言？
A: 任何能发送 HTTP 请求的语言都支持（Python、JavaScript、Java、Go 等）。

### Q: 试用额度用完了怎么办？
A: 可以申请正式额度，或在论坛分享使用体验申请额外试用额度。

## 6️⃣ 下一步

### 想深入学习？
1. **查看完整 API 文档**：了解所有可用端点和参数
2. **加入社区**：在论坛与其他开发者交流
3. **贡献代码**：quota-proxy 和论坛都是开源项目

### 遇到问题？
- 在论坛「新手求助」板块发帖
- 查看常见问题汇总
- 联系管理员（响应时间：工作日 24 小时内）

---

**最后更新**：2026-02-09  
**文档状态**：✅ 可用（API 地址和流程已验证）  
**下一步计划**：实现自助申请 TRIAL_KEY 流程

> 💡 提示：本教程会持续更新，建议收藏官网链接获取最新版本。
