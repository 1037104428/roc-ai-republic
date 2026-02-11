# quota-proxy：DeepSeek 限额试用网关（OpenAI-compatible）

**快速开始**：[QUICKSTART.md](./QUICKSTART.md) - 5分钟快速部署指南

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
- `GET /status` → 公开服务状态信息（无需认证）
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
v1（SQLite）实现提供了 HTTP DELETE 接口来撤销 key：

```bash
# 删除指定的 trial key（会级联删除 daily_usage 记录）
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

**安全建议**：
1. 操作前建议先备份数据库
2. 删除操作不可逆（会同时删除用量记录）
3. 建议在管理界面中集成二次确认

手动数据库操作（备选方案）：
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

## 一键验证命令

为了方便快速测试 quota-proxy 的基本功能，可以使用以下一键验证命令：

### 基础功能验证（无需管理员权限）
```bash
# 1. 健康检查 - 验证服务是否运行
curl -fsS http://127.0.0.1:8787/healthz && echo "✅ 健康检查通过"

# 2. 状态检查 - 查看服务状态信息
curl -fsS http://127.0.0.1:8787/status | jq . || curl -fsS http://127.0.0.1:8787/status

# 3. 模型列表 - 验证API端点可用性（需要有效的TRIAL_KEY）
curl -fsS http://127.0.0.1:8787/v1/models \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY:-your_trial_key_here}" \
  && echo "✅ 模型列表API正常"

# 4. 聊天测试 - 验证完整请求流程
curl -fsS http://127.0.0.1:8787/v1/chat/completions \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY:-your_trial_key_here}" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"你好，请回复'ping'确认连接正常。"}],"max_tokens":10}' \
  && echo "✅ 聊天API正常"
```

### Docker Compose环境一键验证
```bash
# 在quota-proxy目录下运行
cd /opt/roc/quota-proxy

# 一键验证脚本
cat > quick-verify.sh << 'EOF'
#!/bin/bash
set -e

echo "🔍 开始quota-proxy快速验证..."

# 检查服务状态
echo "1. 检查Docker Compose服务状态..."
docker compose ps

# 健康检查
echo "2. 健康检查..."
curl -fsS http://127.0.0.1:8787/healthz && echo "✅ 健康检查通过"

# 状态检查
echo "3. 服务状态..."
curl -fsS http://127.0.0.1:8787/status | jq -r '.mode' || curl -fsS http://127.0.0.1:8787/status

# 检查日志
echo "4. 查看最近日志..."
docker compose logs --tail=5

echo "✅ 快速验证完成！"
EOF

chmod +x quick-verify.sh
./quick-verify.sh
```

### 管理员功能快速验证
```bash
# 一键管理员验证脚本
cat > admin-quick-verify.sh << 'EOF'
#!/bin/bash
set -e

ADMIN_TOKEN="${ADMIN_TOKEN:-your_admin_token}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"

echo "🔐 开始管理员功能快速验证..."

# 1. 创建测试密钥
echo "1. 创建测试密钥..."
KEY_RESPONSE=$(curl -fsS -X POST "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"label":"quick-verify-test"}')
  
TRIAL_KEY=$(echo "$KEY_RESPONSE" | jq -r '.key')
echo "✅ 创建密钥: ${TRIAL_KEY:0:10}..."

# 2. 列出所有密钥
echo "2. 列出所有密钥..."
curl -fsS "${BASE_URL}/admin/keys" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '. | length' && echo "✅ 密钥列表正常"

# 3. 查询今日用量
echo "3. 查询今日用量..."
curl -fsS "${BASE_URL}/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq '.items | length' && echo "✅ 用量查询正常"

# 4. 清理测试密钥
echo "4. 清理测试密钥..."
curl -fsS -X DELETE "${BASE_URL}/admin/keys/${TRIAL_KEY}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" && echo "✅ 密钥清理完成"

echo "✅ 管理员功能验证完成！"
EOF

chmod +x admin-quick-verify.sh
ADMIN_TOKEN=your_token ./admin-quick-verify.sh
```

## 验证脚本

我们提供了多个验证脚本来测试 quota-proxy 功能：

### 快速验证（管理员日常用）
```bash
# 快速验证管理接口可用性
./scripts/verify-admin-api-quick.sh --help

# 本地验证
./scripts/verify-admin-api-quick.sh --host 127.0.0.1:8787 --token $ADMIN_TOKEN

# 远程验证（通过 SSH）
./scripts/verify-admin-api-quick.sh --remote --token $ADMIN_TOKEN
```

### 完整 SQLite 持久化验证
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

## JSON 结构化日志中间件

quota-proxy 提供了 JSON 结构化日志中间件，支持生产环境下的结构化日志输出。

### 功能特性
- **结构化 JSON 输出**：所有日志以 JSON 格式输出，便于日志收集和分析
- **请求追踪**：自动记录 HTTP 请求的详细信息（方法、URL、状态码、响应时间等）
- **多日志级别**：支持 INFO、ERROR、WARN 等日志级别
- **服务标识**：自动包含服务名称和进程 ID
- **请求 ID**：可选生成请求 ID 用于请求追踪

### 使用方法

```javascript
// 在服务器文件中引入 JSON 日志中间件
const { createJsonLogger } = require('./middleware/json-logger.js');

// 创建日志中间件
const jsonLogger = createJsonLogger({
    serviceName: 'quota-proxy',
    includeRequestId: true,
    logLevel: 'info'
});

// 在 Express 应用中使用
app.use(jsonLogger);
```

### 验证脚本

```bash
# 验证 JSON 日志中间件
chmod +x verify-json-logger.sh
./verify-json-logger.sh
```

验证脚本会测试：
1. JSON 日志中间件文件检查
2. 服务器集成检查
3. JSON 格式验证
4. 使用文档检查

### 日志格式示例

```json
{"timestamp":"2026-02-11T12:15:00.000Z","level":"INFO","message":"HTTP Request Completed","method":"GET","url":"/healthz","statusCode":200,"duration":"15ms","userAgent":"curl/7.68.0","ip":"127.0.0.1","pid":12345,"service":"quota-proxy","requestId":"req-1707653700000-abc123def"}
```

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

## 管理界面验证脚本

我们提供了多个验证脚本来检查管理界面的完整功能：

### 1. Admin API 完整验证脚本
```bash
# 运行完整的Admin API验证
./verify-admin-api.sh
```

这个脚本会测试：
1. ✅ 创建试用密钥
2. ✅ 列出所有密钥
3. ✅ 查看使用情况统计
4. ✅ 测试密钥使用和配额消耗
5. ✅ 更新密钥标签
6. ✅ 删除密钥
7. ✅ 错误处理（无效令牌、缺少令牌）

### 2. Admin API 健康检查脚本
```bash
# 快速检查Admin API健康状态
./check-admin-health.sh

# 使用自定义token和URL
./check-admin-health.sh --token your-admin-token --url http://your-server:8787

# 查看帮助
./check-admin-health.sh --help
```

这个脚本提供：
1. ✅ 检查服务健康状态（/healthz端点）
2. ✅ 验证Admin API端点访问权限
3. ✅ 检查数据库文件状态
4. ✅ 显示当前密钥统计信息
5. ✅ 提供后续操作建议

### 3. 管理界面快速验证
```bash
# 查看帮助
./scripts/verify-quota-proxy-admin-ui.sh --help

# 本地验证（默认 127.0.0.1:8787）
./scripts/verify-quota-proxy-admin-ui.sh

# 远程服务器验证
QUOTA_PROXY_HOST=8.210.185.194 ./scripts/verify-quota-proxy-admin-ui.sh

# 带管理员令牌验证 API 端点
ADMIN_TOKEN=your_token ./scripts/verify-quota-proxy-admin-ui.sh
```

脚本会验证：
1. ✅ 健康检查端点 (`/healthz`)
2. ✅ 管理界面可访问性 (`/admin/`)
3. ✅ 密钥管理 API (`/admin/keys`) - 需要 ADMIN_TOKEN
4. ✅ 使用情况 API (`/admin/usage`) - 需要 ADMIN_TOKEN
5. ✅ 提供快速测试命令示例

这对于部署后的验收和日常运维检查非常有用。

## Admin API 性能检查脚本

`check-admin-performance.sh` 脚本用于快速检查 quota-proxy Admin API 的响应时间性能，提供性能基准报告。

### 功能特性

- **响应时间测量**: 测量关键 Admin API 端点的响应时间
- **性能评级**: 根据响应时间提供性能评级（优秀/良好/一般/较慢）
- **完整测试**: 测试所有关键 Admin API 端点
- **详细报告**: 提供详细的性能测试报告和建议

### 使用方法

```bash
# 基本用法
./check-admin-performance.sh

# 自定义配置
./check-admin-performance.sh --url http://localhost:8787 --token myadmin

# 使用环境变量
ADMIN_TOKEN=mysecret BASE_URL=http://192.168.1.100:8787 ./check-admin-performance.sh
```

### 测试端点

脚本会测试以下端点：
- `GET /admin/keys` - 密钥列表查询
- `GET /admin/usage` - 使用统计查询
- `POST /admin/keys` - 密钥创建
- `GET /healthz` - 健康检查

### 输出示例

```
[INFO] 开始Admin API性能检查
[INFO] 配置:
[INFO]   Base URL: http://127.0.0.1:8787
[INFO]   Timeout: 10s
[SUCCESS] 服务运行正常

[INFO] 开始性能测试...
----------------------------------------
[INFO] 测试: GET /admin/keys
[INFO]   端点: /admin/keys
[SUCCESS]   成功 (HTTP 200) - 响应时间: 45ms

[INFO] 测试: GET /admin/usage
[INFO]   端点: /admin/usage
[SUCCESS]   成功 (HTTP 200) - 响应时间: 52ms

[INFO] 测试: POST /admin/keys
[INFO]   端点: /admin/keys
[SUCCESS]   成功 (HTTP 201) - 响应时间: 78ms

[INFO] 测试: GET /healthz
[INFO]   端点: /healthz
[SUCCESS]   成功 (HTTP 200) - 响应时间: 12ms

----------------------------------------
[INFO] 性能测试完成
[SUCCESS] 平均响应时间: 46ms (优秀)
[SUCCESS] 成功测试数: 4/4

[INFO] 建议:
  - 响应时间良好，保持当前配置

[INFO] 脚本执行完成
```

### 性能评级标准

- **优秀**: < 100ms
- **良好**: 100-300ms
- **一般**: 300-500ms
- **较慢**: ≥ 500ms

### 依赖要求

- `curl` - HTTP 客户端
- `jq` - JSON 处理器（可选，用于更复杂的响应解析）

### 集成建议

1. **定期性能监控**: 将脚本加入 Cron 任务，定期检查 API 性能
2. **部署验证**: 在部署新版本后运行脚本验证性能
3. **容量规划**: 根据性能数据规划服务器资源
4. **告警配置**: 设置响应时间阈值告警

### 相关脚本

- `check-admin-health.sh` - 健康状态检查
- `verify-admin-api.sh` - 完整功能验证
- `quick-verify.sh` - 快速验证

