# 日志级别控制指南

## 概述

本文档介绍 quota-proxy 项目的日志级别控制系统，包括日志级别定义、配置方法和使用示例。

## 日志级别定义

quota-proxy 支持以下标准日志级别（从低到高）：

### 1. DEBUG (调试)
- **用途**: 详细的调试信息，通常用于开发环境
- **包含内容**: 
  - 详细的请求/响应数据
  - 数据库查询详情
  - 中间件处理过程
  - 性能指标细节
- **适用环境**: 开发、测试环境

### 2. INFO (信息)
- **用途**: 常规的运行信息，用于了解系统状态
- **包含内容**:
  - 服务启动/停止信息
  - HTTP请求摘要
  - API密钥操作
  - 数据库连接状态
  - 配置加载信息
- **适用环境**: 所有环境（默认级别）

### 3. WARN (警告)
- **用途**: 潜在的问题或异常情况，但不影响核心功能
- **包含内容**:
  - 配置缺失或使用默认值
  - 资源使用率较高
  - 非关键功能失败
  - 降级操作
- **适用环境**: 所有环境

### 4. ERROR (错误)
- **用途**: 错误情况，需要立即关注
- **包含内容**:
  - 服务启动失败
  - 数据库连接失败
  - 关键API调用失败
  - 系统资源耗尽
  - 安全相关事件
- **适用环境**: 所有环境

## 配置方法

### 环境变量配置

通过环境变量控制日志级别：

```bash
# 设置日志级别 (默认: info)
export LOG_LEVEL=debug

# 启用JSON格式日志 (默认: false)
export JSON_LOGS=true

# 服务名称 (默认: quota-proxy)
export SERVICE_NAME=my-quota-proxy
```

### Docker Compose 配置

在 `docker-compose.yml` 或 `compose.yaml` 中配置：

```yaml
version: '3.8'
services:
  quota-proxy:
    image: quota-proxy:latest
    environment:
      - LOG_LEVEL=debug
      - JSON_LOGS=true
      - SERVICE_NAME=production-quota-proxy
    ports:
      - "3000:3000"
```

### 代码配置

在服务器代码中直接配置：

```javascript
const createJsonLogger = require('./middleware/json-logger');

// 创建日志中间件
const jsonLogger = createJsonLogger({
  logLevel: 'debug',      // 日志级别
  jsonFormat: true,       // JSON格式输出
  serviceName: 'quota-proxy' // 服务名称
});

// 使用中间件
app.use(jsonLogger);
```

## 使用示例

### 1. 基本日志记录

```javascript
const createJsonLogger = require('./middleware/json-logger');
const logger = createJsonLogger();

// 不同级别的日志
logger.debug('调试信息', { data: '详细数据' });
logger.info('服务启动', { port: 3000, env: 'development' });
logger.warn('配置缺失', { config: 'database.url', using: 'default' });
logger.error('连接失败', { error: 'Connection refused', host: 'localhost:5432' });
```

### 2. HTTP请求日志

```javascript
// 自动记录HTTP请求（通过中间件）
app.use(createJsonLogger());

// 手动记录特定请求
app.post('/keys', (req, res) => {
  const logger = createJsonLogger();
  logger.info('创建API密钥', { 
    userId: req.body.userId,
    keyType: req.body.type 
  });
  // ... 处理逻辑
});
```

### 3. 数据库操作日志

```javascript
const logger = createJsonLogger();

// 记录数据库操作
async function queryDatabase(sql, params) {
  const startTime = Date.now();
  try {
    const result = await db.query(sql, params);
    const duration = Date.now() - startTime;
    
    logger.db('QUERY', sql, duration, true);
    return result;
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.db('QUERY', sql, duration, false);
    logger.error('数据库查询失败', { error: error.message, sql });
    throw error;
  }
}
```

### 4. API密钥操作日志

```javascript
const logger = createJsonLogger();

// 记录API密钥操作
async function createApiKey(userId, permissions) {
  try {
    const key = await generateApiKey();
    await saveKeyToDatabase(key, userId, permissions);
    
    logger.key('CREATE', key.id, userId, true);
    return key;
  } catch (error) {
    logger.key('CREATE', null, userId, false);
    logger.error('创建API密钥失败', { error: error.message, userId });
    throw error;
  }
}
```

## 输出格式

### 文本格式（默认）

```
[2026-02-12T05:02:52.123Z] INFO [quota-proxy] 服务启动成功 {"port":3000,"env":"development"}
[2026-02-12T05:02:53.456Z] INFO [quota-proxy] POST /keys 201 {"method":"POST","url":"/keys","statusCode":201,"responseTime":"45ms"}
```

### JSON格式（启用 JSON_LOGS=true）

```json
{
  "timestamp": "2026-02-12T05:02:52.123Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "服务启动成功",
  "logId": "log_1770657772123_abc123def",
  "port": 3000,
  "env": "development"
}
```

## 最佳实践

### 1. 环境特定的日志级别

```bash
# 开发环境 - 详细日志
export LOG_LEVEL=debug

# 测试环境 - 信息级别日志
export LOG_LEVEL=info

# 生产环境 - 警告及以上级别
export LOG_LEVEL=warn
```

### 2. 结构化日志字段

始终包含关键上下文信息：

```javascript
// 好的做法
logger.info('用户登录', {
  userId: user.id,
  ip: req.ip,
  userAgent: req.get('user-agent'),
  success: true
});

// 不好的做法
logger.info('用户登录成功'); // 缺少上下文
```

### 3. 敏感信息处理

不要记录敏感信息：

```javascript
// 错误的做法
logger.info('用户认证', {
  userId: user.id,
  password: user.password, // ⚠️ 敏感信息！
  token: user.token        // ⚠️ 敏感信息！
});

// 正确的做法
logger.info('用户认证', {
  userId: user.id,
  action: 'login',
  success: true
});
```

### 4. 性能考虑

- 生产环境中避免使用 `debug` 级别
- 高频操作使用 `info` 级别记录摘要信息
- 错误处理使用 `error` 级别记录完整错误信息

## 故障排除

### 1. 看不到调试日志

```bash
# 检查当前日志级别
echo $LOG_LEVEL

# 设置为debug级别
export LOG_LEVEL=debug
```

### 2. 日志格式不正确

```bash
# 检查JSON格式设置
echo $JSON_LOGS

# 启用JSON格式
export JSON_LOGS=true
```

### 3. 日志文件过大

```bash
# 调整日志级别减少日志量
export LOG_LEVEL=warn

# 使用日志轮转工具
# 例如: logrotate, docker log-driver等
```

## 相关文件

- `middleware/json-logger.js` - JSON日志中间件实现
- `verify-json-logger-enhanced.sh` - 日志增强验证脚本
- `.env.example` - 环境变量示例
- `STRUCTURED-LOG-EXAMPLES.md` - 结构化日志示例

## 更新日志

- **2026-02-12**: 创建日志级别控制指南
- **2026-02-12**: 添加JSON格式日志支持
- **2026-02-12**: 添加结构化日志字段规范