# quota-proxy 快速开始指南

本指南将帮助您在5分钟内快速部署和试用 quota-proxy API 网关服务。

## 1. 前提条件

- Docker 和 Docker Compose 已安装
- 至少 1GB 可用内存
- 网络访问权限（用于下载镜像）

## 2. 一键部署

```bash
# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic

# 运行部署脚本
./scripts/deploy-quota-proxy.sh

# 或者使用详细模式查看部署过程
./scripts/deploy-quota-proxy.sh --verbose
```

## 3. 验证安装

```bash
# 检查服务状态
./scripts/monitor-quota-proxy.sh

# 健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 预期响应: {"ok":true}
```

## 4. 获取试用密钥

```bash
# 使用默认管理员令牌获取试用密钥
ADMIN_TOKEN="your-admin-token-here"  # 默认在 .env 文件中
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"quota": 1000, "expires_in": 86400}'

# 响应示例:
# {"key":"trial_abc123...","quota":1000,"expires_at":"2026-02-11T22:29:52Z"}
```

## 5. 使用 API 网关

```bash
# 使用试用密钥调用 API
TRIAL_KEY="trial_abc123..."
curl -X POST http://127.0.0.1:8787/v1/chat/completions \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## 6. 监控使用情况

```bash
# 查看所有密钥的使用统计
curl -X GET http://127.0.0.1:8787/admin/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查看特定密钥的使用情况
curl -X GET "http://127.0.0.1:8787/admin/usage?key=trial_abc123..." \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 7. 常用管理命令

```bash
# 停止服务
cd /opt/roc/quota-proxy
docker compose down

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart
```

## 8. 故障排除

### 服务无法启动
```bash
# 检查端口占用
sudo lsof -i :8787

# 检查 Docker 状态
docker ps
docker compose ps
```

### 健康检查失败
```bash
# 检查容器日志
docker compose logs quota-proxy

# 检查数据库连接
docker exec -it quota-proxy-quota-proxy-1 sqlite3 /data/quota.db ".tables"
```

### 试用密钥无效
```bash
# 检查密钥是否过期
./scripts/cleanup-expired-trial-keys.sh --list

# 重新生成密钥
./scripts/test-post-admin-keys.sh --verbose
```

## 9. 下一步

- 查看 [完整配置指南](configuration-guide.md) 了解高级配置选项
- 阅读 [API 文档](api-documentation.md) 了解所有可用接口
- 探索 [监控和告警](monitoring-alerts.md) 设置生产环境监控
- 学习 [备份和恢复](backup-recovery.md) 确保数据安全

## 10. 获取帮助

- 查看 [常见问题解答](faq.md)
- 提交 [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)
- 加入社区讨论

---

**提示**: 生产环境部署前，请务必：
1. 修改默认的 ADMIN_TOKEN
2. 配置 HTTPS 证书
3. 设置适当的防火墙规则
4. 配置监控和告警
5. 定期备份数据库