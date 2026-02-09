# Landing Page 部署指南

中华AI共和国 / OpenClaw 小白中文包的官方 landing page 部署指南。

## 概述

Landing page 是一个静态 HTML 页面，提供：
- 项目介绍
- 一键安装指南
- API 试用申请
- 社区论坛入口
- 下载链接

## 文件结构

```
web-landing/
├── index.html                    # 主页面
└── (未来可添加更多资源文件)

scripts/
├── deploy-landing-page.sh        # 部署脚本
└── verify-landing-deployment.sh  # 验证脚本
```

## 快速部署

### 1. 前提条件

- 服务器 SSH 访问权限
- 服务器上已安装 curl、scp 等基本工具
- Web 服务器（Nginx/Caddy/Apache）已安装或计划安装

### 2. 部署步骤

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 预览部署命令（不实际执行）
./scripts/deploy-landing-page.sh --dry-run

# 实际部署
./scripts/deploy-landing-page.sh
```

### 3. 验证部署

```bash
# 验证部署状态
./scripts/verify-landing-deployment.sh

# 或使用综合探活脚本（包含 landing page 检查）
./scripts/probe.sh
```

## 配置选项

### 环境变量

```bash
# 服务器信息文件（默认: /tmp/server.txt）
export SERVER_FILE=/path/to/server.txt

# SSH 密钥路径（可选）
export SSH_KEY=~/.ssh/id_ed25519_roc_server

# 部署目录（默认: /opt/roc/web）
export WEB_DIR=/var/www/html
```

### 命令行参数

```bash
# 指定服务器IP
./scripts/deploy-landing-page.sh --server-ip 1.2.3.4

# 指定部署目录
./scripts/deploy-landing-page.sh --web-dir /var/www/landing

# 组合使用
./scripts/deploy-landing-page.sh --server-ip 1.2.3.4 --web-dir /var/www/html
```

## Web 服务器配置

### Nginx 配置示例

```nginx
server {
    listen 80;
    server_name clawdrepublic.cn www.clawdrepublic.cn;
    
    root /opt/roc/web;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 启用 gzip 压缩
    gzip on;
    gzip_types text/html text/css application/javascript;
}
```

### Caddy 配置示例

```caddy
clawdrepublic.cn {
    root * /opt/roc/web
    file_server
    encode gzip
}
```

## 自动化部署

### 通过 cron 定期同步

```bash
# 每天凌晨3点同步 landing page
0 3 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/deploy-landing-page.sh >> /var/log/landing-deploy.log 2>&1
```

### CI/CD 集成示例

```yaml
# GitHub Actions 示例
name: Deploy Landing Page

on:
  push:
    paths:
      - 'web-landing/**'
      - 'scripts/deploy-landing-page.sh'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Server
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          SERVER_IP: ${{ secrets.SERVER_IP }}
        run: |
          echo "$SSH_PRIVATE_KEY" > /tmp/deploy_key
          chmod 600 /tmp/deploy_key
          SSH_KEY=/tmp/deploy_key SERVER_IP="$SERVER_IP" ./scripts/deploy-landing-page.sh
```

## 故障排除

### 常见问题

1. **部署失败：SSH 连接超时**
   - 检查服务器IP是否正确
   - 检查防火墙设置
   - 验证SSH密钥权限

2. **页面无法访问**
   - 检查Web服务器是否运行：`systemctl status nginx`
   - 检查防火墙端口：`sudo ufw status`
   - 检查文件权限：`ls -la /opt/roc/web/`

3. **页面内容不正确**
   - 验证文件是否成功复制：`cat /opt/roc/web/index.html | head -5`
   - 检查文件大小：`stat -c%s /opt/roc/web/index.html`

### 调试命令

```bash
# 检查服务器连接
ssh -o BatchMode=yes -o ConnectTimeout=5 root@服务器IP "echo connected"

# 检查文件是否存在
ssh root@服务器IP "test -f /opt/roc/web/index.html && echo '文件存在'"

# 检查Web服务器响应
curl -v http://服务器IP/

# 查看部署日志
tail -f /var/log/landing-deploy.log
```

## 更新与维护

### 更新 landing page

1. 修改 `web-landing/index.html`
2. 测试本地修改
3. 部署到服务器

```bash
# 本地测试
cd /home/kai/.openclaw/workspace/roc-ai-republic
python3 -m http.server 8000 &
# 访问 http://localhost:8000/web-landing/

# 部署更新
./scripts/deploy-landing-page.sh
```

### 回滚到上一版本

```bash
# 从git恢复上一版本
git checkout HEAD~1 -- web-landing/index.html

# 重新部署
./scripts/deploy-landing-page.sh
```

## 监控与告警

### 健康检查脚本

```bash
#!/bin/bash
# health-check-landing.sh

URL="http://clawdrepublic.cn/"
TIMEOUT=5

if curl -fsS -m "$TIMEOUT" "$URL" | grep -q "中华AI共和国"; then
    echo "✅ Landing page is healthy"
    exit 0
else
    echo "❌ Landing page check failed"
    # 发送告警（示例）
    # curl -X POST -H "Content-Type: application/json" -d '{"text":"Landing page down!"}' $SLACK_WEBHOOK
    exit 1
fi
```

### 集成到现有监控

```bash
# 添加到 probe-roc-all.sh
./scripts/probe-roc-all.sh --json | jq '.landing_ok'
```

## 安全建议

1. **文件权限**
   ```bash
   chmod 644 /opt/roc/web/index.html
   chown www-data:www-data /opt/roc/web/index.html
   ```

2. **Web服务器安全**
   - 启用 HTTPS
   - 设置安全头部
   - 限制访问频率

3. **部署安全**
   - 使用SSH密钥认证
   - 限制部署脚本执行权限
   - 记录部署日志

## 相关资源

- [Nginx 配置指南](https://nginx.org/en/docs/)
- [Caddy 文档](https://caddyserver.com/docs/)
- [Let's Encrypt SSL](https://letsencrypt.org/)
- [项目主文档](../README.md)

---

**最后更新**: 2026-02-09  
**维护者**: 中华AI共和国运维团队  
**状态**: 生产就绪 ✅