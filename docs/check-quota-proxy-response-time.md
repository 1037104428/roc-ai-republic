# quota-proxy 响应时间检查脚本

## 概述

`check-quota-proxy-response-time.sh` 是一个用于监控 quota-proxy API 网关性能和可用性的工具脚本。它可以测量不同端点的响应时间，帮助识别性能瓶颈和可用性问题。

## 功能特性

- ✅ **健康检查端点监控** - 测量 `/healthz` 端点的响应时间
- ✅ **验证端点测试** - 使用 TRIAL_KEY 测试 `/verify` 端点
- ✅ **管理员端点测试** - 使用管理员令牌测试 `/admin/keys` 端点
- ✅ **灵活配置** - 支持自定义服务器、端口、超时时间
- ✅ **性能基准** - 提供响应时间分类建议（正常/警告/需要调查）
- ✅ **Cron 集成** - 适合定期监控和告警

## 快速开始

### 基本使用

```bash
# 基本健康检查（使用 /tmp/server.txt 中的服务器IP）
./scripts/check-quota-proxy-response-time.sh

# 指定服务器
./scripts/check-quota-proxy-response-time.sh -s 8.210.185.194

# 使用 TRIAL_KEY 测试验证端点
./scripts/check-quota-proxy-response-time.sh -k your_trial_key_here

# 测试管理员端点
./scripts/check-quota-proxy-response-time.sh --admin-token your_admin_token_here
```

### 完整参数

```bash
./scripts/check-quota-proxy-response-time.sh --help
```

## 响应时间分类

脚本通过SSH在服务器内部执行检查，响应时间包含SSH连接开销。提供以下性能基准建议：

| 响应时间（包含SSH） | 分类 | 建议 |
|-------------------|------|------|
| < 500ms | 正常 | 性能良好 |
| 500-1000ms | 警告 | 需要关注，可能存在网络延迟或负载 |
| > 1000ms | 需要调查 | 可能存在性能问题或网络故障 |

## 集成到监控系统

### 1. 定期监控（Cron）

```bash
# 每5分钟检查一次，记录到日志文件
*/5 * * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/check-quota-proxy-response-time.sh >> /var/log/quota-proxy-monitor.log 2>&1
```

### 2. 告警脚本示例

```bash
#!/bin/bash
# alert-if-slow.sh

RESULT=$(./scripts/check-quota-proxy-response-time.sh -s 8.210.185.194 2>&1)

# 提取健康检查响应时间
HEALTHZ_TIME=$(echo "$RESULT" | grep "健康检查端点" -A 1 | grep -oP '响应时间: \K[0-9]+ms' | sed 's/ms//')

if [[ -n "$HEALTHZ_TIME" && "$HEALTHZ_TIME" -gt 500 ]]; then
    echo "警告: quota-proxy 响应时间 ${HEALTHZ_TIME}ms > 500ms" | mail -s "quota-proxy 性能告警" admin@example.com
fi
```

### 3. Prometheus 指标导出

```bash
#!/bin/bash
# export-prometheus-metrics.sh

SERVER="8.210.185.194"
PORT="8787"

# 测量响应时间
START=$(date +%s%N)
curl -fsS -m 5 "http://${SERVER}:${PORT}/healthz" >/dev/null 2>&1
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

# 输出 Prometheus 格式指标
cat <<EOF
# HELP quota_proxy_healthz_response_ms Health check endpoint response time in milliseconds
# TYPE quota_proxy_healthz_response_ms gauge
quota_proxy_healthz_response_ms{server="${SERVER}",port="${PORT}"} ${DURATION_MS}
EOF
```

## 故障排查

### 常见问题

1. **连接超时**
   ```bash
   # 检查网络连通性
   ping 8.210.185.194
   
   # 检查端口是否开放
   nc -zv 8.210.185.194 8787
   ```

2. **响应时间过长**
   - 检查服务器负载：`ssh root@8.210.185.194 "top -bn1"`
   - 检查容器状态：`ssh root@8.210.185.194 "docker stats quota-proxy-quota-proxy-1"`
   - 检查网络延迟：`ssh root@8.210.185.194 "ping -c 4 google.com"`

3. **管理员端点不可用**
   - 确认管理员令牌正确
   - 检查容器日志：`ssh root@8.210.185.194 "docker logs quota-proxy-quota-proxy-1"`

### 调试模式

```bash
# 增加详细输出
./scripts/check-quota-proxy-response-time.sh -s 8.210.185.194 -t 10

# 结合其他验证脚本
./scripts/quick-server-status.sh && ./scripts/check-quota-proxy-response-time.sh
```

## 最佳实践

1. **基线测量** - 在系统正常时记录基准响应时间
2. **定期监控** - 设置 cron 任务定期检查
3. **趋势分析** - 记录历史数据，分析性能趋势
4. **告警阈值** - 根据业务需求设置合适的告警阈值
5. **自动化恢复** - 结合其他脚本实现自动重启或故障转移

## 相关脚本

- `quick-server-status.sh` - 快速服务器状态检查
- `verify-sqlite-persistence-on-server.sh` - SQLite 持久化验证
- `test-trial-key-lifecycle.sh` - TRIAL_KEY 生命周期测试
- `ssh-healthz-quota-proxy.sh` - 简单的健康检查

## 版本历史

- v1.0.0 (2026-02-09) - 初始版本，支持基本响应时间检查

## 贡献

发现问题或改进建议？请提交 Issue 或 Pull Request。