# 站点部署验证指南

## 概述

本文档提供站点部署验证脚本的使用指南，用于验证静态站点部署状态，确保站点正常运行并提供部署建议。

## 脚本功能

`verify-site-deployment.sh` 脚本提供以下功能：

1. **服务器连接检查** - 验证SSH连接是否正常
2. **站点目录验证** - 检查站点目录是否存在及内容
3. **Web服务器检查** - 检测Nginx/Caddy状态
4. **端口监听检查** - 检查HTTP/HTTPS端口
5. **部署建议生成** - 提供详细的部署指导

## 快速开始

### 基本使用

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 赋予执行权限
chmod +x scripts/verify-site-deployment.sh

# 运行验证
./scripts/verify-site-deployment.sh
```

### 常用选项

```bash
# 详细输出模式
./scripts/verify-site-deployment.sh -v

# 安静模式（仅关键信息）
./scripts/verify-site-deployment.sh -q

# 自定义站点目录
./scripts/verify-site-deployment.sh --site-dir /var/www/html

# 自定义服务器
./scripts/verify-site-deployment.sh --server-host 192.168.1.100
```

## 验证项目说明

### 1. 服务器连接检查

脚本首先检查与目标服务器的SSH连接：

- 使用配置的SSH密钥 (`~/.ssh/id_ed25519_roc_server`)
- 设置8秒连接超时
- 验证连接成功后继续后续检查

### 2. 站点目录验证

检查服务器上的站点目录：

- 目录是否存在 (`/opt/roc/web` 默认)
- 目录内容列表（前20个文件）
- 是否包含 `index.html` 文件

### 3. Web服务器检查

检测并验证Web服务器状态：

**Nginx检查：**
- 检查Nginx是否安装
- 验证服务运行状态
- 检查配置语法是否正确

**Caddy检查：**
- 检查Caddy是否安装
- 验证服务运行状态

### 4. 端口监听检查

检查HTTP/HTTPS端口监听状态：

- 80端口（HTTP）
- 443端口（HTTPS）

### 5. 部署建议生成

根据检查结果生成详细的部署建议，包括：
- 基础部署步骤
- Nginx配置指南
- Caddy配置指南
- HTTPS配置建议
- 内容建议

## 部署流程示例

### 基础部署（Nginx）

```bash
# 1. 创建站点目录和基础文件
ssh root@8.210.185.194 "mkdir -p /opt/roc/web && echo '<h1>中华AI共和国</h1><p>OpenClaw 小白中文包</p>' > /opt/roc/web/index.html"

# 2. 安装并配置Nginx
ssh root@8.210.185.194 "apt update && apt install nginx -y && echo 'server { listen 80; server_name _; root /opt/roc/web; index index.html; }' > /etc/nginx/sites-available/roc-site && ln -sf /etc/nginx/sites-available/roc-site /etc/nginx/sites-enabled/ && nginx -t && systemctl restart nginx"
```

### 基础部署（Caddy）

```bash
# 1. 创建站点目录和基础文件
ssh root@8.210.185.194 "mkdir -p /opt/roc/web && echo '<h1>中华AI共和国</h1><p>OpenClaw 小白中文包</p>' > /opt/roc/web/index.html"

# 2. 安装并配置Caddy
ssh root@8.210.185.194 "apt update && apt install caddy -y && echo ':80 { root * /opt/roc/web }' > /etc/caddy/Caddyfile && systemctl restart caddy"
```

## 站点内容建议

建议的站点内容结构：

### 1. 首页 (`index.html`)
```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>中华AI共和国 / OpenClaw 小白中文包</title>
    <style>
        /* 基础样式 */
    </style>
</head>
<body>
    <header>
        <h1>中华AI共和国 / OpenClaw 小白中文包</h1>
        <p>为中文用户优化的OpenClaw发行版</p>
    </header>
    
    <main>
        <section id="download">
            <h2>📥 下载安装</h2>
            <pre><code>curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash</code></pre>
            <p>或使用国内镜像：</p>
            <pre><code>curl -fsSL https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/install-cn.sh | bash</code></pre>
        </section>
        
        <section id="api-gateway">
            <h2>🔑 API网关</h2>
            <p>访问地址: <code>https://8.210.185.194:8787</code></p>
            <p>获取试用密钥: <code>curl -X POST https://8.210.185.194:8787/admin/keys</code></p>
        </section>
        
        <section id="documentation">
            <h2>📚 文档</h2>
            <ul>
                <li><a href="https://github.com/1037104428/roc-ai-republic">GitHub仓库</a></li>
                <li><a href="https://gitee.com/junkaiWang324/roc-ai-republic">Gitee镜像</a></li>
                <li><a href="/docs">本地文档</a></li>
            </ul>
        </section>
    </main>
    
    <footer>
        <p>© 2026 中华AI共和国项目组</p>
    </footer>
</body>
</html>
```

### 2. 功能页面建议

- **下载页面** - 详细的安装说明和故障排除
- **API文档** - quota-proxy API使用指南
- **使用教程** - OpenClaw基础使用教程
- **常见问题** - 常见问题解答

## 高级配置

### HTTPS配置（Let's Encrypt）

```bash
# 使用Certbot获取SSL证书
ssh root@8.210.185.194 "apt install certbot python3-certbot-nginx -y && certbot --nginx -d your-domain.com"

# 自动续期配置
ssh root@8.210.185.194 "echo '0 0 * * * certbot renew --quiet' | crontab -"
```

### 性能优化

```nginx
# Nginx性能优化配置
server {
    listen 80;
    server_name _;
    root /opt/roc/web;
    index index.html;
    
    # 启用gzip压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 缓存设置
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

## 监控与维护

### 1. 定期验证

建议定期运行验证脚本：

```bash
# 每天运行一次验证
0 2 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-site-deployment.sh -q >> /var/log/site-verification.log 2>&1
```

### 2. 监控告警

设置监控告警：

```bash
# 检查脚本返回状态
if ! ./scripts/verify-site-deployment.sh -q; then
    echo "站点部署验证失败" | mail -s "站点告警" admin@example.com
fi
```

### 3. 备份策略

```bash
# 备份站点内容
ssh root@8.210.185.194 "tar -czf /backup/site-$(date +%Y%m%d).tar.gz -C /opt/roc/web ."
```

## 故障排除

### 常见问题

1. **SSH连接失败**
   - 检查SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
   - 验证服务器防火墙设置
   - 检查网络连接

2. **站点目录不存在**
   - 创建目录：`mkdir -p /opt/roc/web`
   - 设置正确权限：`chown -R www-data:www-data /opt/roc/web`

3. **Web服务器未运行**
   - 启动服务：`systemctl start nginx`
   - 检查配置：`nginx -t`
   - 查看日志：`journalctl -u nginx`

4. **端口未监听**
   - 检查防火墙：`ufw status`
   - 验证服务绑定：`netstat -tlnp`
   - 检查配置文件中的监听地址

### 调试模式

使用详细模式获取更多信息：

```bash
./scripts/verify-site-deployment.sh -v
```

## 集成与自动化

### CI/CD集成

```yaml
# GitHub Actions示例
name: Site Deployment Verification

on:
  schedule:
    - cron: '0 2 * * *'  # 每天UTC 2:00运行
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run site verification
        run: |
          chmod +x scripts/verify-site-deployment.sh
          ./scripts/verify-site-deployment.sh --server-host ${{ secrets.SERVER_HOST }}
```

### 监控面板集成

将验证结果集成到监控面板：

```bash
# 生成JSON格式报告
./scripts/verify-site-deployment.sh --quiet | jq -n --arg status "$?" --arg output "$(cat)" '{status: $status, output: $output, timestamp: now}'
```

## 总结

站点部署验证脚本是确保站点正常运行的重要工具。通过定期运行验证，可以：

1. **提前发现问题** - 在用户遇到问题前发现并修复
2. **提供部署指导** - 为新部署提供详细步骤
3. **监控站点健康** - 持续监控站点状态
4. **自动化维护** - 减少人工检查工作量

建议将验证脚本集成到自动化流程中，确保站点始终保持最佳状态。