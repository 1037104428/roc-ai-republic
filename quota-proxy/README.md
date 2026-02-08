# DeepSeek 限额试用网关（OpenAI-compatible proxy）

目的：给“OpenClaw 小白中文包”提供 **可控、可持续** 的免费试用额度。

思路：
- 用户拿到一个 `TRIAL_KEY`（我们发）
- OpenClaw 端把 provider baseUrl 指向本网关
- 网关转发到 DeepSeek 官方 API（后端持有赞助者的 `DEEPSEEK_API_KEY`）
- 网关对每个 `TRIAL_KEY` 做：
  - 每日请求数 / 每日 token 近似额度 / 并发限制
  - 超限返回 429/402（明确提示）

## v0 约束
- 不做任何隐蔽/绕行；就是普通 HTTPS 服务。
- 不收集多余隐私：仅记录必要的计费/风控字段（trial key、时间、用量、IP hash 可选）。

## 状态
- 代码骨架待实现：`server.ts`
- 首选：Node.js + Express + SQLite（单机可跑）

下一步：实现 `POST /v1/chat/completions` 最小转发 + 计数。
