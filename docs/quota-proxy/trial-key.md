# 获取 TRIAL_KEY（手动发放 / 极简流程）

> 适用场景：你想先让少量用户试用 quota-proxy，但还没接入自动化支付/注册。

## TL;DR

- 用户拿到 `TRIAL_KEY` 后，可用几条 curl 立刻验证是否可用
- 管理员建议“一人一钥 + 可撤销 + 可限额”，避免 Key 在公开场合泄露
- **管理接口（admin/usage 等）不对外开放**：请用 `ADMIN_TOKEN` 并在服务器本机访问 `127.0.0.1:8787`

---

## 管理员：发放流程（当前：人工）

1) 在服务器本机生成 `TRIAL_KEY`
2) 私信发给用户（不要公开粘贴）
3) 需要停用时：撤销该 key（或后续版本将其限额设为 0）

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
