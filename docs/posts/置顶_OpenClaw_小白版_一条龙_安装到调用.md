# 置顶｜OpenClaw 小白版（一条龙）：安装 → 配置 → 拿 TRIAL_KEY → 验证调用

> 目标：让**中国大陆用户**在不折腾网络环境的前提下，最快 10 分钟跑通一次「能调用 API」的完整链路。

## 0. 你将得到什么

完成本帖后，你会拿到：

- 一个 `TRIAL_KEY`（试用额度）
- 一个可用的调用入口（`quota-proxy` 统一入口）
- 一条可复制粘贴的 `curl` 验证命令

---

## 1) 安装（任选其一）

### A. 已有 Node.js（推荐）

- Node.js：建议 18+ / 20+ / 22+
- 然后安装 OpenClaw（命令以项目发布为准）

> TODO：补齐「免翻墙」下载渠道（Gitee Release / 镜像）与一条命令安装方式。

### B. 不想装开发环境

> TODO：提供 Windows / macOS 的一键包（或最小可用安装器）。

---

## 2) 配置：把 TRIAL_KEY 放进环境变量

拿到 `TRIAL_KEY` 后，在终端里执行（把 `xxx` 换成你的 key）：

```bash
export TRIAL_KEY="xxx"
```

Windows PowerShell：

```powershell
$env:TRIAL_KEY = "xxx"
```

---

## 3) 获取 TRIAL_KEY（试用额度）

目前获取方式（MVP 阶段：**手动发放**）：

- 在论坛注册后，给管理员发私信领取（推荐）。

私信内容建议按下面格式（复制粘贴即可）：

- 用途：________（例如：跑通 OpenClaw 一条龙/验证公司网络可用）
- 预计试用时长：__ 天
- 预计每天请求量：__（不确定就写「少量」）

> 管理端签发 `TRIAL_KEY` 后，会用私信发给你；管理员也能在后台看到 usage。

---

## 4) 验证调用（最小成功标准）

当你拿到 `TRIAL_KEY` 后，按顺序做两步验证：

1) 先验通路（不产生模型调用成本）：

```bash
curl -fsS https://api.clawdrepublic.cn/healthz
```

2) 再验“确实能调用模型”（会计入试用额度）：

```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"你好！请用一句话自我介绍"}]
  }'
```

预期输出类似：

```json
{"ok":true}
```

如果失败：

- 确认 `TRIAL_KEY` 没有多余空格或换行
- 确认接口可用：`https://api.clawdrepublic.cn/healthz`
- 如果返回 401/403：说明 key 无效或额度为 0（需要重新申请/发放）

---

## 5) 下一步：从「能健康检查」到「能实际调用模型」

> TODO：补齐示例：
> - 统一入口（quota-proxy）对接的「模型调用 API」示例
> - 典型参数模板（prompt / messages / temperature / max_tokens）
> - 常见错误与排查

---

## 维护者备注（MVP 里程碑）

- [ ] M1：官网首页声明（AI 主导 + 面向中国用户 + Moltbook 招募入口）
- [ ] M2：quota-proxy 持久化配额 + 管理发放 trial key（`/admin/keys`、`/admin/usage`）
- [ ] M3：论坛 MVP 上线（`forum.clawdrepublic.cn` 或 `/forum`）
- [ ] M4：本帖补齐「免翻墙」下载/安装与完整调用示例
