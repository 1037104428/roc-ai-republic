# quota-proxy 健康检查指南

## 概述

`check-quota-proxy-health.sh` 脚本是一个全面的健康检查工具，用于验证 quota-proxy 服务的运行状态。它执行三个关键检查：

1. **Docker 容器状态检查** - 验证容器是否正在运行
2. **API 健康端点检查** - 验证 `/healthz` 端点是否响应正常
3. **数据库连接检查** - 验证 SQLite 数据库是否可访问（如果配置了数据库）

## 快速开始

### 基本用法

```bash
# 在 quota-proxy 目录中运行
cd /opt/roc/quota-proxy
./check-quota-proxy-health.sh
```

### 带详细输出

```bash
./check-quota-proxy-health.sh --verbose
```

### 安静模式（适合脚本集成）

```bash
./check-quota-proxy-health.sh --quiet
```

### 模拟运行（不实际执行检查）

```bash
./check-quota-proxy-health.sh --dry-run
```

## 命令行选项

| 选项 | 缩写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 详细输出模式 | false |
| `--quiet` | `-q` | 安静模式，只输出关键信息 | false |
| `--dry-run` | `-d` | 模拟运行，不实际执行检查 | false |
| `--host` | - | 服务器主机地址 | 127.0.0.1 |
| `--port` | - | 服务端口 | 8787 |
| `--timeout` | - | 超时时间（秒） | 10 |
| `--docker-compose-path` | - | docker-compose.yml 路径 | 当前目录 |

## 检查项目详解

### 1. Docker 容器状态检查

脚本会检查：
- `docker-compose.yml` 文件是否存在
- quota-proxy 容器是否正在运行
- 容器健康状态（如果配置了健康检查）

**成功条件**：quota-proxy 容器状态为 "running"

### 2. API 健康端点检查

脚本会调用 `http://<host>:<port>/healthz` 端点并验证响应：
- 连接是否成功
- 响应是否为有效的 JSON
- JSON 中的 `ok` 字段是否为 `true`

**成功条件**：API 返回 `{"ok": true}` 或简单的 "ok" 响应

### 3. 数据库连接检查

脚本会：
1. 从容器环境变量中提取数据库路径（`DATABASE_PATH` 或 `DB_PATH`）
2. 检查数据库文件是否存在
3. 执行简单的 SQLite 查询验证数据库可访问性

**注意**：如果未配置数据库路径，此检查会被跳过

## 退出码

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 所有检查通过 |
| 1 | 参数错误 | 命令行参数错误或显示帮助信息 |
| 2 | Docker 检查失败 | 容器未运行或 docker-compose.yml 不存在 |
| 3 | API 检查失败 | 健康端点无法访问或返回错误 |
| 4 | 数据库检查失败 | 数据库文件不存在或无法连接 |
| 5 | 其他错误 | 脚本内部错误 |

## 使用场景

### 监控系统集成

```bash
# 在监控脚本中使用
if ./check-quota-proxy-health.sh --quiet; then
    echo "quota-proxy 运行正常"
else
    echo "quota-proxy 异常，退出码: $?"
    # 发送告警...
fi
```

### CI/CD 流水线

```bash
# 在部署后验证
./check-quota-proxy-health.sh --host 127.0.0.1 --port 8787 --timeout 30
if [ $? -ne 0 ]; then
    echo "部署后健康检查失败"
    exit 1
fi
```

### 定时健康检查

```bash
# 添加到 crontab，每5分钟检查一次
*/5 * * * * cd /opt/roc/quota-proxy && ./check-quota-proxy-health.sh --quiet > /dev/null 2>&1 || echo "quota-proxy 健康检查失败" | mail -s "quota-proxy 告警" admin@example.com
```

## 故障排除

### 常见问题

#### 1. "docker-compose.yml 文件不存在"
**解决方案**：使用 `--docker-compose-path` 指定正确的路径
```bash
./check-quota-proxy-health.sh --docker-compose-path /opt/roc/quota-proxy
```

#### 2. "无法连接到健康端点"
**解决方案**：
- 检查服务是否正在运行：`docker compose ps`
- 检查端口是否正确：`--port 8787`
- 增加超时时间：`--timeout 30`
- 检查防火墙设置

#### 3. "数据库文件不存在"
**解决方案**：
- 确认数据库路径环境变量已正确配置
- 检查数据库文件权限
- 如果需要，初始化数据库：`./scripts/init-quota-db.sh`

### 调试模式

使用详细输出模式查看详细执行信息：

```bash
./check-quota-proxy-health.sh --verbose --host 127.0.0.1 --port 8787
```

## 最佳实践

### 1. 生产环境配置

```bash
# 创建健康检查脚本别名
alias check-quota-proxy='/opt/roc/quota-proxy/check-quota-proxy-health.sh --host 127.0.0.1 --port 8787 --timeout 15'
```

### 2. 与监控系统集成

```bash
# Prometheus 健康检查端点
#!/bin/bash
if ./check-quota-proxy-health.sh --quiet; then
    echo '# HELP quota_proxy_health Health status of quota-proxy'
    echo '# TYPE quota_proxy_health gauge'
    echo 'quota_proxy_health 1'
else
    echo 'quota_proxy_health 0'
fi
```

### 3. 自动化恢复

```bash
#!/bin/bash
# 健康检查失败时自动重启
if ! ./check-quota-proxy-health.sh --quiet; then
    echo "$(date): quota-proxy 健康检查失败，尝试重启..."
    docker compose restart quota-proxy
    sleep 10
    ./check-quota-proxy-health.sh --verbose
fi
```

## 脚本特性

### 彩色输出
- 绿色：成功信息
- 蓝色：信息性消息
- 黄色：警告信息
- 红色：错误信息

### 灵活的配置
- 支持自定义主机、端口、超时时间
- 支持不同的输出模式（详细/安静）
- 支持模拟运行

### 标准化退出码
- 明确的退出码便于脚本集成
- 每个检查项目有独立的退出码

## 相关脚本

- `init-quota-db.sh` - 数据库初始化
- `verify-quota-db.sh` - 数据库验证
- `backup-quota-db.sh` - 数据库备份
- `restore-quota-db.sh` - 数据库恢复
- `test-quota-proxy-admin-keys-usage.sh` - API 测试

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持 Docker 容器状态检查
- 支持 API 健康端点检查
- 支持数据库连接检查
- 支持多种输出模式
- 提供完整的文档

## 贡献

发现问题或有改进建议？请提交 Issue 或 Pull Request。

## 许可证

MIT License