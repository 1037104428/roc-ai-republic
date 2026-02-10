# 健康监控指南

本文档介绍如何监控中华AI共和国各项服务的健康状态。

## 一键监控脚本

### quota-proxy 服务监控

```bash
# 基本监控
./scripts/health-monitor-quota-proxy.sh

# 输出示例:
# 监控 quota-proxy 服务状态...
# 服务器: 8.210.185.194
# 时间: 2026-02-10 12:10:00 CST
# 
# 1. 检查 Docker 容器状态:
# NAME                        IMAGE                     ... STATUS        PORTS
# quota-proxy-quota-proxy-1   quota-proxy-quota-proxy   ... Up 12 hours   127.0.0.1:8787->8787/tcp
# ✅ 容器运行正常
# 
# 2. 检查健康端点 (127.0.0.1:8787/healthz):
# 响应: {"ok":true}
# ✅ 健康端点正常
# 
# === 监控总结 ===
# ✅ 服务完全健康
```

### 全站探活脚本

```bash
# 检查官网、API、论坛、quota-proxy
./scripts/probe.sh

# 仅检查公开服务（无服务器权限时）
./scripts/probe.sh --no-ssh

# JSON 格式输出（适合 CI/CD）
./scripts/probe-roc-all.sh --json
```

## 监控指标

### 1. 官网 (clawdrepublic.cn)
- 可访问性: `curl -fsS https://clawdrepublic.cn/`
- 响应时间: < 2秒
- HTTP 状态码: 200

### 2. API 网关 (api.clawdrepublic.cn)
- 健康端点: `curl -fsS https://api.clawdrepublic.cn/healthz`
- 期望响应: `{"ok":true}`
- 模型列表: `curl -fsS https://api.clawdrepublic.cn/v1/models`

### 3. quota-proxy 服务
- 容器状态: `docker compose ps` 显示 "Up"
- 健康端点: `curl -fsS http://127.0.0.1:8787/healthz`
- 管理接口: 需要 ADMIN_TOKEN

### 4. 论坛 (forum.clawdrepublic.cn)
- 可访问性: `curl -fsS https://forum.clawdrepublic.cn/`
- 内容检查: 包含 "Clawd 国度论坛"

## 故障排查

### 常见问题

1. **quota-proxy 容器未运行**
   ```bash
   # 登录服务器检查
   ssh -i ~/.ssh/id_ed25519_roc_server root@<server-ip>
   cd /opt/roc/quota-proxy
   docker compose logs
   docker compose up -d
   ```

2. **健康端点返回异常**
   ```bash
   # 检查日志
   docker compose logs quota-proxy
   
   # 检查数据库连接（SQLite 版本）
   ls -la data/
   ```

3. **API 网关 502 错误**
   - 检查 quota-proxy 是否运行
   - 检查反向代理配置
   - 检查防火墙规则

### 自动化监控

可以配置 cron 任务定期监控:

```bash
# 每5分钟检查一次
*/5 * * * * cd /path/to/roc-ai-republic && ./scripts/health-monitor-quota-proxy.sh > /tmp/quota-monitor.log 2>&1

# 每小时全站检查
0 * * * * cd /path/to/roc-ai-republic && ./scripts/probe.sh --no-ssh > /tmp/full-probe.log 2>&1
```

## 告警配置

当监控脚本返回非零退出码时，可以触发告警:

```bash
#!/bin/bash
if ! ./scripts/health-monitor-quota-proxy.sh; then
    # 发送告警（示例）
    echo "quota-proxy 服务异常！" | mail -s "服务告警" admin@example.com
    # 或使用 webhook
    curl -X POST -H "Content-Type: application/json" \
         -d '{"text":"quota-proxy 服务异常"}' \
         https://hooks.slack.com/services/...
fi
```

## 相关脚本

- `scripts/health-monitor-quota-proxy.sh` - quota-proxy 专用监控
- `scripts/probe.sh` - 全站探活（含服务器）
- `scripts/probe-roc-all.sh` - 全站探活（JSON 输出）
- `scripts/ssh-healthz-quota-proxy.sh` - 快速健康检查

## 最佳实践

1. **定期监控**: 至少每天检查一次全站服务
2. **日志保留**: 保留至少7天的监控日志
3. **告警升级**: 设置多级告警（邮件→短信→电话）
4. **恢复预案**: 为每种故障准备恢复步骤
5. **文档更新**: 故障处理后更新本文档