# 论坛子域名 DNS 配置指南

## 问题现状

当前论坛部署在服务器上，但子域名 `forum.clawdrepublic.cn` 无法通过 HTTPS 访问，返回 502 错误。

**根本原因**：DNS 记录缺失，导致 Let's Encrypt 无法验证域名所有权，无法颁发 SSL 证书。

## 解决方案

### 方案 A：添加 DNS A 记录（推荐）

在域名 `clawdrepublic.cn` 的 DNS 管理面板中添加以下记录：

```
类型: A
名称: forum
值: 8.210.185.194
TTL: 自动（或 300 秒）
```

**验证命令**（添加后等待 DNS 传播，通常 5-60 分钟）：
```bash
# 检查 DNS 解析
dig forum.clawdrepublic.cn +short
nslookup forum.clawdrepublic.cn

# 检查 HTTPS 访问
curl -fsS https://forum.clawdrepublic.cn/ | grep -o 'Clawd 国度论坛'
```

### 方案 B：使用现有子域名（备选）

如果不想添加新子域名，可以修改 Caddy 配置，使用路径 `/forum/` 访问论坛：

1. 修改 `/etc/caddy/Caddyfile`，注释掉 `forum.clawdrepublic.cn` 块
2. 确保 `clawdrepublic.cn` 块中的 `/forum/*` 反向代理配置生效

**当前配置**（已生效）：
```
handle /forum/* {
    reverse_proxy http://127.0.0.1:8081
}
```

**访问地址**：https://clawdrepublic.cn/forum/

### 方案 C：临时 HTTP 访问（仅测试）

修改 Caddy 配置，允许论坛通过 HTTP 访问（不推荐生产环境）：

```caddy
forum.clawdrepublic.cn {
    tls internal
    reverse_proxy 127.0.0.1:8081
}
```

## 服务器端验证

论坛容器已在运行，可通过本地端口访问：

```bash
# SSH 到服务器验证
ssh root@8.210.185.194 "curl -fsS http://127.0.0.1:8081/ | grep -o 'Flarum'"

# 检查容器状态
ssh root@8.210.185.194 "docker ps | grep forum"
```

**预期输出**：
```
d41b788e6f97   mondedie/flarum:stable    "/usr/local/bin/star…"   25 hours ago   Up 24 hours   127.0.0.1:8081->8888/tcp   forum-flarum-1
32cdd4eb0f65   mariadb:11                "docker-entrypoint.s…"   25 hours ago   Up 25 hours   3306/tcp                   forum-db-1
```

## Caddy 日志监控

查看证书获取状态：
```bash
ssh root@8.210.185.194 "journalctl -u caddy -f --since '5 minutes ago' | grep -i forum"
```

## 决策清单

- [ ] **选择方案**：A（新子域名） / B（路径访问） / C（HTTP临时）
- [ ] **执行配置**：DNS 记录或 Caddy 修改
- [ ] **验证访问**：运行验证命令确认可访问
- [ ] **更新文档**：在官网添加论坛入口链接

## 故障排除

### 1. DNS 已添加但仍 502
- 等待 DNS 传播（最长 48 小时，通常 <1 小时）
- 检查防火墙：`ssh root@8.210.185.194 "ufw status"`
- 重启 Caddy：`ssh root@8.210.185.194 "systemctl restart caddy"`

### 2. 论坛容器未运行
```bash
# 启动论坛
ssh root@8.210.185.194 "cd /opt/roc/forum && docker compose up -d"

# 查看日志
ssh root@8.210.185.194 "docker logs forum-flarum-1 --tail 20"
```

### 3. 数据库连接问题
```bash
# 检查数据库
ssh root@8.210.185.194 "docker exec forum-db-1 mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e 'SHOW DATABASES;'"
```

## 相关文件

- **Caddy 配置**：`/etc/caddy/Caddyfile`
- **论坛部署**：`/opt/roc/forum/docker-compose.yml`
- **部署脚本**：`scripts/forum-deploy.sh`
- **验证脚本**：`scripts/verify-forum-deployment.sh`

## 下一步

1. 执行选定的 DNS/配置方案
2. 运行验证脚本确认论坛可访问
3. 在官网首页添加论坛入口
4. 创建论坛使用指南和版规