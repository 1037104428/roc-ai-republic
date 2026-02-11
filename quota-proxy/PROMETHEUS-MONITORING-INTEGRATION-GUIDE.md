# Prometheus 监控集成指南

## 概述
本指南介绍如何将 Prometheus 监控集成到 quota-proxy 的 Admin API 服务器中，以提供生产级的性能监控和指标收集功能。

## 快速开始

### 1. 集成 Prometheus 中间件

将现有的 `middleware/prometheus-metrics.js` 中间件集成到 `server-sqlite-admin.js` 中：

```javascript
// 在 server-sqlite-admin.js 顶部添加导入
const prometheusMetrics = require('./middleware/prometheus-metrics');

// 在 Express 应用初始化后添加中间件
app.use(prometheusMetrics.middleware);

// 添加 /metrics 端点用于 Prometheus 抓取
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheusMetrics.register.contentType);
  res.end(prometheusMetrics.register.metrics());
});
```

### 2. 更新后的服务器配置示例

```javascript
// server-sqlite-admin.js 完整集成示例
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const prometheusMetrics = require('./middleware/prometheus-metrics');

const app = express();
app.use(express.json());

// 使用 Prometheus 监控中间件
app.use(prometheusMetrics.middleware);

// ... 其他中间件和路由 ...

// Prometheus 指标端点
app.get('/metrics', (req, res) => {
  res.set('Content-Type', prometheusMetrics.register.contentType);
  res.end(prometheusMetrics.register.metrics());
});

// ... 服务器启动代码 ...
```

## 监控指标

集成后，quota-proxy 将提供以下监控指标：

### HTTP 请求指标
- `http_requests_total` - 总请求数
- `http_requests_by_method` - 按 HTTP 方法统计的请求数
- `http_requests_by_endpoint` - 按端点统计的请求数
- `http_responses_by_status` - 按状态码统计的响应数

### 数据库指标
- `database_queries_total` - 数据库查询总数
- `database_query_duration_seconds` - 数据库查询耗时
- `database_connections_active` - 活跃数据库连接数

### 密钥使用指标
- `api_keys_total` - 总 API 密钥数
- `api_keys_active` - 活跃 API 密钥数
- `api_requests_total` - API 请求总数
- `api_requests_by_key` - 按密钥统计的请求数

### 系统资源指标
- `memory_usage_bytes` - 内存使用量
- `cpu_usage_percent` - CPU 使用率
- `uptime_seconds` - 服务运行时间

## 部署配置

### 1. 更新 Docker Compose 配置

在 `docker-compose.yml` 中添加 Prometheus 配置：

```yaml
version: '3.8'

services:
  quota-proxy:
    build: .
    ports:
      - "8787:8787"
    environment:
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - DATABASE_PATH=/data/quota.db
    volumes:
      - ./data:/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8787/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped

volumes:
  prometheus_data:
```

### 2. Prometheus 配置文件

创建 `prometheus/prometheus.yml`：

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'quota-proxy'
    static_configs:
      - targets: ['quota-proxy:8787']
    metrics_path: '/metrics'
    scrape_interval: 15s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

## 验证监控集成

### 1. 验证脚本

创建验证脚本 `verify-prometheus-integration.sh`：

```bash
#!/bin/bash

echo "🔍 验证 Prometheus 监控集成..."

# 检查中间件文件
if [ ! -f "middleware/prometheus-metrics.js" ]; then
  echo "❌ Prometheus 中间件文件不存在"
  exit 1
fi

echo "✅ Prometheus 中间件文件存在"

# 检查是否已集成到服务器
if grep -q "prometheusMetrics" server-sqlite-admin.js; then
  echo "✅ Prometheus 中间件已集成到服务器"
else
  echo "⚠️  Prometheus 中间件未集成到服务器，请参考集成指南"
fi

# 检查 /metrics 端点
echo "📊 测试 /metrics 端点..."
curl -s http://localhost:8787/metrics | head -5

echo "🎉 Prometheus 监控集成验证完成"
```

### 2. 运行验证

```bash
chmod +x verify-prometheus-integration.sh
./verify-prometheus-integration.sh
```

## Grafana 仪表板

### 1. 预配置仪表板

创建 Grafana 仪表板配置文件 `grafana/dashboards/quota-proxy.json`，包含以下面板：

1. **HTTP 请求概览**
   - 请求速率 (requests/sec)
   - 按方法统计的请求分布
   - 响应状态码分布

2. **数据库性能**
   - 数据库查询速率
   - 平均查询耗时
   - 活跃连接数

3. **API 使用情况**
   - 活跃密钥数
   - API 请求速率
   - 按密钥的请求分布

4. **系统资源**
   - 内存使用率
   - CPU 使用率
   - 服务运行时间

### 2. Docker Compose 添加 Grafana

```yaml
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - ./grafana/dashboards:/var/lib/grafana/dashboards
      - ./grafana/provisioning:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    restart: unless-stopped
    depends_on:
      - prometheus
```

## 告警配置

### 1. Prometheus 告警规则

创建 `prometheus/alerts.yml`：

```yaml
groups:
  - name: quota-proxy-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_responses_by_status{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "高错误率检测"
          description: "HTTP 5xx 错误率超过 10% (当前值: {{ $value }})"

      - alert: HighDatabaseLatency
        expr: rate(database_query_duration_seconds_sum[5m]) / rate(database_query_duration_seconds_count[5m]) > 0.5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "数据库查询延迟过高"
          description: "平均数据库查询延迟超过 500ms (当前值: {{ $value }}s)"

      - alert: ServiceDown
        expr: up{job="quota-proxy"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务不可用"
          description: "quota-proxy 服务已下线超过 1 分钟"
```

### 2. Alertmanager 配置

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-password'

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-alerts'

receivers:
  - name: 'email-alerts'
    email_configs:
      - to: 'admin@example.com'
        from: 'alerts@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@gmail.com'
        auth_password: 'your-password'
        send_resolved: true
```

## 最佳实践

### 1. 监控策略
- **关键指标监控**: 重点关注错误率、延迟和可用性
- **容量规划**: 监控请求增长趋势，提前规划扩容
- **性能基线**: 建立性能基线，检测异常变化

### 2. 安全考虑
- **指标端点保护**: 考虑对 `/metrics` 端点进行认证
- **敏感数据**: 避免在指标中暴露敏感信息
- **访问控制**: 限制对监控系统的访问

### 3. 维护建议
- **定期审查**: 定期审查告警规则的有效性
- **仪表板优化**: 根据使用情况优化 Grafana 仪表板
- **文档更新**: 保持监控文档与实现同步

## 故障排除

### 常见问题

1. **/metrics 端点返回 404**
   - 检查中间件是否正确集成
   - 验证路由配置顺序

2. **指标数据不更新**
   - 检查 Prometheus 抓取配置
   - 验证服务健康状态

3. **Grafana 无法连接数据源**
   - 检查 Prometheus 服务地址
   - 验证网络连接和端口

### 调试命令

```bash
# 检查指标端点
curl http://localhost:8787/metrics

# 检查 Prometheus 目标状态
curl http://localhost:9090/api/v1/targets

# 检查特定指标
curl "http://localhost:9090/api/v1/query?query=http_requests_total"
```

## 相关文档

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [Node.js Prometheus 客户端](https://github.com/siimon/prom-client)
- [quota-proxy 监控文档](./docs/quota-proxy-monitoring.md)

---

**最后更新**: 2026-02-12  
**版本**: 1.0.0  
**状态**: 草案  
**负责人**: 阿爪 (OpenClaw 助手)