# 完整的quota-proxy部署验证指南

## 概述

`verify-full-deployment.sh` 脚本提供了一个全面的quota-proxy部署验证解决方案。它执行从服务器连接到API功能的端到端检查，确保部署的完整性和可用性。

## 功能特性

### 核心检查项目

1. **服务器连接检查**
   - SSH连接测试
   - 服务器可达性验证

2. **Docker Compose服务状态**
   - 容器运行状态检查
   - 服务健康状态验证

3. **quota-proxy健康检查**
   - HTTP健康端点测试
   - API响应验证

4. **数据库文件检查**
   - SQLite数据库文件存在性
   - 数据库目录权限验证

5. **管理员接口验证**（需要管理员令牌）
   - 管理员API访问测试
   - 密钥管理功能验证

6. **本地脚本可用性检查**
   - 验证工具链完整性
   - 脚本依赖检查

### 高级特性

- **多种运行模式**: 详细模式、安静模式、干运行模式
- **彩色输出**: 直观的状态指示
- **结构化报告**: 清晰的检查摘要
- **故障排除建议**: 自动化的修复指导

## 安装与使用

### 前提条件

1. 已部署quota-proxy服务
2. 服务器SSH访问权限
3. （可选）管理员令牌用于完整验证

### 基本使用

```bash
# 显示帮助信息
./scripts/verify-full-deployment.sh --help

# 基本验证（使用默认配置）
./scripts/verify-full-deployment.sh

# 指定服务器和令牌
./scripts/verify-full-deployment.sh -s 8.210.185.194 -t "your-admin-token"

# 详细模式
./scripts/verify-full-deployment.sh --verbose

# 安静模式（仅显示最终结果）
./scripts/verify-full-deployment.sh --quiet

# 干运行模式（预览将要执行的命令）
./scripts/verify-full-deployment.sh --dry-run
```

### 环境变量配置

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token"

# 设置服务器IP（覆盖/tmp/server.txt）
export SERVER_IP="8.210.185.194"

# 运行验证
./scripts/verify-full-deployment.sh
```

## 配置说明

### 服务器配置

脚本会自动从以下位置读取服务器配置：

1. 命令行参数 `-s` 或 `--server`
2. 环境变量 `SERVER_IP`
3. 配置文件 `/tmp/server.txt`（格式: `ip:8.210.185.194`）

### SSH密钥配置

默认使用 `~/.ssh/id_ed25519_roc_server` 密钥文件，可通过 `-k` 参数指定其他密钥。

### 管理员令牌

管理员令牌用于测试管理员接口功能，可通过以下方式提供：

1. 命令行参数 `-t` 或 `--token`
2. 环境变量 `ADMIN_TOKEN`

## 检查流程详解

### 1. 服务器连接检查
- 测试SSH连接可达性
- 验证服务器响应时间
- 检查网络连通性

### 2. Docker Compose服务状态
- 检查容器运行状态
- 验证服务健康状态
- 确认端口映射正确

### 3. quota-proxy健康检查
- 测试HTTP健康端点
- 验证JSON响应格式
- 检查服务响应时间

### 4. 数据库文件检查
- 验证SQLite数据库文件存在
- 检查数据库目录权限
- 确认文件大小合理性

### 5. 管理员接口验证
- 测试管理员令牌有效性
- 验证密钥管理API
- 检查权限控制

### 6. 本地脚本可用性
- 检查相关工具脚本存在
- 验证脚本执行权限
- 确认依赖关系

## 输出说明

### 成功输出示例

```
[INFO] 开始完整的quota-proxy部署验证
[INFO] 服务器: 8.210.185.194
[INFO] 模式: 实际执行

[INFO] 1. 检查服务器连接...
[SUCCESS] ✓ 服务器连接正常

[INFO] 2. 检查Docker Compose服务状态...
[SUCCESS] ✓ Docker Compose服务运行正常

[INFO] 3. 检查quota-proxy健康状态...
[SUCCESS] ✓ quota-proxy健康检查通过

[INFO] 4. 检查数据库文件...
[SUCCESS] ✓ 数据库文件存在

[INFO] 5. 检查管理员接口...
[SUCCESS] ✓ 管理员接口访问正常

[INFO] 6. 检查本地验证脚本...
[SUCCESS] ✓ 本地验证脚本存在

[INFO] 部署验证摘要:
  总检查数: 6
  通过检查: 6
  失败检查: 0

[SUCCESS] ✅ 部署验证通过！所有关键检查均成功。

[INFO] 建议的后续步骤:
  1. 测试API密钥生成: ./scripts/generate-api-key.sh
  2. 运行完整健康检查: ./scripts/enhanced-health-check.sh
  3. 验证数据库备份: ./scripts/verify-db-backup.sh
  4. 配置监控告警: ./scripts/configure-backup-alerts.sh

[INFO] 验证完成于: 2026-02-10 19:26:00 CST
```

### 失败输出示例

```
[ERROR] ❌ 部署验证失败！部分检查未通过。

[INFO] 故障排除建议:
  1. 检查服务器连接: ssh root@8.210.185.194
  2. 检查Docker服务: ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose logs'
  3. 检查quota-proxy日志: ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose logs quota-proxy'
  4. 查看详细文档: docs/quota-proxy-faq-troubleshooting.md
```

## 集成与自动化

### 定时任务集成

```bash
# 每天凌晨2点运行完整验证
0 2 * * * cd /path/to/roc-ai-republic && ./scripts/verify-full-deployment.sh --quiet >> /var/log/quota-proxy-verification.log 2>&1
```

### CI/CD流水线集成

```yaml
# GitHub Actions示例
name: Deployment Verification
on: [push, pull_request]

jobs:
  verify-deployment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Verify Deployment
        run: |
          chmod +x ./scripts/verify-full-deployment.sh
          ./scripts/verify-full-deployment.sh --verbose
        env:
          SERVER_IP: ${{ secrets.SERVER_IP }}
          ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
```

### 监控告警集成

```bash
# 监控脚本示例
#!/bin/bash
cd /path/to/roc-ai-republic
if ! ./scripts/verify-full-deployment.sh --quiet; then
    # 发送告警通知
    echo "quota-proxy部署验证失败" | mail -s "部署告警" admin@example.com
    # 或使用其他通知方式
    ./scripts/send-alert.sh "部署验证失败"
fi
```

## 故障排除

### 常见问题

#### 1. 服务器连接失败
- 检查网络连通性: `ping 8.210.185.194`
- 验证SSH配置: `ssh -v root@8.210.185.194`
- 确认防火墙规则

#### 2. Docker服务未运行
- 检查Docker服务状态: `systemctl status docker`
- 查看Compose文件: `cat /opt/roc/quota-proxy/compose.yaml`
- 检查日志: `docker compose logs`

#### 3. quota-proxy健康检查失败
- 检查容器日志: `docker compose logs quota-proxy`
- 验证端口映射: `netstat -tlnp | grep 8787`
- 测试本地连接: `curl http://127.0.0.1:8787/healthz`

#### 4. 管理员接口访问失败
- 验证管理员令牌: 检查`ADMIN_TOKEN`环境变量
- 检查权限配置: 确认令牌在quota-proxy配置中
- 测试直接访问: `curl -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/keys`

### 调试技巧

```bash
# 启用详细调试
./scripts/verify-full-deployment.sh --verbose

# 仅测试特定功能
export VERBOSE=true
./scripts/verify-full-deployment.sh

# 手动执行检查步骤
ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose ps"
ssh root@8.210.185.194 "curl -fsS http://127.0.0.1:8787/healthz"
```

## 安全考虑

### 敏感信息保护
- 管理员令牌不应硬编码在脚本中
- 使用环境变量或密钥管理服务
- 避免在日志中记录敏感信息

### 访问控制
- 限制脚本执行权限
- 使用最小权限原则
- 定期轮换SSH密钥和管理员令牌

### 审计日志
- 记录所有验证操作
- 保存验证结果历史
- 监控异常访问模式

## 性能优化

### 检查优化
- 并行执行独立检查
- 设置合理的超时时间
- 缓存重复检查结果

### 资源使用
- 最小化SSH连接次数
- 优化远程命令执行
- 减少网络传输数据量

## 扩展与定制

### 添加自定义检查

```bash
# 在verify_deployment函数中添加新检查
add_custom_check() {
    log_info "7. 执行自定义检查..."
    # 自定义检查逻辑
    if custom_check_passed; then
        log_success "✓ 自定义检查通过"
    else
        log_error "✗ 自定义检查失败"
    fi
}
```

### 集成其他工具

```bash
# 集成现有验证工具
integrate_existing_tools() {
    # 运行健康检查
    ./scripts/enhanced-health-check.sh --quiet
    
    # 运行数据库验证
    ./scripts/verify-quota-proxy-db.sh --quiet
    
    # 运行备份验证
    ./scripts/verify-db-backup.sh --quiet
}
```

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持基本部署验证功能
- 提供多种运行模式
- 包含完整的文档

### 未来计划
- 添加更多检查项目
- 支持多服务器验证
- 集成性能基准测试
- 提供Web界面

## 相关资源

- [quota-proxy快速入门指南](quota-proxy-quickstart.md)
- [API使用指南](quota-proxy-api-usage-guide.md)
- [故障排除文档](quota-proxy-faq-troubleshooting.md)
- [健康检查工具](enhanced-health-check-tool.md)
- [数据库验证工具](quota-proxy-database-verification.md)

## 支持与反馈

如有问题或建议，请参考：
1. 查看详细文档
2. 检查故障排除指南
3. 提交GitHub Issue
4. 联系维护团队