# Caddy静态站点部署指南

## 概述

本文档介绍如何部署Caddy静态站点，为中华AI共和国/OpenClaw小白中文包项目提供Web界面和API网关服务。

## 架构

```
用户访问
    ↓
Caddy静态站点 (:8788)
├── 静态文件服务 (/opt/roc/web)
├── 健康检查端点 (/healthz)
└── 反向代理到quota-proxy (:8787)
        ↓
    quota-proxy服务 (:3000)
        ↓
    DeepSeek API
```

## 部署前准备

### 1. 服务器要求
- Ubuntu/Debian系统（推荐）
- 开放端口: 8788 (静态站点), 8787 (API网关)
- 至少1GB可用内存
- 已安装Docker和Docker Compose（用于quota-proxy）

### 2. 本地环境要求
- SSH密钥对（用于服务器认证）
- 项目仓库克隆

## 部署步骤

### 步骤1: 检查服务器状态

```bash
# 检查服务器连接
./scripts/verify-caddy-deployment.sh --dry-run

# 实际验证
./scripts/verify-caddy-deployment.sh --server-ip 8.210.185.194
```

### 步骤2: 部署Caddy静态站点

```bash
# 模拟运行
./scripts/deploy-caddy-static-site.sh --dry-run

# 实际部署
./scripts/deploy-caddy-static-site.sh --server-ip 8.210.185.194
```

### 步骤3: 部署状态页面

```bash
# 生成状态页面
./scripts/create-quota-proxy-status-page.sh

# 部署状态页面
./scripts/deploy-status-page.sh --server-ip 8.210.185.194
```

### 步骤4: 验证部署

```bash
# 验证Caddy部署
./scripts/verify-caddy-deployment.sh --server-ip 8.210.185.194

# 验证状态页面
./scripts/verify-status-page-deployment.sh --server-ip 8.210.185.194
```

## 配置文件说明

### Caddy配置文件 (`configs/caddy-static-site.Caddyfile`)

```caddyfile
# 主站点配置
:8788 {
    root * /opt/roc/web          # 静态文件目录
    file_server browse           # 文件浏览（开发环境）
    encode gzip zstd             # 压缩
    header {                     # 安全头
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Cache-Control "public, max-age=3600"
    }
    @health { path /healthz }    # 健康检查
    respond @health "OK" 200
}

# API网关配置
:8787 {
    reverse_proxy http://localhost:3000  # 代理到quota-proxy
    health_uri /healthz
    health_interval 30s
}
```

### Systemd服务文件

服务文件自动创建在 `/etc/systemd/system/caddy-roc.service`:

```ini
[Unit]
Description=Caddy for ROC AI Republic Static Site
After=network.target network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

[Install]
WantedBy=multi-user.target
```

## 管理命令

### 服务管理

```bash
# 查看服务状态
ssh root@服务器IP 'systemctl status caddy-roc'

# 重启服务
ssh root@服务器IP 'systemctl restart caddy-roc'

# 查看日志
ssh root@服务器IP 'journalctl -u caddy-roc -f'

# 停止服务
ssh root@服务器IP 'systemctl stop caddy-roc'

# 禁用服务
ssh root@服务器IP 'systemctl disable caddy-roc'
```

### 配置管理

```bash
# 查看当前配置
ssh root@服务器IP 'cat /etc/caddy/Caddyfile'

# 更新配置
scp -i ~/.ssh/id_ed25519_roc_server configs/caddy-static-site.Caddyfile root@服务器IP:/etc/caddy/Caddyfile

# 重载配置
ssh root@服务器IP 'systemctl reload caddy-roc'
```

### 监控命令

```bash
# 检查端口监听
ssh root@服务器IP 'netstat -tlnp | grep :8788'

# 健康检查
curl -fsS http://服务器IP:8788/healthz

# 查看进程
ssh root@服务器IP 'ps aux | grep caddy'
```

## 故障排除

### 常见问题

#### 1. Caddy安装失败

**症状**: `command not found: caddy`

**解决方案**:
```bash
# 手动安装Caddy
ssh root@服务器IP 'apt-get update && apt-get install -y curl'
ssh root@服务器IP 'curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg'
ssh root@服务器IP 'curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | tee /etc/apt/sources.list.d/caddy-stable.list'
ssh root@服务器IP 'apt-get update && apt-get install -y caddy'
```

#### 2. 端口冲突

**症状**: `Address already in use`

**解决方案**:
```bash
# 查看占用端口的进程
ssh root@服务器IP 'lsof -i :8788'

# 修改Caddy配置文件端口
# 编辑 configs/caddy-static-site.Caddyfile，修改 :8788 为其他端口
```

#### 3. 权限问题

**症状**: `permission denied`

**解决方案**:
```bash
# 检查目录权限
ssh root@服务器IP 'ls -la /opt/roc/web'

# 修复权限
ssh root@服务器IP 'chown -R caddy:caddy /opt/roc/web'
ssh root@服务器IP 'chmod -R 755 /opt/roc/web'
```

#### 4. 服务启动失败

**症状**: `systemctl status caddy-roc` 显示失败

**解决方案**:
```bash
# 查看详细错误
ssh root@服务器IP 'journalctl -u caddy-roc -n 50'

# 测试Caddy配置
ssh root@服务器IP 'caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile'

# 手动启动测试
ssh root@服务器IP 'caddy run --config /etc/caddy/Caddyfile --adapter caddyfile'
```

## 高级配置

### HTTPS配置（需要域名）

```caddyfile
example.com {
    tls admin@example.com  # 自动获取Let's Encrypt证书
    root * /opt/roc/web
    file_server
    
    # 强制HTTPS
    @http {
        protocol http
    }
    redir @http https://example.com{uri} permanent
}
```

### 自定义错误页面

```caddyfile
handle_errors {
    @404 {
        expression {http.error.status_code} == 404
    }
    respond @404 """
    <!DOCTYPE html>
    <html>
    <head><title>404 - 页面未找到</title></head>
    <body>
        <h1>404 - 页面未找到</h1>
        <p>请求的页面不存在。</p>
        <a href="/">返回首页</a>
    </body>
    </html>
    """ 404 {
        close
    }
}
```

### 访问日志配置

```caddyfile
log {
    output file /var/log/caddy/access.log {
        roll_size 10MB
        roll_keep 5
        roll_keep_for 720h
    }
    format json {
        time_format "2006-01-02T15:04:05Z07:00"
    }
}
```

## 性能优化

### 1. 启用缓存

```caddyfile
header {
    # 静态资源缓存
    Cache-Control "public, max-age=31536000, immutable"
    
    # HTML文件缓存
    @html {
        path *.html
    }
    header @html Cache-Control "public, max-age=3600"
}
```

### 2. 启用压缩

```caddyfile
encode gzip zstd {
    # 排除已压缩的文件
    ext .jpg .jpeg .png .gif .webp .zip .gz .bz2 .xz .zst
}
```

### 3. 连接优化

```caddyfile
reverse_proxy http://localhost:3000 {
    transport http {
        dial_timeout 10s
        response_header_timeout 30s
        keepalive 30s
        keepalive_interval 10s
        max_conns_per_host 100
    }
}
```

## 安全建议

### 1. 防火墙配置

```bash
# 只开放必要端口
ufw allow 22/tcp      # SSH
ufw allow 8788/tcp    # 静态站点
ufw allow 8787/tcp    # API网关
ufw enable
```

### 2. 定期更新

```bash
# 更新Caddy
ssh root@服务器IP 'apt-get update && apt-get upgrade -y caddy'

# 重启服务
ssh root@服务器IP 'systemctl restart caddy-roc'
```

### 3. 监控告警

```bash
# 设置监控脚本
./scripts/monitor-quota-usage.sh --server-ip 服务器IP --alert

# 添加到cron
echo "*/5 * * * * /path/to/scripts/monitor-quota-usage.sh --server-ip 服务器IP --alert" | ssh root@服务器IP 'crontab -'
```

## 相关文档

- [状态页面部署指南](./status-page-deployment.md)
- [quota-proxy部署指南](./quota-proxy-sqlite-auth-deployment.md)
- [数据库备份指南](./sqlite-db-verification.md)
- [监控配置指南](./quota-usage-monitoring.md)

## 支持与反馈

如遇问题，请：
1. 查看日志: `journalctl -u caddy-roc -f`
2. 验证配置: `caddy validate --config /etc/caddy/Caddyfile`
3. 检查网络: `curl -v http://localhost:8788/healthz`
4. 提交Issue: [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)