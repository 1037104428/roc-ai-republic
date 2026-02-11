# Admin API 测试环境配置指南

本文档提供 Admin API 测试环境的快速配置指南，帮助用户快速设置环境变量和启动测试。

## 快速开始

### 1. 环境变量配置

创建 `.env.test` 文件：

```bash
# 必需环境变量
ADMIN_TOKEN=your-secure-admin-token-here
DATABASE_URL=sqlite:///./quota.db
PORT=8787

# 可选环境变量
LOG_LEVEL=info
CORS_ORIGIN=*
MAX_REQUESTS_PER_KEY=1000
KEY_EXPIRY_DAYS=30
```

或者使用快速设置脚本：

```bash
# 生成随机管理员令牌
export ADMIN_TOKEN=$(openssl rand -hex 32)
export DATABASE_URL="sqlite:///./quota.db"
export PORT=8787

# 保存到 .env 文件
cat > .env << EOF
ADMIN_TOKEN=$ADMIN_TOKEN
DATABASE_URL=$DATABASE_URL
PORT=$PORT
EOF
```

### 2. 启动服务

使用 Docker Compose 启动服务：

```bash
# 启动服务
docker compose up -d

# 检查服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

或者直接运行：

```bash
# 安装依赖
npm install

# 启动服务
npm start
```

### 3. 验证服务状态

```bash
# 健康检查
curl -fsS http://localhost:8787/healthz

# 版本信息
curl -fsS http://localhost:8787/version
```

## 测试环境配置示例

### 开发环境配置

```bash
# .env.development
ADMIN_TOKEN=dev-admin-token-123
DATABASE_URL=sqlite:///./quota-dev.db
PORT=8787
LOG_LEVEL=debug
CORS_ORIGIN=*
```

### 测试环境配置

```bash
# .env.test
ADMIN_TOKEN=test-admin-token-456
DATABASE_URL=sqlite:///./quota-test.db
PORT=8788
LOG_LEVEL=info
MAX_REQUESTS_PER_KEY=100
KEY_EXPIRY_DAYS=7
```

### 生产环境配置

```bash
# .env.production
ADMIN_TOKEN=$(openssl rand -hex 64)
DATABASE_URL=postgresql://user:password@localhost:5432/quota_production
PORT=80
LOG_LEVEL=warn
CORS_ORIGIN=https://your-domain.com
```

## 测试脚本使用

### 1. 环境变量验证

```bash
# 验证环境变量配置
./verify-env-vars.sh

# 输出示例：
# ✅ 必需环境变量检查通过
# ⚠️  可选环境变量未设置
# 📊 验证报告：通过 3/3，警告 2/5
```

### 2. Admin API 完整功能验证

```bash
# 设置环境变量
export ADMIN_TOKEN=your-token
export DATABASE_URL=sqlite:///./quota.db

# 运行完整验证
./verify-admin-api-complete.sh

# 快速验证模式
./verify-admin-api-complete.sh --quick
```

### 3. 快速测试示例

```bash
# 一键测试所有 Admin API 功能
./quick-admin-api-test.sh

# 输出示例：
# ✅ 服务健康检查通过
# ✅ POST /admin/keys 测试通过
# ✅ GET /admin/usage 测试通过
# 📊 所有测试通过！
```

## 故障排除

### 常见问题

1. **环境变量未生效**
   ```bash
   # 检查环境变量
   echo $ADMIN_TOKEN
   
   # 重新加载环境文件
   source .env
   ```

2. **服务启动失败**
   ```bash
   # 检查端口占用
   lsof -i :8787
   
   # 检查数据库文件权限
   ls -la quota.db
   ```

3. **API 测试失败**
   ```bash
   # 检查服务日志
   docker compose logs quota-proxy
   
   # 手动测试端点
   curl -v -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8787/admin/keys
   ```

### 调试模式

启用详细日志：

```bash
export LOG_LEVEL=debug
docker compose restart quota-proxy
```

## 集成测试

### CI/CD 环境配置

GitHub Actions 示例：

```yaml
env:
  ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
  DATABASE_URL: sqlite:///./quota-test.db
  PORT: 8787
```

### 自动化测试脚本

```bash
#!/bin/bash
# run-admin-api-tests.sh

set -e

# 设置测试环境
export ADMIN_TOKEN="test-token-$(date +%s)"
export DATABASE_URL="sqlite:///./test-$(date +%s).db"
export PORT=8787

# 启动服务
docker compose up -d
sleep 5

# 运行测试
./verify-env-vars.sh
./verify-admin-api-complete.sh
./quick-admin-api-test.sh

# 清理
docker compose down
rm -f test-*.db
```

## 最佳实践

1. **使用不同的令牌**：开发、测试、生产环境使用不同的管理员令牌
2. **定期轮换令牌**：定期更新管理员令牌增强安全性
3. **环境隔离**：不同环境使用不同的数据库文件
4. **日志监控**：监控 API 访问日志和安全事件
5. **备份配置**：定期备份环境配置文件

## 相关文档

- [Admin API 快速测试示例](./ADMIN-API-QUICK-TEST-EXAMPLES.md)
- [环境变量验证脚本](./verify-env-vars.sh)
- [Admin API 完整功能验证脚本](./verify-admin-api-complete.sh)
- [快速 Admin API 测试脚本](./quick-admin-api-test.sh)
- [验证工具索引](./VALIDATION-TOOLS-INDEX.md)

---

**更新日期**: 2026-02-12  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组