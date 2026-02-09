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

> 说明：生产服务器的 `/opt/roc/quota-proxy` 目录通常只有运行所需文件（未必包含 `scripts/`）。
> 管理脚本在仓库里：`roc-ai-republic/scripts/quota-proxy-admin.sh`。
>
> 你可以在任意一台能访问 **服务器本机 127.0.0.1:8787** 的环境使用它：
> - 直接在服务器上（把脚本复制过去），或
> - 在本机通过 SSH 转发/远程执行（更推荐直接用下方 curl，最不容易出环境差异）。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
export ADMIN_TOKEN='***'
./scripts/quota-proxy-admin.sh --host http://127.0.0.1:8787 keys-create --label 'forum-user:alice'
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
{"key":"sk-xxx","label":"forum-user:alice","created_at":1700000000000}
```

字段说明：
- `key`：签发给用户的 TRIAL_KEY
- `label`：给管理员看的备注（建议包含来源：forum/群/私信 + 用户名）
- `created_at`：毫秒时间戳

---

## 1.1) 撤销/禁用一个 TRIAL_KEY（管理员）

> 典型场景：Key 泄漏、滥用、用户已转正、或需要更换新 key。

### 情况 A：纯内存模式（`mode=memory`）

```bash
export ADMIN_TOKEN='***'
export TRIAL_KEY='sk-xxx'

curl -fsS -X DELETE "http://127.0.0.1:8787/admin/keys/${TRIAL_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 情况 B：SQLite 持久化模式（`mode=file`）

当前版本在 `server-sqlite.js` 里**已提供** `DELETE /admin/keys/:key` 接口：

```bash
# 使用 HTTP DELETE 接口撤销 key
curl -fsS -X DELETE \
  "http://127.0.0.1:8787/admin/keys/sk-49fc7ef5b6c0c8c2c08fab4f9b21c302ad84ff4a24da4f03" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

成功响应：
```json
{"deleted":true}
```

如果 key 不存在：
```json
{"error":{"message":"Key not found"}}
```

**备选方案**（手动数据库操作，可回滚前提：先备份 db 文件）：
```bash
# ⚠️ 只在服务器本机执行；先备份
cp -a /data/quota.db "/data/quota.db.bak.$(date +%F_%H%M%S)"

sqlite3 /data/quota.db "DELETE FROM trial_keys WHERE key='sk-xxx';"
```

> 撤销后该 key 继续被使用时，网关应返回 401/403（取决于实现与鉴权模式）。

## 1.2) 发放策略建议（运维口径）

- **有效期**：建议在 label 里写明发放日 + 预期有效期（例如 `2026-02-09/7d`），方便人工巡检。
- **权限边界**：TRIAL_KEY 仅用于试用调用，不保证稳定 SLA；可随时撤销。
- **额度口径**：若当前只做“请求次数”限制，建议在发放时同步告知：一次请求≠一次成功（上游失败也可能计入）。
- **最小暴露**：管理口永远只在 127.0.0.1；对外只暴露反代后的 API 口。

---

## 2) 查询用量（按天聚合）

> 推荐把 `day=YYYY-MM-DD` 作为唯一正式口径（可做报表）。
> 不带 `day` 的 `limit` 模式仅用于运维快速排查（可能跨天）。

### 2.1 查询某一天所有 key 的用量

curl 方式：
```bash
export ADMIN_TOKEN='***'
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

脚本方式（仓库内置，参数更不容易写错）：
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
export ADMIN_TOKEN='***'
./scripts/quota-proxy-admin.sh --host http://127.0.0.1:8787 usage --day "$(date +%F)"
```

### 2.2 查询某一天某个 key 的用量

```bash
export ADMIN_TOKEN='***'
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=sk-xxx" \
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
