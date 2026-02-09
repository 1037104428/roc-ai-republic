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

## 1) 官网（Landing Page）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/ >/dev/null && echo 'site: OK'
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
./scripts/test-admin-api.sh --local --token "$ADMIN_TOKEN"

# 测试远程管理接口
./scripts/test-admin-api.sh --remote 8.210.185.194 --token "$ADMIN_TOKEN"
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
