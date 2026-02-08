# 服务器巡检（quota-proxy）

本项目的推进循环（cron）会尝试巡检服务器上 quota-proxy 的部署状态。

## 目标

- 查看 compose 状态：`docker compose ps`
- 检查健康探针：`curl -fsS http://127.0.0.1:8787/healthz`

## 前置条件（推荐）

为了让自动化脚本能在无人值守下运行，需要 **SSH 免密** 或在 runner 上提供可用的非交互式认证方式。

推荐做法：配置 **SSH Key 登录**。

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

## 手工巡检命令（在服务器上执行）

```bash
cd /opt/roc/quota-proxy
docker compose ps
curl -fsS http://127.0.0.1:8787/healthz
```
