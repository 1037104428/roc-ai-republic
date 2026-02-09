# 落地页部署验证

本文档说明如何验证落地页部署状态。

## 验证脚本

使用 `verify-landing-page.sh` 脚本检查落地页部署：

```bash
# 基本验证
./scripts/verify-landing-page.sh

# 详细输出
./scripts/verify-landing-page.sh --verbose

# 仅检查本地文件
./scripts/verify-landing-page.sh --local-only

# 指定服务器
SERVER_FILE=/path/to/server.txt ./scripts/verify-landing-page.sh
```

## 验证内容

脚本检查以下项目：

### 1. 本地文件结构
- `web/` 目录存在
- `web/site/` 目录存在
- `web/site/index.html` 文件存在
- `web/caddy/Caddyfile` 配置存在
- `web/nginx/nginx.conf` 配置存在

### 2. 服务器部署状态
- SSH 连接正常
- 远程 Web 目录存在 (`/opt/roc/web`)
- Index 文件已部署

### 3. Web 服务器配置
- Caddy 或 Nginx 配置包含域名
- Web 服务器服务运行中

### 4. 域名可访问性
- HTTP 访问测试
- HTTPS 访问测试

### 5. 服务器本地访问
- 服务器本地 HTTP 访问测试

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SERVER_FILE` | `/tmp/server.txt` | 服务器配置文件路径 |
| `REMOTE_USER` | `root` | SSH 用户名 |
| `REMOTE_WEB_DIR` | `/opt/roc/web` | 远程 Web 目录 |
| `LANDING_DOMAIN` | `clawdrepublic.cn` | 落地页域名 |

## 服务器配置文件格式

服务器配置文件支持两种格式：

1. 简单格式 (仅 IP):
```
8.210.185.194
```

2. Key-value 格式:
```
ip=8.210.185.194
```

## 部署脚本

落地页部署使用 `deploy-landing-page.sh`:

```bash
# 部署落地页
./scripts/deploy-landing-page.sh

# 干运行 (预览)
./scripts/deploy-landing-page.sh --dry-run

# 指定服务器
./scripts/deploy-landing-page.sh --server-file /path/to/server.txt
```

## 故障排除

### SSH 连接失败
1. 检查服务器 IP 是否正确
2. 检查 SSH 密钥配置
3. 检查防火墙设置

### Web 服务器未运行
1. 检查 Caddy/Nginx 服务状态:
   ```bash
   ssh root@服务器IP "systemctl status caddy"
   ssh root@服务器IP "systemctl status nginx"
   ```

2. 检查配置文件:
   ```bash
   ssh root@服务器IP "cat /etc/caddy/Caddyfile"
   ssh root@服务器IP "cat /etc/nginx/nginx.conf"
   ```

### 域名无法访问
1. 检查 DNS 解析:
   ```bash
   nslookup clawdrepublic.cn
   ```

2. 检查服务器防火墙:
   ```bash
   ssh root@服务器IP "ufw status"
   ```

3. 检查端口监听:
   ```bash
   ssh root@服务器IP "netstat -tlnp | grep :80"
   ssh root@服务器IP "netstat -tlnp | grep :443"
   ```

## 手动验证命令

如果脚本失败，可以手动运行以下命令验证:

```bash
# 检查本地文件
ls -la web/site/
ls -la web/caddy/
ls -la web/nginx/

# 检查服务器文件
ssh root@8.210.185.194 "ls -la /opt/roc/web/"

# 检查 Web 服务器
ssh root@8.210.185.194 "systemctl status caddy || systemctl status nginx"

# 检查域名访问
curl -I http://clawdrepublic.cn/
curl -I https://clawdrepublic.cn/

# 检查服务器本地访问
ssh root@8.210.185.194 "curl -fsS http://localhost/"
```

## 集成到 CI/CD

可以将验证脚本集成到自动化流程中:

```bash
# 在部署后自动验证
./scripts/deploy-landing-page.sh
./scripts/verify-landing-page.sh

# 如果验证失败则回滚
if ! ./scripts/verify-landing-page.sh; then
    echo "部署验证失败，执行回滚..."
    # 回滚逻辑
fi
```

## 相关文档

- [部署指南](../docs/deploy-landing-page.md)
- [Web 服务器配置](../docs/web-server-config.md)
- [验证总览](../docs/verify.md)