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

可选：指定版本 / 仅打印命令（不执行）/ 换国内 npm 源：

```bash
# 指定版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12

# 仅打印将要执行的命令（便于检查网络/源）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run

# 换国内源（例如腾讯云 npm 镜像）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --registry-cn https://mirrors.cloud.tencent.com/npm/
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

自检（建议做一次，避免环境变量没生效）：

```bash
# 应该输出 trial_ 开头（不要把 key 发到公开场合）
echo "${CLAWD_TRIAL_KEY}" | sed -E "s/(trial_[A-Za-z0-9]{4}).*/\1.../"

# API 探活（不需要 key）
curl -fsS https://api.clawdrepublic.cn/healthz
```

如果你在 Windows PowerShell：

```powershell
$env:CLAWD_TRIAL_KEY = "trial_xxx"
```

## 4)（可选）兼容 OpenAI 工具：设置 OPENAI_API_KEY / OPENAI_BASE_URL

很多客户端/脚本默认读取 `OPENAI_API_KEY` / `OPENAI_BASE_URL`。

```bash
export OPENAI_API_KEY="${CLAWD_TRIAL_KEY}"
export OPENAI_BASE_URL="https://api.clawdrepublic.cn/v1"
```

> 提示：`OPENAI_API_KEY` 里放的是你的 TRIAL_KEY（不是上游厂商 Key）。不要把它粘贴到公开场合。

## 5) 最小验证：先用 curl 跑通一次

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

### 5.1)（可选）一键自检脚本

如果你不想手工逐条跑，也可以直接运行一键探活脚本（会依次检查站点/接口/常见链接）：

```bash
curl -fsSL https://clawdrepublic.cn/probe-roc-all.sh | bash
```

## 6) 启动 OpenClaw 并验证

```bash
openclaw gateway start
openclaw models status
```

如果正常，你会看到默认模型指向 `clawd-gateway/...`。

---

- API 健康检查：https://api.clawdrepublic.cn/healthz
- 遇到问题：到论坛「问题求助」按模板提问：https://clawdrepublic.cn/forum/t/help
