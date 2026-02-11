# SQLite 持久化配额代理指南

## 概述

`server-sqlite-persistent.js` 是一个完整的配额代理服务器，使用 SQLite 数据库进行试用密钥和使用统计的持久化存储。相比 JSON 文件存储，SQLite 提供了更好的数据一致性、并发支持和查询性能。

## 主要特性

- **SQLite 持久化**: 试用密钥和使用统计数据存储在 SQLite 数据库中
- **完整的 CRUD 操作**: 创建、读取、更新、删除试用密钥
- **使用统计跟踪**: 按天跟踪每个试用密钥的使用情况
- **配额强制执行**: 基于每日限额的配额检查
- **管理员保护**: 所有管理端点都需要 ADMIN_TOKEN
- **向后兼容**: 与现有配额代理 API 兼容

## 快速开始

### 1. 启动服务器

```bash
# 设置必需的环境变量
export DEEPSEEK_API_KEY="your-deepseek-api-key"
export ADMIN_TOKEN="your-secure-admin-token"

# 启动服务器
cd quota-proxy
./start-sqlite-persistent.sh
```

或者使用启动脚本自动生成管理员令牌：

```bash
cd quota-proxy
DEEPSEEK_API_KEY="your-key" ./start-sqlite-persistent.sh
```

### 2. 验证安装

```bash
# 干运行模式验证
./verify-sqlite-persistent-api.sh --dry-run

# 实际验证（需要服务器运行）
./verify-sqlite-persistent-api.sh --admin-token "your-admin-token"
```

## 数据库结构

### trial_keys 表
存储试用密钥信息：
- `key`: 试用密钥 (主键)
- `label`: 密钥标签/描述
- `created_at`: 创建时间戳
- `daily_limit`: 每日请求限额
- `is_active`: 是否激活 (1=激活, 0=停用)

### usage_stats 表
存储使用统计：
- `id`: 自增 ID (主键)
- `trial_key`: 试用密钥 (外键)
- `day`: 日期 (YYYY-MM-DD 格式)
- `requests`: 请求次数
- `updated_at`: 最后更新时间戳

## API 端点

### 公共端点

#### GET /healthz
健康检查端点。

**响应**:
```json
{"ok": true}
```

#### GET /v1/models
获取可用模型列表（透传到 DeepSeek API）。

#### POST /v1/chat/completions
聊天补全端点，包含配额检查。

**请求头**:
- `Authorization: Bearer <trial_key>` 或 `X-Trial-Key: <trial_key>`

**配额检查**:
1. 验证试用密钥是否存在且激活
2. 检查当日使用量是否超过限额
3. 如果通过，递增使用计数并转发请求

### 管理员端点 (需要 ADMIN_TOKEN)

#### POST /admin/keys
生成新的试用密钥。

**请求头**:
- `Authorization: Bearer <ADMIN_TOKEN>` 或 `X-Admin-Token: <ADMIN_TOKEN>`

**请求体**:
```json
{
  "label": "测试用户",
  "daily_limit": 100
}
```

**响应**:
```json
{
  "key": "roc_7d9f8e7c6b5a4d3c2b1a0f9e8d7c6b5a",
  "label": "测试用户",
  "created_at": 1739299200000,
  "daily_limit": 100
}
```

#### GET /admin/keys
列出所有试用密钥。

**响应**:
```json
[
  {
    "key": "roc_7d9f8e7c6b5a4d3c2b1a0f9e8d7c6b5a",
    "label": "测试用户",
    "created_at": 1739299200000,
    "daily_limit": 100,
    "is_active": 1
  }
]
```

#### DELETE /admin/keys/:key
删除试用密钥。

#### GET /admin/usage
获取使用统计。

**查询参数**:
- `day`: 日期 (YYYY-MM-DD 格式，默认为今天)

**响应**:
```json
{
  "day": "2026-02-11",
  "total_keys": 5,
  "total_requests": 42,
  "keys": [
    {
      "key": "roc_7d9f8e7c6b5a4d3c2b1a0f9e8d7c6b5a",
      "label": "测试用户",
      "created_at": 1739299200000,
      "daily_limit": 100,
      "requests": 15,
      "updated_at": 1739299300000
    }
  ]
}
```

#### POST /admin/usage/reset
重置指定日期的使用统计。

**请求体**:
```json
{
  "day": "2026-02-11"
}
```

## 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| `DEEPSEEK_API_KEY` | (必需) | DeepSeek API 密钥 |
| `ADMIN_TOKEN` | (自动生成) | 管理员令牌 |
| `PORT` | 8787 | 服务器端口 |
| `SQLITE_DB_PATH` | ./quota-proxy-sqlite.db | SQLite 数据库文件路径 |
| `DAILY_REQ_LIMIT` | 200 | 默认每日请求限额 |
| `DEEPSEEK_BASE_URL` | https://api.deepseek.com/v1 | DeepSeek API 基础 URL |

## 部署示例

### 使用 Docker Compose

```yaml
version: '3.8'
services:
  quota-proxy:
    build: .
    ports:
      - "8787:8787"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - SQLITE_DB_PATH=/data/quota-proxy.db
    volumes:
      - ./data:/data
```

### 使用 Systemd 服务

创建 `/etc/systemd/system/quota-proxy.service`:

```ini
[Unit]
Description=Quota Proxy with SQLite Persistence
After=network.target

[Service]
Type=simple
User=quota-proxy
WorkingDirectory=/opt/quota-proxy
Environment="DEEPSEEK_API_KEY=your-api-key"
Environment="ADMIN_TOKEN=your-admin-token"
Environment="SQLITE_DB_PATH=/var/lib/quota-proxy/quota-proxy.db"
ExecStart=/usr/bin/node server-sqlite-persistent.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## 维护脚本

### 数据库备份

```bash
# 备份数据库
sqlite3 quota-proxy-sqlite.db ".backup backup/quota-proxy-$(date +%Y%m%d).db"

# 恢复数据库
sqlite3 quota-proxy-sqlite.db ".restore backup/quota-proxy-20260211.db"
```

### 数据清理

```bash
# 清理30天前的使用统计
sqlite3 quota-proxy-sqlite.db "DELETE FROM usage_stats WHERE day < date('now', '-30 days')"

# 停用90天未使用的密钥
sqlite3 quota-proxy-sqlite.db "UPDATE trial_keys SET is_active = 0 WHERE key NOT IN (SELECT DISTINCT trial_key FROM usage_stats WHERE day > date('now', '-90 days'))"
```

## 故障排除

### 常见问题

1. **数据库文件权限问题**
   ```bash
   chown -R quota-proxy:quota-proxy /var/lib/quota-proxy
   chmod 755 /var/lib/quota-proxy
   ```

2. **端口被占用**
   ```bash
   # 检查占用端口的进程
   sudo lsof -i :8787
   
   # 或使用其他端口
   PORT=8788 ./start-sqlite-persistent.sh
   ```

3. **SQLite 数据库损坏**
   ```bash
   # 检查数据库完整性
   sqlite3 quota-proxy-sqlite.db "PRAGMA integrity_check"
   
   # 修复数据库
   sqlite3 quota-proxy-sqlite.db ".backup repaired.db"
   mv repaired.db quota-proxy-sqlite.db
   ```

### 日志查看

服务器日志包含详细的调试信息：
- 数据库连接状态
- API 请求处理
- 配额检查结果
- 错误信息

## 相关文档

- [Admin API 示例](./ADMIN-API-EXAMPLES.md) - 完整的 API 调用示例
- [验证工具索引](./VALIDATION-QUICK-INDEX.md) - 所有验证工具的快速索引
- [部署指南](./DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md) - 生产环境部署指南