# Quota Proxy 快速开始指南

本文档提供 quota-proxy 的快速上手指南，帮助您在5分钟内启动并运行服务。

## 1. 启动服务

### 选项1：使用SQLite持久化版本（推荐）

```bash
cd /path/to/roc-ai-republic/quota-proxy

# 启动SQLite持久化服务器
./start-sqlite-persistent.sh

# 或者带自定义配置启动
ADMIN_TOKEN="my-secret-token" \
DATABASE_PATH="./quota.db" \
PORT=8787 \
./start-sqlite-persistent.sh
```

### 选项2：使用内存版本（仅测试）

```bash
cd /path/to/roc-ai-republic/quota-proxy

# 启动内存版本
./start-memory.sh
```

## 2. 验证服务状态

```bash
# 快速健康检查
./quick-sqlite-health-check.sh

# 或者手动检查
curl -s http://localhost:8787/healthz
```

## 3. 获取管理员令牌

首次启动时，服务器会显示管理员令牌：

```
[INFO] Admin token: admin_abc123def456ghi789
[INFO] 请保存此令牌用于管理操作
```

如果忘记令牌，可以查看启动日志或重新启动服务。

## 4. 生成试用密钥

```bash
# 设置环境变量
export BASE_URL="http://localhost:8787"
export ADMIN_TOKEN="admin_abc123def456ghi789"  # 替换为实际令牌

# 生成单个试用密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "新用户试用"}'

# 生成5个批量密钥
curl -s -X POST "$BASE_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"count": 5, "label": "批量用户", "prefix": "batch_"}'
```

## 5. 使用试用密钥

```bash
# 设置试用密钥
export TRIAL_KEY="trial_abc123def456ghi789"

# 检查配额
curl -s "$BASE_URL/quota?key=$TRIAL_KEY"

# 使用API（消耗配额）
curl -s -X POST "$BASE_URL/use" \
  -H "Content-Type: application/json" \
  -d '{"key": "'"$TRIAL_KEY"'", "service": "ai-chat"}'
```

## 6. 查看使用统计

```bash
# 管理员查看所有密钥使用情况
curl -s "$BASE_URL/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查看特定密钥使用情况
curl -s "$BASE_URL/admin/usage?key=trial_abc123def456ghi789" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 7. 停止服务

```bash
# 查找并停止进程
pkill -f "node.*server-sqlite-persistent.js" || true
pkill -f "node.*server-memory.js" || true

# 或者使用CTRL+C停止正在运行的服务
```

## 8. 故障排除

### 服务无法启动
- 检查Node.js版本：`node --version`（需要Node.js 14+）
- 检查端口占用：`lsof -i :8787`
- 查看日志：检查启动脚本的输出

### API调用失败
- 验证服务是否运行：`curl -s http://localhost:8787/healthz`
- 检查管理员令牌是否正确
- 检查JSON格式是否正确

### 数据库问题
- 检查数据库文件权限：`ls -la quota.db`
- 重置数据库：删除`quota.db`文件并重启服务

## 9. 下一步

- 查看[SQLITE-PERSISTENT-GUIDE.md](./SQLITE-PERSISTENT-GUIDE.md)获取高级配置
- 查看[ADMIN-API-EXAMPLES.md](./ADMIN-API-EXAMPLES.md)获取完整API示例
- 查看[QUICK-SQLITE-HEALTH-CHECK.md](./QUICK-SQLITE-HEALTH-CHECK.md)获取运维工具

## 支持与反馈

如有问题，请查看相关文档或联系维护团队。