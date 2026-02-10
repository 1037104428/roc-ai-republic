# quota-proxy部署状态检查脚本指南

## 概述

`check-quota-proxy-deployment.sh` 是一个快速验证 quota-proxy 部署状态的工具脚本。它提供本地和远程两种检查模式，帮助管理员快速确认 quota-proxy 服务的运行状态和核心功能。

## 功能特性

- **本地检查模式**: 直接检查本地运行的 quota-proxy 实例
- **远程检查模式**: 通过 SSH 检查远程服务器上的 quota-proxy 部署
- **全面验证**: 涵盖健康检查、管理接口、试用密钥创建和验证
- **灵活配置**: 支持自定义主机、端口、令牌等参数
- **模拟运行**: 支持 dry-run 模式，不执行实际检查
- **详细输出**: 支持 verbose 模式，显示详细检查过程
- **彩色输出**: 使用颜色区分不同级别的信息
- **标准化退出码**: 明确的退出码表示不同检查结果

## 使用场景

### 场景1: 本地部署验证
部署 quota-proxy 后，快速验证服务是否正常运行。

### 场景2: 远程服务器监控
定期检查生产环境中的 quota-proxy 服务状态。

### 场景3: 故障排查
当 quota-proxy 出现问题时，快速定位问题所在。

### 场景4: 部署脚本集成
在自动化部署流程中集成状态检查。

## 安装与配置

### 1. 获取脚本
```bash
# 从项目仓库获取
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/scripts
chmod +x check-quota-proxy-deployment.sh
```

### 2. 配置 SSH 密钥（远程检查）
```bash
# 生成 SSH 密钥对（如果还没有）
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_roc_server

# 将公钥复制到远程服务器
ssh-copy-id -i ~/.ssh/id_ed25519_roc_server.pub root@8.210.185.194
```

## 使用方法

### 基本用法

```bash
# 显示帮助信息
./check-quota-proxy-deployment.sh --help

# 检查本地 quota-proxy（默认配置）
./check-quota-proxy-deployment.sh

# 检查远程服务器
./check-quota-proxy-deployment.sh -s root@8.210.185.194

# 使用自定义配置
./check-quota-proxy-deployment.sh -h 192.168.1.100 -p 8080 -t "my-admin-token"
```

### 高级用法

```bash
# 模拟运行（不执行实际检查）
./check-quota-proxy-deployment.sh -n

# 详细输出模式
./check-quota-proxy-deployment.sh -v

# 组合使用
./check-quota-proxy-deployment.sh -s root@8.210.185.194 -v -n

# 在脚本中集成
if ./check-quota-proxy-deployment.sh -s root@8.210.185.194; then
    echo "部署检查通过"
else
    echo "部署检查失败"
    exit 1
fi
```

## 检查项目详解

### 本地检查模式
1. **健康检查**: 验证 `/healthz` 端点是否返回正常
2. **管理接口检查**: 验证 `/admin/status` 端点是否可访问
3. **试用密钥创建**: 通过 POST `/admin/keys` 创建试用密钥
4. **密钥验证**: 使用创建的密钥访问 `/usage` 端点

### 远程检查模式
1. **SSH 连接测试**: 验证到远程服务器的 SSH 连接
2. **Docker 状态检查**: 检查 quota-proxy 容器是否运行
3. **健康状态检查**: 验证服务的健康状态

## 退出码说明

| 退出码 | 说明 | 建议操作 |
|--------|------|----------|
| 0 | 所有检查通过 | 部署正常，无需操作 |
| 1 | 参数错误或帮助信息 | 检查命令行参数 |
| 2 | 健康检查失败 | 检查 quota-proxy 服务是否运行 |
| 3 | 管理接口检查失败 | 检查 ADMIN_TOKEN 配置 |
| 4 | 试用密钥创建失败 | 检查数据库连接和权限 |
| 5 | SSH 连接失败 | 检查网络连接和 SSH 配置 |

## 最佳实践

### 1. 定期检查
```bash
# 添加到 crontab，每小时检查一次
0 * * * * /path/to/roc-ai-republic/scripts/check-quota-proxy-deployment.sh -s root@8.210.185.194 >> /var/log/quota-proxy-check.log 2>&1
```

### 2. 集成到部署流程
```bash
#!/bin/bash
# deploy-quota-proxy.sh

# 部署 quota-proxy
docker compose up -d

# 等待服务启动
sleep 10

# 检查部署状态
if ./check-quota-proxy-deployment.sh -h 127.0.0.1 -p 8787 -t "$ADMIN_TOKEN"; then
    echo "部署成功"
else
    echo "部署失败"
    docker compose logs
    exit 1
fi
```

### 3. 监控告警集成
```bash
#!/bin/bash
# monitor-quota-proxy.sh

LOG_FILE="/var/log/quota-proxy-monitor.log"
ALERT_EMAIL="admin@example.com"

# 运行检查
if ! ./check-quota-proxy-deployment.sh -s root@8.210.185.194; then
    echo "$(date): quota-proxy 检查失败" >> "$LOG_FILE"
    # 发送告警邮件
    echo "quota-proxy 服务异常，请立即检查" | mail -s "quota-proxy 告警" "$ALERT_EMAIL"
fi
```

## 故障排除

### 常见问题

#### 1. SSH 连接失败
```bash
# 错误信息
[ERROR] SSH连接失败

# 解决方案
# 1. 检查网络连接
ping 8.210.185.194

# 2. 检查 SSH 配置
ssh -v root@8.210.185.194

# 3. 检查防火墙
sudo ufw status
```

#### 2. 健康检查失败
```bash
# 错误信息
[ERROR] 健康检查失败

# 解决方案
# 1. 检查服务是否运行
docker compose ps

# 2. 检查端口监听
netstat -tlnp | grep 8787

# 3. 查看服务日志
docker compose logs quota-proxy
```

#### 3. 管理接口检查失败
```bash
# 错误信息
[WARNING] 管理接口返回状态码: 401

# 解决方案
# 1. 检查 ADMIN_TOKEN 配置
echo $ADMIN_TOKEN

# 2. 验证令牌有效性
curl -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/status

# 3. 重新生成令牌
# 参考 quota-proxy 文档重新生成管理令牌
```

## 更新记录

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持本地和远程检查模式
- 实现健康检查、管理接口检查、试用密钥创建和验证
- 支持 dry-run 和 verbose 模式
- 提供完整的文档和使用指南

## 相关资源

- [quota-proxy 项目文档](../docs/quota-proxy-overview.md)
- [验证工具概览](../docs/verification-tools-overview.md)
- [快速验证一键脚本](../docs/quick-validate-all-guide.md)
- [完整 API 流程测试](../docs/quota-proxy-full-api-flow-integration-testing.md)

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

1. Fork 项目仓库
2. 创建功能分支 (`git checkout -b feature/improvement`)
3. 提交更改 (`git commit -am 'Add some improvement'`)
4. 推送到分支 (`git push origin feature/improvement`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。
