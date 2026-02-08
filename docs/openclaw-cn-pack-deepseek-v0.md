# OpenClaw 小白中文包（免翻墙版）— DeepSeek 默认（最短路径 v0）

目标：给纯小白一条“复制粘贴就能跑”的路：**不翻墙**也能用 OpenClaw（对话 + 记忆 + 浏览器/自动化按需）。

> 说明：下面先把“DeepSeek 作为默认在线模型 API”这条路跑通。后续再加“免费试用额度池”和“本地模型离线版”。

---

## 0) 你需要准备什么（小白版）
- 一台 Linux 电脑（我们优先支持 Ubuntu/Debian）
- 一个 DeepSeek API Key（复制一段字符串）

---

## 1) DeepSeek（默认在线模型）的最短路径

### 1.1 注册与获取 Key（待补：官方入口链接）
- 去 DeepSeek 控制台 → 创建 API Key → 复制保存（不要发到群里）

### 1.2 把 Key 写入环境变量（终端一行）
> 下面这行是模板：把 `YOUR_KEY_HERE` 替换成你的 key。

```bash
export DEEPSEEK_API_KEY="YOUR_KEY_HERE"
```

（后续会提供把它写进 `~/.bashrc` 的方式，避免重开终端就丢。）

### 1.3 在 OpenClaw 里启用 DeepSeek（可复制粘贴配置片段）

OpenClaw 支持通过 `models.providers` 添加 **OpenAI-compatible** 的自定义 provider（见 OpenClaw 文档：concepts/model-providers）。DeepSeek 官方提供 OpenAI 兼容接口时，可按下面方式接入。

把下面片段合并到你的 `~/.openclaw/openclaw.json`（注意：`${DEEPSEEK_API_KEY}` 会从环境变量读取）：

```json5
{
  env: {
    // 也可以不写在这里，直接在 shell 里 export DEEPSEEK_API_KEY
    DEEPSEEK_API_KEY: "${DEEPSEEK_API_KEY}",
  },
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-chat" },
      models: {
        "deepseek/deepseek-chat": {},
        "deepseek/deepseek-reasoner": {},
      },
    },
  },
  models: {
    mode: "merge",
    providers: {
      deepseek: {
        // DeepSeek 的 OpenAI-compatible base URL（如官方为 /v1）
        baseUrl: "https://api.deepseek.com/v1",
        apiKey: "${DEEPSEEK_API_KEY}",
        api: "openai-completions",
        models: [
          { id: "deepseek-chat", name: "DeepSeek Chat" },
          { id: "deepseek-reasoner", name: "DeepSeek Reasoner" }
        ]
      }
    }
  }
}
```

> 说明：如果 DeepSeek 实际 baseUrl 或模型 id 与上面不同，把 `baseUrl` 与 `models[].id` 改成其官方文档给的值即可。这个片段的关键是：`api: "openai-completions"` + `baseUrl` + `apiKey`。

### 1.4 一键验证
```bash
openclaw status
```
你应该看到：Gateway running，Agents 运行正常。

---

## 2) 为什么选 DeepSeek 做默认
- 国内更容易直连（免翻墙）
- 对小白来说“拿 key → 粘贴 → 能用”路径更短

---

## 3) 免费试用额度（路线图）
目的：让小白**不买 key 也能开箱体验**。

### 3.1 v0 方案（可持续）
- 新用户获得小额试用额度（例如 1-2 元等价 token）
- 强限流（每分钟/每小时）
- 轻量验证（邀请码/邮箱/设备指纹）
- 耗尽后提示：如何切换到自带 DeepSeek key 或本地模型

### 3.2 需要的工程 ticket（招募用）
- API 网关：转发 + 统计 token + 计费/扣额
- 限流与反滥用：速率限制、封禁、黑名单
- 发放体系：邀请码/注册/配额管理
- 文档与小白测试：把流程压到 10 分钟内

---

## 4) 下一步（我正在做）
- 确认 OpenClaw 的“DeepSeek 接入配置字段”（或 openai-compatible baseURL）并把 1.3 补齐成可直接复制粘贴的片段。
- 把这些内容改写成 Moltbook/论坛的“可领取任务清单”。
