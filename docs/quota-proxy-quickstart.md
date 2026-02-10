# Quota-Proxy 快速入门指南

本文档提供 quota-proxy 的快速入门指南，帮助用户快速部署和使用 API 配额代理服务。

## 1. 服务概述

quota-proxy 是一个轻量级的 API 配额代理服务，主要功能：

- **API 代理转发**：将请求转发到后端服务
- **配额管理**：基于密钥的 API 调用次数限制
- **使用统计**：记录每个密钥的使用情况
- **健康检查**：提供 `/healthz` 端点监控服务状态
- **管理接口**：通过 ADMIN_TOKEN 保护的管理功能

## 2. 快速部署

### 2.1 使用 Docker Compose 部署

```bash
# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/deploy/quota-proxy

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，设置 ADMIN_TOKEN 和数据库配置

# 启动服务
docker compose up -d

# 检查服务状态
docker compose ps
curl http://localhost:8787/healthz
```

### 2.2 环境变量配置

`.env` 文件示例：

```env
# 管理令牌（用于保护管理接口）
ADMIN_TOKEN=your-secure-admin-token-here

# 数据库配置（SQLite）
DATABASE_URL=file:/data/quota.db
# 或使用内存数据库（开发环境）
# DATABASE_URL=:memory:

# 日志级别
LOG_LEVEL=info

# 服务端口
PORT=8787
```

## 3. 基本使用

### 3.1 健康检查

```bash
# 检查服务健康状态
curl http://localhost:8787/healthz
# 预期响应：{"ok":true}
```

### 3.2 创建试用密钥

```bash
# 使用管理令牌创建试用密钥
ADMIN_TOKEN="your-admin-token"
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "trial-user-1",
    "quota": 1000,
    "expires_at": "2026-02-17T00:00:00Z"
  }'

# 响应示例：
# {
#   "key": "trial_abc123def456",
#   "name": "trial-user-1",
#   "quota": 1000,
#   "used": 0,
#   "expires_at": "2026-02-17T00:00:00Z",
#   "created_at": "2026-02-10T09:23:52Z"
# }
```

### 3.3 使用 API 密钥调用服务

```bash
# 使用 API 密钥调用代理服务
API_KEY="trial_abc123def456"
curl http://localhost:8787/proxy \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "endpoint": "https://api.example.com/v1/chat",
    "method": "POST",
    "body": {
      "message": "Hello, quota-proxy!"
    }
  }'

# 响应将包含后端服务的实际响应
```

### 3.4 查看使用情况

```bash
# 查看所有密钥使用情况
curl http://localhost:8787/admin/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查看特定密钥使用情况
curl "http://localhost:8787/admin/usage?key=trial_abc123def456" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 4. 管理功能

### 4.1 密钥管理

```bash
# 列出所有密钥
curl http://localhost:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 删除密钥
curl -X DELETE "http://localhost:8787/admin/keys/trial_abc123def456" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 4.2 重置配额

```bash
# 重置密钥配额
curl -X POST "http://localhost:8787/admin/keys/trial_abc123def456/reset" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "quota": 2000
  }'
```

## 5. 监控与维护

### 5.1 服务监控脚本

项目提供了多个监控脚本：

```bash
# 检查服务状态
./scripts/verify-sqlite-status.sh

# 测试管理接口
./scripts/test-admin-interface.sh

# 检查备份状态
./scripts/check-server-backup-status.sh

# 快速状态摘要
./scripts/backup-status-summary.sh
```

### 5.2 数据库备份

```bash
# 手动备份数据库
./scripts/backup-database.sh

# 配置自动备份
./scripts/configure-backup-alerts.sh
```

## 6. 故障排除

### 6.1 常见问题

**问题1：服务无法启动**
```bash
# 检查日志
docker compose logs quota-proxy

# 检查端口占用
netstat -tlnp | grep 8787
```

**问题2：管理接口返回 401**
```bash
# 确认 ADMIN_TOKEN 配置正确
echo $ADMIN_TOKEN

# 检查请求头格式
curl -v http://localhost:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

**问题3：数据库连接失败**
```bash
# 检查数据库文件权限
ls -la /data/quota.db

# 检查 SQLite 数据库完整性
sqlite3 /data/quota.db "PRAGMA integrity_check;"
```

### 6.2 获取帮助

- 查看详细文档：`docs/` 目录
- 运行验证脚本：`./scripts/verify-sqlite-status.sh --help`
- 检查服务配置：`./scripts/configure-sqlite-persistence.sh --check`

## 7. 下一步

- [ ] 配置 HTTPS 证书（使用 Caddy/Nginx）
- [ ] 设置监控告警（Prometheus + Alertmanager）
- [ ] 集成 CI/CD 流水线
- [ ] 添加多租户支持
- [ ] 实现使用量分析仪表板

---

**最后更新**：2026-02-10 17:24:00 CST  
**版本**：v0.1.0  
**状态**：生产就绪 ✅