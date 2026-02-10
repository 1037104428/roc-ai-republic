# quota-proxy SQLite版本综合验证指南

## 概述

本文档提供`quota-proxy` SQLite版本的全面验证方案，确保部署的服务完全可用且符合预期功能。包含健康检查、管理接口、数据库状态、容器运行等多维度验证。

## 验证脚本

### 主验证脚本
```bash
./scripts/verify-sqlite-comprehensive.sh
```

### 可选参数
```bash
# 指定服务器和端口
./scripts/verify-sqlite-comprehensive.sh --server-ip 8.210.185.194 --port 8788

# 指定管理员令牌
./scripts/verify-sqlite-comprehensive.sh --token "your-admin-token"

# 只显示命令不执行（预检查）
./scripts/verify-sqlite-comprehensive.sh --dry-run
```

## 验证项目

### 1. 容器运行状态
- 检查Docker容器是否正常运行
- 验证容器名称、状态、端口映射
- 预期：`quota-proxy-sqlite-quota-proxy-1` 状态为 `Up`

### 2. 健康检查接口
- 访问 `/healthz` 端点
- 验证返回格式：`{"ok":true,"mode":"sqlite","db":"/data/quota.db"}`
- 响应时间：< 1秒

### 3. 端口监听状态
- 检查8788端口是否被监听
- 验证监听地址为127.0.0.1
- 使用`netstat`或`ss`命令

### 4. 数据库文件存在性
- 检查SQLite数据库文件是否存在
- 路径：`/opt/roc/quota-proxy-sqlite/data/quota.db`
- 验证文件权限和大小

### 5. 日志文件检查
- 查看最近5条容器日志
- 检查是否有错误信息
- 验证服务启动成功

### 6. 管理接口可用性
- 测试 `/admin/usage` 端点
- 使用管理员令牌认证
- 验证返回使用统计数据

### 7. 创建测试key
- 通过 `/admin/keys` 创建测试key
- 验证返回格式包含 `clawd-` 前缀
- 配额设置为50次

### 8. 服务响应时间
- 测量健康检查接口响应时间
- 验证HTTP状态码为200
- 响应时间应 < 0.5秒

## 手动验证命令

### 基础健康检查
```bash
# 容器状态
ssh root@8.210.185.194 'docker ps | grep quota-proxy-sqlite'

# 健康接口
ssh root@8.210.185.194 'curl -fsS http://127.0.0.1:8788/healthz'

# 端口监听
ssh root@8.210.185.194 'netstat -tlnp | grep :8788'
```

### 管理接口测试
```bash
# 查询使用情况
ADMIN_TOKEN="sqlite-test-token-20250210"
ssh root@8.210.185.194 "curl -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8788/admin/usage"

# 创建测试key
ssh root@8.210.185.194 "curl -X POST -H 'Authorization: Bearer $ADMIN_TOKEN' -H 'Content-Type: application/json' -d '{\"label\":\"手动测试\",\"quota\":100}' http://127.0.0.1:8788/admin/keys"
```

### 数据库验证
```bash
# 检查数据库文件
ssh root@8.210.185.194 'ls -la /opt/roc/quota-proxy-sqlite/data/'

# 检查数据库大小
ssh root@8.210.185.194 'du -h /opt/roc/quota-proxy-sqlite/data/quota.db'

# 简单SQL查询（需要sqlite3命令）
ssh root@8.210.185.194 'sqlite3 /opt/roc/quota-proxy-sqlite/data/quota.db ".tables" 2>/dev/null || echo "sqlite3未安装"'
```

## 验证结果解读

### 成功标志
1. 所有验证项目返回绿色"✓ 通过"
2. 健康接口返回`{"ok":true,...}`
3. 管理接口能正常创建和查询key
4. 数据库文件存在且可访问
5. 容器运行时间正常

### 常见问题排查

#### 容器未运行
```bash
# 启动容器
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy-sqlite && docker compose up -d'

# 查看日志
ssh root@8.210.185.194 'docker logs quota-proxy-sqlite-quota-proxy-1'
```

#### 健康检查失败
```bash
# 检查服务进程
ssh root@8.210.185.194 'docker exec quota-proxy-sqlite-quota-proxy-1 ps aux'

# 检查配置文件
ssh root@8.210.185.194 'docker exec quota-proxy-sqlite-quota-proxy-1 cat /app/config.json'
```

#### 管理接口认证失败
```bash
# 检查环境变量
ssh root@8.210.185.194 'docker exec quota-proxy-sqlite-quota-proxy-1 env | grep ADMIN_TOKEN'

# 验证令牌格式
echo "当前令牌: sqlite-test-token-20250210"
```

## 自动化集成

### 定时验证（cron）
```bash
# 每天凌晨2点运行验证
0 2 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-sqlite-comprehensive.sh >> /var/log/quota-proxy-verify.log 2>&1
```

### CI/CD集成
```yaml
# GitHub Actions示例
name: Verify SQLite Deployment
on:
  schedule:
    - cron: '0 */6 * * *'  # 每6小时
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run verification
        run: |
          chmod +x scripts/verify-sqlite-comprehensive.sh
          ./scripts/verify-sqlite-comprehensive.sh --dry-run
```

## 维护建议

### 定期验证
1. **每日检查**：基础健康状态
2. **每周检查**：完整验证套件
3. **每月检查**：性能基准测试

### 监控指标
- 响应时间趋势
- 数据库增长情况
- 错误率统计
- 密钥使用频率

### 备份策略
```bash
# 数据库备份
ssh root@8.210.185.194 'cp /opt/roc/quota-proxy-sqlite/data/quota.db /opt/roc/quota-proxy-sqlite/backup/quota.db.$(date +%Y%m%d)'

# 配置备份
ssh root@8.210.185.194 'tar -czf /opt/roc/quota-proxy-sqlite/backup/config-$(date +%Y%m%d).tar.gz /opt/roc/quota-proxy-sqlite/*.yml /opt/roc/quota-proxy-sqlite/*.env'
```

## 版本历史
- 2026-02-10: 创建综合验证脚本和文档
- 2026-02-09: 初始SQLite版本部署
- 2026-02-08: quota-proxy基础版本发布