# quota-proxy：TRIAL_KEY 发放与使用（手把手）

这页写给**完全小白**：从“我拿到一个 key”到“我能跑通 OpenClaw”。

> 现阶段：**TRIAL_KEY 由管理员手动发放**（不是自助注册）。拿到 key 后，再按本文配置即可。

---

## 0. 你需要准备什么

- 一个 `TRIAL_KEY`（形如 `sk-xxx`）
- 一台能访问网关的机器（你的电脑即可）

---

## 1. 用 curl 验证 key 是否可用（推荐先做）

把 key 放进环境变量（避免贴到命令历史里）：

```bash
export CLAWD_TRIAL_KEY='sk-xxx'
# 兼容旧名字：export TRIAL_KEY='sk-xxx'
```

验证网关健康：

```bash
curl -fsS https://api.clawdrepublic.cn/healthz
```

验证 `TRIAL_KEY` 能请求（OpenAI-compatible）：

```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "ping"}
    ]
  }'
```

常见返回：
- `200`：OK
- `401`：key 不存在/已撤销/你没带对 header
- `429`：当天试用次数已用完（次日自动重置，或联系管理员）

---

## 2. OpenClaw 里怎么用（概念）

- 你的 OpenClaw 配置把 provider 的 `baseUrl` 指向 quota-proxy（也就是 `https://api.clawdrepublic.cn/v1`）
- 你的 OpenClaw 发请求时，带上 `Authorization: Bearer <TRIAL_KEY>`

具体配置写法会随「中文包」版本变化；如果你不知道怎么改配置，优先参考仓库根目录 `README.md` 和 `docs/新手一条龙教程.md`。

---

## 3. 管理员：怎么签发 key / 查用量（运维）

管理员侧的完整说明、脚本与 `admin/usage` 字段解释，统一放在仓库：

- `quota-proxy/README.md`（包含 keys-create、usage 的 curl 示例与字段说明）

如果你要把这套服务部署到自己的服务器，也请直接按 `quota-proxy/README.md` 的 Docker Compose 小节走。
