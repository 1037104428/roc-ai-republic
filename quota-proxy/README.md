# quota-proxy：DeepSeek 限额试用网关（OpenAI-compatible）

目的：给“OpenClaw 小白中文包”提供 **可控、可持续** 的免费试用额度。

基本思路：
- 用户拿到一个 `TRIAL_KEY`（我们发；在客户端/脚本里推荐用环境变量 `CLAWD_TRIAL_KEY` 承载，兼容旧名 `TRIAL_KEY`）
- OpenClaw 端把 provider `baseUrl` 指向本网关
- 网关转发到 DeepSeek 官方 API（后端持有赞助者的 `DEEPSEEK_API_KEY`）
- 网关对每个 `TRIAL_KEY` 做最小限额（v0：按日请求数）

## 安全边界
- 不做任何隐蔽/绕行/“翻墙入口”；就是普通 HTTP(S) 服务。
- 不收集多余隐私：仅做 **按日请求次数** 计数（v0：内存/JSON；v1：SQLite）。
- v1 已引入 SQLite 持久化 + 简单管理接口（见下文）。

## 暴露端口 / HTTPS 建议
`compose.yaml` 默认将服务端口绑定到本机回环：`127.0.0.1:8787:8787`。

- 推荐做法：用 Caddy/Nginx 反代到 `http://127.0.0.1:8787` 并启用 HTTPS。
- 不建议直接把 8787 端口对公网暴露（除非你额外做了鉴权/防火墙/限流等）。

## v0 / v1 版本说明（都已可跑）

- v0（JSON/内存版）：`server.js`
- v1（SQLite 版）：`server-sqlite.js`（推荐生产使用）

提供：
- `GET /healthz` → `{ ok: true }`
- `GET /v1/models` → 最小模型列表（`deepseek-chat` / `deepseek-reasoner`）
- `POST /v1/chat/completions` → OpenAI-compatible 转发到 DeepSeek，并做简单配额：
  - `Authorization: Bearer <TRIAL_KEY>`（或 `x-trial-key`）
  - `DAILY_REQ_LIMIT`（默认 200）超限返回 429

环境变量（通用）：
- 必填：`DEEPSEEK_API_KEY`
- 可选：
  - `PORT`（默认 8787）
  - `DEEPSEEK_BASE_URL`（默认 `https://api.deepseek.com/v1`）
  - `DAILY_REQ_LIMIT`（默认 200）

环境变量（发放/用量，推荐开启）：
- `SQLITE_PATH`：
  - v0：JSON 文件路径（历史兼容名），例如：`/data/quota-proxy.json`
  - v1：SQLite DB 文件路径，例如：`/data/quota.db`
  - 只要设置了该变量：
    - `TRIAL_KEY` 必须是管理员签发过的（未知 key 会 401）
    - 用量会落盘（v0 写 JSON；v1 写 SQLite）
- `ADMIN_TOKEN`：管理口鉴权 token（不要写进仓库）

> 计数口径：每次请求进入 `/v1/chat/completions` 时会先 `incrUsage()`，所以**上游失败/超时也会计入当日次数**（更符合“试用配额=请求机会”）。

## 本地运行（开发）
```bash
cd quota-proxy
npm i
DEEPSEEK_API_KEY=*** PORT=8787 node server.js
curl -fsS http://127.0.0.1:8787/healthz

# v1（SQLite）
DEEPSEEK_API_KEY=*** PORT=8787 SQLITE_PATH=./quota.db ADMIN_TOKEN=*** node server-sqlite.js
curl -fsS http://127.0.0.1:8787/healthz
```

## Docker Compose（部署）
仓库内已提供：`quota-proxy/Dockerfile` + `quota-proxy/compose.yaml`

```bash
cd quota-proxy
# 1) 写入环境变量
cat > .env <<'EOF'
DEEPSEEK_API_KEY=***
PORT=8787
DAILY_REQ_LIMIT=200
# 推荐开启：发放/用量持久化
SQLITE_PATH=/data/quota.db
ADMIN_TOKEN=***
EOF

# 2) 启动
docker compose up -d --build

# 3) 验证
docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```

## TRIAL_KEY 发放（管理员 / 当前可用）

前提：
- `SQLITE_PATH` 已设置（否则 persistence disabled）
- `ADMIN_TOKEN` 已设置
- 管理口仅在内网/本机可访问（建议只监听 127.0.0.1）

### 1) 生成一个 TRIAL_KEY

推荐使用仓库脚本（更不容易写错参数）：
```bash
export ADMIN_TOKEN='***'
./scripts/quota-proxy-admin.sh keys-create --label 'forum-user:alice'
```

等价的 curl：
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

### 2) 查询用量（按天聚合）
推荐脚本：
```bash
export ADMIN_TOKEN='***'
./scripts/quota-proxy-admin.sh usage --day "$(date +%F)"
```

等价的 curl：
```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

也可以查询某个 key：
```bash
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=trial_xxx" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

输出字段说明：
- `day`: 查询日期（`YYYY-MM-DD`）
- `mode`: `file`=已开启持久化（v0 当前实现为 JSON 文件，环境变量名仍沿用 `SQLITE_PATH`）；`sqlite`=SQLite 持久化（仅当你运行 `server-sqlite.js`）；`memory`=纯内存（不推荐生产）
- `items[]`:
  - `key`: trial key（建议在外部展示时做脱敏）
  - `req_count`: 当天累计请求次数
  - `updated_at`: 最后一次写入/更新的时间戳（毫秒）

### 3) 列出已签发 key（管理员）
```bash
curl -fsS http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 4) 撤销 / 禁用某个 key（管理员）
当前 v1（SQLite）实现**未提供**“撤销 key”的 HTTP 接口（避免误操作/需要更明确的审计与权限边界）。

可回滚的做法（推荐先备份 DB）：
```bash
# 1) 进入服务器（示例：compose 运行目录）
cd /opt/roc/quota-proxy

# 2) 找到 DB 路径（与 .env 的 SQLITE_PATH 一致）
#   常见为：/opt/roc/quota-proxy/data/quota.db 或 /data/quota.db

# 3) 备份
cp -a ./data/quota.db ./data/quota.db.bak.$(date +%F-%H%M%S)

# 4) 删除 key（会级联删除 daily_usage）
sqlite3 ./data/quota.db "DELETE FROM trial_keys WHERE key='trial_xxx';"
```

验证（被撤销的 key 再请求应 401）：
```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  http://127.0.0.1:8787/v1/chat/completions \
  -H 'content-type: application/json' \
  -H 'Authorization: Bearer trial_xxx' \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"ping"}]}'
```

## 下一步（v2 / 可选增强）
- key 维度策略：有效期 / 日限额（每 key 覆盖）/ 禁用
- 可选：脱敏审计日志（只保留 request_id / 时间 / key hash / 状态码）
