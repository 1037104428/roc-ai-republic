# quota-proxy部署验证指南

## 概述

`verify-quota-proxy-deployment.sh` 脚本用于验证quota-proxy部署的完整性和基本功能。该脚本提供全面的部署验证，确保quota-proxy服务在生产环境中正常运行。

## 功能特性

### 验证项目
1. **Docker容器状态** - 检查quota-proxy容器是否正常运行
2. **API健康端点** - 验证 `/healthz` 端点是否响应正常
3. **数据库文件存在性** - 检查SQLite数据库文件是否存在且有效
4. **必需环境变量** - 验证关键环境变量是否已配置
5. **基本API功能** - 测试API的基本可访问性和安全保护

### 运行模式
- **详细模式** (`--verbose`) - 显示详细的调试信息
- **安静模式** (`--quiet`) - 只显示关键信息
- **模拟运行** (`--dry-run`) - 不执行实际验证，仅显示计划操作
- **自定义配置** - 支持自定义主机、端口和数据库路径

## 快速开始

### 基本用法
```bash
# 本地验证
./scripts/verify-quota-proxy-deployment.sh

# 远程服务器验证
./scripts/verify-quota-proxy-deployment.sh --host 8.210.185.194 --port 8787

# 详细输出模式
./scripts/verify-quota-proxy-deployment.sh --verbose

# 模拟运行
./scripts/verify-quota-proxy-deployment.sh --dry-run
```

### 查看帮助
```bash
./scripts/verify-quota-proxy-deployment.sh --help
```

## 详细说明

### 验证流程
脚本按照以下顺序执行验证：

1. **Docker容器状态检查**
   - 检查Docker命令是否可用
   - 查找名为"quota-proxy"的容器
   - 验证容器运行状态和端口映射

2. **API健康端点检查**
   - 使用curl测试 `/healthz` 端点
   - 验证响应包含 `{"ok":true}`
   - 检查网络连接和超时设置

3. **数据库文件验证**
   - 检查数据库文件是否存在
   - 验证文件大小（非空）
   - 可选：检查是否为有效的SQLite数据库

4. **环境变量验证**
   - 检查必需环境变量：`ADMIN_TOKEN`, `DATABASE_PATH`, `PORT`, `LOG_LEVEL`
   - 注意：环境变量检查为警告级别，不视为致命错误

5. **基本API功能测试**
   - 测试根端点可访问性
   - 验证未授权访问保护（应返回401/403）

### 退出码说明
| 退出码 | 说明 |
|--------|------|
| 0 | 所有验证通过 |
| 1 | 参数错误或帮助信息 |
| 2 | 验证失败（一个或多个检查失败） |
| 3 | 网络连接失败 |
| 4 | 环境配置错误 |

## 使用场景

### 1. 部署后验证
```bash
# 在部署完成后立即验证
./scripts/verify-quota-proxy-deployment.sh --verbose

# 输出示例：
# [INFO] 开始quota-proxy部署验证...
# [INFO] 配置: 主机=localhost, 端口=8787, 数据库路径=/opt/roc/quota-proxy/data/quota.db
# [INFO] 验证Docker容器状态...
# [SUCCESS] Docker容器 'quota-proxy' 正在运行
# [INFO] 验证API健康端点: http://localhost:8787/healthz
# [SUCCESS] API健康端点响应正常: {"ok":true}
# [INFO] 验证数据库文件: /opt/roc/quota-proxy/data/quota.db
# [SUCCESS] 数据库文件存在，大小: 32KiB
# [INFO] 验证必需环境变量...
# [SUCCESS] 所有必需环境变量已设置
# [INFO] 验证基本API功能...
# [SUCCESS] 根端点可访问: http://localhost:8787/
# [SUCCESS] 未授权访问保护正常 (HTTP 401)
# [SUCCESS] 所有验证通过 (5/5)
```

### 2. 监控和健康检查
```bash
# 定期运行作为健康检查
./scripts/verify-quota-proxy-deployment.sh --quiet

# 集成到监控系统
if ! ./scripts/verify-quota-proxy-deployment.sh --quiet; then
    echo "quota-proxy部署异常，需要人工干预"
    # 发送告警通知
fi
```

### 3. CI/CD流水线集成
```bash
# 在部署流水线中添加验证步骤
echo "开始部署验证..."
if ./scripts/verify-quota-proxy-deployment.sh; then
    echo "✅ 部署验证通过"
else
    echo "❌ 部署验证失败"
    exit 1
fi
```

## 配置选项

### 命令行参数
| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 详细输出模式 | false |
| `--quiet` | `-q` | 安静模式，只显示关键信息 | false |
| `--dry-run` | `-n` | 模拟运行，不执行实际验证 | false |
| `--host HOST` | - | 目标主机 | localhost |
| `--port PORT` | - | 目标端口 | 8787 |
| `--db-path PATH` | - | 数据库路径 | /opt/roc/quota-proxy/data/quota.db |

### 环境变量
脚本会检查以下环境变量（如果设置）：
- `ADMIN_TOKEN` - 管理令牌
- `DATABASE_PATH` - 数据库路径
- `PORT` - 服务端口
- `LOG_LEVEL` - 日志级别

## 故障排除

### 常见问题

#### 1. Docker容器未运行
```bash
# 检查Docker服务状态
systemctl status docker

# 启动quota-proxy容器
cd /opt/roc/quota-proxy && docker compose up -d
```

#### 2. API端点无法访问
```bash
# 检查端口监听
netstat -tlnp | grep 8787

# 检查防火墙规则
iptables -L -n | grep 8787

# 测试本地连接
curl -v http://localhost:8787/healthz
```

#### 3. 数据库文件问题
```bash
# 检查文件权限
ls -la /opt/roc/quota-proxy/data/

# 修复权限问题
chown -R 1000:1000 /opt/roc/quota-proxy/data/
chmod 644 /opt/roc/quota-proxy/data/quota.db

# 重新初始化数据库
./scripts/init-quota-db.sh --force
```

#### 4. 环境变量未设置
```bash
# 检查环境变量
env | grep -E "(ADMIN_TOKEN|DATABASE_PATH|PORT|LOG_LEVEL)"

# 设置环境变量
export ADMIN_TOKEN="your-secret-token"
export DATABASE_PATH="/opt/roc/quota-proxy/data/quota.db"
export PORT="8787"
export LOG_LEVEL="info"
```

### 调试技巧
```bash
# 启用详细输出
./scripts/verify-quota-proxy-deployment.sh --verbose

# 仅测试特定组件
# 1. 单独测试Docker
docker ps --filter "name=quota-proxy"

# 2. 单独测试API
curl -fsS http://localhost:8787/healthz

# 3. 单独测试数据库
ls -la /opt/roc/quota-proxy/data/quota.db
sqlite3 /opt/roc/quota-proxy/data/quota.db "SELECT name FROM sqlite_master WHERE type='table';"
```

## 最佳实践

### 1. 定期验证
```bash
# 添加到cron定时任务（每小时运行一次）
0 * * * * /home/kai/.openclaw/workspace/roc-ai-republic/scripts/verify-quota-proxy-deployment.sh --quiet >> /var/log/quota-proxy-verification.log 2>&1
```

### 2. 监控集成
```bash
# 创建监控脚本
#!/bin/bash
VERIFICATION_LOG="/var/log/quota-proxy-verification.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if ./scripts/verify-quota-proxy-deployment.sh --quiet; then
    echo "$TIMESTAMP - OK" >> "$VERIFICATION_LOG"
else
    echo "$TIMESTAMP - FAILED" >> "$VERIFICATION_LOG"
    # 发送告警通知
    ./scripts/send-alert.sh "quota-proxy部署验证失败"
fi
```

### 3. 自动化恢复
```bash
# 自动修复脚本示例
#!/bin/bash
if ! ./scripts/verify-quota-proxy-deployment.sh --quiet; then
    echo "检测到quota-proxy部署问题，尝试自动修复..."
    
    # 重启Docker容器
    cd /opt/roc/quota-proxy && docker compose restart
    
    # 等待服务启动
    sleep 10
    
    # 重新验证
    if ./scripts/verify-quota-proxy-deployment.sh --quiet; then
        echo "自动修复成功"
    else
        echo "自动修复失败，需要人工干预"
    fi
fi
```

## 相关脚本

### 配套工具
1. **健康检查** - `check-quota-proxy-health.sh`
   - 更详细的健康状态检查
   - 包含数据库连接测试

2. **配置验证** - `verify-quota-proxy-config.sh`
   - 专门验证环境变量配置
   - 支持智能验证规则

3. **数据库管理** - `init-quota-db.sh`, `backup-quota-db.sh`, `restore-quota-db.sh`
   - 数据库初始化、备份和恢复

### 集成使用
```bash
# 完整的部署验证流程
echo "步骤1: 验证配置"
./scripts/verify-quota-proxy-config.sh

echo "步骤2: 验证部署"
./scripts/verify-quota-proxy-deployment.sh --verbose

echo "步骤3: 健康检查"
./scripts/check-quota-proxy-health.sh

echo "步骤4: 数据库验证"
./scripts/verify-quota-db.sh
```

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持5个核心验证项目
- 提供多种运行模式
- 完整的文档和故障排除指南

## 贡献

欢迎提交问题和改进建议。请通过GitHub Issues或Pull Requests参与贡献。

## 许可证

本项目采用MIT许可证。详见LICENSE文件。