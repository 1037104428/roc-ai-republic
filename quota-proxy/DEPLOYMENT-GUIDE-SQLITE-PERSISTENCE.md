# SQLite持久化部署指南

## 概述

本指南详细说明如何部署具有SQLite持久化功能的quota-proxy系统，包括完整的API密钥管理、试用密钥生成和使用统计功能。

## 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    quota-proxy with SQLite                   │
├─────────────────────────────────────────────────────────────┤
│  API端点:                                                   │
│  • /admin/keys        - 管理API密钥（创建、列表、删除）     │
│  • /admin/keys/trial  - 生成试用密钥（7天有效期，100次限额）│
│  • /admin/usage       - 查看使用统计（分页、过滤）          │
│  • /admin/stats       - 系统统计信息                        │
│  • /admin/performance - 数据库性能监控                      │
│  • /admin/audit-logs  - 审计日志                            │
│  • /admin/reset-usage - 重置使用统计                        │
├─────────────────────────────────────────────────────────────┤
│  数据库: SQLite3                                            │
│  • api_keys表 - 存储API密钥和配额信息                      │
│  • usage_log表 - 存储API使用日志                           │
├─────────────────────────────────────────────────────────────┤
│  安全特性:                                                  │
│  • ADMIN_TOKEN保护的管理端点                               │
│  • IP白名单（可选）                                         │
│  • 速率限制                                                │
│  • 审计日志                                                │
└─────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 环境准备

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy

# 安装依赖
npm install

# 创建环境变量文件
cp .env.example .env
```

### 2. 配置环境变量

编辑 `.env` 文件：

```env
# 服务器配置
PORT=8787
HOST=127.0.0.1

# 数据库配置
DB_PATH=./data/quota-proxy.db  # 使用文件数据库替代内存数据库
# DB_PATH=:memory:             # 内存数据库（测试用）

# 安全配置
ADMIN_TOKEN=your-secure-admin-token-change-this
ADMIN_IP_WHITELIST=127.0.0.1,::1  # 可选，逗号分隔的IP列表

# 配额配置
DEFAULT_DAILY_LIMIT=1000
DEFAULT_MONTHLY_LIMIT=30000
API_KEY_PREFIX=roc_

# 日志配置
LOG_LEVEL=info
```

### 3. 初始化数据库

```bash
# 创建数据目录
mkdir -p data

# 运行数据库初始化脚本
./init-sqlite-db.sh

# 验证数据库
./init-sqlite-db.sh --verify
```

### 4. 启动服务器

```bash
# 使用SQLite持久化版本
node server-sqlite.js

# 或使用Docker Compose
docker-compose up -d
```

### 5. 验证部署

```bash
# 快速健康检查
./quick-health-check.sh

# 完整API验证
./verify-admin-api-complete.sh

# 试用密钥生成验证
./verify-trial-key-api.sh

# 使用统计验证
./verify-admin-keys-usage.sh
```

## 核心功能详解

### 1. SQLite持久化

系统使用SQLite3提供数据持久化，支持：

- **文件数据库**：数据持久保存到磁盘
- **内存数据库**：高性能测试环境
- **自动表创建**：启动时自动创建所需表结构
- **数据库备份**：支持定期备份和恢复

### 2. 试用密钥生成

端点：`POST /admin/keys/trial`

功能特性：
- 无需认证即可生成试用密钥
- 每个IP每小时限制3个试用密钥
- 7天有效期，100次API调用限额
- 自动过期清理

示例请求：
```bash
curl -X POST http://localhost:8787/admin/keys/trial
```

响应示例：
```json
{
  "success": true,
  "key": "roc_trial_1739289600000-abc123def",
  "label": "Trial Key - 2026-02-11",
  "totalQuota": 100,
  "expiresAt": "2026-02-18T19:35:53.000Z",
  "id": 1,
  "note": "This is a trial key valid for 7 days with 100 API calls limit.",
  "usageUrl": "http://127.0.0.1:8787/admin/usage?key=roc_trial_1739289600000-abc123def"
}
```

### 3. 使用统计

端点：`GET /admin/usage`

功能特性：
- 需要ADMIN_TOKEN认证
- 支持分页查询（默认每页50条）
- 支持按API密钥过滤
- 支持时间范围过滤（默认最近7天）
- 包含请求统计和响应时间分析

示例请求：
```bash
# 查看所有密钥的使用统计（第1页）
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/usage?page=1&limit=20"

# 查看特定密钥的使用统计
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/usage?key=roc_trial_1739289600000-abc123def&days=30"
```

### 4. 管理员密钥管理

端点：`POST /admin/keys`

功能特性：
- 创建新的API密钥
- 设置自定义标签和配额
- 支持设置过期时间

示例请求：
```bash
curl -X POST \
  -H "Authorization: Bearer your-admin-token" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "生产环境API密钥",
    "totalQuota": 10000,
    "expiresAt": "2026-12-31T23:59:59.000Z"
  }' \
  http://localhost:8787/admin/keys
```

## 生产环境部署

### 1. 使用Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  quota-proxy:
    build: .
    ports:
      - "8787:8787"
    environment:
      - PORT=8787
      - HOST=0.0.0.0
      - DB_PATH=/app/data/quota-proxy.db
      - ADMIN_TOKEN=${ADMIN_TOKEN}
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    restart: unless-stopped
```

### 2. 使用Systemd服务

创建 `/etc/systemd/system/quota-proxy.service`：

```ini
[Unit]
Description=Quota Proxy with SQLite Persistence
After=network.target

[Service]
Type=simple
User=quota-proxy
WorkingDirectory=/opt/quota-proxy
EnvironmentFile=/etc/quota-proxy/.env
ExecStart=/usr/bin/node server-sqlite.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 3. 数据库备份策略

配置定期备份：

```bash
# 每日备份
0 2 * * * /opt/quota-proxy/backup-sqlite-db.sh --backup-dir /backups --keep-days 30
```

## 监控和维护

### 1. 健康检查

```bash
# 基本健康检查
curl -f http://localhost:8787/healthz

# 详细状态检查
curl http://localhost:8787/status
```

### 2. 性能监控

```bash
# 查看数据库性能统计
curl -H "Authorization: Bearer your-admin-token" \
  http://localhost:8787/admin/performance

# 查看系统统计
curl -H "Authorization: Bearer your-admin-token" \
  http://localhost:8787/admin/stats
```

### 3. 日志管理

```bash
# 查看审计日志
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/audit-logs?limit=100"

# 重置使用统计（谨慎使用）
curl -X POST \
  -H "Authorization: Bearer your-admin-token" \
  http://localhost:8787/admin/reset-usage
```

## 故障排除

### 常见问题

1. **数据库连接失败**
   ```bash
   # 检查数据库文件权限
   ls -la data/quota-proxy.db
   
   # 修复权限
   chown -R quota-proxy:quota-proxy data/
   ```

2. **管理员认证失败**
   ```bash
   # 验证ADMIN_TOKEN
   echo $ADMIN_TOKEN
   
   # 重新生成令牌
   openssl rand -hex 32
   ```

3. **试用密钥生成限制**
   ```bash
   # 检查IP限制
   curl -X POST http://localhost:8787/admin/keys/trial
   
   # 等待1小时或使用不同IP
   ```

### 调试模式

```bash
# 启用详细日志
export LOG_LEVEL=debug
node server-sqlite.js

# 查看实时日志
tail -f logs/quota-proxy.log
```

## 安全建议

1. **定期更换ADMIN_TOKEN**
2. **配置IP白名单限制管理端点访问**
3. **启用HTTPS（生产环境必需）**
4. **定期备份数据库**
5. **监控异常访问模式**
6. **设置合理的配额限制**

## 相关文档

- [快速健康检查指南](./QUICK-HEALTH-CHECK.md)
- [API完整性验证指南](./VERIFY_ADMIN_API_COMPLETE.md)
- [数据库备份指南](./BACKUP_SQLITE_DB.md)
- [部署验证指南](./DEPLOY-VERIFICATION.md)
- [安装兼容性验证](./VERIFY_INSTALL_COMPATIBILITY.md)

## 支持与贡献

如有问题或建议，请：
1. 查看现有文档和脚本
2. 运行验证脚本诊断问题
3. 提交Issue到项目仓库
4. 参与贡献改进代码和文档

---

**最后更新**: 2026-02-11 19:35:53 CST  
**版本**: 1.0.0  
**状态**: 生产就绪