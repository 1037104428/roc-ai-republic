# 论坛置顶帖模板

## 1. 欢迎帖（公告区）

**标题**：欢迎来到 Clawd 国度社区论坛！

**内容**：
```
欢迎各位开发者、爱好者和贡献者！

本论坛是 Clawd 国度项目的官方社区讨论平台，旨在：
- 分享 OpenClaw 使用经验
- 讨论 MCP 服务器开发
- 展示个人项目作品
- 解决技术问题
- 收集功能建议

请遵守社区规则，保持友好交流氛围。

【社区规则】
1. 尊重他人，文明讨论
2. 禁止广告、spam
3. 技术问题请发到对应版块
4. 反馈建议请提供具体场景

【快速链接】
- 官网：https://clawd.ai
- GitHub：https://github.com/openclaw/openclaw
- Discord：https://discord.gg/clawd
```

## 2. 快速入门指南（技术讨论）

**标题**：[新手必读] OpenClaw 极速入门指南

**内容**：
```
## 🚀 5分钟极速入门

### 1. 安装 OpenClaw
```bash
npm install -g openclaw
```

### 2. 初始化配置
```bash
# 创建配置文件
openclaw init

# 启动网关服务
openclaw gateway start
```

### 3. 安装第一个技能
```bash
# 搜索可用技能
clawhub search weather

# 安装天气技能
clawhub install weather
```

### 4. 开始使用
```bash
# 查看已安装技能
clawhub list

# 运行 OpenClaw 交互模式
openclaw chat
```

## ❓ 常见问题

**Q: 如何连接 MCP 服务器？**
A: 使用 `mcporter` 工具：
```bash
mcporter list
mcporter add http://your-mcp-server
```

**Q: 如何创建自己的技能？**
A: 参考技能创建指南：`/docs/skill-creator/`

**Q: 遇到问题如何求助？**
A: 1) 查看文档 2) 在论坛提问 3) 加入 Discord
```

## 3. 项目贡献指南（项目展示）

**标题**：[贡献者必读] 如何为 Clawd 国度贡献代码

**内容**：
```
## 贡献流程

### 1. 找到感兴趣的任务
- 查看 GitHub Issues：https://github.com/openclaw/openclaw/issues
- 关注论坛"任务认领"版块
- 参与社区讨论发现需求

### 2. 开发准备
```bash
# 克隆仓库
git clone https://github.com/openclaw/openclaw.git

# 安装依赖
npm install

# 运行测试
npm test
```

### 3. 提交 Pull Request
1. Fork 仓库
2. 创建功能分支
3. 编写代码并测试
4. 提交 PR 并描述变更

### 4. 代码审查
- 至少需要 1 位核心成员 review
- 通过 CI 测试
- 符合代码规范

## 🏆 贡献者权益
- 列入贡献者名单
- 获得社区勋章
- 优先体验新功能
- 参与核心决策
```

## 4. 问题求助模板（问题求助）

**标题**：[求助模板] 请按此格式提问以获得更快解答

**内容**：
```
## 问题描述
[清晰描述你遇到的问题]

## 环境信息
- 操作系统： [如 Ubuntu 22.04]
- Node.js 版本： [如 v22.22.0]
- OpenClaw 版本： [如 1.2.3]
- 相关技能： [如 weather, mcporter]

## 复现步骤
1. [第一步]
2. [第二步]
3. [第三步]

## 期望结果
[描述你期望看到的结果]

## 实际结果
[描述实际看到的结果，包括错误信息]

## 已尝试的解决方案
- [ ] 重启 OpenClaw 网关
- [ ] 重新安装相关技能
- [ ] 查看文档：https://docs.openclaw.ai
- [ ] 搜索论坛类似问题

## 附加信息
[日志文件、截图、配置片段等]
```

## 5. 功能建议模板（意见建议）

**标题**：[建议模板] 功能建议请按此格式提交

**内容**：
```
## 建议标题
[简洁的功能名称]

## 问题/痛点
[描述当前存在的问题或使用不便之处]

## 建议方案
[详细描述你的解决方案]

## 预期收益
- [收益点1]
- [收益点2]
- [收益点3]

## 优先级评估
- 影响用户数： [大量/中等/少量]
- 使用频率： [高频/中频/低频]
- 实现难度： [简单/中等/复杂]

## 替代方案
[如果有其他实现方式，请列出]

## 相关参考
[类似功能的其他项目或工具]
```