# 论坛反向代理修复指南

## 问题描述

论坛 `forum.clawdrepublic.cn` 目前返回 502 错误，原因是 Flarum 容器仅在 `127.0.0.1:8081` 监听，缺少公网反向代理配置。

## 当前状态

- Flarum 容器运行正常：`127.0.0.1:8081`
- 容器名称：`forum-flarum-1`
- 容器状态：运行中（Up 39 hours）
- 公网访问：502 Bad Gateway

## 修复方案

### 方案一：使用 Caddy（推荐）

Caddy 已配置为 `clawdrepublic.cn` 的主 Web 服务器，只需添加论坛子域的反向代理配置。

**配置位置：** `/etc/caddy/Caddyfile`

**配置内容：**
```caddy
# Forum reverse proxy configuration
forum.clawdrepublic.cn {
    # Reverse proxy to Flarum container
    reverse_proxy 127.0.0.1:8081 {
        # Flarum-specific headers
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
        header_up X-Forwarded-Port {port}
    }
    
    # Logging
    log {
        output file /var/log/caddy/forum.log {
            roll_size 10MiB
            roll_keep 5
        }
    }
}
```

### 方案二：使用 Nginx

如果使用 Nginx 作为反向代理，配置如下：

**配置位置：** `/etc/nginx/sites-available/forum.clawdrepublic.cn`

**配置内容：**
```nginx
# Forum reverse proxy configuration
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
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support for Flarum
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Logging
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
}
```

## 一键修复脚本

已提供自动化修复脚本：

```bash
# 查看帮助
./scripts/fix-forum-reverse-proxy.sh --help

# 使用 Caddy（默认）
./scripts/fix-forum-reverse-proxy.sh

# 使用 Nginx
./scripts/fix-forum-reverse-proxy.sh --nginx

# 干运行（只显示命令，不执行）
./scripts/fix-forum-reverse-proxy.sh --dry-run
```

## 验证步骤

修复后，执行以下验证：

1. **本地验证：**
   ```bash
   ssh root@8.210.185.194 'curl -fsS http://127.0.0.1:8081/ | grep -o "Flarum\|论坛"'
   ```

2. **公网验证：**
   ```bash
   curl -fsS http://forum.clawdrepublic.cn/ | grep -o "Flarum\|论坛"
   ```

3. **日志检查：**
   ```bash
   # Caddy 日志
   ssh root@8.210.185.194 'tail -f /var/log/caddy/forum.log'
   
   # Nginx 日志
   ssh root@8.210.185.194 'tail -f /var/log/nginx/forum.access.log'
   ```

## 后续步骤

1. **HTTPS 配置：** 配置 SSL 证书（Let's Encrypt）
2. **性能优化：** 添加缓存、压缩等优化
3. **监控告警：** 设置论坛可用性监控

## 故障排除

### 502 Bad Gateway
- 检查 Flarum 容器是否运行：`docker ps | grep flarum`
- 检查本地访问：`curl http://127.0.0.1:8081/`
- 检查反向代理配置语法：`caddy validate` 或 `nginx -t`

### 403 Forbidden
- 检查文件权限：确保 Web 服务器用户有权访问
- 检查 SELinux/AppArmor 策略

### 连接超时
- 检查防火墙规则：`iptables -L -n`
- 检查端口监听：`netstat -tlnp | grep :8081`

## 相关文档

- [Flarum 官方文档](https://docs.flarum.org/)
- [Caddy 反向代理文档](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
- [Nginx 反向代理文档](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)

## 更新历史

- **2026-02-10**: 创建修复指南和自动化脚本
- **2026-02-09**: 论坛容器部署完成，但缺少反向代理配置