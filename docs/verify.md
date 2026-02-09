# 验收 / 验证清单（小白可复制）

> 目标：任何时候都能用最少的命令，确认“官网 / 下载脚本 / API 网关 / quota-proxy 现网 / 管理界面”是否健康。

## 0) 本地仓库（文档/脚本是否一致）

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic

git status

git log -n 5 --oneline
```

## 0.1) 一键探活（推荐）

> 适合运维/验收：一次跑完「官网 + API + 论坛 + 服务器 quota-proxy」。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe.sh
```

没有服务器 SSH 权限时（例如普通贡献者），可跳过 SSH 检查：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe.sh --no-ssh
```

（可选）查看帮助：

```bash
./scripts/probe.sh --help
```

（可选）自定义探活目标（例如换域名/服务器）：

```bash
WEB_URL=https://clawdrepublic.cn \
API_URL=https://api.clawdrepublic.cn \
SSH_HOST=root@<SERVER_IP> \
bash ./scripts/probe.sh
```

## 0.2) 核心服务一键验证

> 适合项目维护者：检查所有核心服务（quota-proxy、论坛、安装脚本、文档）的完整性。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-all-core-services.sh
```

远程服务器验证（需要 SSH 权限）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-all-core-services.sh --remote
```

验证内容包括：
1. **Quota-Proxy 服务** - Docker 容器状态、健康检查端点、数据库健康
2. **论坛服务** - 容器状态、内网访问
3. **安装脚本** - 语法检查、故障排除文档
4. **文档完整性** - 所有关键文档是否存在

输出示例：
```
=== 中华AI共和国核心服务验证 ===
时间: 2026-02-09 18:28:32 CST
模式: 本地验证

1. Quota-Proxy 服务验证
  ✓ 验证脚本: verify-quota-proxy.sh 存在
  ✓ 数据库验证脚本: verify-quota-db-health.sh 存在

2. 论坛服务验证
  ✓ 论坛验证脚本: verify-forum-access.sh 存在
  ✓ 论坛修复脚本: fix-forum-subdomain.sh 存在

3. 安装脚本验证
  ✓ 主安装脚本: install-cn.sh 语法正确
  ✓ 故障排除文档: install-cn-troubleshooting.md 存在

4. 文档完整性验证
  ✓ README.md: 存在
  ✓ docs/quickstart.md: 存在
  ✓ docs/admin-quick-keygen.md: 存在
  ✓ docs/verify.md: 存在
  ✓ docs/forum/status.md: 存在
```

## 1) 官网（Landing Page）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/ >/dev/null && echo 'site: OK'
```

## 2) 论坛（Forum）

### 2.1) 路径访问（/forum/）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/forum/ >/dev/null && echo 'forum (path): OK'
```

### 2.2) 子域名访问（forum.clawdrepublic.cn）

```bash
curl -fsS -m 8 https://forum.clawdrepublic.cn/ >/dev/null && echo 'forum (subdomain): OK'
```

如果子域名访问失败（502/SSL 错误），可使用论坛修复脚本：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-subdomain.sh --dry-run  # 预览将要执行的操作
# ./scripts/fix-forum-subdomain.sh          # 实际执行修复
```

验证论坛访问状态（包含子域名和路径）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-forum-access.sh
# JSON 输出格式（适合 CI/监控）：
./scripts/verify-forum-access.sh --json
```

### 1.1) 官网（Downloads 页面）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/downloads.html >/dev/null && echo 'downloads: OK'
```

### 1.2) 官网（论坛入口）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/forum/ | grep -q 'Clawd 国度论坛' && echo 'forum: OK'
```

### 1.3) 官网（quota-proxy 说明页）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/quota-proxy.html | grep -q 'CLAWD_TRIAL_KEY' && echo 'quota-proxy page: OK'
```

## 2) API 网关（/healthz）

```bash
curl -fsS -m 8 https://api.clawdrepublic.cn/healthz && echo
```

### 2.1) API 一键探活脚本（/healthz + /v1/models）

> 适合每次改完 quota-proxy 或网关配置后，做最小验收。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe-roc-api.sh
```

（可选）切换目标网关（例如自建域名 / 临时 IP）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
BASE_URL='https://api.clawdrepublic.cn' ./scripts/probe-roc-api.sh
```

期望输出（示例）：
- `/healthz` 返回 `{"ok":true}` 或 `ok` 字样
- `/v1/models` 返回 JSON，且包含至少 1 个 model id

## 3) 国内一键安装脚本（install-cn.sh 可达 + 语法）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/install-cn.sh >/tmp/install-cn.sh
bash -n /tmp/install-cn.sh && echo 'install-cn.sh: syntax OK'
```

可选：只跑自检（不安装）

```bash
bash /tmp/install-cn.sh -- --dry-run
```

可选：仓库内对安装脚本做一次自测（包含语法/自检段落等）

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-install-cn.sh --dry-run
```

### 3.1) 验证 OpenClaw CLI 是否已正确安装（不要求 gateway）

> 适合用户装完后第一时间自查：能否找到 `openclaw`、版本是多少、npm 全局 bin 是否在 PATH。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-openclaw-install.sh
```

## 4) quota-proxy（服务器本机 /healthz）

> 需要你能 SSH 到服务器 root（或具备等价权限）。

如果你在本机 OpenClaw 环境：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/ssh-run-roc-key.sh 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'
```

如果你在任意机器（不依赖仓库脚本）：

```bash
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'
```

### 4.1) quota-proxy 管理接口（发放试用 Key / 用量查询）

> 前提：你已在 quota-proxy 配置了 `ADMIN_TOKEN`（见《quota-proxy 管理接口规范》）。
>
> 推荐：优先用 **SSH 端口转发**验收（更安全，不需要把管理端口暴露到公网）。

#### 4.1.0) 方式一：SSH 端口转发（推荐）

先把服务器本机 `127.0.0.1:8787` 转发到你本机 `127.0.0.1:8788`：

```bash
ssh -N -T -o BatchMode=yes -o ConnectTimeout=8 -L 127.0.0.1:8788:127.0.0.1:8787 root@<SERVER_IP>
```

或直接用仓库脚本（会自动读 `/tmp/server.txt` 的 `ip:<HOST>`）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/ssh-portforward-quota-proxy-admin.sh
```

说明：
- 默认把服务器 `127.0.0.1:8787` 转发到你本机 `127.0.0.1:8788`；脚本会显式绑定到 `127.0.0.1`（避免误暴露到局域网）。
- 保持该命令运行不退出；结束时按 `Ctrl+C` 即可断开转发。

然后在**另一个终端**里跑管理接口（目标换成本机 `http://127.0.0.1:8788`）：

#### 4.1.1) 数据库健康检查（推荐先跑）

先确认 quota-proxy 数据库连接正常：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-quota-db-health.sh --remote
```

期望输出：包含 `"ok": true` 和数据库连接状态。

**新增：数据库健康检查脚本（更详细）**

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-db-health.sh --host http://127.0.0.1:8788

# 如果需要管理员统计（可选）
ADMIN_TOKEN='<ADMIN_TOKEN>' ./scripts/verify-db-health.sh --host http://127.0.0.1:8788 --admin-token "$ADMIN_TOKEN"
```

这个脚本会：
1. 检查 `/healthz/db` 端点（数据库健康）
2. 如果有管理员令牌，还会检查 `/admin/usage` 获取详细统计
3. 输出格式化的 JSON 结果

#### 4.1.2) 管理接口探活（确认 token 保护）

推荐：先跑一个“不会发 key”的安全探活脚本（确认管理接口确实被 token 保护）：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe-quota-proxy-admin.sh

#（可选）带上 token，验证 /admin/usage 可访问
CLAWD_ADMIN_TOKEN='<ADMIN_TOKEN>' ./scripts/probe-quota-proxy-admin.sh
```

然后再手动发放 key：

```bash
ADMIN_TOKEN='<ADMIN_TOKEN>'

# 发放 key
curl -fsS -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  http://127.0.0.1:8788/admin/keys \
  -d '{"days":7,"quota":100000,"label":"trial:ssh-forward"}'

echo

# 查用量
curl -fsS \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  'http://127.0.0.1:8788/admin/usage?limit=20'

echo
```

#### 4.1.1) 方式二：走公网 API 网关（方便但风险更高）

> 适合临时验收；请确保管理接口未被公网直接暴露到不受控网络。

（A）发放一个 TRIAL Key（返回 JSON；建议顺手带上 label 方便后续统计）

```bash
ADMIN_TOKEN='<ADMIN_TOKEN>'

curl -fsS -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  https://api.clawdrepublic.cn/admin/keys \
  -d '{"days":7,"quota":100000,"label":"trial:manual"}'

echo
```

（B）查看用量汇总（用于运营对账/排障）

```bash
ADMIN_TOKEN='<ADMIN_TOKEN>'

curl -fsS \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  'https://api.clawdrepublic.cn/admin/usage?limit=20'

echo
```

（C）禁用/吊销 Key、重置当日用量（规划中）

> 注意：截至本文档更新时，线上 quota-proxy 仅保证已实现并稳定的管理接口为：
> - `POST /admin/keys`（签发 trial key）
> - `GET /admin/usage`（查询用量）
>
> 若出现误发/泄露等情况，临时处理方式：
> 1) 重新签发新 key
> 2) 通知用户更换
> 3) 必要时轮换 `ADMIN_TOKEN`
>
> 后续若新增 `DELETE /admin/keys/:key`、`POST /admin/usage/reset` 等接口，会在《quota-proxy 管理接口规范》中更新，并同步补齐这里的验收命令。

## 5) 进度日志：安全追加一条记录（避免 printf 报错）

> 一些 cron/脚本环境里，如果要写入的文本以 `-` 开头，直接 `printf` 可能会报：`printf: invalid option`。
> 仓库提供了一个轻量封装脚本，建议统一用它向周报/进度文件追加记录。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 直接追加文本
./scripts/append-progress-log.sh \
  --file '/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md' \
  --text "note: 验收记录示例（commit=XXXXXXX; verify=见 docs/verify.md）"

# 或从 stdin 追加（适合多行）
cat <<'EOF' | ./scripts/append-progress-log.sh --stdin \
  --file '/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md'
- verify: BASE_URL=https://api.clawdrepublic.cn; curl -fsS "${BASE_URL}/healthz"
EOF

## 6) 论坛 502 修复验证

### 6.1) 论坛 502 修复脚本验证

```bash
# 检查修复脚本语法
cd /home/kai/.openclaw/workspace/roc-ai-republic
bash -n scripts/fix-forum-502.sh

# 查看修复脚本帮助
./scripts/fix-forum-502.sh --help

# 生成 Caddy 配置（预览）
./scripts/fix-forum-502.sh --caddy

# 生成 Nginx 配置（预览）
./scripts/fix-forum-502.sh --nginx

# 验证论坛是否可访问（本地检查）
./scripts/fix-forum-502.sh --verify
```

### 6.2) 论坛状态检查

```bash
# 检查论坛外网可访问性（期望 502 错误）
curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null && echo "论坛可访问" || echo "论坛502错误（预期）"

# 检查论坛内网服务是否运行（需要 SSH 访问）
ssh root@<SERVER_IP> 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "Flarum 内网服务正常" || echo "Flarum 内网服务异常"'

# 使用仓库脚本检查
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-502.sh --verify
```

## 7) 管理界面部署验证

### 7.1) 管理界面部署脚本验证

```bash
# 检查部署脚本语法
cd /home/kai/.openclaw/workspace/roc-ai-republic
bash -n scripts/deploy-admin-interface.sh

# 查看部署脚本帮助
./scripts/deploy-admin-interface.sh --help

# 模拟运行部署（不实际执行）
./scripts/deploy-admin-interface.sh --dry-run
```

### 6.2) 重建脚本验证

```bash
# 检查重建脚本语法
cd /home/kai/.openclaw/workspace/roc-ai-republic
bash -n scripts/rebuild-quota-proxy-with-admin.sh

# 查看重建脚本帮助
./scripts/rebuild-quota-proxy-with-admin.sh --help
```

### 6.3) 管理界面健康检查

```bash
# 检查管理界面健康端点（需要 ADMIN_TOKEN）
ADMIN_TOKEN='<ADMIN_TOKEN>'
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/health && echo 'admin health: OK'

# 检查管理界面页面（无需 token，但需要部署）
curl -fsS http://127.0.0.1:8787/admin && echo 'admin page: OK'
```
```

## 8) 管理 API 接口验证

### 8.1) 管理 API 测试脚本验证

```bash
# 测试管理 API 接口
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 检查测试脚本语法
bash -n scripts/test-admin-api.sh

# 查看测试脚本帮助
./scripts/test-admin-api.sh --help

# 测试本地管理接口（需要 ADMIN_TOKEN）
# 方式1：通过环境变量设置 ADMIN_TOKEN
export ADMIN_TOKEN="your_admin_token_here"
./scripts/test-admin-api.sh --local

# 方式2：通过参数传递 ADMIN_TOKEN
./scripts/test-admin-api.sh --local --token "your_admin_token_here"

# 测试远程服务器管理接口
./scripts/test-admin-api.sh --remote 8.210.185.194 --token "your_admin_token_here"

# 脚本会自动验证以下接口：
# 1. /admin/keys (POST) - 创建测试密钥（label: "test-admin-api-验证"）
# 2. /admin/keys (GET) - 列出所有密钥，确认新密钥存在
# 3. /admin/usage (GET) - 查看使用情况，确认新密钥用量为0
# 4. /admin/keys/{key} (DELETE) - 删除测试密钥，清理测试数据
```

### 8.2) 手动管理 API 接口验证

```bash
# 手动测试管理接口
ADMIN_TOKEN="your_admin_token_here"
BASE_URL="http://127.0.0.1:8787"

# 1. 创建试用密钥
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  -H "Content-Type: application/json" \n  -X POST "${BASE_URL}/admin/keys" \n  -d '{"label":"test-key"}'

# 2. 列出所有密钥
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  "${BASE_URL}/admin/keys"

# 3. 查看使用情况
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  "${BASE_URL}/admin/usage"

# 4. 删除密钥（替换 {key} 为实际密钥）
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  -X DELETE "${BASE_URL}/admin/keys/{key}"
```

## 9) SQLite 持久化完整功能验证

### 9.1) SQLite 完整功能测试脚本

```bash
# 完整验证 SQLite 持久化与管理接口的端到端测试
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 检查脚本语法
bash -n scripts/test-sqlite-full-cycle.sh

# 查看脚本帮助
./scripts/test-sqlite-full-cycle.sh --help

# 在服务器本机测试（推荐）
ADMIN_TOKEN="your_admin_token_here" ./scripts/test-sqlite-full-cycle.sh

# 远程测试（需确保 admin 接口可访问）
ADMIN_TOKEN="your_admin_token_here" ./scripts/test-sqlite-full-cycle.sh \
  --url http://your-server:8787 \
  --label "test-$(date +%Y%m%d-%H%M%S)"

# 脚本会自动验证以下完整流程：
# 1. 健康检查 (/healthz)
# 2. 模型列表 (/v1/models)
# 3. 创建测试 key (/admin/keys)
# 4. 查询 key 列表 (/admin/keys)
# 5. 查询用量 (/admin/usage)
# 6. 用量重置 (/admin/usage/reset)
# 7. 吊销 key (/admin/keys/:key)
# 8. 验证 key 吊销后不可用
# 9. SQLite 文件存在性检查（本地部署时）
```

### 9.2) SQLite 数据库文件验证

```bash
# 检查 SQLite 数据库文件（需要服务器 SSH 访问）
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && ls -la data/'

# 检查数据库文件大小
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && du -h data/quota.db'

# 检查数据库表结构（需要 sqlite3 命令）
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && sqlite3 data/quota.db ".tables"'

# 检查表结构详情
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && sqlite3 data/quota.db ".schema"'

### 9.3) 服务器端 SQLite 持久化验证脚本

```bash
# 使用专用脚本在服务器上验证 SQLite 持久化
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 检查脚本语法
bash -n scripts/verify-sqlite-persistence-on-server.sh

# 查看脚本帮助
./scripts/verify-sqlite-persistence-on-server.sh --help

# 基本验证（文本输出）
./scripts/verify-sqlite-persistence-on-server.sh

# JSON 格式输出（便于 cron/监控解析）
./scripts/verify-sqlite-persistence-on-server.sh --json

# 自定义服务器文件路径
SERVER_FILE=/path/to/server.txt ./scripts/verify-sqlite-persistence-on-server.sh

# 脚本验证项目：
# 1. SSH 连接性
# 2. quota-proxy 容器运行状态
# 3. SQLite 数据库文件存在性
# 4. 数据库文件可读写性
# 5. 健康检查端点 (/healthz)
# 6. 数据库表结构（如果 sqlite3 可用）
```

# 检查数据行数
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && sqlite3 data/quota.db "SELECT count(*) FROM keys;"'
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && sqlite3 data/quota.db "SELECT count(*) FROM usage;"'
```

### 9.3) SQLite 持久化验证要点

1. **重启后数据不丢失**：重启 quota-proxy 容器后，之前签发的 key 和用量记录应仍然存在
2. **并发安全**：多个请求同时访问时，SQLite 应能正确处理并发（通过事务）
3. **数据一致性**：用量统计应与实际请求匹配，无重复计数或漏计数
4. **管理接口完整性**：所有管理接口（keys/usage/reset/delete）都应正常工作
5. **性能可接受**：在预期负载下（如每日数百次请求），响应时间应在合理范围内

### 9.4) 快速验证 SQLite 持久化是否生效

```bash
# 1. 创建测试 key
ADMIN_TOKEN="your_token" KEY1=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:8787/admin/keys \
  -d '{"label":"persistence-test"}' | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

# 2. 重启 quota-proxy 容器
ssh root@<SERVER_IP> 'cd /opt/roc/quota-proxy && docker compose restart quota-proxy'

# 3. 等待容器启动（约5秒）
sleep 5

# 4. 验证 key 仍然存在且可用
curl -fsS -H "Authorization: Bearer $KEY1" http://127.0.0.1:8787/v1/models && echo "SQLite 持久化验证通过"

# 5. 清理测试 key
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  -X DELETE "http://127.0.0.1:8787/admin/keys/$KEY1"
```

## 10) TRIAL_KEY 生命周期自动化测试

### 10.1) TRIAL_KEY 生命周期测试脚本

```bash
# 自动化测试 TRIAL_KEY 的完整生命周期（创建 → 验证 → 重置 → 删除）
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 检查脚本语法
bash -n scripts/test-trial-key-lifecycle.sh

# 查看脚本帮助
./scripts/test-trial-key-lifecycle.sh --help

# 在服务器上测试（默认）
ADMIN_TOKEN="your_admin_token_here" ./scripts/test-trial-key-lifecycle.sh

# 本地模式测试（如果 quota-proxy 运行在 localhost:8787）
LOCAL_MODE=true ADMIN_TOKEN="your_admin_token_here" ./scripts/test-trial-key-lifecycle.sh

# 自定义服务器 IP
SERVER_IP="your.server.ip" ADMIN_TOKEN="your_admin_token_here" ./scripts/test-trial-key-lifecycle.sh

# 脚本会自动执行以下步骤：
# 1. 创建带唯一标签的测试 TRIAL_KEY
# 2. 验证 key 出现在 /admin/usage 中（标签匹配）
# 3. 尝试用 key 调用 /v1/models（验证 key 可用性）
# 4. 重置 key 用量（/admin/usage/reset）
# 5. 删除 key（/admin/keys/:key）
# 6. 验证 key 已从 /admin/usage 移除
# 7. 输出 SUCCESS 或失败原因
```

### 10.2) 测试脚本使用场景

1. **部署验证**：部署新的 quota-proxy 版本后，验证所有管理接口正常工作
2. **回归测试**：代码修改后，确保 TRIAL_KEY 生命周期功能不受影响
3. **运维巡检**：定期运行，确保 quota-proxy 服务健康
4. **贡献者验收**：新贡献者提交 PR 后，运行此脚本验证功能完整性

### 10.3) 手动验证 TRIAL_KEY 生命周期

```bash
# 手动验证 TRIAL_KEY 生命周期（分步执行）
ADMIN_TOKEN="your_admin_token_here"
BASE_URL="http://127.0.0.1:8787"
TEST_LABEL="test-$(date +%Y%m%d-%H%M%S)"

echo "测试标签: $TEST_LABEL"

# 1. 创建 TRIAL_KEY
echo "创建 TRIAL_KEY..."
RESPONSE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  -H "Content-Type: application/json" \n  -X POST "${BASE_URL}/admin/keys" \n  -d "{\"label\":\"$TEST_LABEL\"}")
TRIAL_KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
echo "创建的 key: $TRIAL_KEY"

# 2. 验证 key 在 /admin/usage 中
echo "验证 key 在 /admin/usage 中..."
USAGE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  "${BASE_URL}/admin/usage")
if echo "$USAGE" | grep -q "$TRIAL_KEY"; then
  echo "✓ Key 存在于 /admin/usage"
else
  echo "✗ Key 不存在于 /admin/usage"
  exit 1
fi

# 3. 测试 key 可用性
echo "测试 key 可用性..."
curl -fsS -H "Authorization: Bearer $TRIAL_KEY" \n  "${BASE_URL}/v1/models" >/dev/null 2>&1 && echo "✓ Key 可用" || echo "⚠ Key 可能无配额（正常）"

# 4. 重置用量
echo "重置用量..."
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  -H "Content-Type: application/json" \n  -X POST "${BASE_URL}/admin/usage/reset" \n  -d "{\"key\":\"$TRIAL_KEY\"}" && echo "✓ 用量重置成功"

# 5. 删除 key
echo "删除 key..."
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  -X DELETE "${BASE_URL}/admin/keys/$TRIAL_KEY" && echo "✓ Key 删除成功"

# 6. 验证 key 已移除
echo "验证 key 已移除..."
FINAL_USAGE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \n  "${BASE_URL}/admin/usage")
if echo "$FINAL_USAGE" | grep -q "$TRIAL_KEY"; then
  echo "✗ Key 仍然存在于 /admin/usage"
  exit 1
else
  echo "✓ Key 已从 /admin/usage 移除"
fi

echo "✅ TRIAL_KEY 生命周期验证完成"
```

## 快速服务器状态检查

对于日常运维和监控，可以使用快速状态检查脚本：

```bash
# 使用默认服务器
./scripts/quick-server-status.sh

# 指定服务器IP
SERVER_IP=你的服务器IP ./scripts/quick-server-status.sh
```

脚本检查内容：
1. SSH连接可用性
2. Docker容器运行状态
3. 健康检查端点 (http://127.0.0.1:8787/healthz)
4. SQLite数据库文件存在性

输出示例：
```
🔍 快速服务器状态检查 - 2026-02-09 16:20:52 CST
服务器: 8.210.185.194

1. SSH 连接测试...
   ✅ SSH 连接正常
2. Docker 容器状态...
   running quota-proxy-quota-proxy-1 (quota-proxy)
3. 健康检查端点...
   ✅ 健康检查通过
4. SQLite 数据库文件...
   -rw-r--r-- 1 root root 8192 Feb  9 14:30 quota.db

📊 状态摘要:
   - SSH连接: ✅
   - Docker容器: 运行中
   - 健康端点: ✅
   - SQLite持久化: 已配置
```

此脚本适合用于：
- 部署后的快速验证
- 日常监控检查
- CI/CD流水线中的健康检查
- 故障排查的第一步

## 9) 落地页部署验证

> 检查落地页（官网）部署状态，包括本地文件、服务器部署、Web服务器配置和域名可访问性。

### 9.1) 一键验证落地页

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-landing-page.sh
```

### 9.2) 详细验证选项

```bash
# 详细输出模式
./scripts/verify-landing-page.sh --verbose

# 仅检查本地文件（不连接服务器）
./scripts/verify-landing-page.sh --local-only

# 指定服务器配置文件
SERVER_FILE=/path/to/server.txt ./scripts/verify-landing-page.sh

# 指定域名
LANDING_DOMAIN=your-domain.com ./scripts/verify-landing-page.sh
```

### 9.3) 验证内容说明

脚本检查以下项目：

1. **本地文件结构**
   - Web目录 (`web/`, `web/site/`)
   - 配置文件 (`web/caddy/Caddyfile`, `web/nginx/nginx.conf`)

2. **服务器部署状态**
   - SSH连接
   - 远程Web目录 (`/opt/roc/web`)
   - 部署的文件完整性

3. **Web服务器配置**
   - Caddy/Nginx配置包含域名
   - Web服务器服务运行状态

4. **域名可访问性**
   - HTTP访问测试
   - HTTPS访问测试

5. **服务器本地访问**
   - 服务器本机HTTP访问测试

### 9.4) 手动验证命令

如果脚本失败，可以手动运行以下命令：

```bash
# 检查本地文件
ls -la web/site/
ls -la web/caddy/
ls -la web/nginx/

# 检查服务器文件
ssh root@8.210.185.194 "ls -la /opt/roc/web/"

# 检查Web服务器
ssh root@8.210.185.194 "systemctl status caddy || systemctl status nginx"

# 检查域名访问
curl -I http://clawdrepublic.cn/
curl -I https://clawdrepublic.cn/

# 检查服务器本地访问
ssh root@8.210.185.194 "curl -fsS http://localhost/"
```

### 9.5) 部署脚本

落地页部署使用 `deploy-landing-page.sh`:

```bash
# 部署落地页
./scripts/deploy-landing-page.sh

# 干运行（预览）
./scripts/deploy-landing-page.sh --dry-run
```

### 9.6) 相关文档

- [落地页部署验证详细说明](./verify-landing-page.md)
- [部署指南](./deploy-landing-page.md)
- [Web服务器配置](./web-server-config.md)
