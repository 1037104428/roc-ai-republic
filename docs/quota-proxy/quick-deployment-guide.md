# quota-proxy 简易部署指南

## 概述

quota-proxy 是一个用于管理 API 配额和访问控制的代理服务，支持 SQLite 持久化存储。本指南提供最简化的部署步骤。

## 前置要求

- Docker 和 Docker Compose
- DeepSeek API 密钥
- 服务器（或本地环境）访问权限

## 快速开始（30秒版）

### 1. 准备环境

```bash
# 克隆项目
git clone https://gitee.com/junkaiWang324/roc-ai-republic.git
cd roc-ai-republic

# 进入 quota-proxy 目录
cd quota-proxy
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
cat > .env << EOF
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
ADMIN_TOKEN=your-secret-admin-token
EOF
```

### 3. 启动服务

```bash
# 使用 Docker Compose 启动
docker compose up -d

# 或者使用 SQLite 版本
docker compose -f compose-sqlite.yaml up -d
```

### 4. 验证部署

```bash
# 健康检查
curl http://localhost:8787/healthz

# 管理员接口（需要 ADMIN_TOKEN）
curl -H "Authorization: Bearer your-secret-admin-token" \
  http://localhost:8787/admin/usage
```

## 详细部署步骤

### 方案一：使用现有部署脚本

```bash
# 1. 设置环境变量
export ADMIN_TOKEN="your-secret-admin-token"
export DEEPSEEK_API_KEY="sk-your-deepseek-api-key"

# 2. 运行部署脚本
./scripts/deploy-quota-proxy-sqlite.sh

# 3. 验证部署
./scripts/verify-quota-proxy.sh
```

### 方案二：手动部署

#### 步骤 1：准备服务器

```bash
# 登录服务器
ssh root@your-server-ip

# 创建项目目录
mkdir -p /opt/roc/quota-proxy
cd /opt/roc/quota-proxy
```

#### 步骤 2：复制文件

```bash
# 复制项目文件
scp -r /path/to/local/quota-proxy/* root@your-server-ip:/opt/roc/quota-proxy/
```

#### 步骤 3：配置 Docker Compose

创建 `compose.yaml`：

```yaml
services:
  quota-proxy:
    build: .
    container_name: quota-proxy
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      - PORT=8787
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - SQLITE_PATH=/app/data/quota.db
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
    command: ["node", "server-sqlite.js"]
```

#### 步骤 4：启动服务

```bash
# 构建并启动
docker compose build
docker compose up -d

# 查看日志
docker compose logs -f
```

## API 使用示例

### 1. 获取试用密钥

```bash
# 申请试用密钥
curl -X POST http://localhost:8787/trial \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'

# 响应示例
# {"key": "trial_xxx", "expires_at": "2026-02-10T23:59:59Z", "quota": 100}
```

### 2. 使用 API 密钥访问

```bash
# 通过代理访问 DeepSeek API
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer trial_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 3. 管理员功能

```bash
# 查看使用情况
curl -H "Authorization: Bearer your-secret-admin-token" \
  http://localhost:8787/admin/usage

# 管理密钥
curl -H "Authorization: Bearer your-secret-admin-token" \
  http://localhost:8787/admin/keys

# 重置配额
curl -X POST -H "Authorization: Bearer your-secret-admin-token" \
  -H "Content-Type: application/json" \
  http://localhost:8787/admin/reset \
  -d '{"key": "trial_xxx", "quota": 100}'
```

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查 Docker 日志
   docker compose logs quota-proxy
   
   # 检查端口占用
   netstat -tlnp | grep 8787
   ```

2. **数据库权限问题**
   ```bash
   # 确保 data 目录可写
   chmod 777 data
   
   # 检查 SQLite 文件
   ls -la data/quota.db
   ```

3. **API 密钥无效**
   ```bash
   # 验证环境变量
   echo $DEEPSEEK_API_KEY
   echo $ADMIN_TOKEN
   
   # 重新设置
   export DEEPSEEK_API_KEY="sk-new-key"
   docker compose restart
   ```

### 健康检查

```bash
# 基础健康检查
curl -f http://localhost:8787/healthz

# 详细状态检查
./scripts/check-quota-proxy-status.sh

# 数据库健康检查
./scripts/verify-quota-db-health.sh
```

## 进阶配置

### 使用 Nginx 反向代理

```nginx
server {
    listen 80;
    server_name quota.yourdomain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 配置 HTTPS

```bash
# 使用 Let's Encrypt
certbot --nginx -d quota.yourdomain.com
```

### 监控和日志

```bash
# 查看实时日志
docker compose logs -f --tail=100

# 监控资源使用
docker stats quota-proxy

# 备份数据库
cp data/quota.db data/quota.db.backup.$(date +%Y%m%d)
```

## 相关资源

- [项目仓库](https://gitee.com/junkaiWang324/roc-ai-republic)
- [API 文档](./api-documentation.md)
- [管理员指南](./admin-guide.md)
- [故障排除手册](./troubleshooting.md)

## 获取帮助

如有问题，请：
1. 查看日志：`docker compose logs quota-proxy`
2. 检查健康状态：`curl http://localhost:8787/healthz`
3. 参考详细文档
4. 在论坛提问（如果已部署）

---

**最后更新：2026-02-09**  
**版本：v1.0**