# 环境变量配置指南

本文档介绍如何为 Quota Proxy 服务配置环境变量。

## 概述

Quota Proxy 现在支持通过环境变量文件（`.env`）进行配置，这使得部署和管理更加灵活和安全。

## 快速开始

### 1. 复制环境变量模板

```bash
cd quota-proxy
cp .env.example .env
```

### 2. 编辑配置文件

使用文本编辑器打开 `.env` 文件，根据您的需求修改配置：

```bash
# 使用 nano 编辑
nano .env

# 或使用 vim
vim .env
```

### 3. 启动服务

服务会自动加载 `.env` 文件中的配置：

```bash
node server-sqlite.js
```

## 配置选项说明

### 服务器配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `PORT` | `8787` | 服务器监听的端口 |
| `HOST` | `127.0.0.1` | 服务器绑定的主机地址 |

### 数据库配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DB_PATH` | `:memory:` | SQLite 数据库文件路径（使用 `:memory:` 表示内存数据库） |
| `DB_BACKUP_DIR` | `./backups` | 数据库备份目录 |
| `DB_BACKUP_RETENTION_DAYS` | `30` | 备份文件保留天数 |

### 认证配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `ADMIN_TOKEN` | `dev-admin-token...` | 管理员令牌（生产环境必须修改！） |
| `API_KEY_PREFIX` | `roc_` | 生成的 API 密钥前缀 |

### 配额配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `DEFAULT_DAILY_LIMIT` | `1000` | 默认每日配额限制 |
| `DEFAULT_MONTHLY_LIMIT` | `30000` | 默认每月配额限制 |

### 日志配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `LOG_LEVEL` | `info` | 日志级别：`debug`, `info`, `warn`, `error` |
| `LOG_FILE` | `./logs/quota-proxy.log` | 日志文件路径 |

### 健康检查配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `HEALTH_CHECK_INTERVAL` | `30000` | 健康检查间隔（毫秒） |
| `HEALTH_CHECK_TIMEOUT` | `5000` | 健康检查超时时间（毫秒） |

### CORS 配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CORS_ORIGIN` | `*` | 允许的跨域来源 |
| `CORS_METHODS` | `GET,POST,...` | 允许的 HTTP 方法 |
| `CORS_ALLOWED_HEADERS` | `Content-Type,...` | 允许的请求头 |

### 性能配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `MAX_REQUEST_SIZE` | `10mb` | 最大请求大小 |
| `REQUEST_TIMEOUT` | `30000` | 请求超时时间（毫秒） |
| `KEEP_ALIVE_TIMEOUT` | `5000` | Keep-Alive 超时时间（毫秒） |

### 安全配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `RATE_LIMIT_WINDOW_MS` | `60000` | 速率限制时间窗口（毫秒） |
| `RATE_LIMIT_MAX_REQUESTS` | `100` | 时间窗口内最大请求数 |

## 高级用法

### 手动加载环境变量

如果您需要在其他脚本中使用相同的配置，可以手动加载环境变量：

```javascript
// 在 Node.js 脚本中
const loadEnv = require('./load-env.cjs');
loadEnv(); // 加载当前目录的 .env 文件
loadEnv('/path/to/custom.env'); // 加载指定文件
```

### 命令行测试

```bash
# 测试环境变量加载
node load-env.cjs

# 加载指定文件
node load-env.cjs /path/to/custom.env
```

### Docker 集成

在 Docker 环境中，您可以将 `.env` 文件挂载到容器中：

```dockerfile
# Dockerfile 示例
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
CMD ["node", "server-sqlite.js"]
```

```bash
# 运行容器
docker run -p 8787:8787 \
  --env-file .env \
  quota-proxy
```

## 验证配置

运行验证脚本确保配置正确：

```bash
./verify-env-config.sh
```

## 安全注意事项

1. **永远不要提交 `.env` 文件到版本控制**
   - 将 `.env` 添加到 `.gitignore`
   - 只提交 `.env.example` 作为模板

2. **生产环境必须修改的配置**
   - `ADMIN_TOKEN`: 使用强密码生成器生成
   - `DB_PATH`: 使用持久化文件路径，而不是内存数据库
   - 所有默认密码和密钥

3. **权限管理**
   - 确保 `.env` 文件只有所有者可读
   - 不要将敏感信息硬编码在代码中

## 故障排除

### 环境变量未生效

1. 检查 `.env` 文件路径是否正确
2. 确保文件格式正确（每行 `KEY=VALUE`）
3. 检查是否有语法错误

### 服务启动失败

1. 检查端口是否被占用
2. 检查数据库文件路径是否有写入权限
3. 查看日志文件获取详细信息

## 相关文件

- `quota-proxy/.env.example`: 环境变量模板
- `quota-proxy/load-env.cjs`: 环境变量加载器
- `quota-proxy/verify-env-config.sh`: 验证脚本
- `quota-proxy/server-sqlite.js`: 主服务文件