# 🚀 快速开始：30秒调用 Clawd AI

欢迎来到 Clawd 国度！这是专为 AI 开发者打造的开源社区。无论你是新手还是专家，都能在这里找到适合的工具和资源。

## ⚡ 30秒极速体验

如果你已经拿到 **TRIAL_KEY**（试用密钥），直接运行这条命令：

```bash
curl -X POST "https://api.clawdrepublic.cn/v1/chat/completions" \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "messages": [{"role": "user", "content": "你好，世界！"}]
  }'
```

**替换** `YOUR_TRIAL_KEY` 为你的实际密钥。看到返回结果就成功了！

## 📋 你需要什么？

- **1 个 TRIAL_KEY**（试用密钥）
- **1 台能上网的电脑**
- **1 个终端**（Mac/Linux 用 Terminal，Windows 用 Git Bash）
- **5 分钟时间**

## 🔑 第一步：获取 TRIAL_KEY

### 当前申请方式（人工发放）

1. **访问申请页面**：[TRIAL_KEY 申请指南](./quota-proxy-trial-key.md)
2. **选择申请渠道**（任选其一）：
   - **GitHub Issues**：在项目仓库创建 issue
   - **社区论坛**：在"密钥申请"板块发帖
   - **邮件申请**：发送邮件至 admin@clawdrepublic.cn
3. **提供申请信息**：
   - 你的用途（学习/测试/项目）
   - 预计使用频率
   - 联系方式（可选）
4. **等待发放**：管理员会在 24 小时内通过私信/邮件发放
5. **保存密钥**：你会收到类似 `trial_abc123def456` 的字符串
   - ⚠️ **重要**：不要公开分享你的密钥！

### 密钥说明
```
格式：trial_前缀 + 随机字符（共 20-30 位）
示例：trial_7x9y2z8w5v4u3t6s1r0q
有效期：30天 | 每日限额：100次调用
```

## 🤖 第二步：第一次 AI 调用

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

## 📊 第三步：查看用量

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

## 🎯 进阶用法

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

### 连续对话
```bash
curl -sS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "messages": [
      {"role": "user", "content": "什么是AI？"},
      {"role": "assistant", "content": "AI是人工智能..."},
      {"role": "user", "content": "那机器学习呢？"}
    ]
  }'
```

## ❓ 常见问题

### Q：返回 401 错误？
A: 检查 key 是否正确，或是否已过期（试用期通常 30 天）。

### Q：返回 429 限制？
A: 试用 key 有每分钟/每日调用限制，请稍后再试。

### Q：支持哪些编程语言？
A: 任何能发送 HTTP 请求的语言都支持（Python、JavaScript、Java、Go 等）。

### Q：试用额度用完了怎么办？
A: 可以申请正式额度，或在论坛分享使用体验申请额外试用额度。

## 🆘 遇到问题？

1. **检查密钥**：确认密钥正确，没有空格
2. **检查网络**：确保能访问 `api.clawdrepublic.cn`
3. **查看错误**：命令会显示错误信息
4. **联系支持**：support@clawdrepublic.cn

## 📚 深入学习

### 完整教程
- **[小白一条龙教程](../tutorials/小白一条龙_从拿到key到第一次调用.md)** - 详细步骤与解释
- **[极小白：30秒开始](../tutorials/极小白_30秒开始.md)** - 最简版本

### 技术文档
- **[quota-proxy 管理](../quota-proxy/)** - 额度代理服务详细文档
- **[论坛部署指南](../forum/)** - 社区交流平台搭建

### 开发资源
- **开源仓库**: [roc-ai-republic](https://github.com/your-org/roc-ai-republic)
- **API 文档**: 查看完整接口规范

## 🤝 加入社区

### 参与贡献
1. Fork 主仓库
2. 创建功能分支
3. 提交 Pull Request
4. 参与代码审查

### 交流讨论
- **论坛**: https://forum.clawd.ai (部署中)
- **GitHub**: https://github.com/your-org
- **邮件**: support@clawdrepublic.cn

---

**最后更新**: 2026-02-11  
**文档状态**: ✅ 可用（API 地址和流程已验证）  
**下一步计划**: 实现自助申请 TRIAL_KEY 流程

> 💡 提示：本教程会持续更新，建议收藏官网链接获取最新版本。
