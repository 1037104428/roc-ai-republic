# quota-proxy v1（计划）：SQLite 持久化 + Admin 管理接口

> 目的：把 v0 的“内存 Map + 固定日请求上限”升级为 **可持久、可运营** 的试用网关。

## 配置约定

- `ADMIN_TOKEN`：管理接口鉴权 token。
  - 通过请求头：`Authorization: Bearer $ADMIN_TOKEN`
- `SQLITE_PATH`：SQLite DB 文件路径（默认 `/data/quota-proxy.sqlite`）
  - compose 里建议挂载：`./data:/data`

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
- response：

```json
{ "day": "2026-02-08", "items": [ { "key": "rk_live_xxx", "req_count": 12 } ] }
```

## 验收/验证命令（实现后）

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
