# 快速验证命令集合

本文档提供quota-proxy的快速验证命令集合，适用于日常运维、故障排查和CI/CD集成。

## 基础健康检查

### 1. 快速健康检查（5秒内完成）
```bash
./quick-sqlite-health-check.sh
```

### 2. 详细健康检查（包含所有API端点）
```bash
./deployment-verification.sh
```

### 3. 干运行模式（预览检查内容）
```bash
./quick-sqlite-health-check.sh --dry-run
./deployment-verification.sh --dry-run
```

## 管理员API验证

### 4. 生成试用密钥
```bash
# 使用环境变量
export ADMIN_TOKEN="your-admin-token"
curl -X POST "http://localhost:8787/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-key","quota":100}'
```

### 5. 查看使用统计
```bash
curl -X GET "http://localhost:8787/admin/usage" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 6. 列出所有试用密钥
```bash
curl -X GET "http://localhost:8787/admin/keys" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 用户API验证

### 7. 检查配额
```bash
export TRIAL_KEY="your-trial-key"
curl -X GET "http://localhost:8787/quota" \
  -H "Authorization: Bearer $TRIAL_KEY"
```

### 8. 使用配额
```bash
curl -X POST "http://localhost:8787/use" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"amount":1}'
```

### 9. 查看使用统计（用户视角）
```bash
curl -X GET "http://localhost:8787/usage" \
  -H "Authorization: Bearer $TRIAL_KEY"
```

## 数据库验证

### 10. 检查SQLite数据库状态
```bash
# 检查数据库文件
ls -la quota-proxy.db

# 检查数据库大小
du -h quota-proxy.db

# 检查数据库完整性
sqlite3 quota-proxy.db "PRAGMA integrity_check;"
```

### 11. 查看数据库表结构
```bash
sqlite3 quota-proxy.db ".schema"
```

### 12. 查看数据统计
```bash
sqlite3 quota-proxy.db "SELECT COUNT(*) as total_keys FROM trial_keys;"
sqlite3 quota-proxy.db "SELECT COUNT(*) as total_usage FROM usage_stats;"
```

## 服务状态验证

### 13. 检查Docker容器状态
```bash
docker compose ps
```

### 14. 检查服务日志
```bash
docker compose logs quota-proxy
```

### 15. 检查服务进程
```bash
ps aux | grep node | grep quota-proxy
```

## 环境验证

### 16. 检查环境变量
```bash
echo "ADMIN_TOKEN: $ADMIN_TOKEN"
echo "TRIAL_KEY: $TRIAL_KEY"
echo "PORT: $PORT"
```

### 17. 检查端口占用
```bash
netstat -tlnp | grep :8787
lsof -i :8787
```

## 批量验证脚本

### 18. 完整API验证
```bash
./verify-sqlite-persistent-api.sh
```

### 19. 文档完整性检查
```bash
./verify-validation-docs.sh
./verify-validation-docs-enhanced.sh
```

## CI/CD集成示例

### 20. 自动化测试脚本
```bash
#!/bin/bash
set -e

# 启动服务
./start-sqlite-persistent.sh &

# 等待服务启动
sleep 5

# 运行验证
./deployment-verification.sh

# 检查退出码
if [ $? -eq 0 ]; then
    echo "✅ 所有验证通过"
    exit 0
else
    echo "❌ 验证失败"
    exit 1
fi
```

### 21. Docker Compose验证
```bash
#!/bin/bash
set -e

# 启动服务
docker compose up -d

# 等待服务启动
sleep 10

# 运行健康检查
curl -f http://localhost:8787/healthz

# 运行API验证
./deployment-verification.sh
```

## 故障排查命令

### 22. 调试模式启动
```bash
DEBUG=quota-proxy:* ./start-sqlite-persistent.sh
```

### 23. 查看详细日志
```bash
tail -f quota-proxy.log
```

### 24. 性能监控
```bash
# 查看内存使用
ps aux --sort=-%mem | head -10

# 查看CPU使用
top -b -n 1 | grep node
```

## 快速参考表

| 场景 | 推荐命令 | 说明 |
|------|----------|------|
| 日常运维 | `./quick-sqlite-health-check.sh` | 5秒内完成基础检查 |
| 故障排查 | `./deployment-verification.sh` | 详细API端点检查 |
| CI/CD集成 | 自动化测试脚本 | 完整的端到端验证 |
| 数据库维护 | SQLite检查命令 | 数据库完整性和状态 |
| 性能监控 | 性能监控命令 | 资源使用情况 |

## 最佳实践

1. **日常检查**：每天运行一次快速健康检查
2. **部署验证**：每次部署后运行详细验证
3. **监控集成**：将健康检查集成到监控系统
4. **日志管理**：定期检查服务日志
5. **备份策略**：定期备份SQLite数据库

## 更新日志

- **v1.0.0** (2026-02-11): 初始版本，包含基础验证命令
- **v1.0.1** (2026-02-11): 添加CI/CD集成示例
- **v1.0.2** (2026-02-11): 添加故障排查命令和最佳实践

---

**相关文档**：
- [快速开始指南](QUICK-START.md)
- [验证脚本选择决策树](VALIDATION-DECISION-TREE.md)
- [验证脚本使用示例](VALIDATION-EXAMPLES.md)
- [故障排除指南](TROUBLESHOOTING.md)
- [验证文档完整性检查](ENHANCED-VALIDATION-DOCS-CHECK.md)