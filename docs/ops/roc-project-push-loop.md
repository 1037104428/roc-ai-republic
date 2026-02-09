# roc-project-push-loop（项目推进 cron）

> 目标：低噪音、持续落地。每 3 分钟 tick；滚动窗口每 15 分钟至少 1 个可验证落地物（commit / 可 healthz 的部署变化 / 文档 push / 新脚本可运行）。

## 本地检查清单（单次 tick）

```bash
# 时间戳（Asia/Shanghai）
TZ=Asia/Shanghai date -Iseconds

# 仓库最近提交
cd /home/kai/.openclaw/workspace/roc-ai-republic
git log -n 10 --date=iso --pretty=format:'%h %ad %s'

# 服务器目标（root 主机 ip/域名）
cat /tmp/server.txt
```

## 服务器探活（quota-proxy）

```bash
SERVER=$(sed -n 's/^ip://p' /tmp/server.txt | tr -d ' \t\r\n')
ssh -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER" \
  'cd /opt/roc/quota-proxy && docker compose ps && curl -fsS http://127.0.0.1:8787/healthz'
```

> 预期：`docker compose ps` 里 quota-proxy 为 Up；healthz 返回 `{"ok":true}`。

## 进度周报追加（最后落地要可复验）

周报文件：`/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md`

建议每条记录至少包含：
- commit id（或服务器变更说明）
- 一条可复制的验证命令（git show / curl / ssh compose ps 等）

参考：`docs/verify.md` 里的“安全追加周报记录”脚本用法。
