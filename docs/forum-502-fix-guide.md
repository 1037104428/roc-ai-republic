# 论坛 502 错误修复指南

## 问题描述

论坛 `forum.clawdrepublic.cn` 外网访问返回 **502 Bad Gateway** 错误，但服务器本地访问正常（`127.0.0.1:8081`）。

## 根本原因

Flarum 论坛在服务器上运行于 `127.0.0.1:8081`，但外网访问需要通过反向代理（Caddy/Nginx）转发。当前反向代理配置缺失或错误。

## 快速修复

### 方法一：使用自动修复脚本（推荐）

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/fix-forum-502.sh
```

脚本会：
1. 检查当前论坛状态
2. 检测使用的 Web 服务器（Caddy/Nginx）
3. 生成正确的反向代理配置
4. 提供自动或手动应用选项

### 方法二：手动修复 Caddy 配置

如果使用 Caddy，在 `/etc/caddy/Caddyfile` 末尾添加：

```caddy
# forum.clawdrepublic.cn 反向代理配置
forum.clawdrepublic.cn {
    # 反向代理到本地 Flarum 论坛
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 日志
    log {
        output file /var/log/caddy/forum.access.log
        format json
    }
}
```

然后重载 Caddy：
```bash
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

### 方法三：手动修复 Nginx 配置

如果使用 Nginx，创建 `/etc/nginx/sites-available/forum.clawdrepublic.cn`：

```nginx
# forum.clawdrepublic.cn 反向代理配置
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
        
        # WebSocket 支持（Flarum 可能需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
}
```

启用配置并重载：
```bash
ln -sf /etc/nginx/sites-available/forum.clawdrepublic.cn /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

## 验证修复

修复后验证：

```bash
# 1. 检查本地服务
ssh root@8.210.185.194 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "本地服务正常"'

# 2. 检查外网访问
curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null && echo "外网访问正常"

# 3. 使用探活脚本
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/probe.sh --no-ssh
```

## 故障排查

如果修复后仍然 502：

1. **检查 Flarum 服务状态**：
   ```bash
   ssh root@8.210.185.194 'systemctl status flarum || docker ps | grep flarum'
   ```

2. **检查端口监听**：
   ```bash
   ssh root@8.210.185.194 'netstat -tlnp | grep :8081'
   ```

3. **检查防火墙**：
   ```bash
   ssh root@8.210.185.194 'iptables -L -n | grep :80'
   ```

4. **检查 DNS 解析**：
   ```bash
   nslookup forum.clawdrepublic.cn
   dig forum.clawdrepublic.cn
   ```

5. **查看 Web 服务器日志**：
   ```bash
   ssh root@8.210.185.194 'tail -f /var/log/caddy/forum.access.log'
   # 或
   ssh root@8.210.185.194 'tail -f /var/log/nginx/forum.error.log'
   ```

## 预防措施

1. **配置监控**：将论坛可用性加入 `probe.sh` 定期检查
2. **文档更新**：新部署时自动配置反向代理
3. **备份配置**：定期备份 Caddy/Nginx 配置文件

## 相关文件

- `scripts/fix-forum-502.sh` - 自动修复脚本
- `docs/tickets.md` - 问题跟踪
- `scripts/probe.sh` - 探活脚本（包含论坛检查）

## 更新记录

- 2026-02-10: 创建修复指南和自动脚本
- 2026-02-09: 首次发现论坛 502 问题并记录到 tickets.md