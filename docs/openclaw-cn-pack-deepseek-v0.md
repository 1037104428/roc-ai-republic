# OpenClaw 小白中文包（免翻墙版）- DeepSeek 默认（最短路径 v0）

目标：给纯小白一条"复制粘贴就能跑"的路：**不翻墙**也能用 OpenClaw。

这份文档只做一件事：把 **DeepSeek（OpenAI-compatible）** 接到 OpenClaw，并设为默认模型。

## 🚀 一键配置（推荐）

如果你已经安装了 OpenClaw，只需运行一条命令：

```bash
curl -fsSL https://clawdrepublic.cn/setup-deepseek-openclaw.sh | bash
```

或者下载后运行：

```bash
# 下载脚本
curl -fsSL https://clawdrepublic.cn/setup-deepseek-openclaw.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

脚本会：
1. 检查 OpenClaw 是否已安装
2. 询问并保存你的 DeepSeek API Key
3. 创建或更新 OpenClaw 配置文件
4. 验证配置并给出后续步骤

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
- 上面这些键（`models.providers.*.baseUrl/apiKey/api/models[]` + `api: "openai-completions"`）是 OpenClaw 文档里"自定义 OpenAI-compatible provider"的标准写法。
- 如果 DeepSeek 未来调整了模型 id / baseUrl，只需要改 `models[].id` / `baseUrl`。

---

## 3) 验证（2 条命令）

```bash
openclaw status
openclaw models status
```

你应当看到：Gateway 正常运行，且 models/provider 已加载（能解析到 `deepseek/*`）。

---

## 4) 一键脚本详情

如果你对脚本的工作原理感兴趣，或者想手动配置：

### 脚本功能
- **自动检测**：检查 OpenClaw 是否已安装
- **安全输入**：交互式输入 API Key（不会在终端历史中留下痕迹）
- **配置管理**：自动创建或更新配置文件
- **环境变量**：自动设置 `.env` 文件
- **验证步骤**：提供完整的验证命令

### 手动运行脚本
```bash
# 从仓库运行
cd /path/to/roc-ai-republic
./scripts/setup-deepseek-openclaw.sh

# 或者直接下载运行
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/setup-deepseek-openclaw.sh | bash
```

### 脚本源码位置
- 仓库：`scripts/setup-deepseek-openclaw.sh`
- 线上：`https://clawdrepublic.cn/setup-deepseek-openclaw.sh`

## 5) 下一步（路线图）

- 增加：不买 key 的"试用额度池/网关"路径（见仓库 `quota-proxy/`）
- 优化：脚本增加更多错误处理和回退机制
- 扩展：支持更多国内可用的 AI 模型（智谱、月之暗面等）
