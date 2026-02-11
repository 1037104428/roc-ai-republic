# 环境变量配置指南

本文档提供 Quota Proxy 环境变量配置的详细说明和最佳实践。

## 快速开始

### 1. 复制配置文件
```bash
cp .env.example .env
```

### 2. 编辑配置
```bash
nano .env  # 或使用你喜欢的编辑器
```

### 3. 验证配置
```bash
./verify-env-example.sh
```

### 4. 启动服务
```bash
docker compose up -d
```

## 配置项说明

### 数据库配置
- **DATABASE_URL**: 数据库连接字符串
  - SQLite: `sqlite:///data/quota.db`
  - PostgreSQL: `postgresql://user:password@localhost:5432/quota_proxy`
  - MySQL: `mysql://user:password@localhost:3306/quota_proxy`

### 服务器配置
- **HOST**: 绑定地址 (默认: `0.0.0.0`)
- **PORT**: 监听端口 (默认: `8787`)
- **LOG_LEVEL**: 日志级别 (`debug`, `info`, `warn`, `error`)

### 安全配置
- **ADMIN_TOKEN**: 管理接口令牌 (必须修改!)
- **JWT_SECRET**: JWT 签名密钥 (必须修改!)

### 试用密钥配置
- **TRIAL_KEY_PREFIX**: 试用密钥前缀 (默认: `TRIAL_`)
- **TRIAL_KEY_EXPIRY_DAYS**: 试用密钥有效期 (天)
- **TRIAL_REQUESTS_LIMIT**: 试用请求限制

### 模型配置
- **MODEL_PROVIDERS**: 支持的模型提供商
- **DEFAULT_MODEL**: 默认模型

### 速率限制
- **RATE_LIMIT_REQUESTS_PER_MINUTE**: 每分钟请求限制
- **RATE_LIMIT_TOKENS_PER_MINUTE**: 每分钟令牌限制

## 环境配置示例

### 开发环境
```bash
# 开发环境配置
DATABASE_URL=sqlite:///data/quota.db
HOST=127.0.0.1
PORT=8787
LOG_LEVEL=debug
ADMIN_TOKEN=dev-admin-token
JWT_SECRET=dev-jwt-secret
```

### 生产环境
```bash
# 生产环境配置
DATABASE_URL=postgresql://prod_user:StrongPassword123@db.example.com:5432/quota_prod
HOST=0.0.0.0
PORT=80
LOG_LEVEL=info
ADMIN_TOKEN=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
```

## 最佳实践

### 1. 密钥管理
- 使用强密码生成器生成密钥
- 定期轮换密钥
- 不要将密钥提交到版本控制

### 2. 数据库配置
- 生产环境使用 PostgreSQL 或 MySQL
- 配置连接池
- 启用 SSL/TLS 加密

### 3. 安全配置
- 使用 HTTPS 反向代理
- 配置防火墙规则
- 启用访问日志

### 4. 监控配置
- 配置指标导出
- 设置告警规则
- 定期备份数据

## 故障排除

### 常见问题

#### 1. 配置不生效
- 检查 `.env` 文件权限
- 确认服务已重启
- 查看日志文件

#### 2. 数据库连接失败
- 检查数据库服务状态
- 验证连接字符串
- 检查网络连通性

#### 3. 密钥验证失败
- 确认 ADMIN_TOKEN 正确
- 检查 JWT_SECRET 配置
- 查看认证日志

### 验证脚本
使用验证脚本检查配置完整性：
```bash
./verify-env-example.sh
./verify-env-example.sh --demo
```

## 相关文档

- [快速部署指南](./QUICK_DEPLOYMENT_GUIDE.md)
- [管理 API 文档](./API_DOCUMENTATION.md)
- [SQLite 示例](./SQLITE_EXAMPLE_USAGE.md)

## 版本历史

- v1.0.0 (2026-02-11): 初始版本，提供基础环境变量配置
