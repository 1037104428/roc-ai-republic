# quota-proxy：TRIAL_KEY 发放与使用（手把手）

这页写给**完全小白**：从"我拿到一个 key"到"我能跑通 OpenClaw"。

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

### 1.1 验证网关健康

```bash
# 生产环境（官方网关）
curl -fsS https://api.clawdrepublic.cn/healthz

# 本地开发环境
curl -fsS http://localhost:8787/healthz

# Docker 容器环境
curl -fsS http://quota-proxy:8787/healthz

# 生产服务器（自定义域名）
curl -fsS https://api.yourdomain.com/healthz
```

### 1.2 验证 `TRIAL_KEY` 能请求（OpenAI-compatible）

```bash
# 生产环境
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "ping"}
    ]
  }'

# 本地开发环境
curl -fsS http://localhost:8787/v1/chat/completions \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "ping"}
    ]
  }'

# Docker Compose 环境
curl -fsS http://quota-proxy:8787/v1/chat/completions \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "ping"}
    ]
  }'
```

### 1.3 检查使用情况

```bash
# 查看当日使用量
curl -fsS -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  https://api.clawdrepublic.cn/usage

# 查看可用模型列表
curl -fsS https://api.clawdrepublic.cn/v1/models
```

常见返回：
- `200`：OK
- `401`：key 不存在/已撤销/你没带对 header
- `429`：当天试用次数已用完（次日自动重置，或联系管理员）

---

## 2. OpenClaw 里怎么用（概念）

- 你的 OpenClaw 配置把 provider 的 `baseUrl` 指向 quota-proxy（也就是 `https://api.clawdrepublic.cn/v1`）
- 你的 OpenClaw 发请求时，带上 `Authorization: Bearer <TRIAL_KEY>`

### 2.1 OpenClaw 配置示例

```yaml
# OpenClaw 配置文件示例
providers:
  - id: deepseek-trial
    name: DeepSeek 试用版
    baseUrl: "https://api.clawdrepublic.cn/v1"
    apiKey: "你的TRIAL_KEY"
    models:
      - id: deepseek-chat
      - id: deepseek-reasoner
```

### 2.2 不同部署环境的配置

```yaml
# 本地开发环境
baseUrl: "http://localhost:8787/v1"

# Docker 容器环境
baseUrl: "http://quota-proxy:8787/v1"

# 生产服务器（自定义域名）
baseUrl: "https://api.yourdomain.com/v1"

# Kubernetes 环境
baseUrl: "http://quota-proxy-service.default.svc.cluster.local:8787/v1"
```

具体配置写法会随「中文包」版本变化；如果你不知道怎么改配置，优先参考仓库根目录 `README.md` 和 `docs/新手一条龙教程.md`。

---

## 3. 管理员：怎么签发 key / 查用量（运维）

管理员侧的完整说明、脚本与 `admin/usage` 字段解释，统一放在仓库：

- `quota-proxy/README.md`（包含 keys-create、usage 的 curl 示例与字段说明）
- `quota-proxy/TRIAL_KEY_MANUAL_PROCESS.md`（详细的手动发放流程，包含多种部署环境的curl示例）

### 3.1 快速签发密钥示例

```bash
# 生产环境
curl -X POST https://api.clawdrepublic.cn/admin/keys \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "用户A-20250211",
    "daily_limit": 200
  }'

# 本地开发环境
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "本地测试用户",
    "daily_limit": 100
  }'

# Docker Compose 环境
curl -X POST http://quota-proxy:8787/admin/keys \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "容器用户",
    "daily_limit": 150
  }'
```

### 3.2 查看所有密钥和使用情况

```bash
# 查看所有密钥
curl -H "Authorization: Bearer 管理员令牌" \
  https://api.clawdrepublic.cn/admin/keys

# 查看使用统计
curl -H "Authorization: Bearer 管理员令牌" \
  https://api.clawdrepublic.cn/admin/usage

# 重置使用次数
curl -X POST https://api.clawdrepublic.cn/admin/reset-usage \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{"key": "要重置的密钥"}'
```

### 3.3 部署到自己的服务器

如果你要把这套服务部署到自己的服务器，请参考：

1. `quota-proxy/README.md` - Docker Compose 部署指南
2. `quota-proxy/deploy-quota-proxy-rate-limit.sh` - 快速部署脚本
3. `docs/deploy-quota-proxy-sqlite-guide.md` - SQLite 持久化部署指南

---

## 4. 故障排除

### 4.1 常见问题

1. **密钥无效**：检查密钥是否正确复制，确保没有多余空格
2. **达到限制**：检查当日使用量，联系管理员增加限制或重置
3. **服务不可用**：检查服务状态，查看服务器日志
4. **网络问题**：检查防火墙设置，确保端口可访问

### 4.2 获取帮助

- 查看详细文档：`quota-proxy/TRIAL_KEY_MANUAL_PROCESS.md`
- 查看故障排除：`docs/quota-proxy-faq-troubleshooting.md`
- 联系管理员：通过社区渠道获取支持

---

**最后更新：** 2026-02-11  
**相关文档：** [新手一条龙教程.md](./新手一条龙教程.md), [小白一条龙_从0到可用.md](./小白一条龙_从0到可用.md)
