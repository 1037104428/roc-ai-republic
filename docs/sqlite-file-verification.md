# SQLite数据库文件验证工具

## 概述

`verify-sqlite-file.sh` 是一个用于检查quota-proxy SQLite数据库文件健康状况的验证脚本。该脚本提供本地和远程两种检查模式，确保数据库文件存在、可访问且结构完整。

## 功能特性

### 核心功能
1. **文件存在性检查** - 验证数据库文件是否存在
2. **文件权限检查** - 检查文件权限和所有者
3. **文件属性检查** - 检查文件大小和修改时间
4. **数据库连接测试** - 测试数据库连接和基本查询
5. **表结构检查** - 检查关键表是否存在（api_keys, usage_stats）

### 检查模式
- **本地模式** - 检查本地文件系统上的数据库文件
- **远程模式** - 通过SSH检查远程服务器上的数据库文件
- **干运行模式** - 预览将要执行的操作而不实际执行

## 快速开始

### 基本用法

```bash
# 检查本地数据库文件
./scripts/verify-sqlite-file.sh --db-path /opt/roc/quota-proxy/data/quota.db

# 检查远程服务器数据库文件
./scripts/verify-sqlite-file.sh --server root@8.210.185.194

# 使用详细模式
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --verbose

# 干运行模式（预览）
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --dry-run
```

### 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-h, --help` | 显示帮助信息 | - |
| `-v, --verbose` | 详细模式，显示更多信息 | false |
| `-q, --quiet` | 安静模式，只显示关键信息 | false |
| `-d, --dry-run` | 干运行模式，只显示将要执行的操作 | false |
| `--db-path PATH` | 数据库文件路径 | `/opt/roc/quota-proxy/data/quota.db` |
| `--server HOST` | 远程服务器地址 | - |
| `--ssh-key PATH` | SSH私钥路径 | `~/.ssh/id_ed25519_roc_server` |

## 详细功能说明

### 1. 文件存在性检查
脚本首先检查指定的数据库文件是否存在。如果文件不存在，脚本将立即失败并返回错误信息。

### 2. 文件权限检查
检查数据库文件的权限设置，确保：
- 文件具有适当的读写权限
- 文件所有者正确（通常为运行quota-proxy的用户）

### 3. 文件属性检查
获取并显示以下文件属性：
- **文件大小** - 以字节和人类可读格式显示
- **最后修改时间** - 显示文件最后修改的时间戳
- **文件权限** - 显示完整的权限字符串
- **所有者** - 显示文件所有者和组

### 4. 数据库连接测试
使用`sqlite3`命令行工具测试数据库连接：
- 执行简单的`SELECT 1;`查询验证连接
- 如果连接失败，脚本将报告错误

### 5. 表结构检查（详细模式）
在详细模式下，脚本会检查数据库中的表结构：
- 列出所有表
- 检查`api_keys`表是否存在并统计记录数
- 检查`usage_stats`表是否存在并统计记录数

## 使用场景

### 场景1：部署后验证
在部署quota-proxy后，验证数据库文件是否正确创建：

```bash
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --verbose
```

### 场景2：定期健康检查
通过cron定时任务定期检查数据库健康状况：

```bash
# 每天凌晨2点检查
0 2 * * * /path/to/roc-ai-republic/scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet
```

### 场景3：故障排除
当quota-proxy出现数据库相关问题时，快速诊断：

```bash
# 详细诊断模式
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --verbose
```

### 场景4：CI/CD集成
在部署流水线中集成数据库验证：

```bash
# 部署前验证
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --dry-run

# 部署后验证
./scripts/verify-sqlite-file.sh --server root@8.210.185.194
```

## 输出示例

### 成功输出示例
```
[INFO] SQLite数据库文件验证脚本启动
[INFO] 时间: 2026-02-10 19:32:52 CST
[INFO] 检查远程服务器: root@8.210.185.194
[INFO] 数据库路径: /opt/roc/quota-proxy/data/quota.db
[SUCCESS] SSH连接成功
[INFO] 执行远程检查...
=== 数据库文件检查开始 ===
[SUCCESS] 数据库文件存在
[INFO] 文件信息:
-rw-r--r-- 1 root root 24576 Feb 10 19:30 /opt/roc/quota-proxy/data/quota.db
[INFO] 文件权限: -rw-r--r--
[INFO] 所有者: root:root
[INFO] 文件大小: 24576 字节
[INFO] 最后修改: 2026-02-10 19:30:15.123456789 +0800
[INFO] 尝试连接数据库...
[SUCCESS] 数据库连接成功
[INFO] 数据库表:
  - api_keys
  - usage_stats
  - sqlite_sequence
[INFO] api_keys表记录数: 5
=== 数据库文件检查完成 ===
[SUCCESS] 远程数据库文件验证成功
```

### 失败输出示例
```
[INFO] SQLite数据库文件验证脚本启动
[INFO] 时间: 2026-02-10 19:32:52 CST
[INFO] 检查远程服务器: root@8.210.185.194
[INFO] 数据库路径: /opt/roc/quota-proxy/data/quota.db
[ERROR] SSH连接失败: root@8.210.185.194
[ERROR] 远程数据库文件验证失败
```

## 集成指南

### 与现有监控系统集成

#### 1. 与健康检查脚本集成
将数据库文件验证集成到现有的健康检查流程中：

```bash
#!/bin/bash
# enhanced-health-check.sh 增强版

# 检查数据库文件
echo "=== 数据库文件检查 ==="
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet
if [ $? -eq 0 ]; then
    echo "✓ 数据库文件正常"
else
    echo "✗ 数据库文件异常"
    exit 1
fi
```

#### 2. 与部署验证脚本集成
在部署验证流程中加入数据库文件检查：

```bash
#!/bin/bash
# verify-full-deployment.sh 完整部署验证

# 数据库文件验证
echo "步骤4: 验证数据库文件"
./scripts/verify-sqlite-file.sh --server root@8.210.185.194
if [ $? -ne 0 ]; then
    echo "错误: 数据库文件验证失败"
    exit 1
fi
```

### 定时任务配置

#### 基本定时任务
```bash
# 每30分钟检查一次数据库文件
*/30 * * * * /path/to/roc-ai-republic/scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet >> /var/log/quota-proxy/db-check.log 2>&1
```

#### 带告警的定时任务
```bash
#!/bin/bash
# check-db-with-alert.sh

LOG_FILE="/var/log/quota-proxy/db-check.log"
ALERT_EMAIL="admin@example.com"

# 执行检查
/path/to/roc-ai-republic/scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet > "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    # 发送告警
    echo "数据库文件检查失败，请查看日志: $LOG_FILE" | mail -s "quota-proxy数据库告警" "$ALERT_EMAIL"
fi
```

## 故障排除

### 常见问题

#### 问题1: SSH连接失败
**症状**: `[ERROR] SSH连接失败`
**解决方案**:
1. 检查服务器地址是否正确
2. 检查SSH密钥文件是否存在且权限正确（600）
3. 检查网络连接和防火墙设置
4. 测试手动SSH连接: `ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194`

#### 问题2: 数据库文件不存在
**症状**: `[ERROR] 数据库文件不存在`
**解决方案**:
1. 检查数据库文件路径是否正确
2. 确认quota-proxy服务已启动并创建了数据库文件
3. 检查数据库目录权限: `ls -la /opt/roc/quota-proxy/data/`

#### 问题3: 数据库连接失败
**症状**: `[ERROR] 数据库连接失败`
**解决方案**:
1. 检查数据库文件是否损坏: `sqlite3 /path/to/db.db "PRAGMA integrity_check;"`
2. 检查文件权限: 确保运行用户有读取权限
3. 尝试修复数据库: `sqlite3 /path/to/db.db ".dump" | sqlite3 repaired.db`

#### 问题4: sqlite3命令未找到
**症状**: `[WARNING] sqlite3未安装`
**解决方案**:
1. 安装sqlite3: `apt-get install sqlite3` (Debian/Ubuntu) 或 `yum install sqlite` (RHEL/CentOS)
2. 或者跳过数据库连接测试，只检查文件属性

### 调试技巧

#### 启用详细模式
```bash
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --verbose
```

#### 手动测试SSH连接
```bash
ssh -i ~/.ssh/id_ed25519_roc_server -o ConnectTimeout=10 root@8.210.185.194 "ls -la /opt/roc/quota-proxy/data/"
```

#### 手动测试数据库连接
```bash
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "sqlite3 /opt/roc/quota-proxy/data/quota.db 'SELECT 1;'"
```

## 安全考虑

### 1. SSH密钥安全
- SSH私钥文件权限应设置为600: `chmod 600 ~/.ssh/id_ed25519_roc_server`
- 定期轮换SSH密钥
- 使用密钥密码保护（如果支持）

### 2. 数据库文件权限
- 数据库文件不应有全局写权限
- 建议权限: `rw-r-----` (640)
- 文件所有者应为运行quota-proxy的用户

### 3. 敏感信息处理
- 脚本不会在日志中暴露数据库内容
- 详细模式下的输出应谨慎处理，避免泄露敏感数据
- 建议在生产环境中使用安静模式

### 4. 网络安全性
- 确保SSH连接使用加密通道
- 考虑使用VPN或专用网络进行服务器访问
- 定期更新SSH配置和安全策略

## 性能优化

### 1. 减少检查频率
对于生产环境，建议的检查频率：
- 高可用环境: 每5-10分钟
- 标准环境: 每30分钟
- 开发环境: 按需检查

### 2. 优化SSH连接
- 使用SSH连接复用: 在`~/.ssh/config`中配置`ControlMaster`和`ControlPath`
- 设置合理的连接超时: `-o ConnectTimeout=10`
- 使用压缩: `-C` 选项（如果网络带宽有限）

### 3. 减少输出数据量
- 生产环境使用`--quiet`模式
- 将输出重定向到日志文件
- 定期清理日志文件

## 扩展功能

### 1. 添加邮件通知
```bash
#!/bin/bash
# verify-sqlite-with-notify.sh

RESULT=$(./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet 2>&1)

if [ $? -ne 0 ]; then
    echo "数据库检查失败: $RESULT" | mail -s "数据库告警" admin@example.com
fi
```

### 2. 集成到监控系统
```bash
#!/bin/bash
# prometheus-exporter.sh

# 执行检查
./scripts/verify-sqlite-file.sh --server root@8.210.185.194 --quiet

if [ $? -eq 0 ]; then
    echo 'quota_proxy_database_status 1'
else
    echo 'quota_proxy_database_status 0'
fi
```

### 3. 添加性能指标
扩展脚本以收集性能指标：
- 数据库文件大小变化趋势
- 表记录数增长情况
- 连接响应时间

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持本地和远程数据库文件检查
- 支持详细/安静/干运行模式
- 完整的文档和示例

## 贡献指南

欢迎贡献代码和改进建议。请遵循以下步骤：

1. Fork项目仓库
2. 创建功能分支: `git checkout -b feature/verify-sqlite-improvement`
3. 提交更改: `git commit -am '添加新功能'`
4. 推送到分支: `git push origin feature/verify-sqlite-improvement`
5. 创建Pull Request

## 许可证

本项目采用MIT许可证。详见LICENSE文件。

## 支持与反馈

如有问题或建议，请通过以下方式联系：
- GitHub Issues: https://github.com/1037104428/roc-ai-republic/issues
- 电子邮件: 项目维护团队

---

*最后更新: 2026-02-10*