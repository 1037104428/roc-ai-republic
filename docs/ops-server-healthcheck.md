# 服务器巡检（quota-proxy）

本项目的推进循环（cron）会尝试巡检服务器上 quota-proxy 的部署状态。

## 目标

- 查看 compose 状态：`docker compose ps`（期望看到 `127.0.0.1:8787->8787/tcp` 或其它受控映射；避免 `0.0.0.0:8787` 误暴露）
- 检查健康探针：`curl -fsS http://127.0.0.1:8787/healthz`（期望输出：`{"ok":true}`）

## 前置条件（推荐）

为了让自动化脚本能在无人值守下运行，需要 **SSH 免密** 或在 runner 上提供可用的非交互式认证方式。

推荐做法：配置 **SSH Key 登录**（最安全、最稳定）。

> 临时兜底：如果你只有 root 密码、runner 上也没有 sudo 能力安装 sshpass，可以用本仓库提供的 `pexpect` 方式（见下文“密码模式（临时）”）。

### 1) 在运行 cron 的机器上生成 key（如已有可跳过）

```bash
ssh-keygen -t ed25519 -C roc-quota-proxy-healthcheck
```

### 2) 把公钥加到服务器

```bash
ssh-copy-id root@<server-ip>
# 或手动追加到 /root/.ssh/authorized_keys
```

### 3) 验证（必须能无交互登录）

```bash
ssh -o BatchMode=yes root@<server-ip> 'echo ok'
```

## 服务器地址来源

推进循环默认从本机的 `/tmp/server.txt` 读取服务器信息。

> 一键清理明文密码（只保留 ip: 行；也支持只有一行裸 IPv4；顺便 chmod 600）：
>
> ```bash
> cd roc-ai-republic
> ./scripts/sanitize-server-txt.sh
> ```


目前约定格式示例（最小）：

```text
ip:8.8.8.8
```

兼容格式（脚本会尽量解析并归一化为 `ip:x.x.x.x`）：

```text
ip=8.8.8.8
ip: 8.8.8.8
8.8.8.8
```

如果需要“密码模式（临时）”，可写成：

```text
ip:8.8.8.8
password:YOUR_PASSWORD
```

（注意：密码不应以明文方式长期保存；长期自动化建议使用 key。）

### 关于 /tmp/server.txt 的安全建议

- **不要把包含密码的 server.txt 加进仓库**（避免误 commit / 误 push）。
- 如必须用密码模式：优先用环境变量 `PASSWORD=...` 传入（不落盘）。
- 建议把 server 文件权限收紧：`chmod 600 /tmp/server.txt`。
- 如果你只需要 key 模式，`/tmp/server.txt` 里只保留 `ip:` 一行即可。

## 自动巡检脚本

### 方式 0：一键探活（官网 + API + 服务器 quota-proxy）

```bash
# pretty 输出（适合人读）
./scripts/probe-roc-all.sh

# JSON 单行输出（适合 cron/CI 收集）
./scripts/probe-roc-all.sh --json

# 字段与退出码
# - 输出字段：ts, home_ok, api_ok, install_ok, quota_page_ok, server_ok, all_ok
# - 退出码：全部 ok → 0；任意失败 → 2
#
# 示例：只在失败时告警
# ./scripts/probe-roc-all.sh --json || echo "probe failed"
#
# 示例：用 jq 取字段
# ./scripts/probe-roc-all.sh --json | jq -r '.all_ok'
```

### 方式 0.5：滚动窗口自检（15 分钟）

推进循环的硬性目标是：**每 15 分钟至少 1 个可验证落地物**。

仓库提供了一个“窗口自检”脚本：同时检查 repo 最近 commit、远端 quota-proxy（compose ps + /healthz）以及 API 网关探活，并支持 JSON 输出与严格退出码（适合 cron/CI）。

```bash
# 人类可读
./scripts/check-artifact-window.sh --minutes 15

# JSON（单行）+ 严格模式（任一项失败则 exit!=0）
./scripts/check-artifact-window.sh --minutes 15 --json --strict | python3 -m json.tool
```

### 方式 1：SSH Key（推荐）

```bash
# 需要能够无交互 ssh 登录
./scripts/check-server-quota-proxy.sh

# 更“傻瓜”的一键远端探活（读取 /tmp/server.txt；输出 compose ps + /healthz）
./scripts/ssh-healthz-quota-proxy.sh

# 只看 compose 状态（方便贴周报 / 只要 ps）
./scripts/ssh-compose-ps-quota-proxy.sh

# JSON 单行摘要（适合 cron/CI 收集）
./scripts/ssh-healthz-quota-proxy.sh --json | python3 -m json.tool

# 一键组合状态（healthz + compose + 端口暴露审计）
# - 默认：人类可读
# - --json：单行 JSON + 严格退出码（overall_ok=1 才 exit 0）
./scripts/ssh-quota-proxy-status.sh
./scripts/ssh-quota-proxy-status.sh --json | python3 -m json.tool

# 一键远端拉取日志（排障时用；默认 tail=200；也支持 --follow / --service）
./scripts/ssh-logs-quota-proxy.sh --since 10m
./scripts/ssh-logs-quota-proxy.sh --service quota-proxy --since 10m
./scripts/ssh-logs-quota-proxy.sh --follow --since 2m

# 可选：覆盖 server 文件路径/远端目录/用户
# SERVER_FILE=/tmp/server.txt REMOTE_DIR=/opt/roc/quota-proxy REMOTE_USER=root ./scripts/check-server-quota-proxy.sh

# 只想“用 /tmp/server.txt 跑一条远端命令”（key 模式）
./scripts/ssh-run-roc-key.sh "cd /opt/roc/quota-proxy && docker compose ps"
./scripts/ssh-run-roc-key.sh "curl -fsS http://127.0.0.1:8787/healthz"
```

### 方式 2：密码模式（临时，避免安装 sshpass）

适用场景：runner 上没有 sudo / 无法安装 sshpass，但你又确实只有密码。

1) `/tmp/server.txt`（示例）：

```text
ip:8.8.8.8
password:YOUR_PASSWORD
```

2) 运行：

```bash
./scripts/check-server-quota-proxy-password.py

# 推荐：用环境变量显式传密码（不会写文件）
PASSWORD='YOUR_PASSWORD' ./scripts/check-server-quota-proxy-password.py

# 可选：覆盖 server 文件路径/远端目录
# SERVER_FILE=/tmp/server.txt REMOTE_DIR=/opt/roc/quota-proxy ./scripts/check-server-quota-proxy-password.py
```

3) （可选）如果你只想“用 /tmp/server.txt 跑一条远端命令”，可以用轻量封装：

```bash
./scripts/ssh-run-server-txt.sh "cd /opt/roc/quota-proxy && docker compose ps"
./scripts/ssh-run-server-txt.sh "curl -fsS http://127.0.0.1:8787/healthz"
```

> 备注：本脚本依赖 Python 的 `pexpect`。
> - Debian/Ubuntu：`sudo apt-get update && sudo apt-get install -y python3-pexpect`
> - 或 pip：`python3 -m pip install --user pexpect`
>
> 首次连接某台新服务器时，ssh 可能会输出：
> `Warning: Permanently added 'x.x.x.x' (ED25519) to the list of known hosts.`
> 这通常是正常现象（写入 `~/.ssh/known_hosts`），但如果你对主机指纹有要求，应当提前校验指纹再接入。

## 安全提示（端口暴露）

当前 compose 可能会把 8787 端口映射到公网（`0.0.0.0:8787->8787`）。

- 如果你只需要本机自检：建议只绑定到 `127.0.0.1`，并在前面加反向代理（Caddy/Nginx）做 HTTPS 与访问控制。
- 如果要对外提供试用网关：务必在应用层加鉴权（例如后续的 `ADMIN_TOKEN`）并配合防火墙/限流。

## 手工巡检命令

### 在服务器上执行

```bash
cd /opt/roc/quota-proxy
docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```

### 从本机一条命令执行（需要 SSH Key）

```bash
ssh root@<server-ip> 'cd /opt/roc/quota-proxy && docker compose ps && echo ---HEALTHZ--- && curl -fsS http://127.0.0.1:8787/healthz'
```

## 常见故障排查（服务器侧）

当 `docker compose ps` 显示容器未运行，或 `/healthz` 超时/非 200，可按下面顺序快速定位：

```bash
cd /opt/roc/quota-proxy

# 1) 看容器状态
docker compose ps

# 2) 看最近日志（最常用）
docker compose logs --tail=200 -f quota-proxy

# 3) 重新拉取镜像并重启（可回滚；不会改代码）
docker compose pull
docker compose up -d

# 4) 再次健康检查
curl -fsS http://127.0.0.1:8787/healthz
```

如果你使用了反向代理（Caddy/Nginx），同时也要检查代理侧是否把请求转发到 `127.0.0.1:8787`，以及证书/域名解析是否正确。

## 对外访问（如已部署 Caddy/Nginx）

如果你已经把 quota-proxy 通过反向代理对外提供（推荐 HTTPS + 子域名），可以在任意机器上做最小外部探测：

```bash
# API 网关健康
curl -fsS https://api.<your-domain>/healthz

# landing page（200 即可；内容可能随版本变化）
curl -fsSI https://<your-domain>/ | head
```

---

## 进度日志追加（给 cron/推进循环用）

推进循环需要把“本轮落地/阻塞/下一步”追加到进度日志（通常在你的桌面 weekly 目录）。

为避免 `printf` 遇到以 `-` 开头的文本时报 `invalid option`，仓库内提供了一个轻量安全封装：

```bash
# 默认会加时间戳（Asia/Shanghai）
./scripts/append-progress-log.sh "小落地：... commit=abcd123"

# 指定文件路径
./scripts/append-progress-log.sh --file '/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md' \
  "blocker: 本轮仅探活无 commit；next: ..."

# 不加时间戳（原样追加）
./scripts/append-progress-log.sh --no-ts "- raw line starting with dash"

# 如果文本里包含引号/反斜杠等，建议用 --stdin 避免 shell 转义坑
printf '%s' "blocker: can't append due to quoting" | ./scripts/append-progress-log.sh --stdin
```

## Port binding exposure quick-audit (recommended)

Make sure quota-proxy is **not** bound to 0.0.0.0 / :: (public exposure risk). Expected:
`127.0.0.1:8787->8787/tcp`

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/ssh-audit-quota-proxy-exposure.sh
./scripts/ssh-audit-quota-proxy-exposure.sh --json | python3 -m json.tool
```
