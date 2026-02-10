# OpenClaw 小白一条龙（免翻墙）

> 官网版本（建议阅读）：https://clawdrepublic.cn/quickstart.html

这份文档给"第一次装 OpenClaw、只想复制粘贴跑起来"的人用。

## 开始前：一键验证网络环境

在安装前，可以先运行这个验证脚本检查网络环境是否正常：

```bash
# 下载并运行验证脚本
curl -fsSL https://clawdrepublic.cn/verify-quickstart.sh | bash

# 或者如果有 TRIAL_KEY，可以这样验证：
# curl -fsSL https://clawdrepublic.cn/verify-quickstart.sh | bash -s -- --key 你的TRIAL_KEY
```

这个脚本会检查：
- 官网是否可访问
- API 网关是否健康
- 安装脚本是否可下载
- 你的 TRIAL_KEY 是否有效（如果提供）

如果验证通过，说明网络环境正常，可以继续安装。

## 你将获得什么

- 国内可直连安装 OpenClaw
- 默认使用 Clawd 国度的 DeepSeek 限额网关（无需自己申请 DeepSeek key）
- 遇到问题：按模板发帖，按"复制粘贴 + 你应该看到什么 + 失败怎么办"的方式排障

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

说明：安装脚本会**优先**使用国内可达的 npm 源（默认 npmmirror），若安装失败会自动回退到 npmjs 官方源；不会永久修改你的 npm registry 配置。

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
- 为了更快审核，建议在帖里写清楚：
  - 你要用它做什么（例如：本地写代码、做 demo、学习）
  - 预计频率（每天大概几次对话/脚本调用）
  - 你的环境（Windows/macOS/Linux；是否在公司网络）

> 注意：**不要在公开帖子里粘贴你拿到的 TRIAL_KEY**。管理员只会私信/单独回复给你。

拿到 key 后，在终端执行（把 `sk-xxx` 换成你的 key）：

```bash
export CLAWD_TRIAL_KEY="sk-xxx"
```

（可选）让它每次打开终端都生效：

```bash
# bash
printf '\nexport CLAWD_TRIAL_KEY="sk-xxx"\n' >> ~/.bashrc

# zsh
printf '\nexport CLAWD_TRIAL_KEY="sk-xxx"\n' >> ~/.zshrc
```

自检（建议做一次，避免环境变量没生效）：

```bash
# 应该输出 sk- 开头（不要把 key 发到公开场合）
echo "${CLAWD_TRIAL_KEY}" | sed -E "s/(sk-[A-Za-z0-9]{4}).*/\1.../"

# API 探活（不需要 key）
curl -fsS https://api.clawdrepublic.cn/healthz
```

如果你在 Windows PowerShell：

```powershell
$env:CLAWD_TRIAL_KEY = "sk-xxx"
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
# 不需要 key
curl -fsS https://api.clawdrepublic.cn/healthz

# 需要 key：验证你的 TRIAL_KEY 是否可用
# 期望：返回一段 JSON（包含 deepseek-chat / deepseek-reasoner 等模型 id）
# 若返回 401/403：通常是 key 没设置成功，或 key 不可用
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}"

# 需要 key：最小对话测试
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

## 7) 故障排除快速参考

| 问题 | 可能原因 | 解决方法 |
|------|----------|----------|
| `openclaw` 命令找不到 | Node.js 路径问题 | 重新打开终端，或运行 `source ~/.bashrc` |
| 安装脚本下载失败 | 网络问题 | 检查网络，或手动下载：`curl -O https://clawdrepublic.cn/install-cn.sh` |
| TRIAL_KEY 无效 | Key 过期或格式错误 | 重新申请：https://clawdrepublic.cn/forum/t/trial-key |
| API 连接失败 | 网关维护或网络问题 | 检查：`curl -fsS https://api.clawdrepublic.cn/healthz` |
| 模型下载慢 | 国内网络限制 | 耐心等待，或检查是否有代理干扰 |
| 配置文件错误 | JSON 格式问题 | 验证配置：`cat ~/.openclaw/openclaw.json \| python3 -m json.tool` |

**一键诊断**：运行 `curl -fsSL https://clawdrepublic.cn/verify-quickstart.sh \| bash` 检查所有环节。

## 常见问题（FAQ）

### Q1: 安装时提示 "npm: command not found"
**原因**：Node.js 未安装或未正确配置 PATH。
**解决**：
1. 检查 Node.js 是否安装：`node --version`
2. 如果未安装，从官网下载：https://nodejs.org/（建议 LTS 版本）
3. 安装后重新打开终端

### Q2: 运行 `openclaw` 命令提示 "command not found"
**原因**：npm 全局包路径未加入 PATH。
**解决**：
1. 找到 npm 全局包路径：`npm config get prefix`
2. 将该路径下的 `bin` 目录加入 PATH：
   ```bash
   export PATH="$(npm config get prefix)/bin:$PATH"
   ```
3. 永久生效：将上述命令加入 `~/.bashrc` 或 `~/.zshrc`

### Q3: TRIAL_KEY 验证返回 401/403
**原因**：
1. Key 未正确设置到环境变量
2. Key 已过期或被撤销
3. 环境变量未生效
**解决**：
1. 检查环境变量：`echo $CLAWD_TRIAL_KEY`
2. 重新申请 Key：https://clawdrepublic.cn/forum/t/trial-key
3. 确保重启终端或运行 `source ~/.bashrc`

### Q4: API 连接超时或无法访问
**原因**：网络问题或网关维护。
**解决**：
1. 检查网络连接：`ping api.clawdrepublic.cn`
2. 检查网关状态：`curl -fsS https://api.clawdrepublic.cn/healthz`
3. 如果网关维护，请等待或查看公告

### Q5: 配置文件格式错误
**原因**：JSON 格式不正确。
**解决**：
1. 验证 JSON 格式：`cat ~/.openclaw/openclaw.json | python3 -m json.tool`
2. 如果报错，检查引号、逗号、括号是否匹配
3. 使用在线 JSON 验证工具检查

### Q6: 安装脚本下载慢或失败
**原因**：网络问题或源不可用。
**解决**：
1. 使用 `--dry-run` 查看脚本内容：`curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run`
2. 手动下载脚本：`curl -O https://clawdrepublic.cn/install-cn.sh`
3. 检查脚本权限：`chmod +x install-cn.sh`

### Q7: 如何获取更多帮助？
**解决**：
1. 查看完整文档：https://clawdrepublic.cn/
2. 在论坛提问：https://clawdrepublic.cn/forum/t/help
3. 按模板发帖，包含：
   - 你的操作系统和版本
   - 错误信息全文
   - 你已经尝试的步骤
   - 期望的结果

## 🚀 快速验证（安装后必做）

完成安装后，运行以下命令验证系统是否正常工作：

### 1. 验证 API 网关
```bash
# 检查健康状态
curl -fsS https://api.clawdrepublic.cn/healthz

# 检查版本信息
curl -fsS https://api.clawdrepublic.cn/version
```

### 2. 验证试用密钥（可选）
```bash
# 获取试用密钥（需要注册）
curl -fsS https://clawdrepublic.cn/trial-key-guide.html

# 使用密钥测试 API
curl -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  https://api.clawdrepublic.cn/v1/chat/completions \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello"}]}'
```

### 3. 验证安装脚本
```bash
# 检查安装脚本版本
./install-cn.sh --version

# 查看帮助信息
./install-cn.sh --help
```

### 4. 一键验证脚本
我们提供了完整的验证脚本，一键检查所有组件：
```bash
# 下载验证脚本
curl -O https://clawdrepublic.cn/scripts/verify-all.sh
chmod +x verify-all.sh

# 运行验证
./verify-all.sh --local
```

**预期结果**：
- ✅ API 网关返回 `{"ok":true}`
- ✅ 版本信息显示当前版本
- ✅ 安装脚本正常运行
- ✅ 验证脚本通过所有检查

---

- API 健康检查：https://api.clawdrepublic.cn/healthz
- 遇到问题：到论坛「问题求助」按模板提问：https://clawdrepublic.cn/forum/t/help
