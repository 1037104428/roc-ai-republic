# quota-proxy 快速部署指南

## 概述

本文档提供 quota-proxy 的最快速部署方法，帮助用户在 5 分钟内完成部署并开始使用。

## 1. 环境要求

- **操作系统**: Linux (Ubuntu 20.04+ / CentOS 7+ / Debian 11+)
- **Docker**: Docker 20.10+ 和 Docker Compose v2+
- **网络**: 可访问互联网（用于拉取镜像）
- **端口**: 8787 端口可用

## 2. 一键部署脚本

### 2.1 下载部署脚本

```bash
# 下载一键部署脚本
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/quota-proxy/deploy-quick.sh -o deploy-quick.sh

# 授予执行权限
chmod +x deploy-quick.sh
```

### 2.2 执行部署

```bash
# 快速部署（使用默认配置）
./deploy-quick.sh

# 或指定配置
./deploy-quick.sh --port 8787 --admin-token your-secret-token
```

## 3. 手动部署步骤

### 3.1 创建项目目录

```bash
# 创建项目目录
mkdir -p /opt/roc/quota-proxy
cd /opt/roc/quota-proxy
```

### 3.2 创建 docker-compose.yml

```yaml
version: '3.8'

services:
  quota-proxy:
    image: ghcr.io/1037104428/quota-proxy:latest
    container_name: quota-proxy
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      - ADMIN_TOKEN=your-secret-admin-token-here
      - TRIAL_KEY_EXPIRY_DAYS=7
      - DEFAULT_QUOTA_LIMIT=1000
    volumes:
      - ./data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8787/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### 3.3 启动服务

```bash
# 启动服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

## 4. 快速验证

### 4.1 健康检查

```bash
# 检查服务是否正常运行
curl -fsS http://localhost:8787/healthz
```

### 4.2 获取试用密钥

```bash
# 使用管理令牌获取试用密钥
ADMIN_TOKEN="your-secret-admin-token-here"
curl -X POST http://localhost:8787/admin/keys/trial \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quota_limit": 1000, "expiry_days": 7}'
```

### 4.3 使用试用密钥访问

```bash
# 使用试用密钥访问API
TRIAL_KEY="your-trial-key-here"
curl -X GET http://localhost:8787/v1/models \
  -H "Authorization: Bearer $TRIAL_KEY"
```

## 5. 常用管理命令

### 5.1 服务管理

```bash
# 启动服务
docker compose start

# 停止服务
docker compose stop

# 重启服务
docker compose restart

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f quota-proxy
```

### 5.2 数据管理

```bash
# 备份数据
docker compose exec quota-proxy tar -czf /app/data/backup-$(date +%Y%m%d).tar.gz /app/data/*.db

# 恢复数据
docker compose exec quota-proxy tar -xzf /app/data/backup-20260211.tar.gz -C /app/data/
```

### 5.3 监控检查

```bash
# 检查容器健康状态
docker inspect --format='{{.State.Health.Status}}' quota-proxy

# 查看资源使用情况
docker stats quota-proxy --no-stream

# 查看端口绑定
docker port quota-proxy
```

## 6. 故障排除

### 6.1 常见问题

**问题1**: 端口 8787 已被占用
```bash
# 检查端口占用
sudo netstat -tlnp | grep :8787

# 修改端口（在 docker-compose.yml 中修改）
# ports:
#   - "8788:8787"  # 外部端口:内部端口
```

**问题2**: 容器启动失败
```bash
# 查看详细日志
docker compose logs quota-proxy

# 检查容器状态
docker compose ps -a
```

**问题3**: 健康检查失败
```bash
# 手动检查服务
curl -v http://localhost:8787/healthz

# 进入容器检查
docker compose exec quota-proxy curl http://localhost:8787/healthz
```

### 6.2 日志分析

```bash
# 查看实时日志
docker compose logs -f quota-proxy

# 查看最近100行日志
docker compose logs --tail=100 quota-proxy

# 查看错误日志
docker compose logs quota-proxy | grep -i error
```

## 7. 下一步操作

### 7.1 配置持久化存储

```bash
# 创建数据目录
mkdir -p /opt/roc/quota-proxy/data

# 设置正确的权限
chmod 755 /opt/roc/quota-proxy/data
```

### 7.2 配置反向代理（可选）

```nginx
# Nginx 配置示例
server {
    listen 80;
    server_name quota.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8787;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 7.3 设置自动启动

```bash
# 启用 Docker 服务自启动
sudo systemctl enable docker

# 设置容器自启动（已在 docker-compose.yml 中配置 restart: unless-stopped）
```

## 8. 验证脚本

使用内置验证脚本确保部署成功：

```bash
# 运行快速验证
cd /opt/roc/quota-proxy
./verify-deployment-quick.sh

# 或运行完整验证
./verify-deployment-full.sh
```

## 版本历史

- **2026-02-11**: 创建快速部署指南，提供一键部署和手动部署两种方式
- **2026-02-10**: 初始版本，包含基本部署步骤

## 支持与反馈

如有问题，请参考：
- [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)
- [项目文档](../README.md)
- [详细部署指南](DEPLOYMENT_GUIDE.md)