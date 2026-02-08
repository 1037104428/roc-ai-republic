# 服务器巡检（quota-proxy）

本项目的推进循环（cron）会尝试巡检服务器上 quota-proxy 的部署状态。

## 目标

- 查看 compose 状态：`docker compose ps`
- 检查健康探针：`curl -fsS http://127.0.0.1:8787/healthz`

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

目前约定格式示例（最小）：

```text
ip:8.8.8.8
```

如果需要“密码模式（临时）”，可写成：

```text
ip:8.8.8.8
password:YOUR_PASSWORD
```

（注意：密码不应以明文方式长期保存；长期自动化建议使用 key。）

## 自动巡检脚本

### 方式 0：一键探活（官网 + API + 服务器 quota-proxy）

```bash
# pretty 输出（适合人读）
./scripts/probe-roc-all.sh

# JSON 单行输出（适合 cron/CI 收集）
./scripts/probe-roc-all.sh --json

# 字段与退出码
# - 输出字段：ts, home_ok, api_ok, server_ok, all_ok
# - 退出码：全部 ok → 0；任意失败 → 2
#
# 示例：只在失败时告警
# ./scripts/probe-roc-all.sh --json || echo "probe failed"
#
# 示例：用 jq 取字段
# ./scripts/probe-roc-all.sh --json | jq -r '.all_ok'
```

### 方式 1：SSH Key（推荐）

```bash
# 需要能够无交互 ssh 登录
./scripts/check-server-quota-proxy.sh
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

## 对外访问（如已部署 Caddy/Nginx）

如果你已经把 quota-proxy 通过反向代理对外提供（推荐 HTTPS + 子域名），可以在任意机器上做最小外部探测：

```bash
# API 网关健康
curl -fsS https://api.<your-domain>/healthz

# landing page（200 即可；内容可能随版本变化）
curl -fsSI https://<your-domain>/ | head
```
