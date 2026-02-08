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

目前约定格式示例：

```text
ip:8.8.8.8
```

（注意：密码不应以明文方式长期保存；自动化建议使用 key。）

## 自动巡检脚本

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
# 或显式传密码（不会写文件）：
PASSWORD='YOUR_PASSWORD' ./scripts/check-server-quota-proxy-password.py
```

> 备注：本脚本依赖 Python 的 `pexpect`（Ubuntu 通常自带/可通过 python3-pexpect 安装）。

## 手工巡检命令（在服务器上执行）

```bash
cd /opt/roc/quota-proxy
docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```
