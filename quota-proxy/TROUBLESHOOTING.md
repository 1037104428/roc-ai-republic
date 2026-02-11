# 故障排除指南

本文档提供 quota-proxy 常见问题的诊断和解决方案。

## 快速诊断流程

1. **检查服务状态**
   ```bash
   # Docker Compose 环境
   docker compose ps
   
   # 查看日志
   docker compose logs -f quota-proxy
   
   # 健康检查
   curl -fsS http://127.0.0.1:8787/healthz
   ```

2. **检查环境变量配置**
   ```bash
   # 使用验证脚本
   ./verify-env-vars.sh --quick
   
   # 手动检查必需变量
   echo "DATABASE_URL: ${DATABASE_URL:-未设置}"
   echo "ADMIN_TOKEN: ${ADMIN_TOKEN:-未设置}"
   echo "PORT: ${PORT:-未设置}"
   ```

3. **检查数据库连接**
   ```bash
   # 检查数据库文件
   ls -la quota-proxy/data/
   
   # 使用 SQLite 验证脚本
   ./verify-sqlite-integrity.sh --quick
   ```

## 常见问题

### 1. 服务无法启动

**症状**: `docker compose up` 失败或容器立即退出

**可能原因**:
- 必需环境变量缺失
- 端口被占用
- 数据库文件权限问题

**解决方案**:
```bash
# 1. 验证环境变量
./verify-env-vars.sh --full

# 2. 检查端口占用
sudo lsof -i :8787

# 3. 检查数据库文件权限
ls -la quota-proxy/data/
chmod 644 quota-proxy/data/quota.db  # 如果需要

# 4. 查看详细日志
docker compose logs --tail=50 quota-proxy
```

### 2. 健康检查失败

**症状**: `curl http://127.0.0.1:8787/healthz` 返回非 200 状态码

**可能原因**:
- 数据库连接失败
- 服务内部错误
- 内存不足

**解决方案**:
```bash
# 1. 检查数据库连接
sqlite3 quota-proxy/data/quota.db "SELECT count(*) FROM api_keys;"

# 2. 检查服务日志中的错误
docker compose logs quota-proxy | grep -i error

# 3. 重启服务
docker compose restart quota-proxy

# 4. 检查系统资源
free -h
df -h .
```

### 3. API 调用返回 401 或 403

**症状**: API 调用返回认证错误

**可能原因**:
- TRIAL_KEY 无效或过期
- TRIAL_KEY 格式错误
- 管理员令牌配置错误

**解决方案**:
```bash
# 1. 验证 TRIAL_KEY 格式
echo "你的TRIAL_KEY" | wc -c  # 应该为 32 字符

# 2. 检查密钥是否在数据库中
sqlite3 quota-proxy/data/quota.db "SELECT key, enabled, created_at FROM api_keys WHERE key='你的TRIAL_KEY';"

# 3. 重新生成 TRIAL_KEY
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"note":"故障排除重新生成"}'
```

### 4. 数据库文件损坏

**症状**: 数据库相关操作失败，日志显示 SQLite 错误

**可能原因**:
- 磁盘空间不足
- 异常关机导致数据库损坏
- 文件权限问题

**解决方案**:
```bash
# 1. 使用完整性验证脚本
./verify-sqlite-integrity.sh --full

# 2. 备份当前数据库
cp quota-proxy/data/quota.db quota-proxy/data/quota.db.backup.$(date +%Y%m%d_%H%M%S)

# 3. 尝试修复数据库
sqlite3 quota-proxy/data/quota.db ".dump" | sqlite3 quota-proxy/data/quota.fixed.db
mv quota-proxy/data/quota.fixed.db quota-proxy/data/quota.db

# 4. 从备份恢复（如果修复失败）
cp quota-proxy/data/quota.db.backup.* quota-proxy/data/quota.db
```

### 5. 性能问题

**症状**: API 响应缓慢，高延迟

**可能原因**:
- 数据库索引缺失
- 日志级别过高
- 系统资源不足

**解决方案**:
```bash
# 1. 检查数据库索引
sqlite3 quota-proxy/data/quota.db ".indices"

# 2. 调整日志级别（如果使用 DEBUG 级别）
export LOG_LEVEL=INFO
docker compose restart quota-proxy

# 3. 监控系统资源
docker stats quota-proxy_quota-proxy_1

# 4. 优化数据库
sqlite3 quota-proxy/data/quota.db "VACUUM;"
sqlite3 quota-proxy/data/quota.db "ANALYZE;"
```

### 6. Docker 网络问题

**症状**: 容器间通信失败，无法连接到数据库或其他服务

**可能原因**:
- Docker 网络配置问题
- 防火墙规则
- 主机网络问题

**解决方案**:
```bash
# 1. 检查 Docker 网络
docker network ls
docker network inspect quota-proxy_default

# 2. 测试容器间连通性
docker compose exec quota-proxy ping -c 3 db

# 3. 检查防火墙
sudo ufw status
sudo iptables -L -n | grep DOCKER

# 4. 重启 Docker 服务
sudo systemctl restart docker
```

## 诊断工具

### 快速诊断脚本
```bash
#!/bin/bash
# quick-diagnose.sh

echo "=== quota-proxy 快速诊断 ==="
echo "时间: $(date)"
echo ""

echo "1. 服务状态检查"
docker compose ps 2>/dev/null || echo "Docker Compose 未运行"

echo ""
echo "2. 健康检查"
curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null && echo "✓ 健康检查通过" || echo "✗ 健康检查失败"

echo ""
echo "3. 环境变量检查"
./verify-env-vars.sh --quick 2>/dev/null || echo "环境变量检查失败"

echo ""
echo "4. 数据库检查"
./verify-sqlite-integrity.sh --quick 2>/dev/null || echo "数据库检查失败"

echo ""
echo "=== 诊断完成 ==="
```

### 日志分析命令
```bash
# 查看最近错误
docker compose logs quota-proxy | grep -i error | tail -20

# 查看 API 访问日志
docker compose logs quota-proxy | grep "POST\|GET\|PUT\|DELETE" | tail -20

# 查看启动日志
docker compose logs quota-proxy | grep -i "starting\|listening\|ready" | tail -10
```

## 紧急恢复步骤

如果服务完全不可用，按以下步骤恢复：

1. **停止所有服务**
   ```bash
   docker compose down
   ```

2. **备份重要数据**
   ```bash
   cp -r quota-proxy/data/ quota-proxy/data.backup.$(date +%Y%m%d_%H%M%S)/
   ```

3. **检查系统状态**
   ```bash
   df -h .  # 磁盘空间
   free -h  # 内存
   docker system df  # Docker 资源
   ```

4. **清理 Docker 资源**
   ```bash
   docker system prune -f
   ```

5. **重新部署**
   ```bash
   docker compose up -d
   docker compose logs -f quota-proxy
   ```

## 获取帮助

如果以上步骤无法解决问题：

1. **收集诊断信息**
   ```bash
   ./quick-diagnose.sh > diagnose-$(date +%Y%m%d_%H%M%S).log
   docker compose logs quota-proxy > logs-$(date +%Y%m%d_%H%M%S).log
   ```

2. **检查项目文档**
   - [README.md](./README.md) - 主要文档
   - [部署指南](./DEPLOYMENT.md) - 部署说明
   - [API 文档](./API.md) - API 接口说明

3. **查看 GitHub Issues**
   - 访问项目仓库查看已知问题
   - 提交新的 Issue 并附上诊断日志

## 预防措施

1. **定期备份**
   ```bash
   # 使用备份脚本
   ./backup-sqlite-db.sh
   ```

2. **监控设置**
   ```bash
   # 设置健康检查监控
   */5 * * * * curl -fsS http://127.0.0.1:8787/healthz || echo "quota-proxy 健康检查失败" | mail -s "警报" admin@example.com
   ```

3. **定期维护**
   ```bash
   # 每周执行一次
   ./verify-sqlite-integrity.sh --full
   ./verify-env-vars.sh --full
   docker system prune -f
   ```

---

**最后更新**: 2026-02-11  
**版本**: 1.0.0  
**维护者**: 中华AI共和国运维团队