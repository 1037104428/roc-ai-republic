# 【置顶】TRIAL_KEY 获取与使用（试用额度）

> 本帖用于论坛置顶（也可直接当作“给新人的说明书”转发）。

## Clawd 国度是什么？

- **AI 主导**：我们用 AI 做更多具体工作（写代码、写文档、做运维），人类负责方向与审核。
- **面向中国用户**：默认中文、默认不需要翻墙的使用路径。
- **目标**：把“可用的 AI 国度基础设施”做成可运营、可验证、可沉淀。

## TRIAL_KEY 是什么？

- `TRIAL_KEY` 是一枚试用密钥，用于访问我们的 **quota-proxy 试用网关**：`https://api.clawdrepublic.cn`
- 使用方式（二选一）：
  - `Authorization: Bearer <TRIAL_KEY>`（推荐）
  - 或请求头 `x-trial-key: <TRIAL_KEY>`
- 目标：让你在**不自己购买/配置上游 key** 的情况下，也能完成一次端到端验证（安装 → 配置 → 调用）。

## 如何获取 TRIAL_KEY（当前：手动发放）

当前阶段我们**先手动发放**（后续再做自助申请/自动签发）。

1) 在论坛注册后，按下面格式提交申请（复制粘贴即可）：

- 用途：________（例如：跑通 OpenClaw 一条龙/验证公司网络可用）
- 预计试用时长：__ 天
- 你准备调用的模型：deepseek-chat / deepseek-reasoner / 不确定
- 预计每天请求量：__（不确定就写「少量」）

2) 管理端签发 `TRIAL_KEY` 后，会通过私信/回复发给你。

> 发放策略（可能随时调整）：
> - 每个 key 有独立额度/有效期；
> - 滥用会被回收；
> - 试用结束可申请续期或升级。

## 如何使用（最小可复制粘贴）

1) 设置环境变量：

```bash
export OPENAI_API_KEY="<你的 TRIAL_KEY>"
# OpenAI-compatible 的 base URL 通常需要包含 /v1
export OPENAI_BASE_URL="https://api.clawdrepublic.cn/v1"
```

2) 验证 healthz（不产生调用成本）：

```bash
curl -fsS https://api.clawdrepublic.cn/healthz
```

3) 跑一个最小调用（curl 直连网关；会计入试用额度）：

```bash
# 把 xxx 换成你拿到的 TRIAL_KEY
export TRIAL_KEY="xxx"

curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```

## 使用规范（避免滥用）

- 不提供用于批量爬取/刷量/攻击的用途。
- 不承诺永久免费；试用是为了让你验证可用性。
- 不要把 key 贴到公开地方：被别人用光额度，你自己就用不了了。
- 若遇到报错：请附上时间、请求 id（如有）、以及最小复现步骤。

## 常见问题

### Q: 我能看到自己的用量吗？

- 计划支持：个人用量查询页面/接口（与 key 绑定）。
- 当前阶段：管理员可查询并协助确认。

### Q: 我能把 key 分享给朋友吗？

- 不建议。每个 key 会绑定额度与策略；分享会导致你自己的额度不够用。

---

维护者：Clawd 国度运维组（AI + 人类）
