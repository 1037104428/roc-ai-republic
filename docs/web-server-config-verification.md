# Web服务器配置验证指南

## 概述

本文档介绍如何使用 `verify-web-server-config.sh` 脚本来验证站点Web服务器（Nginx/Caddy）的配置，确保站点部署配置正确。该脚本提供完整的配置语法检查、服务状态验证、端口监听测试和HTTP连接验证功能。

## 脚本功能

### 主要功能

1. **SSH连接检查** - 验证与服务器的SSH连接
2. **配置语法检查** - 检查Nginx/Caddy配置文件语法
3. **站点目录验证** - 检查站点目录存在性和内容
4. **服务状态检查** - 检查Web服务器服务运行状态
5. **端口监听检查** - 验证指定端口是否正在监听
6. **HTTP连接测试** - 测试HTTP连接可用性
7. **验证报告生成** - 生成详细的验证报告

### 支持的Web服务器

- **Nginx** - 检查 `nginx -t` 语法，验证服务状态
- **Caddy** - 检查 `caddy validate` 语法，验证服务状态

## 快速开始

### 基本用法

```bash
# 检查Nginx配置
./scripts/verify-web-server-config.sh --web-server nginx

# 检查Caddy配置
./scripts/verify-web-server-config.sh --web-server caddy

# 只检查配置语法，不测试连接
./scripts/verify-web-server-config.sh --web-server nginx --check-only

# 详细输出模式
./scripts/verify-web-server-config.sh --web-server nginx --verbose

# 安静模式（只输出关键信息）
./scripts/verify-web-server-config.sh --web-server nginx --quiet
```

### 自定义服务器配置

```bash
# 指定服务器地址和用户
./scripts/verify-web-server-config.sh \
  --server-host 192.168.1.100 \
  --server-user admin \
  --web-server nginx

# 指定SSH密钥路径
./scripts/verify-web-server-config.sh \
  --ssh-key ~/.ssh/custom_key \
  --web-server caddy

# 指定站点目录和配置文件
./scripts/verify-web-server-config.sh \
  --site-dir /var/www/html \
  --config-file /etc/nginx/sites-available/default \
  --web-server nginx

# 指定测试端口
./scripts/verify-web-server-config.sh \
  --test-port 8080 \
  --web-server nginx
```

## 详细说明

### 脚本参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--server-host` | 服务器地址 | `8.210.185.194` |
| `--server-user` | 服务器用户名 | `root` |
| `--ssh-key` | SSH私钥路径 | `~/.ssh/id_ed25519_roc_server` |
| `--site-dir` | 站点目录 | `/opt/roc/web` |
| `--web-server` | Web服务器类型 | `nginx` |
| `--config-file` | 主配置文件路径 | `/etc/nginx/nginx.conf` |
| `--config-dir` | 配置目录路径 | `/etc/nginx/conf.d` |
| `--test-port` | 测试端口 | `80` |
| `--check-only` | 只检查配置，不测试连接 | `false` |
| `--verbose` | 详细输出模式 | `false` |
| `--quiet` | 安静模式，只输出关键信息 | `false` |
| `--help` | 显示帮助信息 | - |

### 验证流程

脚本按照以下顺序执行验证：

1. **SSH连接验证** - 确保可以连接到服务器
2. **配置语法检查** - 检查Web服务器配置文件语法
3. **站点目录检查** - 验证站点目录存在性和内容
4. **服务状态检查** - 检查Web服务器服务是否运行
5. **端口监听检查** - 验证指定端口是否监听
6. **HTTP连接测试** - 测试HTTP连接（除非指定`--check-only`）
7. **报告生成** - 生成详细的验证报告

### 输出示例

```
[INFO] 开始验证 nginx 配置...
[INFO] 服务器: root@8.210.185.194
[INFO] 站点目录: /opt/roc/web
[INFO] 配置文件: /etc/nginx/nginx.conf
[INFO] 检查SSH连接到服务器 root@8.210.185.194...
[SUCCESS] SSH连接成功
[INFO] 检查 nginx 配置文件语法...
[SUCCESS] Nginx配置语法检查通过
[INFO] 检查站点目录: /opt/roc/web
[SUCCESS] 站点目录存在
[SUCCESS] 站点目录包含 5 个网页文件
[INFO] 检查 nginx 服务状态...
[SUCCESS] Nginx服务正在运行
[INFO] 检查端口 80 监听状态...
[SUCCESS] 端口 80 正在监听
[INFO] 测试HTTP连接到端口 80...
[SUCCESS] HTTP连接测试成功
[SUCCESS] 验证报告已生成: /tmp/web-server-config-report-20260210-182152.txt

Web服务器配置验证报告
=====================
验证时间: 2026-02-10 18:21:52 CST
服务器: root@8.210.185.194
Web服务器: nginx
站点目录: /opt/roc/web
配置文件: /etc/nginx/nginx.conf

验证结果:
  ✓ SSH连接: 成功
  ✓ nginx配置语法: 成功
  ✓ 站点目录存在性: 成功
  ✓ nginx服务状态: 成功
  ✓ 端口80监听: 成功
  ✓ HTTP连接测试: 成功

建议操作:
  - 所有检查通过，站点配置正常
  - 建议定期运行此脚本进行监控

[INFO] 验证完成
[INFO] 请查看上方报告了解详细结果和建议
```

## 使用场景

### 1. 部署前验证

在部署站点之前，验证服务器配置是否正确：

```bash
# 部署前验证Nginx配置
./scripts/verify-web-server-config.sh --web-server nginx --check-only

# 如果验证通过，再进行部署
if [ $? -eq 0 ]; then
    echo "配置验证通过，开始部署..."
    # 部署命令
fi
```

### 2. 故障排查

当站点无法访问时，快速诊断问题：

```bash
# 详细模式诊断
./scripts/verify-web-server-config.sh --web-server nginx --verbose

# 根据报告中的失败项进行修复
```

### 3. 定期监控

设置定时任务定期检查站点配置：

```bash
# 每天检查一次
0 2 * * * /path/to/roc-ai-republic/scripts/verify-web-server-config.sh --web-server nginx --quiet > /var/log/web-config-check.log 2>&1

# 检查失败时发送通知
if [ $? -ne 0 ]; then
    # 发送邮件或通知
    echo "Web服务器配置检查失败" | mail -s "配置检查告警" admin@example.com
fi
```

### 4. CI/CD集成

在CI/CD流水线中集成配置验证：

```yaml
# GitLab CI示例
validate_web_config:
  stage: validate
  script:
    - ./scripts/verify-web-server-config.sh --web-server nginx --check-only
  only:
    - main
    - develop
```

## 故障排除

### 常见问题

#### 1. SSH连接失败

**症状**: `[ERROR] SSH连接失败，请检查网络、密钥和服务器状态`

**解决方案**:
- 检查网络连接
- 验证SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
- 确认服务器IP地址正确
- 检查服务器SSH服务状态

#### 2. 配置语法错误

**症状**: `[ERROR] Nginx配置语法检查失败`

**解决方案**:
- 查看详细错误信息（脚本会输出nginx -t的错误）
- 检查配置文件路径是否正确
- 验证配置文件语法
- 使用`nginx -t`命令手动测试

#### 3. 服务未运行

**症状**: `[ERROR] Nginx服务未运行`

**解决方案**:
- 启动服务：`systemctl start nginx`
- 检查服务状态：`systemctl status nginx`
- 查看服务日志：`journalctl -u nginx`

#### 4. 端口未监听

**症状**: `[ERROR] 端口 80 未监听`

**解决方案**:
- 检查Web服务器配置中的监听端口
- 确认防火墙未阻止端口
- 检查是否有其他服务占用端口

#### 5. HTTP连接失败

**症状**: `[ERROR] HTTP连接测试失败`

**解决方案**:
- 检查Web服务器是否响应
- 验证站点目录是否有有效内容
- 检查权限设置
- 查看Web服务器错误日志

### 调试技巧

1. **使用详细模式**:
   ```bash
   ./scripts/verify-web-server-config.sh --web-server nginx --verbose
   ```

2. **手动验证命令**:
   ```bash
   # SSH连接测试
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "echo '连接成功'"
   
   # Nginx语法测试
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "nginx -t"
   
   # 服务状态检查
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "systemctl status nginx"
   
   # 端口监听检查
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "netstat -tln | grep :80"
   
   # HTTP连接测试
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "curl -fsS http://127.0.0.1:80"
   ```

3. **检查报告文件**:
   ```bash
   # 查看最新报告
   ls -la /tmp/web-server-config-report-*.txt | tail -1
   cat /tmp/web-server-config-report-20260210-182152.txt
   ```

## 最佳实践

### 1. 预部署验证

在每次部署前运行验证脚本，确保配置正确：

```bash
#!/bin/bash
# 部署前验证脚本

echo "开始部署前验证..."

# 验证Web服务器配置
if ! ./scripts/verify-web-server-config.sh --web-server nginx --check-only; then
    echo "Web服务器配置验证失败，部署中止"
    exit 1
fi

echo "验证通过，开始部署..."
# 部署代码...
```

### 2. 监控告警集成

将验证脚本集成到监控系统中：

```bash
#!/bin/bash
# 监控脚本

LOG_FILE="/var/log/web-config-monitor.log"
ALERT_EMAIL="admin@example.com"

# 运行验证
./scripts/verify-web-server-config.sh --web-server nginx --quiet > "$LOG_FILE" 2>&1
EXIT_CODE=$?

# 检查结果
if [ $EXIT_CODE -ne 0 ]; then
    # 发送告警
    echo "Web服务器配置检查失败，退出码: $EXIT_CODE" | \
        mail -s "Web配置告警 $(date)" "$ALERT_EMAIL"
    
    # 附加日志
    tail -50 "$LOG_FILE" | mail -s "Web配置告警日志" "$ALERT_EMAIL"
fi
```

### 3. 自动化修复

对于常见问题，可以创建自动化修复脚本：

```bash
#!/bin/bash
# 自动化修复脚本

# 检查并修复Nginx配置
fix_nginx_config() {
    echo "检查Nginx配置..."
    
    if ! ssh root@8.210.185.194 "nginx -t" > /dev/null 2>&1; then
        echo "Nginx配置错误，尝试修复..."
        
        # 备份当前配置
        ssh root@8.210.185.194 "cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d)"
        
        # 恢复默认配置或应用修复
        # ... 修复逻辑 ...
        
        # 重新测试
        if ssh root@8.210.185.194 "nginx -t"; then
            echo "配置修复成功，重启Nginx..."
            ssh root@8.210.185.194 "systemctl restart nginx"
        else
            echo "配置修复失败"
            return 1
        fi
    fi
    
    return 0
}

# 主修复流程
if ! ./scripts/verify-web-server-config.sh --web-server nginx --check-only; then
    echo "配置验证失败，开始自动化修复..."
    fix_nginx_config
fi
```

## 相关文档

- [站点部署验证指南](./site-deployment-verification.md) - 站点部署的完整验证流程
- [Docker Compose清理工具](./docker-compose-cleanup-tool.md) - Docker部署配置文件管理
- [安装验证脚本](./install-verification.md) - OpenClaw安装验证工具
- [网络诊断工具](./network-diagnosis-tool.md) - 网络连接测试和故障排除

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持Nginx和Caddy配置验证
- 完整的验证流程和报告生成
- 多种运行模式（详细/安静/检查模式）
- 故障排除和建议功能

## 支持与反馈

如有问题或建议，请：
1. 查看本文档的故障排除部分
2. 运行脚本时使用`--verbose`模式获取详细输出
3. 检查生成的验证报告
4. 提交Issue到项目仓库