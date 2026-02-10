# quota-proxy 常见问题与故障排除

本文档提供 quota-proxy 使用过程中的常见问题解答和故障排除指南。

## 目录
- [服务启动问题](#服务启动问题)
- [数据库问题](#数据库问题)
- [API 使用问题](#api-使用问题)
- [网络连接问题](#网络连接问题)
- [性能问题](#性能问题)
- [监控与日志](#监控与日志)
- [安全与权限](#安全与权限)

## 服务启动问题

### 1. Docker Compose 启动失败

**症状**: `docker compose up` 失败，容器无法启动

**可能原因及解决方案**:

1. **端口冲突**:
   ```bash
   # 检查8787端口是否被占用
   sudo lsof -i :8787
   # 或使用netstat
   sudo netstat -tlnp | grep :8787
   
   # 解决方案：修改docker-compose.yml中的端口映射
   # 将 "8787:8787" 改为 "8788:8787" 或其他可用端口
   ```

2. **镜像拉取失败**:
   ```bash
   # 检查网络连接
   curl -I https://hub.docker.com
   
   # 手动拉取镜像
   docker pull node:20-alpine
   
   # 使用国内镜像源（如果在中国大陆）
   # 在docker-compose.yml中添加镜像前缀
   # image: registry.cn-hangzhou.aliyuncs.com/library/node:20-alpine
   ```

3. **权限问题**:
   ```bash
   # 检查当前用户是否有docker权限
   groups
   
   # 将用户添加到docker组
   sudo usermod -aG docker $USER
   # 重新登录生效
   ```

### 2. 服务启动但健康检查失败

**症状**: 容器运行但 `curl http://localhost:8787/healthz` 返回错误

**排查步骤**:
```bash
# 1. 查看容器日志
docker compose logs quota-proxy

# 2. 进入容器检查
docker compose exec quota-proxy sh

# 3. 检查应用是否在运行
ps aux | grep node

# 4. 检查端口监听
netstat -tln | grep 8787

# 5. 从容器内部测试
curl -v http://localhost:8787/healthz
```

**常见解决方案**:
- 检查环境变量配置
- 检查数据库连接（如果是SQLite模式）
- 检查文件权限

## 数据库问题

### 1. SQLite 数据库文件权限问题

**症状**: 应用无法写入数据库文件

**解决方案**:
```bash
# 检查数据库文件权限
ls -la /opt/roc/quota-proxy/data/

# 修复权限
sudo chown -R 1000:1000 /opt/roc/quota-proxy/data/
sudo chmod 755 /opt/roc/quota-proxy/data/
sudo chmod 644 /opt/roc/quota-proxy/data/*.db 2>/dev/null || true
```

### 2. 数据库损坏

**症状**: 数据库查询失败，应用报错

**修复步骤**:
```bash
# 1. 备份当前数据库
cp /opt/roc/quota-proxy/data/quota.db /opt/roc/quota-proxy/data/quota.db.backup.$(date +%Y%m%d_%H%M%S)

# 2. 使用SQLite工具修复
sqlite3 /opt/roc/quota-proxy/data/quota.db ".dump" > /tmp/quota_backup.sql
sqlite3 /opt/roc/quota-proxy/data/quota_repaired.db < /tmp/quota_backup.sql

# 3. 验证修复后的数据库
sqlite3 /opt/roc/quota-proxy/data/quota_repaired.db ".tables"
sqlite3 /opt/roc/quota-proxy/data/quota_repaired.db "SELECT COUNT(*) FROM api_keys;"

# 4. 替换数据库文件
mv /opt/roc/quota-proxy/data/quota_repaired.db /opt/roc/quota-proxy/data/quota.db

# 5. 重启服务
docker compose restart quota-proxy
```

### 3. 数据库迁移失败

**症状**: 从内存模式迁移到SQLite模式失败

**解决方案**:
```bash
# 使用迁移脚本的dry-run模式检查
./scripts/migrate-to-sqlite.sh --dry-run

# 手动备份当前状态
docker compose stop quota-proxy
cp -r /opt/roc/quota-proxy/data /opt/roc/quota-proxy/data.backup

# 清理旧的数据库文件
rm -f /opt/roc/quota-proxy/data/quota.db

# 重新初始化数据库
./scripts/init-sqlite-db.sh --force

# 重新启动服务
docker compose up -d quota-proxy
```

## API 使用问题

### 1. API 密钥无效

**症状**: `401 Unauthorized` 错误

**排查步骤**:
```bash
# 1. 检查API密钥格式
echo "API_KEY: $API_KEY" | head -c 50

# 2. 验证密钥是否存在
curl -H "Authorization: Bearer $API_KEY" http://localhost:8787/admin/keys

# 3. 检查密钥配额
curl -H "Authorization: Bearer $API_KEY" http://localhost:8787/admin/usage

# 4. 生成新的API密钥
./scripts/generate-api-key.sh --prefix test --quota 1000
```

### 2. 代理请求失败

**症状**: 代理请求返回错误

**测试步骤**:
```bash
# 1. 测试健康检查
curl -v http://localhost:8787/healthz

# 2. 测试代理端点（使用有效API密钥）
curl -H "Authorization: Bearer $VALID_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST http://localhost:8787/v1/chat/completions \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello"}]}'

# 3. 检查请求日志
docker compose logs quota-proxy --tail=20
```

### 3. 管理员接口访问被拒绝

**症状**: `403 Forbidden` 错误

**解决方案**:
```bash
# 1. 检查ADMIN_TOKEN环境变量
echo "ADMIN_TOKEN: $ADMIN_TOKEN"

# 2. 验证管理员令牌
curl -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:8787/admin/health

# 3. 重新设置管理员令牌
# 编辑.env文件
echo "ADMIN_TOKEN=$(openssl rand -hex 32)" >> .env

# 4. 重启服务
docker compose down && docker compose up -d
```

## 网络连接问题

### 1. 外部服务连接超时

**症状**: 代理请求到外部API超时

**诊断步骤**:
```bash
# 1. 测试网络连通性
curl -v https://api.openai.com/v1/models

# 2. 检查DNS解析
nslookup api.openai.com

# 3. 测试代理服务器（如果有）
curl --proxy http://proxy-server:port https://api.openai.com/v1/models

# 4. 调整超时设置
# 在quota-proxy配置中增加超时时间
```

### 2. 容器网络问题

**症状**: 容器无法访问外部网络

**解决方案**:
```bash
# 1. 检查容器网络配置
docker network ls
docker network inspect quota-proxy_default

# 2. 测试容器内网络
docker compose exec quota-proxy curl -I https://google.com

# 3. 重启Docker网络
sudo systemctl restart docker

# 4. 使用host网络模式（测试用）
# 在docker-compose.yml中添加:
# network_mode: "host"
```

## 性能问题

### 1. 响应时间慢

**症状**: API响应延迟高

**优化建议**:
1. **数据库优化**:
   ```bash
   # 为常用查询添加索引
   sqlite3 /opt/roc/quota-proxy/data/quota.db \
     "CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(api_key);"
   
   sqlite3 /opt/roc/quota-proxy/data/quota.db \
     "CREATE INDEX IF NOT EXISTS idx_usage_stats_api_key ON usage_stats(api_key);"
   ```

2. **调整Node.js配置**:
   ```dockerfile
   # 在Dockerfile或docker-compose.yml中增加
   NODE_OPTIONS="--max-old-space-size=512"
   ```

3. **启用缓存**:
   ```javascript
   // 在应用代码中启用内存缓存
   const cache = new Map();
   ```

### 2. 内存使用过高

**症状**: 容器内存占用持续增长

**监控和优化**:
```bash
# 1. 监控内存使用
docker stats quota-proxy-quota-proxy-1

# 2. 查看内存快照
docker compose exec quota-proxy node -e "console.log(process.memoryUsage())"

# 3. 限制容器内存
# 在docker-compose.yml中添加:
# deploy:
#   resources:
#     limits:
#       memory: 512M
```

## 监控与日志

### 1. 日志不显示

**症状**: `docker compose logs` 无输出

**解决方案**:
```bash
# 1. 检查日志驱动
docker inspect quota-proxy-quota-proxy-1 | grep -A5 LogConfig

# 2. 直接查看应用日志文件
docker compose exec quota-proxy cat /app/logs/app.log 2>/dev/null || \
  docker compose exec quota-proxy ls -la /app/

# 3. 调整日志级别
# 设置环境变量: LOG_LEVEL=debug
```

### 2. 监控指标缺失

**症状**: Prometheus/metrics端点无数据

**排查步骤**:
```bash
# 1. 检查metrics端点
curl http://localhost:8787/metrics

# 2. 验证Prometheus配置
# 检查是否启用了metrics收集

# 3. 手动启用metrics
# 设置环境变量: ENABLE_METRICS=true
```

## 安全与权限

### 1. 安全漏洞扫描

定期进行安全检查:
```bash
# 1. 扫描镜像漏洞
docker scan quota-proxy-quota-proxy

# 2. 检查依赖漏洞
docker compose exec quota-proxy npm audit

# 3. 更新依赖
docker compose exec quota-proxy npm update
```

### 2. 权限加固

**建议的安全实践**:
1. **使用非root用户运行容器**:
   ```dockerfile
   USER node
   ```

2. **限制文件系统访问**:
   ```yaml
   volumes:
     - ./data:/app/data:ro  # 只读挂载
   ```

3. **网络隔离**:
   ```yaml
   networks:
     internal:
       internal: true
   ```

## 紧急恢复

### 1. 服务完全不可用

**紧急恢复步骤**:
```bash
# 1. 停止所有服务
docker compose down

# 2. 备份关键数据
tar -czf /tmp/quota-proxy-backup-$(date +%Y%m%d_%H%M%S).tar.gz \
  /opt/roc/quota-proxy/data/ \
  /opt/roc/quota-proxy/.env

# 3. 清理并重新部署
rm -rf /opt/roc/quota-proxy/data/*
cp .env.example .env

# 4. 重新启动
docker compose up -d --build

# 5. 验证恢复
curl -f http://localhost:8787/healthz && echo "恢复成功"
```

### 2. 数据丢失恢复

**从备份恢复**:
```bash
# 1. 停止服务
docker compose down

# 2. 恢复数据库
tar -xzf /path/to/backup.tar.gz -C /opt/roc/quota-proxy/

# 3. 修复权限
chown -R 1000:1000 /opt/roc/quota-proxy/data

# 4. 启动服务
docker compose up -d

# 5. 验证数据
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/keys | jq '.total'
```

## 获取帮助

如果以上解决方案无法解决问题，请:

1. **收集诊断信息**:
   ```bash
   # 收集系统信息
   ./scripts/collect-diagnostics.sh
   ```

2. **查看详细日志**:
   ```bash
   docker compose logs --tail=100 quota-proxy > quota-proxy-logs.txt
   ```

3. **提交Issue**:
   - 在GitHub仓库提交Issue
   - 包含诊断信息和日志文件
   - 描述重现步骤

4. **社区支持**:
   - 加入OpenClaw Discord社区
   - 在相关论坛提问

---

**最后更新**: 2026-02-10  
**维护者**: 中华AI共和国项目组  
**文档版本**: 1.0.0