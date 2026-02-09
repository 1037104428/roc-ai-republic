# roc-project-push-loop（项目推进 cron）

> 目标：低噪音、持续落地。每 3 分钟 tick；滚动窗口每 15 分钟至少 1 个可验证落地物（commit / 可 healthz 的部署变化 / 文档 push / 新脚本可运行）。

## “可验证落地物”判定（便于自检）

满足任一即可（建议**同时写入可复制的 verify 命令**，方便回看）：

1) 仓库：有新 commit（已 push）。
   - verify：`cd /home/kai/.openclaw/workspace/roc-ai-republic && git show --name-only --oneline <COMMIT>`
2) 服务器：部署状态变化且可探活（healthz OK）。
   - verify：`ssh root@$(sed -n 's/^ip://p' /tmp/server.txt) 'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'`
3) 文档：新增/更新文档且已 push（同 1）。
4) 脚本：新增/更新脚本并可运行（至少 `bash -n` 或 `--help/--dry-run` 能通过）。

> 经验：本项目的“落地”更看重**可复验**而不是字数；宁可小，也要能一条命令确认。

## 本地检查清单（单次 tick）

### 一键自检（推荐）

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/check-artifact-window.sh --minutes 15
```

### 手动检查

```bash
# 时间戳（Asia/Shanghai）
TZ=Asia/Shanghai date -Iseconds

# 仓库最近提交
cd /home/kai/.openclaw/workspace/roc-ai-republic
git log -n 10 --date=iso --pretty=format:'%h %ad %s'

# 服务器目标（root 主机 ip/域名）
cat /tmp/server.txt

# 约定：/tmp/server.txt 格式
# - 建议仅一行：ip:<HOST>
# - 允许前后空格
# - <HOST> 可以是 IP 或可解析域名
# 示例：
#   ip:8.210.185.194
#
# 安全提示：不要把密码之类的内容放进 /tmp/server.txt。
# 如果历史上混入过其它行，可先运行（会原地清理，仅保留 ip 行，并 chmod 600）：
#   cd /home/kai/.openclaw/workspace/roc-ai-republic
#   ./scripts/sanitize-server-txt.sh /tmp/server.txt
```

## 服务器探活（quota-proxy）

```bash
SERVER=$(sed -n 's/^ip://p' /tmp/server.txt | tr -d ' \t\r\n')
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER" \
  'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'
```

> 预期：`docker compose ps` 里 quota-proxy 为 Up；healthz 返回 `{"ok":true}`。

## API 探活（网关 / OpenAI 兼容）

```bash
# 默认探测公开网关；也可 BASE_URL 指向自建地址
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe-roc-api.sh

# 或者手动：
BASE_URL=https://api.clawdrepublic.cn
curl -fsS "${BASE_URL}/healthz"
curl -fsS "${BASE_URL}/v1/models" | head
```

## 进度周报追加（最后落地要可复验）

周报文件：`/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md`

建议每条记录至少包含：
- commit id（或服务器变更说明）
- 一条可复制的验证命令（git show / curl / ssh compose ps 等）

### 推荐追加方式（避免 printf: invalid option）

> 一些 cron/脚本环境里，写入的文本如果以 `-` 开头，直接 `printf` 可能会报：`printf: invalid option`。
> 建议统一用仓库内脚本追加周报。

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic

./scripts/append-progress-log.sh \
  --file '/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md' \
  --text "[$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z')] 小落地：<一句话总结>。commit=<COMMIT>; verify=cd /home/kai/.openclaw/workspace/roc-ai-republic && git show --name-only --oneline <COMMIT>"
```

参考：`docs/verify.md` 里的“安全追加周报记录”脚本用法。
