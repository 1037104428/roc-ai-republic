# Quota-Proxy 监控功能测试指南

## 概述
本文档介绍如何测试quota-proxy的监控功能，包括状态页面部署和API使用统计验证。

## 监控功能组件

### 1. 状态页面
- **URL**: `/status` 或 `/admin/status`
- **功能**: 显示服务运行状态、数据库连接状态、API使用统计
- **部署方式**: 集成在quota-proxy服务中，无需额外配置

### 2. API使用统计
- **数据源**: SQLite数据库中的`api_usage`表
- **统计维度**: 
  - 按API端点统计调用次数
  - 按时间范围统计（日/周/月）
  - 按用户/密钥统计使用量

### 3. 健康检查
- **端点**: `/healthz`
- **功能**: 检查服务是否正常运行，数据库是否可连接

## 测试步骤

### 步骤1: 启动quota-proxy服务
```bash
# 进入roc-ai-republic目录
cd roc-ai-republic

# 安装依赖
npm install

# 启动服务（开发模式）
npm run dev

# 或者使用Docker Compose
docker-compose up -d
```

### 步骤2: 验证状态页面
```bash
# 检查状态页面
curl http://localhost:3000/status

# 或者使用浏览器访问
# http://localhost:3000/status
```

预期响应应包含：
- 服务状态: "running"
- 数据库连接状态: "connected"
- 启动时间
- 内存使用情况

### 步骤3: 测试API使用统计
```bash
# 1. 首先调用一些API以生成使用数据
curl -X POST http://localhost:3000/api/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 2. 查看API使用统计
curl http://localhost:3000/admin/api/stats

# 3. 查看特定时间范围的统计
curl "http://localhost:3000/admin/api/stats?start=2026-02-01&end=2026-02-10"
```

### 步骤4: 验证健康检查
```bash
# 健康检查
curl http://localhost:3000/healthz

# 预期响应: {"status":"ok","timestamp":"2026-02-10T18:05:00.000Z"}
```

### 步骤5: 监控告警测试（如果配置了）
```bash
# 测试监控告警（需要配置告警规则）
# 可以通过模拟高负载或错误率来触发告警
```

## 自动化测试脚本

创建测试脚本 `test-monitoring.sh`:

```bash
#!/bin/bash

# 测试监控功能
echo "=== 开始测试quota-proxy监控功能 ==="

# 1. 测试健康检查
echo "测试健康检查..."
curl -s http://localhost:3000/healthz | jq '.status' | grep -q "ok"
if [ $? -eq 0 ]; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    exit 1
fi

# 2. 测试状态页面
echo "测试状态页面..."
curl -s http://localhost:3000/status | jq '.service_status' | grep -q "running"
if [ $? -eq 0 ]; then
    echo "✓ 状态页面正常"
else
    echo "✗ 状态页面异常"
    exit 1
fi

# 3. 生成测试API调用
echo "生成测试API调用..."
curl -s -X POST http://localhost:3000/api/v1/chat/completions \
  -H "Authorization: Bearer test-key-123" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"test"}]}' > /dev/null

# 4. 验证API统计
echo "验证API统计..."
sleep 2  # 等待数据写入
curl -s http://localhost:3000/admin/api/stats | jq '.total_calls' | grep -q "[0-9]"
if [ $? -eq 0 ]; then
    echo "✓ API统计功能正常"
else
    echo "✗ API统计功能异常"
    exit 1
fi

echo "=== 所有监控功能测试通过 ==="
```

## 部署验证

### Docker Compose部署验证
```yaml
# docker-compose.monitoring.yml
version: '3.8'
services:
  quota-proxy:
    image: quota-proxy:latest
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=sqlite:/data/quota.db
      - ENABLE_MONITORING=true
    volumes:
      - ./data:/data
      - ./logs:/logs
  
  # 可选：添加Prometheus监控
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

### 验证命令
```bash
# 部署后验证
curl http://localhost:3000/healthz
curl http://localhost:3000/status
curl http://localhost:3000/admin/api/stats

# 验证Prometheus指标（如果配置了）
curl http://localhost:3000/metrics
```

## 故障排除

### 常见问题

1. **状态页面无法访问**
   - 检查服务是否运行: `docker ps` 或 `ps aux | grep node`
   - 检查端口是否被占用: `netstat -tlnp | grep 3000`
   - 检查防火墙设置

2. **API统计数据显示为空**
   - 确认数据库连接正常
   - 检查`api_usage`表是否有数据
   - 确认API调用已成功记录

3. **健康检查失败**
   - 检查数据库连接字符串
   - 确认SQLite数据库文件存在且有读写权限
   - 检查服务日志: `docker logs quota-proxy` 或查看应用日志

### 日志查看
```bash
# 查看服务日志
docker logs -f quota-proxy

# 或者查看应用日志
tail -f logs/quota-proxy.log

# 查看监控相关日志
grep -i "monitoring\|stats\|health" logs/quota-proxy.log
```

## 总结

quota-proxy的监控功能提供了以下价值：
1. **实时状态监控**: 快速了解服务健康状态
2. **使用统计**: 分析API使用模式和趋势
3. **故障排查**: 通过状态页面快速定位问题
4. **容量规划**: 基于使用统计进行资源规划

通过以上测试步骤，可以确保监控功能正常工作，为生产环境部署提供可靠的状态监控能力。