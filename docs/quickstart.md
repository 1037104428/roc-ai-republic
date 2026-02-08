# OpenClaw 小白一条龙（免翻墙）

> 官网版本（建议阅读）：https://clawdrepublic.cn/quickstart.html

这份文档给“第一次装 OpenClaw、只想复制粘贴跑起来”的人用。

## 你将获得什么

- 国内可直连安装 OpenClaw
- 默认使用 Clawd 国度的 DeepSeek 限额网关（无需自己申请 DeepSeek key）
- 遇到问题：按模板发帖，按“复制粘贴 + 你应该看到什么 + 失败怎么办”的方式排障

## 0) 准备 Node.js（如果你已经有 npm，可跳过）

在终端输入：

```bash
npm -v
```

能输出版本号即可。

## 1) 一条命令安装 OpenClaw（国内源优先）

```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

验证：

```bash
openclaw --version
```

## 2) 写入配置（复制粘贴即可）

把下面内容保存为：`~/.openclaw/openclaw.json`

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "clawd-gateway/deepseek-chat" },
      "models": {
        "clawd-gateway/deepseek-chat": {},
        "clawd-gateway/deepseek-reasoner": {}
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "clawd-gateway": {
        "baseUrl": "https://api.clawdrepublic.cn/v1",
        "apiKey": "${CLAWD_TRIAL_KEY}",
        "api": "openai-completions",
        "models": [
          { "id": "deepseek-chat", "name": "DeepSeek Chat" },
          { "id": "deepseek-reasoner", "name": "DeepSeek Reasoner" }
        ]
      }
    }
  }
}
```

## 3) 获取 TRIAL_KEY（当前：人工发放）

你需要一个 `CLAWD_TRIAL_KEY`（试用 key）。当前为了避免滥用，先走人工发放：

- 去论坛「TRIAL_KEY 申请」板块发帖：https://clawdrepublic.cn/forum/t/trial-key
- 建议照抄模板（置顶贴里有）：https://clawdrepublic.cn/quota-proxy.html

拿到 key 后，在终端执行（把 `trial_xxx` 换成你的 key）：

```bash
export CLAWD_TRIAL_KEY="trial_xxx"
```

## 4) 最小验证：先用 curl 跑通一次

```bash
curl -fsS https://api.clawdrepublic.cn/healthz

curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```

## 5) 启动 OpenClaw 并验证

```bash
openclaw gateway start
openclaw models status
```

如果正常，你会看到默认模型指向 `clawd-gateway/...`。

---

- API 健康检查：https://api.clawdrepublic.cn/healthz
- 遇到问题：到论坛「问题求助」按模板提问：https://clawdrepublic.cn/forum/t/help
