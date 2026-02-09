# quota-proxy admin：验收清单（可复制粘贴）

> 目的：把 “开启持久化 + /admin/keys + /admin/usage（ADMIN_TOKEN）” 做成**可验证的最小闭环**。

关联：
- 规格：`docs/quota-proxy-v1-admin-spec.md`
- 需求/工单：`docs/tickets.md`

---

## 0) 前置：compose 约定（示例）

- 端口只绑定本机：`127.0.0.1:8787:8787`
- 数据目录挂载：`./data:/data`
- 环境变量：
  - `DEEPSEEK_API_KEY`（必填）
  - `ADMIN_TOKEN`（必填）
  - `SQLITE_PATH=/data/quota-proxy.json`（建议；当前实现为 JSON 文件）
  - `DAILY_REQ_LIMIT=200`（可选）

> 注意：`ADMIN_TOKEN` / `DEEPSEEK_API_KEY` 不要写进仓库；只在服务器上以 `.env`/环境变量保存。

---

## 1) 启动 + 健康检查

```bash
cd /opt/roc/quota-proxy

docker compose up -d --build

docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```

期望：
- `docker compose ps` 显示 `Up`
- `/healthz` 返回：`{"ok":true}`

---

## 1.5) 常见坑（3 条）

1) **不要把 admin 端口暴露到公网**：compose 端口绑定必须是 `127.0.0.1:8787:8787`。
2) **admin curl 一律带 token**：
   - 推荐：`-H "Authorization: Bearer $ADMIN_TOKEN"`
   - 若 `ADMIN_TOKEN` 没有 export，curl 会变成空 token，表现为一直 401。
3) **远程验收时用 SSH 转发**（不用开公网端口）：

```bash
# 本机执行：把服务器的 127.0.0.1:8787 转到你本机 18787
ssh -N -L 18787:127.0.0.1:8787 root@<SERVER_IP>

# 另开一个终端：指向本机转发端口验收
ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:18787 \
  ./scripts/curl-admin-usage.sh --day "$(date +%F)" --mask --pretty
```

## 2) 生成 1 个 trial key

推荐用脚本（更不容易粘贴错）。如果服务器目录 `/opt/roc/quota-proxy` 里**没有** `scripts/`，建议在任意目录先 clone 本仓库再运行脚本（脚本只依赖 curl）：

```bash
# 任选其一：在服务器上 clone 仓库（推荐）
cd /opt/roc
[ -d roc-ai-republic ] || git clone https://github.com/openclaw/roc-ai-republic.git
cd roc-ai-republic

ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
  ./scripts/curl-admin-create-key.sh --label 'forum-user:alice' --pretty

# 想先确认将发送的请求内容（不实际发请求）：
ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
  ./scripts/curl-admin-create-key.sh --label 'forum-user:alice' --dry-run
```

等价的原始 curl：

```bash
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'
```

期望：返回 JSON，包含：
- `key`（形如 `trial_<hex>`）
- `created_at`（毫秒时间戳）

---

## 3) 查询今日用量（按天汇总，推荐）

推荐用脚本（支持 `--mask` 脱敏，适合贴日志；也支持 `--base-url` 覆盖环境变量）。同上：如果当前目录没有 `scripts/`，请先 clone 本仓库再执行。

```bash
ADMIN_TOKEN=*** BASE_URL=http://127.0.0.1:8787 \
  ./scripts/curl-admin-usage.sh --day "$(date +%F)" --mask --pretty
```

等价的原始 curl：

```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

期望：返回 JSON，包含 `day` 与 `items`；`items[]` 每条包含：
- `key`
- `label`（如果该 key 是通过 `POST /admin/keys` 生成并带 label）
- `req_count`
- `updated_at`

补充说明（字段含义）：
- `day`：按天汇总的日期（YYYY-MM-DD）
- `req_count`：该 key 在该日累计请求次数（通常每次调用 /v1/* 记 1 次；以实现为准）
- `updated_at`：该 key 在该日计数最后更新时间（毫秒时间戳）

示例输出（格式示意，字段以实际为准）：
```json
{
  "day": "2026-02-09",
  "items": [
    {
      "key": "trial_...",
      "label": "forum-user:alice",
      "req_count": 3,
      "updated_at": 1760000000000
    }
  ]
}
```

---

## 3.5) （可选）查询最近用量（跨天，运维排查用）

> 仅用于快速排查最近有没有人在刷；不建议作为正式运营/报表查询方式。

```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?limit=50" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

期望：返回 JSON，`items` 内每条记录包含 `day` 字段。

---

## 4) 持久化验收（重启不丢 key/usage）

```bash
cd /opt/roc/quota-proxy

ls -la ./data

docker compose restart
sleep 1

# 重启后 admin 仍可查询（key/usage 不应丢失）
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

期望：
- `./data/quota-proxy.json`（或你实际设置的 `SQLITE_PATH` 文件）存在且体积非 0
- 重启后 `GET /admin/usage` 仍可读到之前记录（或至少结构/列表正常）

---

## 5) 安全回归（最小）

```bash
# 端口不应对公网直出（只绑定 localhost）
docker compose ps | sed -n '1,120p'

# 未带 token 访问 admin 应失败（401）
set +e
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8787/admin/usage
set -e
```

期望：
- `PORTS` 形如 `127.0.0.1:8787->8787/tcp`
- 未鉴权请求返回 `401`

---

## 6) SQLite 持久化（下一步：验收口径先写清）

> 当前实现为 JSON 文件也可以跑通闭环；但为了 **并发安全 / 可扩展查询 / 未来报表**，建议尽快切到 SQLite。

建议约定（落地实现时按此验收）：
- `SQLITE_PATH=/data/quota-proxy.sqlite`
- 容器内确保 `sqlite3`（或应用提供 `--migrate`）可用于快速自检

自检命令（实现后应当可用）：

```bash
# 文件存在且非 0
ls -la /opt/roc/quota-proxy/data/quota-proxy.sqlite

# 可读表结构（示例；具体表名以实现为准）
sqlite3 /opt/roc/quota-proxy/data/quota-proxy.sqlite ".tables"
```

---

## 附：给用户的发放回复模板（可复制）

> 建议通过论坛私信/工单发送；**不要**在公开帖子里粘贴完整 key。

```
你的 TRIAL_KEY 已签发：trial_xxx

最小自检（不会调用上游模型；通常不消耗额度；但可能计入 req_count 作为“请求次数”统计）：
  export CLAWD_TRIAL_KEY='trial_xxx'
  curl -fsS https://api.clawdrepublic.cn/v1/models \
    -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}"

如果需要跑一个最小对话（会消耗额度）：
  curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
    -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
    -H 'content-type: application/json' \
    -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好"}]}'

常见报错：
- 401/403：key 贴错或没带 Authorization 头
- 429：额度用尽或限流
```

脱敏展示示例：`trial_abcd...wxyz`

（可选）把自检命令打包成脚本（仓库内）：

```bash
export CLAWD_TRIAL_KEY='trial_xxx'
./scripts/verify-trial-key.sh                                # healthz + models
./scripts/verify-trial-key.sh --chat                         # 额外跑一次最小对话（会消耗额度）
./scripts/verify-trial-key.sh --chat --model deepseek-chat    # 指定模型（便于对照线上默认/推荐模型）
```
