# TRIAL_KEY 申请与使用（复制粘贴版）

## 申请前准备
1. 已注册论坛账号并登录
2. 了解基本使用场景和预计调用量
3. 同意试用条款（不用于商业盈利、不滥用、不分享 key）

## 发帖模板（复制填写）

**标题：** 申请 TRIAL_KEY - [你的用户名]

**正文：**
```
### 申请信息
- **用户名：** [你的论坛用户名]
- **使用场景：** [例如：学习 AI 对话、开发测试、个人项目等]
- **预计每日调用量：** [例如：10-50 次]
- **预计使用时长：** [例如：1-2 周]

### 承诺
- [ ] 不将 key 用于商业盈利目的
- [ ] 不分享或泄露 key 给他人
- [ ] 遵守社区规则和额度限制
- [ ] 如不再使用会主动告知

### 备注（可选）
[其他需要说明的情况]
```

## 审核流程说明
1. **提交申请**：在「TRIAL_KEY 申请」板块发帖，使用上述模板
2. **人工审核**：管理员会在 24 小时内审核申请
3. **发放 key**：审核通过后，管理员会通过私信发送 `sk-xxx` 格式的 key
4. **开始使用**：收到 key 后即可按照使用指南配置

## 拿到 KEY 后的使用步骤

### 1. 设置环境变量
```bash
# 将 xxx 替换为你的实际 key
export CLAWD_TRIAL_KEY="sk-xxx"

# 对于通用 OpenAI 客户端
export OPENAI_API_KEY="${CLAWD_TRIAL_KEY}"
export OPENAI_BASE_URL="https://api.clawdrepublic.cn/v1"
```

### 2. 验证 key 有效性
```bash
# 健康检查（不消耗额度）
curl -fsS https://api.clawdrepublic.cn/healthz

# 测试调用（消耗 1 次额度）
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"test"}]
  }'
```

### 3. 配置 OpenClaw
编辑 `~/.openclaw/openclaw.json`，确保包含：
```json
"apiKey": "${CLAWD_TRIAL_KEY}"
```

## 额度说明与续期

### 初始额度
- 每个 TRIAL_KEY 初始额度：100 次调用
- 额度按请求次数计算（无论成功失败）
- 额度每日不重置，用完即止

### 查看剩余额度
```bash
# 需要管理员权限，普通用户请联系管理员查询
```

### 额度续期
1. **良好使用记录**：正常使用、无滥用的用户可申请续期
2. **贡献社区**：分享使用经验、帮助他人解决问题的用户优先
3. **续期申请**：在原申请帖回复或新开帖申请

### 额度耗尽处理
- API 会返回 429 状态码（Too Many Requests）
- 需要申请新的 TRIAL_KEY 或等待续期
- 旧 key 不会自动恢复额度

## 重要提醒
1. **安全第一**：不要将 key 提交到公开仓库或分享给他人
2. **合理使用**：额度有限，请用于学习和测试
3. **及时反馈**：遇到问题及时在「问题求助」板块发帖
4. **遵守规则**：滥用可能导致 key 被禁用

## 常见问题

### Q：key 被泄露了怎么办？
A：立即联系管理员撤销旧 key，申请新 key。

### Q：额度用完了还能申请吗？
A：可以，但需要说明使用情况和后续计划。

### Q：支持哪些模型？
A：目前支持 deepseek-chat 和 deepseek-reasoner。

### Q：调用延迟大怎么办？
A：检查网络连接，或联系管理员查看服务状态。