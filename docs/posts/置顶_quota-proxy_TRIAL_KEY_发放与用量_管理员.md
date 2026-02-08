# 置顶：quota-proxy 的 TRIAL_KEY 发放与用量查询（管理员）

> 这篇是给「管理员/运维」看的：如何**手动发放 TRIAL_KEY**、如何查询**当天用量**、以及 admin 接口输出字段说明。
>
> 给普通用户的「怎么用 TRIAL_KEY 调用」请看：
> - 小白一条龙：`docs/小白一条龙_从0到可用.md`

---

## 0) 前提（必须）

- quota-proxy 已部署并可在服务器本机访问：
  - `curl -fsS http://127.0.0.1:8787/healthz`
- 已启用持久化（否则无法“只允许已签发 key”）：
  - 环境变量 `SQLITE_PATH=/data/quota.db`
- 已设置管理口鉴权：
  - 环境变量 `ADMIN_TOKEN=***`

> 安全建议：管理口仅允许 **127.0.0.1** 访问；不要把 8787 直接暴露公网（用 Caddy/Nginx 反代公开 API 口即可）。

---

## 1) 生成/签发一个 TRIAL_KEY

### 方式 A：用脚本（推荐）

```bash
cd /opt/roc/quota-proxy
export ADMIN_TOKEN='***'
./scripts/quota-proxy-admin.sh keys-create --label 'forum-user:alice'
```

### 方式 B：直接 curl

```bash
export ADMIN_TOKEN='***'
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'
```

返回示例：

```json
{"key":"trial_xxx","label":"forum-user:alice","created_at":1700000000000}
```

字段说明：
- `key`：签发给用户的 TRIAL_KEY
- `label`：给管理员看的备注（建议包含来源：forum/群/私信 + 用户名）
- `created_at`：毫秒时间戳

---

## 2) 查询用量（按天聚合）

> 推荐把 `day=YYYY-MM-DD` 作为唯一正式口径（可做报表）。
> 不带 `day` 的 `limit` 模式仅用于运维快速排查（可能跨天）。

### 2.1 查询某一天所有 key 的用量

```bash
export ADMIN_TOKEN='***'
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 2.2 查询某一天某个 key 的用量

```bash
export ADMIN_TOKEN='***'
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=trial_xxx" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

返回示例（示意）：

```json
{
  "day": "2026-02-09",
  "mode": "file",
  "items": [
    {"key":"trial_abc...xyz","req_count":12,"updated_at":1760000000000},
    {"key":"trial_def...uvw","req_count":3,"updated_at":1760000001234}
  ]
}
```

输出字段说明：
- `day`：查询日期（`YYYY-MM-DD`）
- `mode`：
  - `file`：开启了 `SQLITE_PATH`（持久化启用，推荐生产）
  - `memory`：纯内存（不推荐生产）
- `items[]`：
  - `key`：TRIAL_KEY（建议对外展示时做脱敏：只留前后几位）
  - `req_count`：当天累计请求次数
  - `updated_at`：最后一次写入/更新的毫秒时间戳

> 计数口径：每次请求进入 `/v1/chat/completions` 时会先 `incrUsage()`；因此**上游失败/超时也会计入当日次数**（更符合“试用配额=请求机会”）。

---

## 3) 列出已签发 key（管理员）

```bash
export ADMIN_TOKEN='***'
curl -fsS http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

---

## 4) 给用户的最小验证命令（你可以直接发给他/她）

```bash
# 1) 只测网关健康（不产生调用成本）
curl -fsS https://api.clawdrepublic.cn/healthz

# 2) 最小一次对话（把 xxx 换成你签发的 TRIAL_KEY）
export TRIAL_KEY="xxx"

curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```
