# quota-proxy：DeepSeek 限额试用网关（OpenAI-compatible）

目的：给"OpenClaw 小白中文包"提供 **可控、可持续** 的免费试用额度。

基本思路：
- 用户拿到一个 `TRIAL_KEY`（我们发；在客户端/脚本里推荐用环境变量 `CLAWD_TRIAL_KEY` 承载，兼容旧名 `TRIAL_KEY`）
- OpenClaw 端把 provider `baseUrl` 指向本网关
- 网关转发到 DeepSeek 官方 API（后端持有赞助者的 `DEEPSEEK_API_KEY`）
- 网关对每个 `TRIAL_KEY` 做最小限额（v0：按日请求数）

## 安全边界
- 不做任何隐蔽/绕行/"翻墙入口"；就是普通 HTTP(S) 服务。
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

> 计数口径：每次请求进入 `/v1/chat/completions` 时会先 `incrUsage()`，所以**上游失败/超时也会计入当日次数**（更符合"试用配额=请求机会"）。

## 快速验证（部署后）

部署完成后，可以用以下命令验证服务是否正常：

```bash
# 1. 健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 2. 模型列表（需要有效的 TRIAL_KEY）
curl -fsS http://127.0.0.1:8787/v1/models \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY"

# 3. 简单聊天请求
curl -fsS http://127.0.0.1:8787/v1/chat/completions \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好"}]}'
```

如果看到 `{"ok":true}`（健康检查）或正常的模型列表/响应，说明网关工作正常。

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
当前 v1（SQLite）实现**未提供**"撤销 key"的 HTTP 接口（避免误操作/需要更明确的审计与权限边界）。

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

## 验证脚本

我们提供了完整的验证脚本来测试 SQLite 持久化功能：

```bash
# 设置环境变量
export ADMIN_TOKEN=your_admin_token_here
export QUOTA_PROXY_URL=http://localhost:8787

# 运行完整验证
./scripts/verify-sqlite-persistence.sh
```

验证脚本会测试：
1. 健康检查
2. 管理员认证
3. Trial key 创建和持久化
4. Key 使用和计数
5. 使用情况查询
6. 数据清理

## 部署指南

详细的 SQLite 版本部署指南请参考：[sqlite-deployment-guide.md](../docs/sqlite-deployment-guide.md)

## 下一步（v2 / 可选增强）
- key 维度策略：有效期 / 日限额（每 key 覆盖）/ 禁用
- 可选：脱敏审计日志（只保留 request_id / 时间 / key hash / 状态码）

## TRIAL_KEY 申请与使用流程

### 申请试用密钥（当前为手动发放）

目前 TRIAL_KEY 需要通过管理员手动发放。申请流程：

1. **联系管理员**：通过 Clawd 社区渠道（论坛/Telegram群）联系管理员申请试用
2. **提供信息**：提供你的使用场景和预计用量
3. **获取密钥**：管理员通过管理界面创建密钥后发送给你

### 使用试用密钥

获取 TRIAL_KEY 后，在客户端配置：

```bash
# 环境变量方式（推荐）
export CLAWD_TRIAL_KEY="your_trial_key_here"
export OPENAI_BASE_URL="http://localhost:8787"

# 或在 OpenClaw 配置中设置
# provider.baseUrl = "http://localhost:8787"
# provider.apiKey = "your_trial_key_here"
```

### 验证密钥状态

```bash
# 检查密钥是否有效
curl -H "Authorization: Bearer your_trial_key_here" \
  http://localhost:8787/v1/models
```

### 自助申请流程（规划中）

未来将实现自助申请页面，用户可通过 Web 表单申请试用密钥，系统自动审核发放。

## Web 管理界面

当设置了 `ADMIN_TOKEN` 环境变量时，可以通过浏览器访问管理界面：

```
http://localhost:8787/admin
```

管理界面提供以下功能：
1. **系统状态查看** - 检查数据库连接、运行模式等
2. **密钥管理** - 创建、查看、删除试用密钥
3. **使用情况监控** - 查看各密钥的 API 调用情况

### 访问方式
1. 确保服务器运行在 SQLite 模式下（使用 `server-sqlite.js`）
2. 设置 `ADMIN_TOKEN` 环境变量
3. 访问 `http://localhost:8787/admin`
4. 在界面中输入管理员令牌进行认证

### 安全注意事项
- **不要将管理界面暴露到公网** - 建议只通过本地访问或 VPN 访问
- **使用强密码作为 ADMIN_TOKEN**
- **定期轮换 ADMIN_TOKEN**
- **记录所有管理操作** - 界面操作会记录到服务器日志中

详细说明请参考 [ADMIN-INTERFACE.md](./ADMIN-INTERFACE.md)
