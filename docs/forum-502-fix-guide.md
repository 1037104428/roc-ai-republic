# 论坛 502 错误修复指南

## 问题描述

访问 `http://forum.clawdrepublic.cn/` 返回 502 Bad Gateway 错误。

## 根本原因

Flarum 论坛服务在服务器内部运行在 `127.0.0.1:8081`，但缺少对外网访问的反向代理配置。

## 解决方案

### 方案一：使用 Caddy（推荐，自动 HTTPS）

Caddy 配置简单，支持自动 HTTPS。

1. **部署修复脚本**：
   ```bash
   cd /path/to/roc-ai-republic
   ./scripts/deploy-forum-fix-502.sh --caddy
   ```

2. **验证修复**：
   ```bash
   ./scripts/verify-forum-502-fix.sh
   ```

### 方案二：使用 Nginx

如果需要手动管理 SSL 证书，使用 Nginx。

1. **部署修复脚本**：
   ```bash
   cd /path/to/roc-ai-republic
   ./scripts/deploy-forum-fix-502.sh --nginx
   ```

2. **配置 SSL 证书**（如果需要 HTTPS）：
   ```bash
   # 使用 certbot 获取证书
   certbot --nginx -d forum.clawdrepublic.cn
   ```

3. **验证修复**：
   ```bash
   ./scripts/verify-forum-502-fix.sh
   ```

## 手动配置步骤

### Caddy 配置

在 `/etc/caddy/Caddyfile` 中添加：

```caddy
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    encode gzip
    header {
        -Server
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
```

重载 Caddy：
```bash
systemctl reload caddy
```

### Nginx 配置

创建 `/etc/nginx/sites-available/forum.clawdrepublic.cn`：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name forum.clawdrepublic.cn;
    
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:8081;
    }
}
```

启用配置：
```bash
ln -sf /etc/nginx/sites-available/forum.clawdrepublic.cn /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

## 验证步骤

### 基础验证

```bash
# 检查论坛是否可访问
curl -fsS -m 5 http://forum.clawdrepublic.cn/

# 使用验证脚本
./scripts/verify-forum-502-fix.sh --verbose

# JSON 格式输出（适合 CI/CD）
./scripts/verify-forum-502-fix.sh --json
```

### 完整验证清单

1. **内部服务检查**：
   ```bash
   ssh root@服务器IP "curl -fsS http://127.0.0.1:8081/"
   ```

2. **反向代理检查**：
   ```bash
   ssh root@服务器IP "systemctl status caddy || systemctl status nginx"
   ```

3. **防火墙检查**：
   ```bash
   ssh root@服务器IP "iptables -L -n | grep :80"
   ```

4. **域名解析检查**：
   ```bash
   dig forum.clawdrepublic.cn +short
   ```

## 故障排除

### 常见问题

1. **502 错误仍然存在**
   - 检查 Flarum 服务是否运行：`systemctl status flarum`
   - 检查端口监听：`netstat -tlnp | grep :8081`
   - 检查服务日志：`journalctl -u flarum -n 20`

2. **Caddy/Nginx 配置错误**
   - Caddy：`caddy validate --config /etc/caddy/Caddyfile`
   - Nginx：`nginx -t`

3. **权限问题**
   - 确保 Caddy/Nginx 用户有权访问证书文件
   - 检查 SELinux/AppArmor 限制

4. **DNS 问题**
   - 确认域名解析到正确的服务器 IP
   - 检查 DNS 缓存：`dig forum.clawdrepublic.cn`

### 回滚步骤

如果修复失败，可以回滚：

```bash
# Caddy 回滚
ssh root@服务器IP "cp /etc/caddy/Caddyfile.backup.* /etc/caddy/Caddyfile && systemctl reload caddy"

# Nginx 回滚
ssh root@服务器IP "rm /etc/nginx/sites-enabled/forum.clawdrepublic.cn && systemctl reload nginx"
```

## 自动化脚本

项目提供了完整的自动化脚本：

| 脚本 | 用途 | 示例 |
|------|------|------|
| `deploy-forum-fix-502.sh` | 部署修复 | `./deploy-forum-fix-502.sh --caddy --dry-run` |
| `verify-forum-502-fix.sh` | 验证修复 | `./verify-forum-502-fix.sh --json` |
| `probe-roc-all.sh` | 完整探活 | `./probe-roc-all.sh`（包含论坛检查） |

## 后续维护

1. **监控**：将论坛可用性加入监控系统
2. **备份**：定期备份论坛数据和配置
3. **更新**：保持 Flarum 和反向代理软件更新
4. **安全**：定期检查 SSL 证书和安全性配置

## 相关文档

- [论坛部署指南](../docs/forum-deployment.md)
- [服务器运维检查清单](../docs/ops-server-healthcheck.md)
- [故障排查手册](../docs/troubleshooting.md)