# SQLite 数据库状态快速验证指南

本文档提供 quota-proxy SQLite 数据库状态的快速验证方法，确保数据持久化功能正常工作。

## 验证脚本

仓库提供了快速验证脚本：`scripts/verify-sqlite-status.sh`

### 使用方法

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your_admin_token_here"

# 运行验证（使用默认地址 127.0.0.1:8787）
./scripts/verify-sqlite-status.sh

# 指定服务地址
./scripts/verify-sqlite-status.sh --host 8.210.185.194:8787

# 通过参数指定令牌
./scripts/verify-sqlite-status.sh --host 127.0.0.1:8787 --token your_admin_token
```

### 验证内容

脚本执行以下验证步骤：

1. **服务健康检查** - 验证 `/healthz` 端点
2. **管理员接口访问** - 验证 `/admin/keys` 端点
3. **测试密钥创建** - 创建临时测试密钥
4. **密钥可用性验证** - 使用测试密钥查询模型列表
5. **使用情况统计** - 检查今日 API 使用统计
6. **结果摘要** - 提供完整的验证报告

## 手动验证步骤

如果不想使用脚本，可以手动执行以下命令：

### 1. 基础健康检查
```bash
# 检查服务是否运行
curl -fsS http://127.0.0.1:8787/healthz
# 预期输出: {"ok":true}
```

### 2. 管理员功能验证
```bash
# 设置环境变量
export ADMIN_TOKEN="your_admin_token"
export QUOTA_URL="http://127.0.0.1:8787"

# 检查现有密钥
curl -fsS "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 3. 创建测试密钥
```bash
# 创建新密钥
curl -fsS -X POST "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"verification-test"}'

# 保存返回的密钥
export TEST_KEY="trial_xxx"
```

### 4. 验证密钥功能
```bash
# 查询可用模型
curl -fsS "$QUOTA_URL/v1/models" \
  -H "Authorization: Bearer $TEST_KEY"
```

### 5. 检查数据库持久化
```bash
# 重启服务
docker compose restart quota-proxy

# 等待服务启动
sleep 5

# 验证密钥仍然存在
curl -fsS "$QUOTA_URL/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | grep "verification-test"
```

## 验证指标

### 成功标准
- ✅ 健康检查返回 `{"ok":true}`
- ✅ 管理员接口可访问（HTTP 200）
- ✅ 可以创建新密钥
- ✅ 新密钥可以调用 API
- ✅ 使用情况统计可查询
- ✅ 重启服务后数据保留（持久化验证）

### 失败排查

#### 健康检查失败
```bash
# 检查容器状态
docker compose ps

# 查看日志
docker compose logs quota-proxy

# 常见问题：
# 1. 端口冲突 - 修改 docker-compose.yml 中的端口映射
# 2. 环境变量缺失 - 检查 DEEPSEEK_API_KEY 和 ADMIN_TOKEN
# 3. 数据库权限 - 检查 /data 目录权限
```

#### 管理员接口返回 401
```bash
# 验证管理员令牌
echo "ADMIN_TOKEN: $ADMIN_TOKEN"

# 检查数据库中的令牌
sqlite3 /data/quota.db "SELECT value FROM config WHERE key='admin_token';"
```

#### 密钥创建失败
```bash
# 检查数据库连接
curl -fsS http://127.0.0.1:8787/healthz

# 检查数据库文件
ls -la /data/quota.db

# 检查表结构
sqlite3 /data/quota.db ".schema trial_keys"
```

## 自动化集成

### CI/CD 流水线示例
```yaml
# GitHub Actions 示例
name: Verify SQLite Database
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: 启动测试环境
        run: |
          docker compose up -d
          sleep 10
      
      - name: 运行数据库验证
        run: |
          export ADMIN_TOKEN="test_admin_token_123"
          ./scripts/verify-sqlite-status.sh --host 127.0.0.1:8787
      
      - name: 清理
        run: docker compose down
```

### 监控告警配置
```bash
# 定时验证脚本（cron）
0 */6 * * * /opt/roc/quota-proxy/scripts/verify-sqlite-status.sh --host 127.0.0.1:8787 --token $ADMIN_TOKEN >> /var/log/quota-verify.log 2>&1

# 检查验证结果并发送告警
if ! tail -1 /var/log/quota-verify.log | grep -q "验证通过"; then
  echo "quota-proxy 数据库验证失败" | mail -s "数据库告警" admin@example.com
fi
```

## 性能基准

### 正常响应时间
- 健康检查: < 100ms
- 管理员接口: < 200ms  
- 密钥创建: < 300ms
- 模型查询: < 500ms

### 资源使用
- 数据库文件大小: 初始 ~1MB，每万条记录增加 ~5MB
- 内存使用: 基础 ~50MB，峰值 ~100MB
- CPU 使用: 空闲 < 1%，峰值 < 10%

## 维护建议

### 定期维护任务
1. **每日检查**
   ```bash
   # 检查数据库大小
   du -h /data/quota.db
   
   # 检查表记录数
   sqlite3 /data/quota.db "SELECT 'trial_keys', COUNT(*) FROM trial_keys; SELECT 'daily_usage', COUNT(*) FROM daily_usage;"
   ```

2. **每周优化**
   ```bash
   # 数据库优化
   sqlite3 /data/quota.db "VACUUM;"
   
   # 重建索引
   sqlite3 /data/quota.db "REINDEX;"
   ```

3. **每月备份验证**
   ```bash
   # 验证备份完整性
   ./scripts/verify-database-backup.sh
   ```

### 故障恢复
如果验证失败，按以下步骤恢复：

1. **检查日志**
   ```bash
   docker compose logs quota-proxy --tail 100
   ```

2. **验证数据库文件**
   ```bash
   sqlite3 /data/quota.db ".dbinfo"
   sqlite3 /data/quota.db "PRAGMA integrity_check;"
   ```

3. **从备份恢复**
   ```bash
   # 停止服务
   docker compose stop quota-proxy
   
   # 恢复数据库
   cp /backup/quota.db.bak /data/quota.db
   
   # 重启服务
   docker compose start quota-proxy
   ```

## 总结

SQLite 数据库状态验证是确保 quota-proxy 数据持久化的关键步骤。通过定期运行验证脚本，可以：

1. **确保数据完整性** - 验证数据库读写功能正常
2. **提前发现问题** - 在影响用户前发现数据库问题
3. **监控性能趋势** - 跟踪响应时间和资源使用
4. **保障服务可用性** - 确保 API 网关稳定运行

建议在生产环境中至少每日运行一次完整验证，并在每次部署后立即验证。