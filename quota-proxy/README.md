# quota-proxy：DeepSeek 限额试用网关（OpenAI-compatible）

目的：给“OpenClaw 小白中文包”提供 **可控、可持续** 的免费试用额度。

基本思路：
- 用户拿到一个 `TRIAL_KEY`（我们发）
- OpenClaw 端把 provider `baseUrl` 指向本网关
- 网关转发到 DeepSeek 官方 API（后端持有赞助者的 `DEEPSEEK_API_KEY`）
- 网关对每个 `TRIAL_KEY` 做最小限额（v0：按日请求数）

## 安全边界
- 不做任何隐蔽/绕行/“翻墙入口”；就是普通 HTTP(S) 服务。
- 不收集多余隐私：v0 仅做 **按日请求次数** 计数（内存 Map）。
- 生产版（v1）再引入：SQLite 持久化 + admin 管理 API + 更细用量统计。

## 暴露端口 / HTTPS 建议
`compose.yaml` 默认将服务端口绑定到本机回环：`127.0.0.1:8787:8787`。

- 推荐做法：用 Caddy/Nginx 反代到 `http://127.0.0.1:8787` 并启用 HTTPS。
- 不建议直接把 8787 端口对公网暴露（除非你额外做了鉴权/防火墙/限流等）。

## v0 功能现状（已可跑）
实现文件：`server.js`

提供：
- `GET /healthz` → `{ ok: true }`
- `GET /v1/models` → 最小模型列表（`deepseek-chat` / `deepseek-reasoner`）
- `POST /v1/chat/completions` → OpenAI-compatible 转发到 DeepSeek，并做简单配额：
  - `Authorization: Bearer <TRIAL_KEY>`（或 `x-trial-key`）
  - `DAILY_REQ_LIMIT`（默认 200）超限返回 429

环境变量：
- 必填：`DEEPSEEK_API_KEY`
- 可选：`PORT`（默认 8787）、`DEEPSEEK_BASE_URL`（默认 `https://api.deepseek.com/v1`）、`DAILY_REQ_LIMIT`

## 本地运行（开发）
```bash
cd quota-proxy
npm i
DEEPSEEK_API_KEY=*** PORT=8787 node server.js
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
EOF

# 2) 启动
docker compose up -d --build

# 3) 验证
docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```

## 下一步（v1 / 中等落地）
- SQLite 持久化（trial key、按日用量、审计日志最小字段）
- `POST /admin/keys`：生成 trial key（`ADMIN_TOKEN` 保护）
- `GET /admin/usage`：查询用量（`ADMIN_TOKEN` 保护）
