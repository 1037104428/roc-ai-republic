# Admin API 快速部署指南

## 概述
本文档提供 Admin API 的快速部署指南，帮助用户在 5 分钟内完成 Admin API 的部署和验证。

## 前置条件
- Node.js 18+ 已安装
- SQLite3 已安装（通常 Node.js 自带）
- 基本的命令行操作能力

## 快速部署步骤

### 1. 环境准备
```bash
# 进入项目目录
cd /path/to/roc-ai-republic/quota-proxy

# 安装依赖
npm install sqlite3 express cors dotenv
```

### 2. 配置环境变量
```bash
# 复制环境变量示例文件
cp .env.example .env

# 编辑 .env 文件，设置以下变量：
# ADMIN_TOKEN=your-secure-admin-token-here
# PORT=8787
# DATABASE_PATH=./quota.db
```

### 3. 启动 Admin API 服务器
```bash
# 启动服务器
node server-sqlite-admin.js

# 或者使用后台模式
nohup node server-sqlite-admin.js > admin-api.log 2>&1 &
```

### 4. 验证部署
```bash
# 使用快速验证脚本
./quick-verify-admin-api.sh

# 或者手动验证
curl -fsS http://127.0.0.1:8787/healthz
```

## 一键式部署脚本

### 完整部署脚本
创建 `deploy-admin-api.sh`：
```bash
#!/bin/bash
set -e

echo "=== Admin API 一键部署脚本 ==="

# 1. 检查环境
echo "1. 检查环境..."
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未安装"
    exit 1
fi

if ! command -v sqlite3 &> /dev/null; then
    echo "警告: SQLite3 未安装，尝试安装..."
    sudo apt-get install -y sqlite3 || echo "请手动安装 SQLite3"
fi

# 2. 安装依赖
echo "2. 安装依赖..."
npm install sqlite3 express cors dotenv

# 3. 配置环境
echo "3. 配置环境..."
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "已创建 .env 文件，请编辑设置 ADMIN_TOKEN"
    else
        echo "ADMIN_TOKEN=your-secure-admin-token-here" > .env
        echo "PORT=8787" >> .env
        echo "DATABASE_PATH=./quota.db" >> .env
        echo "已创建 .env 文件，请编辑设置 ADMIN_TOKEN"
    fi
fi

# 4. 启动服务器
echo "4. 启动 Admin API 服务器..."
node server-sqlite-admin.js &
SERVER_PID=$!

# 5. 等待服务器启动
echo "5. 等待服务器启动..."
sleep 3

# 6. 验证部署
echo "6. 验证部署..."
if curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1; then
    echo "✅ Admin API 部署成功！"
    echo "服务器 PID: $SERVER_PID"
    echo "健康检查: http://127.0.0.1:8787/healthz"
else
    echo "❌ Admin API 部署失败"
    kill $SERVER_PID 2>/dev/null
    exit 1
fi

echo "=== 部署完成 ==="
```

### 使用一键部署脚本
```bash
# 添加执行权限
chmod +x deploy-admin-api.sh

# 运行部署脚本
./deploy-admin-api.sh
```

## Docker 部署（可选）

### Dockerfile
```dockerfile
FROM node:18-alpine

WORKDIR /app

# 复制文件
COPY package*.json ./
COPY server-sqlite-admin.js ./
COPY .env ./

# 安装依赖
RUN npm install --production

# 暴露端口
EXPOSE 8787

# 启动命令
CMD ["node", "server-sqlite-admin.js"]
```

### Docker Compose 配置
```yaml
version: '3.8'

services:
  admin-api:
    build: .
    ports:
      - "8787:8787"
    environment:
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - PORT=8787
      - DATABASE_PATH=/data/quota.db
    volumes:
      - ./data:/data
    restart: unless-stopped
```

### Docker 部署命令
```bash
# 构建镜像
docker build -t roc-admin-api .

# 运行容器
docker run -d \
  --name roc-admin-api \
  -p 8787:8787 \
  -e ADMIN_TOKEN=your-secure-token \
  -v $(pwd)/data:/data \
  roc-admin-api
```

## 验证和测试

### 基本验证
```bash
# 健康检查
curl -fsS http://127.0.0.1:8787/healthz

# Admin 认证测试
curl -H "Authorization: Bearer your-admin-token" \
  http://127.0.0.1:8787/admin/keys

# 生成 Trial Key
curl -X POST -H "Authorization: Bearer your-admin-token" \
  -H "Content-Type: application/json" \
  -d '{"quota": 1000, "expiresIn": 86400}' \
  http://127.0.0.1:8787/admin/keys
```

### 使用验证脚本
```bash
# 快速验证
./quick-verify-admin-api.sh

# 详细验证
./verify-admin-api.sh
```

## 监控和维护

### 查看日志
```bash
# 查看实时日志
tail -f admin-api.log

# 查看错误日志
grep -i error admin-api.log
```

### 数据库维护
```bash
# 备份数据库
cp quota.db quota.db.backup.$(date +%Y%m%d)

# 检查数据库状态
sqlite3 quota.db "SELECT COUNT(*) as total_keys FROM api_keys;"
```

### 性能监控
```bash
# 使用性能检查脚本
./check-admin-performance.sh
```

## 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 检查端口占用
   lsof -i :8787
   
   # 杀死占用进程
   kill $(lsof -t -i:8787)
   ```

2. **Admin Token 错误**
   ```bash
   # 重新生成 Token
   echo "ADMIN_TOKEN=$(openssl rand -hex 32)" >> .env
   ```

3. **数据库权限问题**
   ```bash
   # 修复数据库权限
   chmod 644 quota.db
   ```

4. **依赖安装失败**
   ```bash
   # 清理并重新安装
   rm -rf node_modules package-lock.json
   npm cache clean --force
   npm install
   ```

### 获取帮助
- 查看详细文档：`ADMIN-API-GUIDE.md`
- 使用验证脚本：`./verify-admin-api.sh --help`
- 检查日志文件：`admin-api.log`

## 更新日志

### v1.0.0 (2026-02-12)
- 初始版本发布
- 包含完整的 Admin API 快速部署指南
- 提供一键部署脚本
- 支持 Docker 部署
- 包含完整的验证和故障排除指南

## 下一步
- [ ] 配置 HTTPS 支持
- [ ] 添加 Prometheus 监控
- [ ] 实现数据库自动备份
- [ ] 添加 API 文档自动生成

---

**提示**：部署完成后，建议运行 `./quick-verify-admin-api.sh` 进行完整验证。