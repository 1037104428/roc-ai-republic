# Quota-Proxy 本地测试指南

本文档介绍如何在本地环境中运行和测试 quota-proxy 服务，无需 Docker 环境。

## 1. 环境准备

### 1.1 安装 Node.js
确保已安装 Node.js 18+：
```bash
node --version
```

### 1.2 克隆仓库
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
git submodule update --init --recursive
```

## 2. 启动服务

### 2.1 安装依赖
```bash
cd quota-proxy
npm install
```

### 2.2 配置环境变量
创建 `.env` 文件：
```bash
cp .env.example .env
```

编辑 `.env` 文件，设置必要的配置：
```
PORT=3000
NODE_ENV=development
ADMIN_API_KEY=your-secret-admin-key-here
```

### 2.3 启动服务
```bash
npm start
# 或使用开发模式
npm run dev
```

服务将在 http://localhost:3000 启动。

## 3. API 测试

### 3.1 健康检查
```bash
curl http://localhost:3000/healthz
```

### 3.2 管理员 API 测试

#### 获取服务状态
```bash
curl -H "X-Admin-Key: your-secret-admin-key-here" \
  http://localhost:3000/admin/status
```

#### 手动发放试用密钥
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: your-secret-admin-key-here" \
  -d '{
    "userId": "test-user-001",
    "quota": 1000,
    "expiresIn": 86400
  }' \
  http://localhost:3000/admin/trial-keys
```

#### 查看所有试用密钥
```bash
curl -H "X-Admin-Key: your-secret-admin-key-here" \
  http://localhost:3000/admin/trial-keys
```

#### 查看使用情况统计
```bash
curl -H "X-Admin-Key: your-secret-admin-key-here" \
  http://localhost:3000/admin/usage
```

## 4. 客户端使用测试

### 4.1 使用试用密钥访问 API
```bash
# 首先获取一个试用密钥（使用上面发放的密钥）
TRIAL_KEY="your-trial-key-here"

# 测试配额消耗
curl -H "X-Trial-Key: $TRIAL_KEY" \
  http://localhost:3000/api/test
```

### 4.2 检查剩余配额
```bash
curl -H "X-Trial-Key: $TRIAL_KEY" \
  http://localhost:3000/api/quota
```

## 5. 常见问题排查

### 5.1 服务启动失败
- 检查端口是否被占用：`lsof -i :3000`
- 检查 Node.js 版本：需要 18+
- 检查依赖安装：`npm list` 查看是否有错误

### 5.2 API 返回 401 错误
- 检查管理员密钥是否正确
- 检查请求头格式：`X-Admin-Key` 必须正确设置
- 检查环境变量配置

### 5.3 数据库连接问题
- 检查 SQLite 数据库文件权限
- 检查数据库迁移状态：`npm run migrate`

## 6. 自动化测试脚本

创建测试脚本 `test-local.sh`：
```bash
#!/bin/bash

# 测试健康检查
echo "测试健康检查..."
curl -s http://localhost:3000/healthz | jq .

# 测试管理员 API
echo "测试管理员状态..."
curl -s -H "X-Admin-Key: $ADMIN_KEY" \
  http://localhost:3000/admin/status | jq .

# 发放试用密钥
echo "发放试用密钥..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: $ADMIN_KEY" \
  -d '{"userId": "test-$(date +%s)", "quota": 100, "expiresIn": 3600}' \
  http://localhost:3000/admin/trial-keys)

echo $RESPONSE | jq .
```

## 7. 下一步

完成本地测试后，可以：
1. 编写更详细的 API 文档
2. 创建 Docker 部署配置
3. 设置 CI/CD 自动化测试
4. 集成到生产环境