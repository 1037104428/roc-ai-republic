# quota-proxy v0.1（当前实现）：JSON 持久化 + Admin 管理接口

> 目的：把“试用网关”的 **发 key / 查用量** 做成可运营、可验证的最小闭环。
>
> 说明：历史文件名里写的是 v1/SQLite，但**当前线上实现为 v0.1：用 JSON 文件持久化**（环境变量仍沿用 `SQLITE_PATH` 这个名字，后续再切真正 SQLite 不破坏配置）。

## 运营发放流程（当前：人工发放）

- 用户在论坛发帖申请（说明用途/频率）。
- 管理员在服务器本机用 `POST /admin/keys` 生成一个 `trial_...` key。
- 将该 key 私信/回复给用户，并提示：
  - 用 `Authorization: Bearer trial_...` 调用 `https://api.clawdrepublic.cn/v1/chat/completions`
  - 可用 `https://api.clawdrepublic.cn/healthz` 做非消耗型健康检查

（官网版说明页：`docs/site/quota-proxy.html`）

## 配置约定（环境变量）

- `DEEPSEEK_API_KEY`：上游 DeepSeek key（必填）。
- `DEEPSEEK_BASE_URL`：上游 base url（默认 `https://api.deepseek.com/v1`）。
- `DAILY_REQ_LIMIT`：每个 TRIAL_KEY 的每日请求次数上限（默认 `200`）。

- `ADMIN_TOKEN`：管理接口鉴权 token。
  - 建议用 `openssl rand -hex 32` 生成，并仅在服务器侧保存（不要写进仓库）。
  - 通过请求头：`Authorization: Bearer $ADMIN_TOKEN`（或 `x-admin-token: $ADMIN_TOKEN`）

- `SQLITE_PATH`：**持久化文件路径**（当前实现为 JSON 文件）。
  - 例如：`/data/quota-proxy.json`
  - compose 里建议挂载：`./data:/data`

## 安全与暴露面（强烈建议）

- **管理接口永远不要直出公网**：保持 8787 仅监听 `127.0.0.1`，通过 SSH 登录到服务器本机执行 `curl`（或用反代做 HTTPS + 额外访问控制）。
- `ADMIN_TOKEN` 一旦泄露应立即轮换；必要时重发 key（或在未来版本增加禁用/吊销机制）。

## 数据模型（当前 v0.1）

- `keys`：
  - `trialKey -> { label, created_at }`
- `usage`：
  - `day -> { trialKey -> { requests, updated_at } }`

时间戳：`created_at/updated_at` **都是毫秒**（`Date.now()`）。

## 计数语义（很重要，关系到运营解释）

- `req_count` 统计的是对 `POST /v1/chat/completions` 的**请求次数**。
- 计数发生在：
  1) 已提供 TRIAL_KEY 且（在开启持久化时）key 已被签发
  2) **在转发上游之前**
  3) **在限额判断之前**
- 因此：
  - 上游失败（例如 5xx/超时）也会计入次数。
  - 超过上限后返回 429 的那次请求也会计入次数（因为先 +1 再判断）。

> 这套语义的好处是实现简单、能反映“网关承受的请求压力”。
> 如需“只统计成功请求”或“区分成功/失败”，后续可扩展字段（如 `success_count`/`error_count`）。

---

## Admin API（当前实现）

### 1) 生成 trial key

`POST /admin/keys`

- 鉴权：必须携带 `ADMIN_TOKEN`
- 前置：必须开启持久化（设置 `SQLITE_PATH`），否则返回 400
- body：

```json
{ "label": "optional" }
```

- response：

```json
{ "key": "trial_<hex>", "label": "...", "created_at": 1700000000000 }
```

### 2) 查询用量（推荐：按天）

`GET /admin/usage?day=YYYY-MM-DD&key=<optional>`

- 鉴权：必须携带 `ADMIN_TOKEN`
- 说明：
  - `day`：推荐必填（稳定、可报表化）
  - `key`：可选，只看某个 key

- response：

```json
{
  "day": "2026-02-08",
  "mode": "file",
  "items": [
    { "key": "trial_xxx", "req_count": 12, "updated_at": 1700000000000 }
  ]
}
```

- 字段说明：
  - `day`：查询日期（`YYYY-MM-DD`）
  - `mode`：
    - `file`：已开启 `SQLITE_PATH`（JSON 文件持久化）
    - `memory`：纯内存（不推荐生产）
  - `items[]`：用量条目列表（默认按 `updated_at` 倒序）
    - `key`：trial key（外部展示建议脱敏，例如 `trial_abcd…wxyz`）
    - `req_count`：当天累计请求次数（见“计数语义”）
    - `updated_at`：最后一次更新用量的时间戳（毫秒）

### 3) 查询最近用量（兼容/运维排查用）

`GET /admin/usage?limit=50`

- 不带 `day` 时，返回跨天的最近记录（每条包含 `day`）。
- 仅用于快速排查，不建议作为正式运营查询方式。

---

## 验收/验证命令

更完整的“可复制粘贴验收清单”见：`docs/quota-proxy-v1-admin-acceptance.md`。

```bash
# 0) 基础健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 1) 生成 key
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'

# 2) 查询今日用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```
