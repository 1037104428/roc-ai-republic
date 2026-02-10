# 审计日志功能指南

## 概述

审计日志功能用于记录所有 Admin API 操作，提供完整的操作追踪能力。这对于安全审计、故障排查和合规性要求非常重要。

## 功能特性

1. **自动记录**: 所有 Admin API 操作自动记录
2. **操作类型识别**: 自动识别操作类型（CREATE_KEY, UPDATE_KEY, DELETE_KEY 等）
3. **隐私保护**: 管理员令牌存储为哈希值，保护敏感信息
4. **查询接口**: 提供分页查询和过滤功能
5. **性能优化**: 数据库索引确保高效查询

## 数据库表结构

```sql
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    ip TEXT NOT NULL,                    -- 客户端IP地址
    method TEXT NOT NULL,                -- HTTP方法 (GET, POST, PUT, DELETE)
    path TEXT NOT NULL,                  -- 请求路径
    action TEXT NOT NULL,                -- 操作类型
    key_affected TEXT,                   -- 受影响的API密钥
    admin_token_hash TEXT,               -- 管理员令牌哈希（前16位）
    details TEXT                         -- 操作详情（JSON格式）
);
```

## 支持的操作类型

| 操作类型 | 描述 | 触发条件 |
|---------|------|----------|
| CREATE_KEY | 创建新密钥 | POST /admin/keys |
| LIST_KEYS | 列出所有密钥 | GET /admin/keys |
| DELETE_KEY | 删除密钥 | DELETE /admin/keys/:key |
| UPDATE_KEY | 更新密钥标签 | PUT /admin/keys/:key |
| VIEW_USAGE | 查看使用情况 | GET /admin/usage |
| RESET_USAGE | 重置使用统计 | POST /admin/reset-usage |
| VIEW_PERFORMANCE | 查看性能指标 | GET /admin/performance |
| OTHER_ADMIN_ACTION | 其他管理操作 | 其他 Admin API 路径 |

## 快速验证

要快速验证审计日志功能是否正常工作，可以使用以下命令：

```bash
# 本地验证
./scripts/verify-audit-log.sh --local

# 远程验证（针对已部署的服务器）
./scripts/verify-audit-log.sh --remote 8.210.185.194:8787
```

验证脚本会：
1. 创建一个测试密钥
2. 查询使用情况
3. 检查审计日志中是否记录了这些操作
4. 清理测试数据

## API 端点

### GET /admin/audit-logs

查询审计日志，需要管理员认证。

**查询参数**:
- `limit` (可选): 返回记录数，默认 100
- `offset` (可选): 偏移量，默认 0
- `action` (可选): 过滤特定操作类型

**响应示例**:
```json
{
  "logs": [
    {
      "id": 1,
      "timestamp": "2026-02-10 10:45:23",
      "ip": "127.0.0.1",
      "method": "POST",
      "path": "/admin/keys",
      "action": "CREATE_KEY",
      "key_affected": "sk-1770657123456-abc123def",
      "admin_token_hash": "a1b2c3d4e5f67890",
      "details": "{\"label\":\"测试密钥\"}"
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 100,
    "offset": 0,
    "hasMore": true
  }
}
```

## 使用方法

### 1. 本地测试

```bash
# 启动本地服务器
cd quota-proxy
npm start

# 在另一个终端运行验证脚本
./scripts/verify-audit-log.sh --local
```

### 2. 远程服务器测试

```bash
# 测试远程服务器
./scripts/verify-audit-log.sh --remote 8.210.185.194:8787
```

### 3. 手动查询审计日志

```bash
# 设置管理员令牌
export ADMIN_TOKEN="86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d"

# 查询最近的10条日志
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://8.210.185.194:8787/admin/audit-logs?limit=10"

# 查询特定操作类型的日志
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://8.210.185.194:8787/admin/audit-logs?action=CREATE_KEY&limit=5"
```

## 验证脚本

提供了完整的验证脚本 `scripts/verify-audit-log.sh`，可以自动测试审计日志功能：

```bash
# 查看帮助
./scripts/verify-audit-log.sh --help

# 本地测试
./scripts/verify-audit-log.sh --local

# 远程测试
./scripts/verify-audit-log.sh --remote 8.210.185.194:8787
```

## 部署注意事项

1. **数据库持久化**: 确保 `/data/quota.db` 目录已正确挂载为 Docker 数据卷
2. **存储空间**: 审计日志会持续增长，建议定期清理或归档旧日志
3. **性能影响**: 审计日志记录对性能影响很小，但大量日志查询可能影响性能
4. **安全考虑**: 审计日志包含敏感操作信息，应妥善保护访问权限

## 故障排查

### 常见问题

1. **审计日志表未创建**
   - 检查服务器启动日志是否有 "Audit log table initialized" 消息
   - 检查数据库文件权限

2. **查询返回空结果**
   - 确认有 Admin API 操作发生
   - 检查管理员令牌是否正确

3. **性能问题**
   - 确保数据库索引已创建
   - 考虑定期归档旧日志

### 日志位置

审计日志存储在 SQLite 数据库的 `audit_log` 表中，可以通过以下命令查看：

```bash
# 连接到数据库
sqlite3 /data/quota.db

# 查看表结构
.schema audit_log

# 查看最近10条记录
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 10;
```

## 更新记录

- 2026-02-10: 初始版本，包含基本审计日志功能和验证脚本

