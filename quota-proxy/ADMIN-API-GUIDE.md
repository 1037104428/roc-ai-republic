# Admin API 指南

## 概述

quota-proxy-admin 是一个带有 SQLite 持久化和完整 Admin API 的配额代理服务器。它提供了 trial key 管理、使用统计和完整的 Admin 控制面板功能。

## 快速开始

### 1. 启动服务器

```bash
# 设置环境变量
export DEEPSEEK_API_KEY="your-deepseek-api-key"
export ADMIN_TOKEN="your-secure-admin-token"
export SQLITE_DB_PATH="./quota-proxy-admin.db"
export DAILY_REQ_LIMIT=200
export PORT=8787

# 启动服务器
node server-sqlite-admin.js
```

### 2. 验证服务器运行

```bash
# 健康检查
curl http://localhost:8787/healthz

# 应该返回:
# {"status":"ok","timestamp":...,"service":"quota-proxy-admin","version":"1.0.0"}
```

## Admin API 端点

所有 Admin API 都需要有效的 Admin Token 进行认证。

### 认证方式

**方式1: Authorization Header**
```bash
curl -H "Authorization: Bearer your-admin-token" ...
```

**方式2: X-Admin-Token Header**
```bash
curl -H "X-Admin-Token: your-admin-token" ...
```

### 1. 生成 Trial Key

**POST /admin/keys**

生成一个新的 trial key。

```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer your-admin-token" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "测试用户",
    "daily_limit": 100
  }'
```

**响应示例:**
```json
{
  "success": true,
  "key": "trial_5f4dcc3b5aa765d61d8327deb882cf99",
  "label": "测试用户",
  "daily_limit": 100,
  "created_at": 1739318400000,
  "message": "Trial key generated successfully"
}
```

### 2. 获取使用统计

**GET /admin/usage**

获取指定时间段内的使用统计。

```bash
# 获取最近7天的使用统计
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/usage?days=7"

# 获取特定key的使用统计
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/usage?key=trial_xxx&days=30"
```

**响应示例:**
```json
{
  "success": true,
  "summary": {
    "total_requests_last_days": 1250,
    "active_keys": 15,
    "days": 7
  },
  "usage": [
    {
      "key": "trial_xxx",
      "label": "测试用户",
      "created_at": 1739318400000,
      "daily_limit": 100,
      "is_active": 1,
      "usage": [
        {
          "day": "2026-02-11",
          "requests": 85,
          "updated_at": 1739318500000
        },
        {
          "day": "2026-02-10",
          "requests": 100,
          "updated_at": 1739232100000
        }
      ]
    }
  ]
}
```

### 3. 列出所有 Trial Keys

**GET /admin/keys**

列出所有 trial keys，可筛选活跃状态。

```bash
# 列出所有keys
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/keys"

# 只列出活跃keys
curl -H "Authorization: Bearer your-admin-token" \
  "http://localhost:8787/admin/keys?active_only=true"
```

**响应示例:**
```json
{
  "success": true,
  "keys": [
    {
      "key": "trial_xxx",
      "label": "测试用户",
      "created_at": 1739318400000,
      "daily_limit": 100,
      "is_active": 1,
      "today_requests": 15,
      "remaining": 85
    }
  ],
  "count": 1
}
```

## 代理 API 端点

### 1. 聊天补全

**POST /v1/chat/completions**

使用 trial key 调用 DeepSeek API。

**认证方式:**
- `Authorization: Bearer trial_key_here`
- `X-Trial-Key: trial_key_here`

```bash
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer trial_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好"}
    ],
    "stream": false
  }'
```

### 2. 健康检查

**GET /healthz**

```bash
curl http://localhost:8787/healthz
```

## 数据库结构

### trial_keys 表
| 字段 | 类型 | 说明 |
|------|------|------|
| key | TEXT PRIMARY KEY | Trial key 值 |
| label | TEXT | 用户标签（可选） |
| created_at | INTEGER | 创建时间戳 |
| daily_limit | INTEGER | 每日请求限制 |
| is_active | INTEGER | 是否激活 (1=激活, 0=停用) |

### usage_stats 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 自增ID |
| trial_key | TEXT NOT NULL | Trial key |
| day | TEXT NOT NULL | 日期 (YYYY-MM-DD) |
| requests | INTEGER | 当日请求数 |
| updated_at | INTEGER | 最后更新时间戳 |

### request_logs 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 自增ID |
| trial_key | TEXT NOT NULL | Trial key |
| timestamp | INTEGER NOT NULL | 请求时间戳 |
| endpoint | TEXT | API 端点 |
| status_code | INTEGER | HTTP 状态码 |
| response_time_ms | INTEGER | 响应时间（毫秒） |

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| DEEPSEEK_API_KEY | (必需) | DeepSeek API Key |
| ADMIN_TOKEN | (必需) | Admin API 认证令牌 |
| SQLITE_DB_PATH | ./quota-proxy-admin.db | SQLite 数据库路径 |
| DAILY_REQ_LIMIT | 200 | 默认每日请求限制 |
| PORT | 8787 | 服务器端口 |
| DEEPSEEK_API_BASE_URL | https://api.deepseek.com/v1 | DeepSeek API 基础URL |

## 部署示例

### 使用 PM2 部署

```bash
# 安装 PM2
npm install -g pm2

# 启动服务
pm2 start server-sqlite-admin.js --name quota-proxy-admin

# 查看日志
pm2 logs quota-proxy-admin

# 设置开机自启
pm2 startup
pm2 save
```

### Docker 部署

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

ENV NODE_ENV=production
ENV PORT=8787

EXPOSE 8787

CMD ["node", "server-sqlite-admin.js"]
```

## 监控和运维

### 1. 数据库备份

```bash
# 备份数据库
sqlite3 quota-proxy-admin.db ".backup backup-$(date +%Y%m%d).db"

# 恢复数据库
sqlite3 quota-proxy-admin.db ".restore backup-20260212.db"
```

### 2. 查看数据库状态

```bash
# 查看表结构
sqlite3 quota-proxy-admin.db ".schema"

# 查看数据统计
sqlite3 quota-proxy-admin.db <<EOF
SELECT 
  (SELECT COUNT(*) FROM trial_keys) as total_keys,
  (SELECT COUNT(*) FROM trial_keys WHERE is_active=1) as active_keys,
  (SELECT COUNT(*) FROM usage_stats) as usage_records,
  (SELECT COUNT(*) FROM request_logs) as request_logs;
EOF
```

### 3. 清理旧数据

```bash
# 清理30天前的请求日志
sqlite3 quota-proxy-admin.db "DELETE FROM request_logs WHERE timestamp < $(date -d '30 days ago' +%s%3N)"

# 清理60天前的使用统计
sqlite3 quota-proxy-admin.db "DELETE FROM usage_stats WHERE day < date('now', '-60 days')"
```

## 故障排除

### 常见问题

1. **Admin API 返回 401**
   - 检查 ADMIN_TOKEN 环境变量是否正确设置
   - 确认请求头中包含正确的认证信息

2. **数据库连接失败**
   - 检查 SQLITE_DB_PATH 指向的文件是否可写
   - 确保有足够的磁盘空间

3. **Trial key 无效**
   - 确认 key 存在于 trial_keys 表中
   - 检查 key 是否处于激活状态 (is_active=1)

4. **每日限制超限**
   - 检查 usage_stats 表中的当日请求数
   - 考虑增加 daily_limit 或创建新的 trial key

### 日志查看

```bash
# 查看服务器日志
tail -f quota-proxy-admin.log

# 查看 PM2 日志
pm2 logs quota-proxy-admin

# 查看数据库错误
sqlite3 quota-proxy-admin.db ".log stderr"
```

## 安全建议

1. **使用强密码**
   - ADMIN_TOKEN 应使用强随机字符串
   - 定期更换 Admin Token

2. **限制访问**
   - 使用防火墙限制访问 IP
   - 考虑使用 HTTPS (通过反向代理)

3. **定期备份**
   - 定期备份数据库文件
   - 测试恢复流程

4. **监控使用**
   - 监控异常使用模式
   - 设置使用告警阈值

## 更新日志

### v1.0.0 (2026-02-12)
- 初始版本发布
- 完整的 SQLite 持久化
- Admin API: 生成 trial key、查看使用统计、列出 keys
- 代理 API: 支持 DeepSeek 聊天补全
- 健康检查端点
- 详细的文档和部署指南