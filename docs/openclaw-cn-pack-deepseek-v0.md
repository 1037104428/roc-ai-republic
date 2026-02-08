# OpenClaw 小白中文包（免翻墙版）— DeepSeek 默认（最短路径 v0）

目标：给纯小白一条“复制粘贴就能跑”的路：**不翻墙**也能用 OpenClaw。

这份文档只做一件事：把 **DeepSeek（OpenAI-compatible）** 接到 OpenClaw，并设为默认模型。

> 字段来源（本机 OpenClaw docs）：
> - 配置文件位置/格式：`docs/help/faq.md`（`~/.openclaw/openclaw.json`，JSON5）
> - 环境变量与 `.env` 读取优先级：`docs/environment.md`
> - 自定义 provider（`models.providers`）与 `openai-completions`：`docs/concepts/model-providers.md`

---

## 0) 你需要准备什么
- 一台 Linux 电脑（Ubuntu/Debian 优先）
- 一个 DeepSeek API Key（字符串）
- 已安装并能运行 `openclaw`（能执行 `openclaw status`）

---

## 1) 把 DeepSeek Key 写进去（两选一，推荐 A）

### A. 写入全局 `~/.openclaw/.env`（推荐，重开终端不丢）

```bash
mkdir -p ~/.openclaw
printf 'DEEPSEEK_API_KEY=%s\n' 'YOUR_KEY_HERE' >> ~/.openclaw/.env
# 可选：立刻在当前 shell 生效
export DEEPSEEK_API_KEY='YOUR_KEY_HERE'
```

说明：OpenClaw 会读取 `~/.openclaw/.env`，且**不会覆盖**你已经在系统环境变量里设置的同名值。

### B. 只在当前终端临时 export（最简单，但重开终端会丢）

```bash
export DEEPSEEK_API_KEY='YOUR_KEY_HERE'
```

---

## 2) 在 OpenClaw 配置里启用 DeepSeek（可复制粘贴）

编辑 `~/.openclaw/openclaw.json`（JSON5），把下面片段合并进去：

```json5
{
  agents: {
    defaults: {
      // 设为默认模型（provider/modelId 的 ref 形式）
      model: { primary: "deepseek/deepseek-chat" },

      // 可选：给模型一个人类友好的别名（不影响路由）
      models: {
        "deepseek/deepseek-chat": { alias: "DeepSeek Chat" },
        "deepseek/deepseek-reasoner": { alias: "DeepSeek Reasoner" },
      },
    },
  },

  models: {
    mode: "merge",
    providers: {
      deepseek: {
        // DeepSeek 的 OpenAI-compatible base URL（一般是 /v1）
        baseUrl: "https://api.deepseek.com/v1",
        apiKey: "${DEEPSEEK_API_KEY}",
        api: "openai-completions",
        models: [
          { id: "deepseek-chat", name: "DeepSeek Chat" },
          { id: "deepseek-reasoner", name: "DeepSeek Reasoner" },
        ],
      },
    },
  },
}
```

备注：
- 上面这些键（`models.providers.*.baseUrl/apiKey/api/models[]` + `api: "openai-completions"`）是 OpenClaw 文档里“自定义 OpenAI-compatible provider”的标准写法。
- 如果 DeepSeek 未来调整了模型 id / baseUrl，只需要改 `models[].id` / `baseUrl`。

---

## 3) 验证（2 条命令）

```bash
openclaw status
openclaw models status
```

你应当看到：Gateway 正常运行，且 models/provider 已加载（能解析到 `deepseek/*`）。

---

## 4) 下一步（路线图）

- 补齐：DeepSeek 官方入口链接（写入 `docs/links.md`，避免散落在文档里）
- 增加：小白向“10 分钟开箱”脚本（安装 + 写 `.env` + 写配置 + 验证）
- 增加：不买 key 的“试用额度池/网关”路径（见仓库 `quota-proxy/`）
