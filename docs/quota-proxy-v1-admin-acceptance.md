# quota-proxy v1 admin：验收清单（可复制粘贴）

> 目的：把 “SQLite 持久化 + /admin/keys + /admin/usage（ADMIN_TOKEN）” 做成**可验证的最小闭环**。

关联：
- 任务票：`docs/tickets.md` → **T5**
- 规格草案：`docs/quota-proxy-v1-admin-spec.md`

---

## 0) 前置：compose 约定（示例）

- 端口只绑定本机：`127.0.0.1:8787:8787`
- 数据目录挂载：`./data:/data`
- 环境变量：
  - `ADMIN_TOKEN`（必填）
  - `SQLITE_PATH=/data/quota-proxy.sqlite`（建议）

> 注意：`ADMIN_TOKEN` 不要写进仓库；只在服务器上以 `.env`/环境变量保存。

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

## 2) 生成 1 个 trial key

```bash
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{"note":"trial","daily_req_limit":200}'
```

期望：返回 JSON，包含 `key` 与 `created_at`。

---

## 3) 查询今日用量（按天汇总）

```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

期望：返回 JSON，包含 `day` 与 `items`。

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
- `./data/quota-proxy.sqlite`（或你实现的 sqlite 文件）存在且体积非 0
- 重启后 `GET /admin/usage` 仍可读到之前记录（或至少结构/列表正常）

---

## 5) 安全回归（最小）

```bash
# 端口不应对公网直出（只绑定 localhost）
docker compose ps | sed -n '1,120p'

# 未带 token 访问 admin 应失败（401/403）
set +e
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8787/admin/usage
set -e
```

期望：
- `PORTS` 形如 `127.0.0.1:8787->8787/tcp`
- 未鉴权请求返回 `401` 或 `403`
