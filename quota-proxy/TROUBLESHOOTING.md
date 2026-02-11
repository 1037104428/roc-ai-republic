# 故障排除指南

本文档提供 quota-proxy 常见问题的诊断和解决方案。

## 快速诊断流程

### 1. 服务状态检查
```bash
# 检查 Docker Compose 服务状态
cd /opt/roc/quota-proxy
docker compose ps

# 检查容器日志
docker compose logs quota-proxy

# 检查健康端点
curl -fsS http://127.0.0.1:8787/healthz
```

### 2. 数据库连接问题
```bash
# 检查 SQLite 数据库文件
ls -la /opt/roc/quota-proxy/data/

# 检查数据库权限
ls -la /opt/roc/quota-proxy/data/quota.db

# 手动测试数据库连接
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT COUNT(*) FROM quota_usage;"
```

### 3. 网络和端口问题
```bash
# 检查端口监听
netstat -tlnp | grep 8787

# 检查防火墙规则
sudo ufw status

# 测试本地连接
curl -v http://127.0.0.1:8787/healthz
```

## 常见问题及解决方案

### 问题1: Docker Compose 启动失败
**症状**: `docker compose up -d` 失败，容器无法启动

**解决方案**:
1. 检查 Docker 服务状态:
   ```bash
   sudo systemctl status docker
   ```

2. 检查 Docker Compose 版本:
   ```bash
   docker compose version
   ```

3. 检查环境变量文件:
   ```bash
   # 确保 .env 文件存在
   ls -la .env
   
   # 检查关键环境变量
   grep -E "ADMIN_TOKEN|PORT|DATABASE_URL" .env
   ```

4. 清理并重新启动:
   ```bash
   docker compose down
   docker compose up -d
   ```

### 问题2: 健康检查失败
**症状**: `curl http://127.0.0.1:8787/healthz` 返回非 200 状态码

**解决方案**:
1. 检查容器日志:
   ```bash
   docker compose logs quota-proxy --tail=50
   ```

2. 检查数据库连接:
   ```bash
   # 进入容器检查
   docker compose exec quota-proxy sh -c "sqlite3 /app/data/quota.db 'SELECT 1;'"
   ```

3. 检查环境变量:
   ```bash
   docker compose exec quota-proxy env | grep -E "DATABASE_URL|ADMIN_TOKEN"
   ```

### 问题3: 管理员 API 返回 401 未授权
**症状**: 使用 `POST /admin/keys` 或 `GET /admin/usage` 返回 401

**解决方案**:
1. 验证 ADMIN_TOKEN:
   ```bash
   # 检查 .env 文件中的 ADMIN_TOKEN
   grep ADMIN_TOKEN .env
   
   # 验证 token 格式（应为 32 字符 hex）
   ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2)
   echo "Token length: ${#ADMIN_TOKEN}"
   ```

2. 检查请求头:
   ```bash
   # 正确的 curl 命令格式
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST http://127.0.0.1:8787/admin/keys \
        -d '{"quota": 1000, "expires_in": 86400}'
   ```

### 问题4: SQLite 数据库权限问题
**症状**: 数据库写入失败，日志显示 "permission denied"

**解决方案**:
1. 检查文件权限:
   ```bash
   ls -la /opt/roc/quota-proxy/data/
   sudo chown -R 1000:1000 /opt/roc/quota-proxy/data/
   ```

2. 检查挂载权限:
   ```bash
   # 检查 docker-compose.yml 中的 volumes 配置
   cat docker-compose.yml | grep -A2 -B2 "volumes"
   ```

### 问题5: 试用密钥验证失败
**症状**: 使用 TRIAL_KEY 访问 API 返回 403

**解决方案**:
1. 检查密钥状态:
   ```bash
   # 使用管理员权限查询密钥状态
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://127.0.0.1:8787/admin/keys
   ```

2. 检查密钥是否过期:
   ```bash
   # 检查密钥的 expires_at 字段
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://127.0.0.1:8787/admin/keys | jq .
   ```

3. 生成新的试用密钥:
   ```bash
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST http://127.0.0.1:8787/admin/keys \
        -d '{"quota": 1000, "expires_in": 86400}'
   ```

## 调试模式

### 启用详细日志
```bash
# 修改 .env 文件
echo "LOG_LEVEL=debug" >> .env

# 重启服务
docker compose down
docker compose up -d

# 查看详细日志
docker compose logs quota-proxy --tail=100 -f
```

### 手动测试端点
```bash
# 测试健康端点
curl -v http://127.0.0.1:8787/healthz

# 测试配额检查（需要有效的 TRIAL_KEY）
curl -v -H "Authorization: Bearer $TRIAL_KEY" \
     http://127.0.0.1:8787/v1/quota/check

# 测试管理员端点（需要 ADMIN_TOKEN）
curl -v -H "Authorization: Bearer $ADMIN_TOKEN" \
     http://127.0.0.1:8787/admin/usage
```

## 性能问题

### 高延迟响应
**解决方案**:
1. 检查数据库性能:
   ```bash
   # 检查数据库大小
   du -sh /opt/roc/quota-proxy/data/quota.db
   
   # 优化数据库
   sqlite3 /opt/roc/quota-proxy/data/quota.db "VACUUM;"
   ```

2. 检查系统资源:
   ```bash
   # 查看容器资源使用
   docker stats quota-proxy
   
   # 查看系统负载
   top -b -n 1 | head -20
   ```

### 内存使用过高
**解决方案**:
1. 调整 Docker 资源限制:
   ```yaml
   # 在 docker-compose.yml 中添加
   services:
     quota-proxy:
       deploy:
         resources:
           limits:
             memory: 512M
   ```

2. 重启容器释放内存:
   ```bash
   docker compose restart quota-proxy
   ```

## 紧急恢复

### 数据库损坏恢复
```bash
# 1. 停止服务
docker compose down

# 2. 备份当前数据库
cp /opt/roc/quota-proxy/data/quota.db /opt/roc/quota-proxy/data/quota.db.backup.$(date +%Y%m%d_%H%M%S)

# 3. 尝试修复
sqlite3 /opt/roc/quota-proxy/data/quota.db ".dump" > /tmp/quota_dump.sql
sqlite3 /opt/roc/quota-proxy/data/quota.new.db < /tmp/quota_dump.sql
mv /opt/roc/quota-proxy/data/quota.new.db /opt/roc/quota-proxy/data/quota.db

# 4. 重新启动
docker compose up -d
```

### 重置管理员令牌
```bash
# 生成新的管理员令牌
NEW_TOKEN=$(openssl rand -hex 32)
echo "ADMIN_TOKEN=$NEW_TOKEN" > .env

# 重启服务
docker compose down
docker compose up -d
```

## 联系支持

如果以上解决方案无法解决问题，请提供以下信息:

1. Docker Compose 日志: `docker compose logs quota-proxy`
2. 环境配置: `cat .env` (隐藏敏感信息)
3. 系统信息: `uname -a` 和 `docker version`
4. 错误复现步骤

提交问题到: https://github.com/1037104428/roc-ai-republic/issues