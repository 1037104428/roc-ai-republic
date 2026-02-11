# OpenClaw 配置模板使用指南

## 概述

OpenClaw 配置模板提供针对不同环境（开发、测试、生产）的预配置模板，帮助用户快速部署和配置 OpenClaw。这些模板遵循最佳实践，确保在不同环境中的安全性和性能。

## 可用模板

### 1. 开发环境模板 (`openclaw-config-dev.yaml`)
- **适用场景**: 本地开发、个人测试
- **特点**: 
  - 宽松的安全设置
  - 详细的调试日志
  - 所有工具启用
  - 适合快速迭代和调试

### 2. 测试环境模板 (`openclaw-config-test.yaml`)
- **适用场景**: 测试服务器、CI/CD 环境
- **特点**:
  - 适中的安全设置
  - JSON 格式日志
  - 限制的工具权限
  - 监控集成

### 3. 生产环境模板 (`openclaw-config-prod.yaml`)
- **适用场景**: 生产服务器、正式环境
- **特点**:
  - 严格的安全设置
  - 高性能配置
  - 完整的监控和备份
  - 高可用性支持

## 快速开始

### 方法一：手动复制模板

```bash
# 开发环境
cp config-templates/openclaw-config-dev.yaml ~/.openclaw/config.yaml

# 测试环境
sudo mkdir -p /etc/openclaw
sudo cp config-templates/openclaw-config-test.yaml /etc/openclaw/config.yaml
sudo chmod 640 /etc/openclaw/config.yaml

# 生产环境
sudo mkdir -p /etc/openclaw
sudo cp config-templates/openclaw-config-prod.yaml /etc/openclaw/production.yaml
sudo chmod 600 /etc/openclaw/production.yaml
```

### 方法二：使用 install-cn.sh 的配置模板功能

```bash
# 生成开发环境配置
./scripts/install-cn.sh --generate-config dev --output ~/.openclaw/config.yaml

# 生成测试环境配置
./scripts/install-cn.sh --generate-config test --output /etc/openclaw/config.yaml

# 生成生产环境配置
./scripts/install-cn.sh --generate-config prod --output /etc/openclaw/production.yaml
```

## 配置说明

### 关键配置项

#### 1. 安全配置
```yaml
security:
  requireAuth: true/false      # 是否要求认证
  allowedOrigins: []           # 允许的源域名
  rateLimit:
    enabled: true/false        # 是否启用速率限制
    requestsPerMinute: 10      # 每分钟请求数限制
```

#### 2. 工具权限
```yaml
tools:
  exec:
    enabled: true/false        # 是否启用执行命令
    security: "allowlist"      # 安全模式: deny/allowlist/full
    allowlist: ["ls", "ps"]    # 允许的命令列表
```

#### 3. 日志配置
```yaml
logging:
  level: "debug/info/warn/error"  # 日志级别
  format: "text/json"             # 日志格式
  file: "/path/to/logfile"        # 日志文件路径
```

#### 4. 监控配置
```yaml
monitoring:
  enabled: true/false          # 是否启用监控
  metricsPort: 9090            # 监控指标端口
  healthCheckPath: "/health"   # 健康检查路径
```

## 环境特定配置

### 开发环境
- 启用所有调试功能
- 宽松的安全设置
- 本地文件系统访问
- 适合快速原型开发

### 测试环境
- 适中的安全级别
- 监控集成
- 限制的工具权限
- 适合自动化测试

### 生产环境
- 严格的安全控制
- 性能优化
- 完整的监控和告警
- 备份和高可用性

## 验证配置

### 1. 语法验证
```bash
# 验证配置文件语法
openclaw config validate --config /path/to/config.yaml
```

### 2. 功能测试
```bash
# 启动服务
openclaw gateway start --config /path/to/config.yaml

# 测试健康检查
curl http://localhost:9090/health

# 测试基本功能
openclaw --version
```

### 3. 监控验证
```bash
# 查看监控指标
curl http://localhost:9090/metrics

# 检查日志
tail -f /var/log/openclaw/production.log
```

## 最佳实践

### 1. 安全最佳实践
- 生产环境必须启用认证
- 使用最小权限原则配置工具
- 定期轮换 API 密钥
- 启用审计日志

### 2. 性能最佳实践
- 根据负载调整连接池大小
- 启用缓存减少重复计算
- 监控内存使用情况
- 定期清理会话数据

### 3. 运维最佳实践
- 使用版本控制管理配置
- 实现配置即代码
- 定期备份配置和数据
- 监控关键指标和告警

## 故障排除

### 常见问题

#### 1. 配置语法错误
```bash
# 检查 YAML 语法
yamllint config.yaml

# 验证 OpenClaw 配置
openclaw config validate --config config.yaml
```

#### 2. 权限问题
```bash
# 检查文件权限
ls -la /etc/openclaw/config.yaml

# 检查目录权限
ls -la /var/lib/openclaw/
```

#### 3. 服务启动失败
```bash
# 查看服务日志
journalctl -u openclaw -f

# 检查端口占用
netstat -tlnp | grep :9090
```

## 更新记录

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0 | 2026-02-11 | 创建配置模板和使用指南 |

## 相关文档

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [OpenClaw 配置参考](https://docs.openclaw.ai/configuration)
- [install-cn.sh 安装脚本](../scripts/install-cn.sh)