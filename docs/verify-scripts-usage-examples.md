# 验证脚本使用示例

本文档提供项目中各种验证脚本的快速使用示例，帮助管理员快速上手。

## 1. 服务器健康检查脚本

### 快速服务器状态检查
```bash
# 快速检查服务器状态
./scripts/quick-server-status.sh

# 输出示例：
# [2026-02-09 16:25:00] 服务器状态检查开始
# ✅ Docker 容器运行正常: quota-proxy-quota-proxy-1 (Up 2 hours)
# ✅ 健康检查通过: {"ok":true}
# ✅ 服务器时间同步: 2026-02-09 16:25:01 CST
# [2026-02-09 16:25:01] 所有检查通过
```

### SSH健康检查
```bash
# 通过SSH检查远程服务器健康状态
./scripts/ssh-healthz-quota-proxy.sh

# 输出示例：
# [2026-02-09 16:25:05] 开始检查服务器 8.210.185.194...
# ✅ SSH连接成功
# ✅ Docker Compose服务运行正常
# ✅ 健康检查端点返回: {"ok":true}
# [2026-02-09 16:25:06] 服务器健康状态: OK
```

## 2. SQLite持久化验证

### 服务器端SQLite验证
```bash
# 验证服务器端SQLite持久化功能
./scripts/verify-sqlite-persistence-on-server.sh

# 输出示例（JSON格式）：
# {
#   "timestamp": "2026-02-09T16:25:10+08:00",
#   "server": "8.210.185.194",
#   "checks": {
#     "ssh_connection": true,
#     "docker_running": true,
#     "sqlite_file_exists": true,
#     "health_check": true
#   },
#   "all_passed": true
# }
```

### 完整SQLite生命周期测试
```bash
# 运行端到端SQLite持久化测试
./scripts/test-sqlite-full-cycle.sh

# 输出示例：
# ===== SQLite持久化完整测试开始 =====
# 1. 创建测试数据...
# 2. 重启容器...
# 3. 验证数据持久化...
# ✅ 测试通过：数据在容器重启后仍然存在
# ===== 测试完成 =====
```

## 3. TRIAL_KEY管理验证

### TRIAL_KEY生命周期测试
```bash
# 测试TRIAL_KEY的完整生命周期
./scripts/test-trial-key-lifecycle.sh

# 输出示例：
# ===== TRIAL_KEY生命周期测试开始 =====
# 1. 创建TRIAL_KEY...
# 2. 验证TRIAL_KEY...
# 3. 重置TRIAL_KEY使用量...
# 4. 删除TRIAL_KEY...
# ✅ 所有测试通过
# ===== 测试完成 =====
```

## 4. 备份管理

### 备份文件清理（干运行模式）
```bash
# 查看哪些备份文件会被清理（不实际删除）
./scripts/cleanup-quota-proxy-backups.sh --dry-run

# 输出示例：
# [DRY RUN] 将清理以下备份文件：
# - /opt/roc/quota-proxy/backup_2026-02-08.tar.gz (创建于 2 天前)
# - /opt/roc/quota-proxy/backup_2026-02-07.tar.gz (创建于 3 天前)
# 总计：2个文件，约 45.2 MB
```

### 实际清理备份文件
```bash
# 实际清理超过7天的备份文件
./scripts/cleanup-quota-proxy-backups.sh --keep-days 7

# 输出示例：
# 清理完成：
# ✅ 已删除：/opt/roc/quota-proxy/backup_2026-02-01.tar.gz
# ✅ 已删除：/opt/roc/quota-proxy/backup_2026-01-31.tar.gz
# 释放空间：89.5 MB
```

## 5. 论坛文档验证

### 论坛MVP文档完整性检查
```bash
# 验证论坛文档的完整性
./scripts/verify-forum-mvp.sh

# 输出示例：
# ===== 论坛MVP文档验证开始 =====
# ✅ 信息架构文档存在：docs/site/pages/forum/info-architecture.md
# ✅ 置顶帖模板存在：docs/site/pages/forum/sticky-templates.md
# ✅ 所有必需章节完整
# ===== 验证通过 =====
```

## 6. 组合使用示例

### 日常运维检查流程
```bash
#!/bin/bash
# daily-check.sh - 日常运维检查脚本

echo "=== 日常运维检查开始 ==="
echo "1. 检查服务器状态..."
./scripts/quick-server-status.sh

echo ""
echo "2. 检查SQLite持久化..."
./scripts/verify-sqlite-persistence-on-server.sh | jq '.all_passed' | grep -q true && echo "✅ SQLite持久化正常" || echo "❌ SQLite持久化异常"

echo ""
echo "3. 检查备份文件..."
./scripts/cleanup-quota-proxy-backups.sh --dry-run --keep-days 7

echo "=== 日常运维检查完成 ==="
```

### CI/CD集成示例
```bash
# .github/workflows/verify.yml 示例
name: Verify
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: 验证论坛文档
        run: ./scripts/verify-forum-mvp.sh
        
      - name: 验证脚本语法
        run: |
          for script in scripts/*.sh; do
            shellcheck "$script" || true
          done
```

## 7. 故障排查

### 常见问题解决

**问题1：SSH连接失败**
```bash
# 检查SSH密钥权限
chmod 600 ~/.ssh/id_ed25519_roc_server

# 测试SSH连接
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 "echo 'SSH连接测试成功'"
```

**问题2：健康检查失败**
```bash
# 直接检查健康端点
curl -fsS http://127.0.0.1:8787/healthz

# 检查Docker容器状态
docker compose ps
```

**问题3：SQLite文件权限问题**
```bash
# 检查SQLite文件权限
ls -la /opt/roc/quota-proxy/data/

# 修复权限
chown 1000:1000 /opt/roc/quota-proxy/data/quota.db
```

## 总结

这些验证脚本提供了完整的运维检查工具链，覆盖了：
- ✅ 服务器健康状态监控
- ✅ 数据持久化验证  
- ✅ 密钥管理功能测试
- ✅ 备份文件管理
- ✅ 文档完整性检查

建议将关键脚本（如`quick-server-status.sh`）加入cron定时任务，实现自动化监控。