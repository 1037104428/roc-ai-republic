# 统计API指南

## 概述

quota-proxy 提供了一个统计API端点 (`GET /admin/stats`)，用于获取系统的实时统计信息。这个端点需要管理员权限访问。

## 快速开始

### 1. 获取统计信息

```bash
# 使用管理员令牌访问统计API
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/stats

# 使用jq格式化输出
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/stats | jq .
```

### 2. 使用验证脚本

```bash
# 本地测试
./scripts/verify-stats-api.sh --local

# 远程测试
./scripts/verify-stats-api.sh --remote your-server:8787 --admin-token your-token

# 详细输出
./scripts/verify-stats-api.sh --local --verbose
```

## API响应格式

统计API返回JSON格式的数据，包含以下信息：

### 服务器信息
```json
{
  "timestamp": "2026-02-10T11:35:52.123Z",
  "server": {
    "uptime": 3600.5,
    "memory": {
      "rss": 12345678,
      "heapTotal": 9876543,
      "heapUsed": 5432109,
      "external": 123456
    },
    "version": "quota-proxy/v1.0"
  }
}
```

### 数据库统计
```json
{
  "database": {
    "total_keys": 25,
    "active_keys": 20,
    "expired_keys": 5,
    "total_quota": 25000,
    "used_quota": 12500,
    "quota_usage_percent": "50.00",
    "total_requests": 1500,
    "today_requests": 120
  }
}
```

## 字段说明

### 服务器字段
- `timestamp`: 统计生成的时间戳 (ISO 8601格式)
- `server.uptime`: 服务器运行时间 (秒)
- `server.memory`: Node.js进程内存使用情况
- `server.version`: 服务器版本标识

### 数据库字段
- `total_keys`: 总API密钥数量
- `active_keys`: 活跃密钥数量 (未过期)
- `expired_keys`: 已过期密钥数量
- `total_quota`: 总配额量 (所有密钥)
- `used_quota`: 已使用配额量
- `quota_usage_percent`: 配额使用百分比
- `total_requests`: 总请求数量
- `today_requests`: 今日请求数量

## 使用场景

### 1. 监控系统健康
```bash
# 检查系统基本状态
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/stats | \
  jq '{uptime: .server.uptime, memory: .server.memory, keys: .database.total_keys}'
```

### 2. 监控配额使用
```bash
# 监控配额使用情况
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/stats | \
  jq '.database | {total_quota, used_quota, quota_usage_percent}'
```

### 3. 自动化监控脚本
```bash
#!/bin/bash
# 监控脚本示例

STATS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/stats)

# 检查配额使用率
USAGE_PERCENT=$(echo "$STATS" | jq -r '.database.quota_usage_percent | tonumber')
if (( $(echo "$USAGE_PERCENT > 80" | bc -l) )); then
  echo "警告: 配额使用率超过80% ($USAGE_PERCENT%)"
fi

# 检查活跃密钥数量
ACTIVE_KEYS=$(echo "$STATS" | jq -r '.database.active_keys')
if [ "$ACTIVE_KEYS" -lt 5 ]; then
  echo "提示: 活跃密钥较少 ($ACTIVE_KEYS个)"
fi
```

## 安全注意事项

1. **管理员令牌保护**: 统计API需要管理员权限，确保 `ADMIN_TOKEN` 保密
2. **访问控制**: 建议结合IP白名单中间件使用
3. **速率限制**: 统计API受管理员速率限制保护
4. **审计日志**: 所有统计API访问都会被记录到审计日志

## 故障排除

### 常见问题

1. **401 Unauthorized**
   ```bash
   # 检查管理员令牌
   echo "ADMIN_TOKEN: $ADMIN_TOKEN"
   
   # 验证令牌格式
   curl -v -H "Authorization: Bearer $ADMIN_TOKEN" \
     http://localhost:8787/admin/stats
   ```

2. **连接失败**
   ```bash
   # 检查服务器是否运行
   curl http://localhost:8787/healthz
   
   # 检查端口监听
   netstat -tlnp | grep 8787
   ```

3. **响应格式错误**
   ```bash
   # 检查服务器日志
   tail -f quota-proxy.log
   
   # 验证数据库连接
   ./scripts/check-quota-status.sh --local
   ```

### 调试模式
```bash
# 启用详细日志
DEBUG=quota-proxy:* node quota-proxy/server-sqlite.js

# 使用验证脚本调试
./scripts/verify-stats-api.sh --local --verbose
```

## 集成示例

### Prometheus监控
```yaml
# prometheus.yml 配置示例
scrape_configs:
  - job_name: 'quota-proxy'
    static_configs:
      - targets: ['localhost:8787']
    metrics_path: '/admin/stats'
    bearer_token: '${ADMIN_TOKEN}'
    scheme: 'http'
```

### Grafana仪表板
使用统计API数据创建监控仪表板，监控：
- 配额使用趋势
- 请求速率
- 密钥状态
- 系统资源使用

## 相关文档

- [管理员API指南](./admin-api-guide.md)
- [审计日志指南](./audit-log-guide.md)
- [快速开始指南](./quickstart.md)
- [验证脚本说明](../scripts/README.md)