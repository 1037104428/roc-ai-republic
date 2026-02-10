# quota-proxy SQLite版本部署指南

## 概述

quota-proxy SQLite版本是一个增强的API网关代理，提供以下核心功能：

1. **SQLite持久化存储** - 试用密钥和使用数据持久保存到SQLite数据库
2. **管理接口** - 完整的`POST /admin/keys`和`GET /admin/usage`接口
3. **试用密钥管理** - 创建、查看试用密钥
4. **使用情况跟踪** - 按天统计API使用情况
5. **配额限制** - 每日请求限制保护

## 特性

- ✅ SQLite数据库持久化
- ✅ POST /admin/keys - 创建试用密钥
- ✅ GET /admin/keys - 查看试用密钥列表
- ✅ GET /admin/usage - 查看使用情况统计
- ✅ 健康检查端点 (/healthz)
- ✅ DeepSeek API代理
- ✅ 每日配额限制
- ✅ ADMIN_TOKEN保护的管理接口
- ✅ Docker容器化部署
- ✅ systemd服务集成

## 快速开始

### 1. 环境准备

```bash
# 设置DeepSeek API密钥
export DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# 可选：设置其他环境变量
export DAILY_REQ_LIMIT=200
export ADMIN_TOKEN=your-secure-admin-token
```

### 2. 一键部署

```bash
# 使用默认配置部署
./scripts/deploy-quota-proxy-sqlite.sh

# 指定服务器和目录
./scripts/deploy-quota-proxy-sqlite.sh \
  --server root@your-server.com \
  --dir /opt/roc/quota-proxy \
  --token your-admin-token \
  --verbose
```

### 3. 手动部署步骤

#### 3.1 复制文件到服务器

```bash
scp -r quota-proxy/* root@your-server.com:/opt/roc/quota-proxy/
```

#### 3.2 创建环境配置文件

在服务器上创建`.env`文件：

```bash
cat > /opt/roc/quota-proxy/.env << EOF
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
PORT=8787
DAILY_REQ_LIMIT=200
ADMIN_TOKEN=your-secure-admin-token
DATABASE_PATH=./quota-proxy.db
LOG_LEVEL=info
EOF
```

#### 3.3 安装依赖

```bash
cd /opt/roc/quota-proxy
npm ci --only=production
```

#### 3.4 启动服务

```bash
# 直接运行
node server-sqlite-simple.js

# 或使用启动脚本
./start.sh
```

#### 3.5 使用Docker部署

```bash
# 构建镜像
docker build -t quota-proxy-sqlite .

# 运行容器
docker run -d \
  --name quota-proxy-sqlite \
  -p 127.0.0.1:8787:8787 \
  -e DEEPSEEK_API_KEY=sk-your-key \
  -e ADMIN_TOKEN=your-token \
  -v ./data:/data \
  quota-proxy-sqlite
```

#### 3.6 使用Docker Compose

```bash
# 创建.env文件
echo "DEEPSEEK_API_KEY=sk-your-key" > .env
echo "ADMIN_TOKEN=your-token" >> .env

# 启动服务
docker-compose up -d
```

## API接口文档

### 公共接口

#### 健康检查
```bash
GET /healthz
```
响应：
```json
{"ok": true}
```

#### 获取模型列表
```bash
GET /v1/models
```

#### 聊天补全（需要试用密钥）
```bash
POST /v1/chat/completions
Authorization: Bearer <TRIAL_KEY>
Content-Type: application/json

{
  "model": "deepseek-chat",
  "messages": [
    {"role": "user", "content": "Hello"}
  ]
}
```

### 管理接口（需要ADMIN_TOKEN）

#### 创建试用密钥
```bash
POST /admin/keys
Authorization: Bearer <ADMIN_TOKEN>
Content-Type: application/json

{
  "label": "用户标签（可选）"
}
```

响应：
```json
{
  "key": "trial_abc123...",
  "label": "用户标签",
  "created_at": 1678886400000
}
```

#### 查看试用密钥列表
```bash
GET /admin/keys
Authorization: Bearer <ADMIN_TOKEN>
```

#### 查看使用情况

按天查询：
```bash
GET /admin/usage?day=2024-03-15
Authorization: Bearer <ADMIN_TOKEN>
```

查询特定密钥：
```bash
GET /admin/usage?key=trial_abc123...
Authorization: Bearer <ADMIN_TOKEN>
```

查询所有记录（限制数量）：
```bash
GET /admin/usage?limit=100
Authorization: Bearer <ADMIN_TOKEN>
```

## 数据库结构

### trial_keys表
| 字段 | 类型 | 说明 |
|------|------|------|
| key | TEXT PRIMARY KEY | 试用密钥 |
| label | TEXT | 用户标签 |
| created_at | INTEGER | 创建时间戳 |
| expires_at | INTEGER | 过期时间戳（可选） |

### usage_logs表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY | 自增ID |
| trial_key | TEXT NOT NULL | 试用密钥 |
| day | TEXT NOT NULL | 日期（YYYY-MM-DD） |
| requests | INTEGER DEFAULT 0 | 请求次数 |
| updated_at | INTEGER NOT NULL | 更新时间戳 |

## 环境变量

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| DEEPSEEK_API_KEY | 是 | - | DeepSeek API密钥 |
| DEEPSEEK_BASE_URL | 否 | https://api.deepseek.com/v1 | DeepSeek API基础URL |
| PORT | 否 | 8787 | 服务监听端口 |
| DAILY_REQ_LIMIT | 否 | 200 | 每日请求限制 |
| ADMIN_TOKEN | 否 | - | 管理接口令牌 |
| DATABASE_PATH | 否 | ./quota-proxy.db | SQLite数据库文件路径 |
| LOG_LEVEL | 否 | info | 日志级别 |

## 监控和维护

### 健康检查
```bash
curl -f http://localhost:8787/healthz
```

### 查看服务状态
```bash
systemctl status quota-proxy-sqlite
```

### 查看日志
```bash
journalctl -u quota-proxy-sqlite -f
```

### 数据库备份
```bash
# 备份数据库
cp /opt/roc/quota-proxy/quota-proxy.db /backup/quota-proxy-$(date +%Y%m%d).db

# 或使用提供的备份脚本
./scripts/backup-quota-proxy-db.sh
```

### 数据库维护
```bash
# 查看数据库大小
ls -lh quota-proxy.db

# 优化数据库
sqlite3 quota-proxy.db "VACUUM;"

# 查看表信息
sqlite3 quota-proxy.db ".tables"
sqlite3 quota-proxy.db "SELECT COUNT(*) FROM trial_keys;"
sqlite3 quota-proxy.db "SELECT COUNT(*) FROM usage_logs;"
```

## 故障排除

### 服务无法启动
1. 检查环境变量：
   ```bash
   cat .env
   ```

2. 检查端口占用：
   ```bash
   netstat -tlnp | grep :8787
   ```

3. 查看错误日志：
   ```bash
   journalctl -u quota-proxy-sqlite -n 50
   ```

### 管理接口返回401
1. 检查ADMIN_TOKEN设置：
   ```bash
   echo $ADMIN_TOKEN
   ```

2. 验证令牌格式：
   ```bash
   curl -v -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8787/admin/keys
   ```

### 数据库问题
1. 检查数据库文件权限：
   ```bash
   ls -la quota-proxy.db
   ```

2. 修复数据库：
   ```bash
   sqlite3 quota-proxy.db ".recover" | sqlite3 quota-proxy-recovered.db
   ```

## 安全建议

1. **保护ADMIN_TOKEN**：使用强密码，定期更换
2. **限制访问**：使用防火墙限制管理接口访问
3. **数据库备份**：定期备份SQLite数据库
4. **监控日志**：监控异常访问模式
5. **更新依赖**：定期更新Node.js依赖包

## 性能优化

1. **数据库索引**：已自动创建优化索引
2. **连接池**：SQLite是文件数据库，无需连接池
3. **缓存**：考虑添加Redis缓存高频查询
4. **负载均衡**：多实例部署时使用负载均衡器

## 扩展开发

### 添加新功能
1. 修改`server-sqlite-simple.js`添加新接口
2. 更新数据库模式（需要迁移脚本）
3. 添加相应的测试

### 集成监控
```javascript
// 添加监控中间件
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.url} ${res.statusCode} ${duration}ms`);
  });
  next();
});
```

## 相关资源

- [项目仓库](https://github.com/1037104428/roc-ai-republic)
- [SQLite文档](https://www.sqlite.org/docs.html)
- [Express.js文档](https://expressjs.com/)
- [DeepSeek API文档](https://platform.deepseek.com/api-docs/)

## 支持与反馈

如有问题或建议，请提交GitHub Issue或联系项目维护者。