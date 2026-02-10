# quota-proxy 使用统计监控指南

## 概述

`monitor-quota-usage.sh` 是一个用于监控 quota-proxy API 使用情况的脚本工具。它可以定期检查服务状态、获取 trial key 列表、统计使用数据，并生成详细的使用报告。

## 功能特性

- ✅ **健康检查**: 验证 quota-proxy 服务是否正常运行
- ✅ **Key 管理**: 获取所有 trial key 列表
- ✅ **使用统计**: 统计每个 key 的请求数、成功率、剩余配额
- ✅ **异常检测**: 自动检测异常使用模式（高失败率、低配额等）
- ✅ **报告生成**: 生成格式化的使用报告，包含汇总统计和建议
- ✅ **灵活配置**: 支持自定义服务地址、输出文件、详细模式等

## 快速开始

### 1. 基本用法

```bash
# 使用环境变量中的 ADMIN_TOKEN
cd /opt/roc/quota-proxy
./scripts/monitor-quota-usage.sh -t "$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)"
```

### 2. 完整示例

```bash
# 指定所有参数
./scripts/monitor-quota-usage.sh \
  -t "your-admin-token-here" \
  -u "http://localhost:8787" \
  -o "/var/log/quota-usage-$(date +%Y%m%d).log" \
  -v
```

### 3. 模拟运行（测试配置）

```bash
# 不实际调用 API，测试脚本逻辑
./scripts/monitor-quota-usage.sh -t "test-token" -d -v
```

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--token` | `-t` | ADMIN_TOKEN（必需） | 无 |
| `--url` | `-u` | quota-proxy 服务地址 | `http://127.0.0.1:8787` |
| `--output` | `-o` | 输出文件路径 | `/tmp/quota-usage-report-YYYYMMDD-HHMMSS.txt` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | `-d` | 模拟运行，不实际调用 API | `false` |
| `--help` | `-h` | 显示帮助信息 | 无 |

## 输出报告示例

```
=============================================
quota-proxy 使用统计报告
=============================================
生成时间: 2026-02-10 15:00:00 CST
服务地址: http://127.0.0.1:8787
报告文件: /tmp/quota-usage-report-20260210-150000.txt

服务状态: ✅ 健康

📊 使用统计概览
---------------------------------------------
🔑 Key: trial-key-1
   📈 总请求: 150
   ✅ 成功: 145
   ❌ 失败: 5
   💰 剩余配额: 850
   📊 使用率: 15%
   ⏰ 最后使用: 2026-02-10T14:55:00Z

🔑 Key: trial-key-2
   📈 总请求: 75
   ✅ 成功: 72
   ❌ 失败: 3
   💰 剩余配额: 925
   📊 使用率: 7%
   ⏰ 最后使用: 2026-02-10T13:30:00Z

=============================================
📈 汇总统计
---------------------------------------------
活跃 key 数量: 2
总请求数: 225
成功请求: 217
失败请求: 8
总剩余配额: 1775
成功率: 96%

🔍 异常检测
---------------------------------------------
✅ 失败率正常
✅ 配额充足

💡 建议操作
---------------------------------------------
4. 定期运行此监控脚本 (建议每小时)
```

## 集成到监控系统

### 1. 定期监控（cron 任务）

```bash
# 每小时运行一次
0 * * * * cd /opt/roc/quota-proxy && ./scripts/monitor-quota-usage.sh -t "$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)" -o /var/log/quota-usage-hourly.log >> /var/log/quota-monitor.log 2>&1

# 每天凌晨生成汇总报告
0 0 * * * cd /opt/roc/quota-proxy && ./scripts/monitor-quota-usage.sh -t "$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)" -o /var/log/quota-usage-daily-$(date +\%Y\%m\%d).log -v >> /var/log/quota-daily.log 2>&1
```

### 2. 监控告警配置

```bash
#!/bin/bash
# alert-on-anomaly.sh - 异常告警脚本

cd /opt/roc/quota-proxy
REPORT_FILE="/tmp/quota-usage-alert-$(date +%s).txt"

# 运行监控
./scripts/monitor-quota-usage.sh \
  -t "$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)" \
  -o "$REPORT_FILE" \
  -v

# 检查失败率
FAILURE_RATE=$(grep "失败率" "$REPORT_FILE" | grep -o "[0-9]*%" | tr -d '%')
if [[ $FAILURE_RATE -gt 10 ]]; then
  echo "⚠️  quota-proxy 失败率过高: $FAILURE_RATE%" | mail -s "quota-proxy 告警" admin@example.com
fi

# 检查配额
REMAINING=$(grep "总剩余配额" "$REPORT_FILE" | grep -o "[0-9]*")
if [[ $REMAINING -lt 500 ]]; then
  echo "⚠️  quota-proxy 剩余配额不足: $REMAINING" | mail -s "quota-proxy 告警" admin@example.com
fi
```

### 3. 与现有监控系统集成

```bash
# 发送数据到 Prometheus
#!/bin/bash
# quota-metrics-to-prometheus.sh

cd /opt/roc/quota-proxy
REPORT_FILE="/tmp/quota-metrics-$(date +%s).txt"

./scripts/monitor-quota-usage.sh \
  -t "$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)" \
  -o "$REPORT_FILE"

# 提取指标
TOTAL_REQUESTS=$(grep "总请求数" "$REPORT_FILE" | grep -o "[0-9]*")
SUCCESS_RATE=$(grep "成功率" "$REPORT_FILE" | grep -o "[0-9]*")
ACTIVE_KEYS=$(grep "活跃 key 数量" "$REPORT_FILE" | grep -o "[0-9]*")

# 生成 Prometheus 格式
cat << EOF > /var/lib/prometheus/quota-metrics.prom
# HELP quota_total_requests Total API requests
# TYPE quota_total_requests gauge
quota_total_requests $TOTAL_REQUESTS

# HELP quota_success_rate API success rate percentage
# TYPE quota_success_rate gauge
quota_success_rate $SUCCESS_RATE

# HELP quota_active_keys Number of active trial keys
# TYPE quota_active_keys gauge
quota_active_keys $ACTIVE_KEYS
EOF
```

## 故障排除

### 常见问题

1. **权限错误**
   ```
   错误: 必须提供 ADMIN_TOKEN
   ```
   **解决方案**: 确保提供有效的 ADMIN_TOKEN
   ```bash
   # 从 .env 文件读取
   ADMIN_TOKEN=$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)
   ./scripts/monitor-quota-usage.sh -t "$ADMIN_TOKEN"
   ```

2. **连接失败**
   ```
   ✗ 服务不可用: http://127.0.0.1:8787/healthz
   ```
   **解决方案**: 检查 quota-proxy 服务状态
   ```bash
   # 检查服务是否运行
   docker compose ps
   
   # 检查端口监听
   netstat -tlnp | grep 8787
   
   # 检查防火墙
   sudo ufw status
   ```

3. **认证失败**
   ```
   curl: (22) The requested URL returned error: 401
   ```
   **解决方案**: 验证 ADMIN_TOKEN 是否正确
   ```bash
   # 重新生成 ADMIN_TOKEN
   ADMIN_TOKEN=$(openssl rand -hex 32)
   echo "ADMIN_TOKEN=$ADMIN_TOKEN" >> .env
   
   # 重启服务
   docker compose restart
   ```

### 调试模式

使用详细模式查看详细输出：

```bash
./scripts/monitor-quota-usage.sh -t "$ADMIN_TOKEN" -v
```

## 最佳实践

### 1. 安全建议

- **保护 ADMIN_TOKEN**: 不要硬编码在脚本中，使用环境变量或配置文件
- **限制访问**: 监控脚本应仅限管理员访问
- **日志轮转**: 定期清理旧的监控日志

### 2. 性能优化

- **减少频率**: 根据实际需求调整监控频率（每小时通常足够）
- **批量处理**: 如果有大量 key，考虑分批处理
- **缓存结果**: 对于频繁查询，可以缓存部分结果

### 3. 扩展建议

- **集成告警**: 与 Slack、Telegram、邮件等告警系统集成
- **数据可视化**: 将数据导入 Grafana 等可视化工具
- **历史分析**: 存储历史数据，进行趋势分析

## 相关资源

- [quota-proxy 部署指南](./quota-proxy-deployment.md)
- [管理员 API 文档](./admin-api-reference.md)
- [故障排查指南](./troubleshooting.md)

## 更新日志

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0.0 | 2026-02-10 | 初始版本发布，包含基本监控功能 |
| 1.0.1 | 2026-02-10 | 添加详细模式、模拟运行选项 |
| 1.0.2 | 2026-02-10 | 改进错误处理和报告格式 |

## 贡献

欢迎提交 Issue 和 Pull Request 来改进此工具。

## 许可证

MIT License