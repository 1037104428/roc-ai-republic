# 静态站点部署指南

## 概述

`deploy-static-site.sh` 脚本是一个用于将静态站点部署到服务器的自动化工具。它支持 Nginx 和 Caddy 两种 Web 服务器，可以配置 HTTP 和 HTTPS，提供完整的部署验证和报告生成功能。

## 功能特性

- ✅ **服务器连接检查** - 自动验证SSH连接
- ✅ **目录准备** - 创建站点目录并设置权限
- ✅ **文件上传** - 批量上传静态文件
- ✅ **Web服务器配置** - 支持 Nginx 和 Caddy
- ✅ **HTTPS支持** - 可配置SSL证书
- ✅ **部署验证** - 自动验证服务状态和可访问性
- ✅ **详细报告** - 生成部署报告和后续操作指南
- ✅ **干运行模式** - 预览将要执行的命令
- ✅ **彩色输出** - 友好的命令行界面

## 快速开始

### 1. 基本部署

```bash
# 部署静态站点到默认服务器
./scripts/deploy-static-site.sh --local-source ./site

# 指定服务器和目录
./scripts/deploy-static-site.sh \
  --server-ip 8.210.185.194 \
  --local-source ./public \
  --site-dir /opt/roc/web
```

### 2. 使用Caddy服务器

```bash
./scripts/deploy-static-site.sh \
  --local-source ./dist \
  --web-server caddy \
  --domain example.com \
  --https
```

### 3. 干运行模式（预览）

```bash
./scripts/deploy-static-site.sh \
  --local-source ./build \
  --dry-run \
  --verbose
```

## 详细配置

### 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-s, --server-ip IP` | 服务器IP地址 | 从 `/tmp/server.txt` 读取 |
| `-k, --ssh-key PATH` | SSH私钥路径 | `~/.ssh/id_ed25519_roc_server` |
| `-d, --site-dir DIR` | 服务器站点目录 | `/opt/roc/web` |
| `-l, --local-source DIR` | 本地静态文件目录 | （必需） |
| `-w, --web-server TYPE` | Web服务器类型: `nginx` 或 `caddy` | `nginx` |
| `--domain DOMAIN` | 域名（用于HTTPS） | 空 |
| `--https` | 启用HTTPS | `false` |
| `--dry-run` | 干运行模式 | `false` |
| `-v, --verbose` | 详细输出 | `false` |
| `-h, --help` | 显示帮助信息 | - |

### 服务器配置

#### 从文件读取服务器IP

脚本会自动从 `/tmp/server.txt` 读取服务器IP，文件格式：

```bash
ip:8.210.185.194
```

#### SSH密钥配置

默认使用 `~/.ssh/id_ed25519_roc_server` 密钥，确保：

1. 密钥文件存在且权限正确（600）
2. 公钥已添加到服务器的 `~/.ssh/authorized_keys`
3. 服务器允许密钥认证

### Web服务器配置

#### Nginx 配置

脚本会创建以下Nginx配置文件：

**HTTP配置（默认）:**
```nginx
server {
    listen 80;
    server_name _;
    
    root /opt/roc/web;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**HTTPS配置（需要SSL证书）:**
```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/ssl/certs/example.com.crt;
    ssl_certificate_key /etc/ssl/private/example.com.key;
    
    root /opt/roc/web;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

#### Caddy 配置

**HTTP配置:**
```caddy
:80 {
    root * /opt/roc/web
    file_server
    
    # 静态文件缓存
    header Cache-Control "public, max-age=31536000" {
        /assets/*
        /static/*
        /images/*
        /css/*
        /js/*
    }
}
```

**HTTPS配置（自动获取证书）:**
```caddy
example.com {
    root * /opt/roc/web
    file_server
    
    # 静态文件缓存
    header Cache-Control "public, max-age=31536000" {
        /assets/*
        /static/*
        /images/*
        /css/*
        /js/*
    }
}
```

## 部署流程

### 1. 准备工作

确保满足以下条件：

1. **本地静态文件** - 准备好要部署的静态文件目录
2. **服务器访问** - SSH密钥配置正确
3. **Web服务器** - 服务器已安装 Nginx 或 Caddy
4. **域名** - 如需HTTPS，准备好域名和DNS解析

### 2. 执行部署

```bash
# 完整部署示例
./scripts/deploy-static-site.sh \
  --local-source ./my-site \
  --domain mysite.example.com \
  --https \
  --web-server nginx \
  --verbose
```

### 3. 验证部署

脚本会自动验证：

1. **服务状态** - 检查Nginx/Caddy是否运行
2. **端口监听** - 检查80/443端口
3. **文件存在** - 检查站点目录文件
4. **可访问性** - 尝试访问站点（如可能）

### 4. 查看报告

部署完成后会生成报告，包含：

- 部署配置摘要
- 验证结果
- 后续操作建议
- 故障排除指南

## 高级用法

### 自定义配置

创建配置文件：

```bash
# deploy-config.sh
export SERVER_IP="8.210.185.194"
export LOCAL_SOURCE_DIR="./build"
export WEB_SERVER="caddy"
export DOMAIN="example.com"
export HTTPS_ENABLED=true

# 执行部署
source deploy-config.sh
./scripts/deploy-static-site.sh
```

### 集成到CI/CD

```yaml
# GitHub Actions 示例
name: Deploy Static Site

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build static site
        run: npm run build
        
      - name: Deploy to server
        run: |
          chmod +x ./scripts/deploy-static-site.sh
          ./scripts/deploy-static-site.sh \
            --server-ip ${{ secrets.SERVER_IP }} \
            --local-source ./dist \
            --domain ${{ secrets.DOMAIN }} \
            --https
        env:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

### 定时部署

```bash
# 每天凌晨自动部署
0 2 * * * cd /path/to/roc-ai-republic && ./scripts/deploy-static-site.sh --local-source ./site --dry-run
```

## 故障排除

### 常见问题

#### 1. SSH连接失败

**症状:** `无法连接到服务器`
**解决方案:**
- 检查服务器IP是否正确
- 验证SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
- 确认公钥已添加到服务器：`ssh-copy-id -i ~/.ssh/id_ed25519_roc_server root@server-ip`
- 检查防火墙设置

#### 2. 权限不足

**症状:** `Permission denied`
**解决方案:**
- 确保使用root用户或具有sudo权限的用户
- 检查目录权限：`chmod 755 /opt/roc/web`
- 验证sudo配置

#### 3. Web服务启动失败

**症状:** `Nginx/Caddy服务未运行`
**解决方案:**
- 检查配置文件语法：`nginx -t` 或 `caddy validate`
- 查看服务日志：`journalctl -u nginx` 或 `journalctl -u caddy`
- 检查端口冲突：`netstat -tlnp | grep :80`

#### 4. HTTPS证书问题

**症状:** `SSL证书错误`
**解决方案:**
- 确保证书文件存在且权限正确
- 检查证书链完整性
- 验证域名DNS解析
- 对于Caddy，确保域名可公开访问以获取Let's Encrypt证书

### 调试模式

启用详细输出查看详细过程：

```bash
./scripts/deploy-static-site.sh --local-source ./site --verbose
```

### 手动验证

部署后手动验证：

```bash
# 检查服务状态
ssh root@server-ip "systemctl status nginx"

# 检查文件
ssh root@server-ip "ls -la /opt/roc/web"

# 测试访问
curl -I http://server-ip
```

## 安全考虑

### 1. 权限管理

- 使用最小权限原则
- 避免在脚本中硬编码敏感信息
- 使用环境变量或配置文件存储密钥

### 2. 文件安全

- 静态文件不应包含敏感信息
- 配置适当的文件权限
- 定期备份站点内容

### 3. Web服务器安全

- 保持Web服务器软件更新
- 配置适当的安全头
- 启用防火墙限制访问
- 使用HTTPS加密传输

### 4. 访问控制

- 限制管理接口访问
- 配置适当的认证机制
- 监控访问日志

## 性能优化

### 1. 静态文件缓存

脚本已配置静态文件缓存头：

```nginx
# Nginx缓存配置
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

### 2. 压缩传输

建议在Web服务器配置中启用Gzip压缩：

```nginx
# Nginx Gzip配置
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
```

### 3. CDN集成

对于高流量站点，建议集成CDN：

1. 配置CDN回源到服务器
2. 设置适当的缓存规则
3. 配置SSL证书
4. 启用HTTP/2或HTTP/3

## 监控和维护

### 1. 健康检查

创建健康检查脚本：

```bash
#!/bin/bash
# health-check.sh
SERVER_IP="8.210.185.194"
SITE_URL="http://$SERVER_IP"

if curl -s -f -I "$SITE_URL" > /dev/null; then
    echo "站点健康: $SITE_URL"
    exit 0
else
    echo "站点不可访问: $SITE_URL"
    exit 1
fi
```

### 2. 日志监控

配置日志监控：

```bash
# 查看访问日志
ssh root@server-ip "tail -f /var/log/nginx/access.log"

# 查看错误日志
ssh root@server-ip "tail -f /var/log/nginx/error.log"
```

### 3. 定期备份

设置定期备份：

```bash
# backup-site.sh
BACKUP_DIR="/opt/backups/web"
SITE_DIR="/opt/roc/web"
DATE=$(date +%Y%m%d-%H%M%S)

tar -czf "$BACKUP_DIR/site-$DATE.tar.gz" -C "$SITE_DIR" .
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
```

## 扩展功能

### 1. 多环境部署

支持开发、测试、生产环境：

```bash
# deploy-to-env.sh
ENVIRONMENT=$1

case $ENVIRONMENT in
    dev)
        SERVER_IP="dev-server-ip"
        DOMAIN="dev.example.com"
        ;;
    staging)
        SERVER_IP="staging-server-ip"
        DOMAIN="staging.example.com"
        ;;
    production)
        SERVER_IP="production-server-ip"
        DOMAIN="example.com"
        ;;
esac

./scripts/deploy-static-site.sh \
  --server-ip "$SERVER_IP" \
  --domain "$DOMAIN" \
  --https \
  --local-source ./dist
```

### 2. 回滚功能

添加回滚支持：

```bash
# rollback-site.sh
VERSION=$1
BACKUP_FILE="/opt/backups/web/site-$VERSION.tar.gz"

if [[ -f "$BACKUP_FILE" ]]; then
    ssh root@server-ip "tar -xzf $BACKUP_FILE -C /opt/roc/web"
    ssh root@server-ip "systemctl reload nginx"
    echo "回滚到版本: $VERSION"
else
    echo "备份文件不存在: $BACKUP_FILE"
    exit 1
fi
```

### 3. 自动化测试

集成自动化测试：

```bash
# test-deployment.sh
# 部署前测试
npm test

# 构建
npm run build

# 部署
./scripts/deploy-static-site.sh --local-source ./dist

# 部署后测试
./scripts/verify-site-deployment.sh
```

## 最佳实践

### 1. 版本控制

- 将静态站点代码纳入版本控制
- 使用语义化版本号
- 保留部署历史记录

### 2. 文档化

- 记录部署配置
- 维护故障排除指南
- 更新部署流程文档

### 3. 自动化

- 自动化构建和部署流程
- 配置CI/CD流水线
- 设置监控告警

### 4. 监控

- 监控站点可用性
- 跟踪性能指标
- 设置错误告警

## 相关工具

### 1. 验证工具

- `verify-site-deployment.sh` - 站点部署验证
- `verify-web-server-config.sh` - Web服务器配置验证

### 2. 监控工具

- `enhanced-health-check.sh` - 增强健康检查
- `query-api-usage.sh` - API使用统计

### 3. 管理工具

- `deploy-static-site.sh` - 静态站点部署
- `cleanup-docker-compose-files.sh` - Docker Compose清理

## 总结

`deploy-static-site.sh` 脚本提供了一个完整的静态站点部署解决方案，具有以下优势：

1. **简单易用** - 命令行界面，彩色输出
2. **灵活配置** - 支持多种Web服务器和部署场景
3. **安全可靠** - 完整的验证和错误处理
4. **可扩展** - 易于集成到现有工作流
5. **文档完善** - 详细的指南和故障排除

通过使用此脚本，可以大大简化静态站点的部署流程，提高部署效率和可靠性。