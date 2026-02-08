# quota-proxy v1（计划）：SQLite 持久化 + Admin 管理接口

> 目的：把 v0 的“内存 Map + 固定日请求上限”升级为 **可持久、可运营** 的试用网关。

## 配置约定

- `ADMIN_TOKEN`：管理接口鉴权 token。
  - 建议用 `openssl rand -hex 32` 生成，并仅在服务器侧保存（不要写进仓库）。
  - 通过请求头：`Authorization: Bearer $ADMIN_TOKEN`
- `SQLITE_PATH`：SQLite DB 文件路径（默认 `/data/quota-proxy.sqlite`）
  - compose 里建议挂载：`./data:/data`

## 安全与暴露面（建议）

- **管理接口永远不要直出公网**：保持 8787 仅监听 `127.0.0.1`，通过反代（Caddy/Nginx）做 HTTPS + 额外访问控制。
- `ADMIN_TOKEN` 一旦泄露应立即轮换，并视情况清理/禁用已发放 trial keys。

## 数据模型（最小可用）

- `trial_keys`
  - `key` TEXT PRIMARY KEY
  - `created_at` INTEGER (unix seconds)
  - `note` TEXT NULL
  - `daily_req_limit` INTEGER NULL（为空则使用全局默认）
  - `disabled` INTEGER DEFAULT 0

- `daily_usage`
  - `day` TEXT（`YYYY-MM-DD`）
  - `key` TEXT
  - `req_count` INTEGER
  - PRIMARY KEY (`day`, `key`)

## Admin API（草案）

### 1) 生成 trial key

`POST /admin/keys`

- 鉴权：必须携带 `ADMIN_TOKEN`
- body：

```json
{ "note": "optional", "daily_req_limit": 200 }
```

- response：

```json
{ "key": "rk_live_xxx", "created_at": 1700000000 }
```

### 2) 查询用量

`GET /admin/usage?day=YYYY-MM-DD&key=<optional>`

- 鉴权：必须携带 `ADMIN_TOKEN`
- 说明：
  - `day` 必填（推荐的稳定查询方式）。
  - `key` 可选：只看某一个 key。
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

> 兼容模式（用于快速排查最近用量）：不带 `day` 时，可用 `?limit=50` 返回跨天的最近记录（字段含 `day`）。

## 验收/验证命令（实现后）

更完整的“可复制粘贴验收清单”见：`docs/quota-proxy-v1-admin-acceptance.md`。

```bash
# 0) 基础健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 1) 生成 key
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{"note":"trial","daily_req_limit":200}'

# 2) 查询今日用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```
