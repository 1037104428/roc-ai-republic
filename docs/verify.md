# 验收 / 验证清单（小白可复制）

> 目标：任何时候都能用最少的命令，确认“官网 / 下载脚本 / API 网关 / quota-proxy 现网”是否健康。

## 0) 本地仓库（文档/脚本是否一致）

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic

git status

git log -n 5 --oneline
```

## 1) 官网（Landing Page）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/ >/dev/null && echo 'site: OK'
```

### 1.1) 官网（Downloads 页面）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/downloads.html >/dev/null && echo 'downloads: OK'
```

### 1.2) 官网（quota-proxy 说明页）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/quota-proxy.html | grep -q 'CLAWD_TRIAL_KEY' && echo 'quota-proxy page: OK'
```

## 2) API 网关（/healthz）

```bash
curl -fsS -m 8 https://api.clawdrepublic.cn/healthz && echo
```

## 3) 国内一键安装脚本（install-cn.sh 可达 + 语法）

```bash
curl -fsS -m 8 https://clawdrepublic.cn/install-cn.sh >/tmp/install-cn.sh
bash -n /tmp/install-cn.sh && echo 'install-cn.sh: syntax OK'
```

可选：只跑自检（不安装）

```bash
bash /tmp/install-cn.sh -- --dry-run
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
