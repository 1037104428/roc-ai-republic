# 获取 TRIAL_KEY（手动发放 / 极简流程）

> 适用场景：你想先让少量用户试用 quota-proxy，但还没接入自动化支付/注册。

## TL;DR

- 用户拿到 `TRIAL_KEY` 后，可用几条 curl 立刻验证是否可用
- 管理员建议“一人一钥 + 可撤销 + 可限额”，避免 Key 在公开场合泄露
- **管理接口（admin/usage 等）不对外开放**：请用 `ADMIN_TOKEN` 并在服务器本机访问 `127.0.0.1:8787`

---

## 管理员：发放流程（当前：人工）

### 方法一：通过 admin/keys API 生成（推荐）

在运行 quota-proxy 的服务器上执行：

```bash
# 1. 设置管理员令牌（启动服务时设置的 ADMIN_TOKEN 环境变量）
export ADMIN_TOKEN="your_admin_token_here"

# 2. 生成新的 TRIAL_KEY（可添加备注标签）
curl -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "用户:alice 用途:demo测试"}' \
  | python3 -m json.tool
```

响应示例：
```json
{
  "key": "trial_4a7b9c2d5e8f1a3b6c9d2e5f8a1b4c7d9e",
  "label": "用户:alice 用途:demo测试",
  "created_at": 1739203083000
}
```

### 方法二：手动生成（备用）

如果 API 不可用，可以手动生成符合格式的 key：

```bash
# 生成随机 key（18字节十六进制）
node -e "console.log('trial_' + require('crypto').randomBytes(18).toString('hex'))"
```

然后将生成的 key 手动添加到 quota-proxy 的存储中。

### 发放步骤

1) 在服务器本机生成 `TRIAL_KEY`（使用上述方法）
2) 私信发给用户（不要公开粘贴）
3) 记录 key 的 label 备注，便于后续管理
4) 需要停用时：通过 `/admin/keys/:key` DELETE 接口撤销该 key

> 管理接口说明与脚本：见仓库文档 `roc-ai-republic/docs/quota-proxy-v1-admin-spec.md`。

---

## 用户：curl 快速验证

默认服务端入口（如无特殊说明）：

- API Base: `https://api.clawdrepublic.cn`

把 `YOUR_TRIAL_KEY` 换成你的 key（或先导出到环境变量，避免反复复制）：

```bash
export TRIAL_KEY="YOUR_TRIAL_KEY"

# 0) 不需要 key 的健康检查（不消耗额度）
curl -fsS https://api.clawdrepublic.cn/healthz

# 1) 需要 key：查看可用模型（用于确认 key 生效）
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $TRIAL_KEY" \
  | head
```

如果返回模型列表（或 JSON 输出），说明 Key 已生效。

## 用户：第一次调用（chat/completions）

```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "你好，给我一个 3 步学习计划"}]
  }'
```

---

## 管理员：admin/usage 输出字段怎么读（简版）

> 以当前线上实现为准（详细规范见 `roc-ai-republic/docs/quota-proxy-v1-admin-spec.md`）。

典型返回（按天查询）：

```json
{
  "day": "2026-02-08",
  "mode": "file",
  "items": [
    { "key": "trial_xxx", "label": "forum:alice purpose:demo", "req_count": 12, "updated_at": 1700000000000 }
  ]
}
```

字段说明：

- `day`：查询日期（`YYYY-MM-DD`）
- `mode`：`file`（已开启持久化）/ `memory`（纯内存，不推荐生产）
- `items[]`：用量条目
  - `key`：trial key（对外展示建议脱敏）
  - `label`：签发时写入的备注
  - `req_count`：当天累计请求次数
  - `updated_at`：最后一次更新用量的时间戳（毫秒）

管理员查询示例（服务器本机执行）：

```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -m json.tool | head
```
