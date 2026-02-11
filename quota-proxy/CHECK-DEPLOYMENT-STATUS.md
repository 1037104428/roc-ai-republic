# CHECK-DEPLOYMENT-STATUS.md - 部署状态检查脚本文档

## 概述

`check-deployment-status.sh` 是一个轻量级的quota-proxy部署状态检查脚本，用于快速验证服务是否正常运行。它提供了简单的健康检查、状态验证和API端点测试功能，适用于日常监控、快速故障排查和部署验证。

## 快速开始

### 基本使用

```bash
# 授予执行权限
chmod +x check-deployment-status.sh

# 基本检查（默认使用 http://127.0.0.1:8787）
./check-deployment-status.sh

# 指定服务URL
./check-deployment-status.sh --url http://localhost:8787

# 使用管理员令牌进行完整检查
./check-deployment-status.sh --token your-admin-token

# 干运行模式（显示检查步骤但不实际执行）
./check-deployment-status.sh --dry-run

# 详细输出模式
./check-deployment-status.sh --verbose

# 安静模式（只显示最终结果）
./check-deployment-status.sh --quiet
```

### 完整示例

```bash
# 完整检查示例
./check-deployment-status.sh \
  --url http://192.168.1.100:8787 \
  --token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" \
  --verbose

# 干运行示例（用于测试脚本）
./check-deployment-status.sh --dry-run --verbose

# 快速检查（安静模式）
./check-deployment-status.sh --quiet
```

## 功能特性

### 1. 健康检查
- 检查 `/healthz` 端点是否返回健康状态
- 验证服务基本可用性

### 2. 状态检查
- 检查 `/status` 端点是否返回正常状态
- 验证服务运行状态

### 3. API密钥检查（需要管理员令牌）
- 检查 `/admin/keys` 端点是否可访问
- 验证管理员API权限

### 4. 试用密钥检查（需要管理员令牌）
- 检查 `/admin/keys/trial` 端点是否可生成试用密钥
- 验证试用密钥生成功能

### 5. 部署状态报告
- 生成格式化的检查报告
- 显示通过/失败/跳过的检查项
- 提供清晰的汇总信息

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--url` | `-u` | 服务基础URL | `http://127.0.0.1:8787` |
| `--token` | `-t` | 管理员令牌（可选） | 空 |
| `--dry-run` | `-d` | 干运行模式，显示步骤但不执行 | `false` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--quiet` | `-q` | 安静模式，只显示最终结果 | `false` |

## 使用场景

### 场景1：新部署验证
```bash
# 部署后立即验证服务是否正常运行
./check-deployment-status.sh --url http://new-server:8787 --verbose
```

### 场景2：日常监控
```bash
# 定时任务中的健康检查（安静模式）
./check-deployment-status.sh --quiet

# 如果检查失败，发送告警
if ! ./check-deployment-status.sh --quiet; then
  echo "quota-proxy服务异常！" | mail -s "服务告警" admin@example.com
fi
```

### 场景3：故障排查
```bash
# 详细检查所有端点，帮助诊断问题
./check-deployment-status.sh --verbose --token $ADMIN_TOKEN
```

### 场景4：CI/CD流水线集成
```bash
# 在部署流水线中添加验证步骤
echo "开始部署验证..."
if ./check-deployment-status.sh --url $DEPLOYMENT_URL --token $CI_ADMIN_TOKEN; then
  echo "部署验证通过"
else
  echo "部署验证失败"
  exit 1
fi
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Deploy Verification
on: [push]

jobs:
  verify-deployment:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        
      - name: Verify deployment
        run: |
          chmod +x quota-proxy/check-deployment-status.sh
          ./quota-proxy/check-deployment-status.sh \
            --url ${{ secrets.QUOTA_PROXY_URL }} \
            --token ${{ secrets.ADMIN_TOKEN }} \
            --quiet
```

### GitLab CI 示例

```yaml
stages:
  - verify

verify_deployment:
  stage: verify
  script:
    - chmod +x quota-proxy/check-deployment-status.sh
    - ./quota-proxy/check-deployment-status.sh --url $QUOTA_PROXY_URL --token $ADMIN_TOKEN
```

## 故障排除

### 常见问题

#### 1. "无法访问服务URL"
- 检查服务是否正在运行：`docker compose ps` 或 `systemctl status quota-proxy`
- 检查防火墙设置：`sudo ufw status`
- 验证端口是否正确：`netstat -tlnp | grep 8787`

#### 2. "健康检查失败"
- 检查服务日志：`docker compose logs quota-proxy` 或 `journalctl -u quota-proxy`
- 验证环境变量配置：`cat .env`
- 检查依赖服务（如数据库）是否正常

#### 3. "API密钥检查失败"
- 验证管理员令牌是否正确：`echo $ADMIN_TOKEN`
- 检查令牌权限：确保令牌有管理员权限
- 验证API端点路径：确保 `/admin/keys` 端点存在

#### 4. "试用密钥检查失败"
- 检查试用密钥生成配置
- 验证数据库连接（如果使用持久化）
- 检查试用密钥配额限制

### 诊断命令

```bash
# 检查服务进程
ps aux | grep quota-proxy

# 检查端口监听
sudo lsof -i :8787

# 检查网络连接
curl -v http://127.0.0.1:8787/healthz

# 检查服务日志
tail -f /var/log/quota-proxy.log

# 检查环境变量
env | grep QUOTA
```

## 最佳实践

### 1. 定时监控
```bash
# 使用cron定时检查
*/5 * * * * /opt/roc/quota-proxy/check-deployment-status.sh --quiet
```

### 2. 告警集成
```bash
# 检查失败时发送告警
if ! ./check-deployment-status.sh --quiet; then
  # 发送Slack通知
  curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"quota-proxy服务异常！"}' \
    $SLACK_WEBHOOK_URL
  
  # 发送邮件
  echo "quota-proxy服务检查失败于 $(date)" | mail -s "服务告警" admin@example.com
fi
```

### 3. 性能监控
```bash
# 添加响应时间监控
start_time=$(date +%s.%N)
./check-deployment-status.sh --quiet
end_time=$(date +%s.%N)
response_time=$(echo "$end_time - $start_time" | bc)
echo "检查完成，耗时: ${response_time}秒"
```

### 4. 日志记录
```bash
# 记录检查结果到日志文件
./check-deployment-status.sh >> /var/log/quota-proxy-status.log 2>&1

# 按日期分割日志
./check-deployment-status.sh >> /var/log/quota-proxy-status-$(date +%Y-%m-%d).log
```

## 相关文档

- [VALIDATION-TOOLS-INDEX.md](./VALIDATION-TOOLS-INDEX.md) - 验证工具索引
- [QUICK-HEALTH-CHECK.md](./QUICK-HEALTH-CHECK.md) - 快速健康检查指南
- [DEPLOY-VERIFICATION.md](./DEPLOY-VERIFICATION.md) - 部署验证指南
- [ADMIN-API-EXAMPLES.md](./ADMIN-API-EXAMPLES.md) - Admin API调用示例

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持健康检查、状态检查、API密钥检查、试用密钥检查
- 支持干运行模式、详细输出、安静模式
- 生成格式化的部署状态报告
- 提供完整的文档和示例

## 贡献指南

欢迎提交问题和改进建议！

1. Fork仓库
2. 创建功能分支：`git checkout -b feature/new-check`
3. 提交更改：`git commit -am 'Add new check feature'`
4. 推送到分支：`git push origin feature/new-check`
5. 创建Pull Request

## 许可证

MIT License