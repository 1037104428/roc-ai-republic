# 结构化日志示例

## 概述

本文档提供 quota-proxy 项目的结构化日志示例，展示不同场景下的日志格式和最佳实践。

## 日志结构

所有结构化日志都包含以下基本字段：

| 字段名 | 类型 | 描述 | 示例 |
|--------|------|------|------|
| timestamp | string | ISO 8601 时间戳 | "2026-02-12T05:02:52.123Z" |
| level | string | 日志级别 (DEBUG, INFO, WARN, ERROR) | "INFO" |
| service | string | 服务名称 | "quota-proxy" |
| message | string | 日志消息 | "服务启动成功" |
| logId | string | 唯一日志ID | "log_1770657772123_abc123def" |

## 示例分类

### 1. 服务生命周期日志

#### 服务启动

```json
{
  "timestamp": "2026-02-12T05:02:52.123Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "服务启动成功",
  "logId": "log_1770657772123_abc123def",
  "port": 3000,
  "environment": "development",
  "nodeVersion": "v22.22.0",
  "pid": 12345,
  "hostname": "server-01",
  "startupTime": "2.5s"
}
```

#### 服务关闭

```json
{
  "timestamp": "2026-02-12T05:03:52.456Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "服务正常关闭",
  "logId": "log_1770657832456_def456ghi",
  "uptime": "60.333s",
  "totalRequests": 1250,
  "averageResponseTime": "45ms",
  "shutdownReason": "SIGTERM"
}
```

### 2. HTTP请求日志

#### 成功请求

```json
{
  "timestamp": "2026-02-12T05:04:12.789Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "POST /keys 201",
  "logId": "log_1770657852789_ghi789jkl",
  "method": "POST",
  "url": "/keys",
  "statusCode": 201,
  "responseTime": "45ms",
  "userAgent": "curl/7.68.0",
  "ip": "192.168.1.100",
  "contentLength": "256",
  "requestId": "req_abc123",
  "userId": "user_12345"
}
```

#### 失败请求

```json
{
  "timestamp": "2026-02-12T05:04:25.123Z",
  "level": "WARN",
  "service": "quota-proxy",
  "message": "GET /admin/usage 401",
  "logId": "log_1770657865123_jkl012mno",
  "method": "GET",
  "url": "/admin/usage",
  "statusCode": 401,
  "responseTime": "12ms",
  "userAgent": "PostmanRuntime/7.26.8",
  "ip": "10.0.0.50",
  "error": "Unauthorized",
  "missingHeader": "Authorization",
  "requestId": "req_def456"
}
```

### 3. 数据库操作日志

#### 查询成功

```json
{
  "timestamp": "2026-02-12T05:05:10.456Z",
  "level": "DEBUG",
  "service": "quota-proxy",
  "message": "Database SELECT",
  "logId": "log_1770657910456_mno345pqr",
  "operation": "SELECT",
  "table": "api_keys",
  "query": "SELECT * FROM api_keys WHERE user_id = ?",
  "parameters": ["user_12345"],
  "duration": "23ms",
  "rowsReturned": 3,
  "success": true
}
```

#### 查询失败

```json
{
  "timestamp": "2026-02-12T05:05:25.789Z",
  "level": "ERROR",
  "service": "quota-proxy",
  "message": "Database INSERT failed",
  "logId": "log_1770657925789_pqr678stu",
  "operation": "INSERT",
  "table": "request_logs",
  "query": "INSERT INTO request_logs (key_id, endpoint, response_time) VALUES (?, ?, ?)",
  "parameters": ["key_abc123", "/api/v1/chat", 125],
  "duration": "5ms",
  "error": "SQLITE_CONSTRAINT: UNIQUE constraint failed",
  "errorCode": "SQLITE_CONSTRAINT",
  "success": false
}
```

### 4. API密钥操作日志

#### 创建密钥

```json
{
  "timestamp": "2026-02-12T05:06:15.123Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "API Key CREATE",
  "logId": "log_1770657975123_stu901vwx",
  "operation": "CREATE",
  "keyId": "key_abc123def456",
  "userId": "user_12345",
  "keyType": "trial",
  "permissions": ["chat:read", "chat:write"],
  "expiresAt": "2026-03-12T05:06:15.123Z",
  "success": true
}
```

#### 验证密钥

```json
{
  "timestamp": "2026-02-12T05:06:30.456Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "API Key VALIDATE",
  "logId": "log_1770657990456_vwx234yza",
  "operation": "VALIDATE",
  "keyId": "key_abc123def456",
  "userId": "user_12345",
  "endpoint": "/api/v1/chat",
  "remainingQuota": 950,
  "totalQuota": 1000,
  "valid": true,
  "success": true
}
```

#### 密钥过期

```json
{
  "timestamp": "2026-02-12T05:06:45.789Z",
  "level": "WARN",
  "service": "quota-proxy",
  "message": "API Key EXPIRED",
  "logId": "log_1770658005789_yza567bcd",
  "operation": "VALIDATE",
  "keyId": "key_expired123",
  "userId": "user_67890",
  "endpoint": "/api/v1/chat",
  "error": "Key expired",
  "expiredAt": "2026-02-11T00:00:00.000Z",
  "valid": false,
  "success": false
}
```

### 5. 系统监控日志

#### 内存使用

```json
{
  "timestamp": "2026-02-12T05:07:00.123Z",
  "level": "DEBUG",
  "service": "quota-proxy",
  "message": "Memory usage",
  "logId": "log_1770658020123_bcd890efg",
  "metric": "memory",
  "heapUsed": "45.2MB",
  "heapTotal": "128MB",
  "external": "12.5MB",
  "arrayBuffers": "3.2MB",
  "rss": "156MB",
  "percentage": "35.3%"
}
```

#### 请求率

```json
{
  "timestamp": "2026-02-12T05:07:15.456Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "Request rate",
  "logId": "log_1770658035456_efg123hij",
  "metric": "requests",
  "period": "1m",
  "totalRequests": 125,
  "requestsPerSecond": "2.08",
  "averageResponseTime": "42ms",
  "p95ResponseTime": "78ms",
  "errorRate": "0.8%"
}
```

#### 数据库连接

```json
{
  "timestamp": "2026-02-12T05:07:30.789Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "Database connection pool",
  "logId": "log_1770658050789_hij456klm",
  "metric": "database",
  "totalConnections": 10,
  "activeConnections": 3,
  "idleConnections": 7,
  "waitingClients": 0,
  "connectionUsage": "30%"
}
```

### 6. 错误和异常日志

#### 配置错误

```json
{
  "timestamp": "2026-02-12T05:08:00.123Z",
  "level": "ERROR",
  "service": "quota-proxy",
  "message": "Configuration error",
  "logId": "log_1770658080123_klm789nop",
  "error": "Missing required environment variable",
  "variable": "DATABASE_URL",
  "file": "server.js",
  "line": 45,
  "function": "loadConfiguration",
  "stackTrace": "Error: DATABASE_URL is required\n    at loadConfiguration (server.js:45:15)\n    at startServer (server.js:89:5)",
  "severity": "high",
  "recoverable": true
}
```

#### 外部服务错误

```json
{
  "timestamp": "2026-02-12T05:08:15.456Z",
  "level": "ERROR",
  "service": "quota-proxy",
  "message": "External service error",
  "logId": "log_1770658095456_nop012qrs",
  "error": "Connection refused",
  "service": "redis",
  "host": "redis://localhost:6379",
  "operation": "SET",
  "key": "rate_limit:user_12345",
  "retryCount": 3,
  "maxRetries": 5,
  "fallback": "memory_cache",
  "severity": "medium"
}
```

#### 业务逻辑错误

```json
{
  "timestamp": "2026-02-12T05:08:30.789Z",
  "level": "ERROR",
  "service": "quota-proxy",
  "message": "Business logic error",
  "logId": "log_1770658110789_qrs345tuv",
  "error": "Insufficient quota",
  "userId": "user_12345",
  "keyId": "key_abc123",
  "endpoint": "/api/v1/chat/completions",
  "requiredQuota": 10,
  "availableQuota": 5,
  "totalQuota": 1000,
  "usedQuota": 995,
  "action": "reject_request",
  "severity": "low"
}
```

## 最佳实践示例

### 1. 完整的请求处理流程

```json
// 1. 请求到达
{
  "timestamp": "2026-02-12T05:09:00.123Z",
  "level": "DEBUG",
  "service": "quota-proxy",
  "message": "Request received",
  "logId": "log_1770658140123_tuv678wxy",
  "requestId": "req_abc123",
  "method": "POST",
  "url": "/api/v1/chat/completions",
  "contentType": "application/json",
  "contentLength": "1024"
}

// 2. API密钥验证
{
  "timestamp": "2026-02-12T05:09:00.456Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "API key validated",
  "logId": "log_1770658140456_wxy901zab",
  "requestId": "req_abc123",
  "keyId": "key_abc123def456",
  "userId": "user_12345",
  "valid": true,
  "remainingQuota": 890
}

// 3. 配额检查
{
  "timestamp": "2026-02-12T05:09:00.789Z",
  "level": "DEBUG",
  "service": "quota-proxy",
  "message": "Quota checked",
  "logId": "log_1770658140789_zab234cde",
  "requestId": "req_abc123",
  "requiredQuota": 5,
  "availableQuota": 890,
  "sufficient": true
}

// 4. 请求处理完成
{
  "timestamp": "2026-02-12T05:09:02.123Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "Request completed",
  "logId": "log_1770658142123_cde567fgh",
  "requestId": "req_abc123",
  "statusCode": 200,
  "responseTime": "2000ms",
  "quotaUsed": 5,
  "remainingQuota": 885
}
```

### 2. 错误处理流程

```json
// 1. 请求到达
{
  "timestamp": "2026-02-12T05:10:00.123Z",
  "level": "DEBUG",
  "service": "quota-proxy",
  "message": "Request received",
  "logId": "log_1770658200123_fgh890ijk",
  "requestId": "req_def456",
  "method": "POST",
  "url": "/api/v1/chat/completions"
}

// 2. API密钥验证失败
{
  "timestamp": "2026-02-12T05:10:00.456Z",
  "level": "WARN",
  "service": "quota-proxy",
  "message": "API key validation failed",
  "logId": "log_1770658200456_ijk123lmn",
  "requestId": "req_def456",
  "keyId": "key_invalid123",
  "error": "Invalid API key",
  "statusCode": 401
}

// 3. 请求被拒绝
{
  "timestamp": "2026-02-12T05:10:00.789Z",
  "level": "INFO",
  "service": "quota-proxy",
  "message": "Request rejected",
  "logId": "log_1770658200789_lmn456opq",
  "requestId": "req_def456",
  "statusCode": 401,
  "responseTime": "25ms",
  "reason": "invalid_api_key"
}
```

## 日志查询示例

### 使用 jq 查询日志

```bash
# 查找所有错误日志
cat app.log | jq 'select(.level == "ERROR")'

# 查找特定用户的日志
cat app.log | jq 'select(.userId == "user_12345")'

# 查找响应时间超过100ms的请求
cat app.log | jq 'select(.responseTime != null and (.responseTime | tonumber) > 100)'

# 统计各端点请求数量
cat app.log | jq -r 'select(.url != null) | .url' | sort | uniq -c | sort -rn

# 按小时统计错误数量
cat app.log | jq -r 'select(.level == "ERROR") | .timestamp[0:13]' | sort | uniq -c
```

### 使用 Elasticsearch 查询

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "service": "quota-proxy" } },
        { "range": { "timestamp": { "gte": "now-1h" } } },
        { "terms": { "level": ["ERROR", "WARN"] } }
      ]
    }
  },
  "aggs": {
    "errors_by_endpoint": {
      "terms": { "field": "url.keyword" }
    }
  }
}
```

## 相关文件

- `middleware/json-logger.js` - JSON日志中间件实现
- `LOG-LEVEL-CONTROL.md` - 日志级别控制指南
- `verify-json-logger-enhanced.sh` - 日志增强验证脚本

## 更新日志

- **2026-02-12**: 创建结构化日志示例文档
- **2026-02-12**: 添加6类日志示例
- **2026-02-12**: 添加最佳实践和查询示例