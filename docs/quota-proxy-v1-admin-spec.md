# quota-proxy v0.1（当前实现）：JSON 持久化 + Admin 管理接口

> 目的：把“试用网关”的 **发 key / 查用量** 做成可运营、可验证的最小闭环。
>
> 说明：历史文件名里写的是 v1/SQLite，但**当前线上实现为 v0.1：用 JSON 文件持久化**（环境变量仍沿用 `SQLITE_PATH` 这个名字，后续再切真正 SQLite 不破坏配置）。

## 运营发放流程（当前：人工发放）

- 用户在论坛发帖申请（说明用途/频率）。
- 管理员在服务器本机用 `POST /admin/keys` 生成一个 `trial_...` key。
- 将该 key 私信/回复给用户，并提示：
  - 用 `Authorization: Bearer trial_...` 调用 `https://api.clawdrepublic.cn/v1/chat/completions`
  - 可用 `https://api.clawdrepublic.cn/healthz` 做非消耗型健康检查

（官网版说明页：`web/site/quota-proxy.html`）

管理员在**服务器本机**执行示例（推荐用 SSH 登录后 curl 本机 127.0.0.1）：

```bash
ssh -o BatchMode=yes -o ConnectTimeout=8 root@<server_ip> \
  'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'
```

## 给新人的官网入口（TRIAL_KEY + 最小 curl 验证）

- 官网页面：`https://clawdrepublic.cn/quota-proxy.html`（源文件：`web/site/quota-proxy.html`）
- 建议新人优先走小白一条龙：`https://clawdrepublic.cn/quickstart.html`

约定：对外文档统一用环境变量名 `CLAWD_TRIAL_KEY`（等价于 OpenAI 生态常用的 `OPENAI_API_KEY`）。


### label 推荐格式（便于运营统计）

建议把 `label` 当作“发放备注”，采用可 grep 的半结构化格式，例如：

- `forum:<username>`（来源用户）
- `purpose:<short>`（用途）
- `expires:<YYYY-MM-DD>`（到期日，可选）

示例：`forum:alice purpose:demo expires:2026-03-01`

## 配置约定（环境变量）

- `DEEPSEEK_API_KEY`：上游 DeepSeek key（必填）。
- `DEEPSEEK_BASE_URL`：上游 base url（默认 `https://api.deepseek.com/v1`）。
- `DAILY_REQ_LIMIT`：每个 TRIAL_KEY 的每日请求次数上限（默认 `200`）。

- `ADMIN_TOKEN`：管理接口鉴权 token。
  - 建议用 `openssl rand -hex 32` 生成，并仅在服务器侧保存（不要写进仓库）。
  - 鉴权请求头（对外文档统一）：`Authorization: Bearer $ADMIN_TOKEN`
  - 备注：如代码里还兼容 `x-admin-token`，仅作为内部/过渡用法；对外不要宣传，避免与常见网关/反代的 header 规则冲突。

- `SQLITE_PATH`：**持久化文件路径**（当前实现为 JSON 文件）。
  - 例如：`/data/quota-proxy.json`
  - compose 里建议挂载：`./data:/data`

## 安全与暴露面（强烈建议）

- **管理接口永远不要直出公网**：保持 8787 仅监听 `127.0.0.1`，通过 SSH 登录到服务器本机执行 `curl`（或用反代做 HTTPS + 额外访问控制）。
- `ADMIN_TOKEN` 一旦泄露应立即轮换；必要时重发 key（或在未来版本增加禁用/吊销机制）。

## 数据模型（当前 v0.1）

- `keys`：
  - `trialKey -> { label, created_at }`
- `usage`：
  - `day -> { trialKey -> { requests, updated_at } }`

时间戳：`created_at/updated_at` **都是毫秒**（`Date.now()`）。

## 计数语义（很重要，关系到运营解释）

- `req_count` 统计的是对 `POST /v1/chat/completions` 的**请求次数**。
- 计数发生在：
  1) 已提供 TRIAL_KEY 且（在开启持久化时）key 已被签发
  2) **在转发上游之前**
  3) **在限额判断之前**
- 因此：
  - 上游失败（例如 5xx/超时）也会计入次数。
  - 超过上限后返回 429 的那次请求也会计入次数（因为先 +1 再判断）。

> 这套语义的好处是实现简单、能反映“网关承受的请求压力”。
> 如需“只统计成功请求”或“区分成功/失败”，后续可扩展字段（如 `success_count`/`error_count`）。

---

## Admin API（当前实现）

### 1) 生成 trial key

`POST /admin/keys`

- 鉴权：必须携带 `ADMIN_TOKEN`
- 前置：必须开启持久化（设置 `SQLITE_PATH`），否则返回 400
- body：

```json
{ "label": "optional" }
```

- response：

```json
{ "key": "trial_<hex>", "label": "...", "created_at": 1700000000000 }
```

### 2) 查询用量（推荐：按天）

`GET /admin/usage?day=YYYY-MM-DD&key=<optional>`

- 鉴权：必须携带 `ADMIN_TOKEN`
- 说明：
  - `day`：推荐必填（稳定、可报表化）
  - `key`：可选，只看某个 key

- response：

```json
{
  "day": "2026-02-08",
  "mode": "file",
  "items": [
    { "key": "trial_xxx", "label": "forum:alice purpose:demo", "req_count": 12, "updated_at": 1700000000000 }
  ]
}
```

- 字段说明：
  - `day`：查询日期（`YYYY-MM-DD`）
  - `mode`：
    - `file`：已开启 `SQLITE_PATH`（JSON 文件持久化）
    - `memory`：纯内存（不推荐生产）
  - `items[]`：用量条目列表（默认按 `updated_at` 倒序）
    - `key`：trial key（外部展示建议脱敏，例如 `trial_abcd…wxyz`）
    - `label`：签发时写入的备注（建议用“label 推荐格式”）
    - `req_count`：当天累计请求次数（见“计数语义”）
    - `updated_at`：最后一次更新用量的时间戳（毫秒）

### 3) 查询最近用量（兼容/运维排查用）

`GET /admin/usage?limit=50`

- 不带 `day` 时，返回跨天的最近记录（每条通常包含 `day`）。
- 仅用于快速排查，不建议作为正式运营查询方式。

返回示例：

```json
{
  "mode": "file",
  "items": [
    { "day": "2026-02-08", "key": "trial_xxx", "label": "forum:alice purpose:demo", "req_count": 12, "updated_at": 1700000000000 }
  ]
}
```

---

## 验收/验证命令

更完整的“可复制粘贴验收清单”见：`docs/quota-proxy-v1-admin-acceptance.md`。

```bash
# 0) 基础健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 1) 生成 key
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'

# 2) 查询今日用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 快速测试脚本

仓库中提供了测试脚本，方便快速验证 quota-proxy 功能：

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 基本健康检查
./scripts/verify-quota-proxy.sh http://127.0.0.1:8787

# 服务状态检查（推荐日常使用）
./scripts/check-quota-status.sh --url http://127.0.0.1:8787

# Admin API 测试（需要 ADMIN_TOKEN）
export ADMIN_TOKEN="your_admin_token_here"
./scripts/test-quota-proxy-admin.sh http://127.0.0.1:8787 "$ADMIN_TOKEN"

# Admin API 增强测试（v2 - 持久化验证）
./scripts/test-quota-proxy-admin-v2.sh http://127.0.0.1:8787 "$ADMIN_TOKEN"

# 远程服务器测试（通过 SSH）
./scripts/ssh-run-roc-key.sh 'cd /opt/roc/quota-proxy && curl -fsS http://127.0.0.1:8787/healthz'
```

### 测试脚本说明

#### 1. `check-quota-status.sh` - 服务状态检查（推荐日常使用）
快速查看 quota-proxy 服务状态、持久化模式和基本统计：
```bash
# 基础状态检查
./scripts/check-quota-status.sh --url http://127.0.0.1:8787

# 带管理员令牌的详细检查
./scripts/check-quota-status.sh --url http://127.0.0.1:8787 --admin-token your_admin_token_here

# 显示详细信息
./scripts/check-quota-status.sh --url http://127.0.0.1:8787 --admin-token your_admin_token_here --details
```
输出包括：
- 健康状态检查
- 持久化配置分析
- 管理接口验证（如果提供令牌）
- 今日用量统计
- 服务状态总结和建议

#### 2. `check-current-persistence.sh` - 持久化模式检查
检查当前 quota-proxy 的实际持久化模式（JSON/SQLite/内存）：
```bash
./scripts/check-current-persistence.sh http://127.0.0.1:8787
```
输出包括：
- 服务健康状态
- 持久化配置提示
- 本地数据文件检查
- 环境变量分析
- 当前实现说明（JSON v0.1）

#### 2. `test-quota-proxy-admin.sh` - 基础测试
检查：
1. 健康状态 (`/healthz`)
2. 未授权访问保护 (`/admin/usage` 返回 401)
3. 授权访问 (`/admin/usage` 带 token)
4. Trial key 生成 (`POST /admin/keys`)

#### 2. `test-quota-proxy-admin-v2.sh` - 增强持久化验证
新增功能：
1. 持久化模式检测（`file`/`memory`）
2. Trial key 持久化验证
3. 使用统计查询（按key过滤）
4. 跨日查询验证
5. 批量查询测试
6. 工具依赖检查（jq, curl）

#### 使用建议
- 开发/测试环境：使用 `test-quota-proxy-admin.sh` 快速验证
- 生产环境部署验证：使用 `test-quota-proxy-admin-v2.sh` 进行全面持久化验证
- 定期巡检：结合 cron 任务定期运行验证脚本

对于生产环境，建议定期运行验证脚本确保服务正常。

### 3. `check-quota-persistence.sh` - 持久化状态快速检查
新增功能：
1. 服务健康检查
2. 持久化模式检测（JSON文件/SQLite/内存模式）
3. 环境变量提示
4. 验证脚本可用性检查

```bash
# 快速检查持久化状态
./scripts/check-quota-persistence.sh http://127.0.0.1:8787

# 带 ADMIN_TOKEN 的详细检查（可选）
export ADMIN_TOKEN="your_admin_token_here"
./scripts/check-quota-persistence.sh http://127.0.0.1:8787
```

#### 使用场景
- 部署后快速验证：确认服务状态和持久化模式
- 故障排查：快速检查基础配置
- 新人上手：了解当前环境配置

### 4. `quick-gen-trial-key.sh` - 快速生成 trial key
新增功能：
1. 一键生成 trial key
2. 自动检查服务健康状态
3. 输出可直接使用的环境变量命令
4. 详细的错误提示

```bash
# 快速生成 trial key（需要 ADMIN_TOKEN）
./scripts/quick-gen-trial-key.sh http://127.0.0.1:8787 your_admin_token_here

# 指定有效期（默认7天）
DAYS=30 ./scripts/quick-gen-trial-key.sh http://127.0.0.1:8787 your_admin_token_here
```

#### 使用场景
- 管理员快速发放试用 key
- 自动化脚本集成
- 新人快速获取测试 key

#### 输出示例
```
正在生成 trial key...
目标: http://127.0.0.1:8787
有效期: 7 天

✅ 成功生成 trial key:

export CLAWD_TRIAL_KEY="trial_abc123def456..."

使用方式:
  export CLAWD_TRIAL_KEY="trial_abc123def456..."
  openclaw --trial-key "${CLAWD_TRIAL_KEY}"

或直接使用:
  openclaw --trial-key "trial_abc123def456..."

提示:
  - 此 key 有效期为 7 天
  - 查看使用情况: curl -sS "http://127.0.0.1:8787/admin/usage" -H "Authorization: Bearer your_admin_token_here" | jq .
```

### 5. `verify-sqlite-persistence.sh` - SQLite持久化验证
新增功能：
1. 健康端点检查
2. 持久化配置验证
3. SQLite文件状态检查
4. Admin API集成测试（可选）
5. 详细的下一步建议

```bash
# 基础验证（仅检查健康状态和配置）
./scripts/verify-sqlite-persistence.sh http://127.0.0.1:8787

# 完整验证（需要 ADMIN_TOKEN）
export ADMIN_TOKEN="your_admin_token_here"
./scripts/verify-sqlite-persistence.sh http://127.0.0.1:8787
```

#### 使用场景
- 部署后验证：确认SQLite持久化配置正确
- 故障排查：检查持久化相关的问题
- 运维巡检：定期验证持久化功能
- 新人培训：了解持久化验证流程

#### 输出示例
```
🔍 Verifying SQLite persistence for quota-proxy at http://127.0.0.1:8787

1. Checking health endpoint...
✅ Health check passed

2. Checking persistence configuration...
   ADMIN_TOKEN is set (length: 64)

3. SQLite persistence status:
   SQLITE_PATH: /data/quota.sqlite
   Note: Run on server to check file existence:
     docker exec -it $(docker ps -q -f name=quota-proxy) ls -la $SQLITE_PATH 2>/dev/null || echo 'File not found'

4. Testing admin API with persistence...
   Generating test key: test-verify-1700000000
✅ Test key created
   Checking usage...
✅ Usage query works

📋 Summary:
   - Health endpoint: ✅ OK
   - Persistence config: SQLITE_PATH=/data/quota.sqlite
   - Admin API: ✅ Token available

💡 Next steps:
   1. Set ADMIN_TOKEN environment variable for full verification
   2. On server, check SQLite file: docker exec -it $(docker ps -q -f name=quota-proxy) sqlite3 $SQLITE_PATH '.tables'
   3. Verify data persists across container restarts
```

#### 验证要点
1. **健康检查**：确保服务正常运行
2. **配置验证**：检查SQLITE_PATH等环境变量
3. **文件状态**：验证SQLite文件存在且可访问
4. **功能测试**：通过Admin API验证持久化功能
5. **运维建议**：提供具体的下一步操作建议

此脚本特别适合在生产环境中验证持久化配置，确保数据不会因容器重启而丢失。

### 6. `check-persistence-type.sh` - 持久化类型检查
新增功能：
1. 健康状态检查
2. 持久化文件类型分析（JSON/SQLite/内存）
3. 管理接口验证（可选）
4. 版本说明和迁移建议

```bash
# 基础检查
./scripts/check-persistence-type.sh --url http://127.0.0.1:8787

# 带管理员令牌的完整检查
./scripts/check-persistence-type.sh --url http://127.0.0.1:8787 --admin-token your_admin_token_here
```

#### 使用场景
- **版本确认**：明确当前是 v0.1（JSON文件持久化）还是 v1.0（SQLite持久化）
- **配置验证**：检查环境变量和文件命名约定
- **迁移准备**：了解当前实现，为升级到 SQLite 做准备
- **新人培训**：理解 quota-proxy 的持久化架构

#### 关键说明
- **v0.1 实现**：使用 JSON 文件持久化，但环境变量和文件名沿用 SQLite 命名（如 `SQLITE_PATH`、`quota.sqlite`）
- **文件约定**：`.sqlite` 扩展名但实际存储 JSON 格式
- **迁移计划**：未来升级到真正的 SQLite 数据库时，配置保持不变

#### 输出示例
```
🔍 检查 quota-proxy 持久化类型
目标地址: http://127.0.0.1:8787

1. 检查健康状态...
   ✅ 健康检查通过

2. 检查环境信息...
   ✅ 基础健康接口正常

3. 持久化配置分析...
   ℹ️  当前实现说明：
   - 环境变量 SQLITE_PATH 指向持久化文件路径
   - 文件扩展名可能是 .sqlite 但实际内容是 JSON 格式
   - 这是 v0.1 实现（JSON文件持久化）
   - 未来 v1.0 将迁移到真正的 SQLite 数据库

4. 验证管理接口...
   ✅ 管理接口访问正常
   ✅ Key生成功能正常
   ℹ️  测试key前缀: trial_abc123def456...

📋 持久化类型总结:
   🔸 当前版本: v0.1 (JSON文件持久化)
   🔸 文件约定: 使用 .sqlite 扩展名但存储JSON格式
   🔸 迁移计划: 未来升级到真正的 SQLite 数据库

💡 建议:
   1. 保持当前配置不变（兼容现有部署）
   2. 文档中明确说明 v0.1 使用 JSON 文件持久化
   3. 升级到 v1.0 时只需替换 server.js，配置保持不变

✅ 检查完成
```

#### 为什么需要这个脚本？
1. **避免混淆**：明确区分 v0.1（JSON）和 v1.0（SQLite）
2. **运维透明**：管理员清楚知道实际持久化类型
3. **平滑升级**：为未来迁移到 SQLite 做好准备
4. **问题排查**：快速识别持久化相关的问题

使用此脚本可以确保团队对 quota-proxy 的持久化实现有清晰一致的理解。
