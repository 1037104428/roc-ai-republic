# Enhanced Health Check Tool for quota-proxy

## 概述

`enhanced-health-check.sh` 是一个增强版的健康检查工具，专门为 quota-proxy 服务设计。它不仅检查基本的服务状态，还提供数据库连接、API响应时间、磁盘空间和内存使用情况的全面监控。

## 功能特性

### 1. 全面的健康检查
- **服务状态检查**: 验证 quota-proxy Docker 容器是否正常运行
- **API 健康端点**: 检查 `/healthz` 端点的可用性和响应时间
- **数据库连接**: 验证 SQLite 数据库连接和表结构
- **文件系统检查**: 检查数据库文件的存在性、权限和可访问性
- **资源监控**: 监控磁盘空间和内存使用情况

### 2. 智能诊断
- **响应时间监控**: 测量 API 响应时间，识别性能问题
- **阈值告警**: 自动检测高响应时间（>1000ms）和高磁盘使用率（>80%）
- **详细报告**: 提供彩色输出和结构化诊断信息

### 3. 灵活的配置
- **多种运行模式**: 支持详细模式、静默模式和自定义超时
- **环境适配**: 自动检测 SQLite 可用性和数据库状态
- **安全检查**: 验证文件权限和可访问性

## 安装与使用

### 安装
```bash
# 确保脚本有执行权限
chmod +x scripts/enhanced-health-check.sh
```

### 基本使用
```bash
# 运行基本健康检查
./scripts/enhanced-health-check.sh
```

### 详细模式
```bash
# 显示详细输出
./scripts/enhanced-health-check.sh --verbose
```

### 自定义超时
```bash
# 设置自定义超时时间（秒）
./scripts/enhanced-health-check.sh --timeout 10
```

### 帮助信息
```bash
# 查看帮助信息
./scripts/enhanced-health-check.sh --help
```

## 输出示例

### 成功检查示例
```
=== Enhanced Health Check for quota-proxy ===
Timestamp: 2026-02-10 19:15:00 CST

  1. Checking quota-proxy service status...
✓ quota-proxy service is running
  2. Checking healthz endpoint...
✓ Healthz endpoint responded: {"ok":true}
  Response time: 45ms
  3. Checking database file...
✓ Database file exists: /opt/roc/quota-proxy/data/quota.db
  Permissions: -rw-r--r--
  Size: 81920 bytes
✓ Database file is readable
✓ Database file is writable
  4. Checking database connection...
✓ Database connection successful
  API keys in database: 5
  Quota usage records: 128
  5. Checking disk space...
  Disk usage: 65%
✓ Disk usage is normal
  6. Checking memory usage...
  Container memory: 45.21MiB / 512MiB

✓ === Health check completed successfully ===
  All critical checks passed
```

### 警告示例
```
⚠ Response time is high (>1000ms)
⚠ Disk usage is moderate (>80%)
```

### 错误示例
```
✗ quota-proxy service is not running
✗ Healthz endpoint failed or timed out
```

## 检查项详解

### 1. 服务状态检查
- 使用 `docker compose ps` 检查 quota-proxy 容器状态
- 验证容器是否处于 "Up" 状态

### 2. API 健康端点检查
- 向 `http://127.0.0.1:8787/healthz` 发送 HTTP 请求
- 测量响应时间并检查 JSON 响应格式
- 响应时间阈值：正常 <500ms，警告 500-1000ms，错误 >1000ms

### 3. 数据库文件检查
- 检查 `/opt/roc/quota-proxy/data/quota.db` 文件是否存在
- 验证文件权限（至少需要读权限，推荐写权限）
- 检查文件大小和最后修改时间

### 4. 数据库连接检查
- 使用 `sqlite3` 命令行工具连接数据库
- 查询 `api_keys` 表记录数量
- 查询 `quota_usage` 表记录数量（如果存在）

### 5. 磁盘空间检查
- 检查 `/opt/roc` 目录所在分区的磁盘使用率
- 阈值：正常 <80%，警告 80-90%，错误 >90%

### 6. 内存使用检查
- 使用 `docker stats` 检查容器内存使用情况
- 显示当前内存使用量和限制

## 集成与自动化

### 定时任务（Cron）
```bash
# 每小时运行一次健康检查，记录到日志文件
0 * * * * /path/to/roc-ai-republic/scripts/enhanced-health-check.sh >> /var/log/quota-proxy-health.log 2>&1
```

### CI/CD 集成
```yaml
# GitHub Actions 示例
name: Health Check
on: [push, pull_request]
jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run enhanced health check
        run: ./scripts/enhanced-health-check.sh --timeout 10
```

### 监控系统集成
```bash
# Nagios/Icinga 插件格式
exit_code=0
output=$(./scripts/enhanced-health-check.sh 2>&1)

if echo "$output" | grep -q "Health check completed successfully"; then
    echo "OK: quota-proxy health check passed"
    exit 0
else
    echo "CRITICAL: quota-proxy health check failed"
    echo "$output"
    exit 2
fi
```

## 故障排除

### 常见问题

#### 1. "quota-proxy service is not running"
```bash
# 启动 quota-proxy 服务
cd /opt/roc/quota-proxy
docker compose up -d
```

#### 2. "Healthz endpoint failed or timed out"
```bash
# 检查服务日志
docker compose logs quota-proxy

# 检查端口监听
netstat -tlnp | grep 8787
```

#### 3. "Database file not found"
```bash
# 检查数据库文件路径
ls -la /opt/roc/quota-proxy/data/

# 如果是新安装，可能需要初始化数据库
./scripts/init-sqlite-db.sh
```

#### 4. "Database file is not readable/writable"
```bash
# 修复文件权限
chmod 644 /opt/roc/quota-proxy/data/quota.db
chown 1000:1000 /opt/roc/quota-proxy/data/quota.db
```

#### 5. "Disk usage is high"
```bash
# 清理旧日志和备份文件
find /opt/roc/quota-proxy/logs -name "*.log" -mtime +7 -delete
find /opt/roc/quota-proxy/backups -name "*.db" -mtime +30 -delete
```

## 最佳实践

### 1. 定期监控
- 建议每小时运行一次健康检查
- 将结果记录到日志文件进行趋势分析
- 设置告警阈值（响应时间 >1000ms，磁盘使用 >85%）

### 2. 自动化响应
- 集成到监控系统自动触发告警
- 配置自动修复脚本（如重启服务、清理磁盘）
- 设置升级和维护窗口

### 3. 安全考虑
- 确保健康检查脚本有适当的执行权限
- 不要在脚本中硬编码敏感信息
- 定期更新脚本以适应服务变更

### 4. 性能优化
- 调整超时时间以适应网络环境
- 使用缓存减少重复检查
- 并行化独立检查项

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 包含6个核心健康检查项
- 支持详细模式和自定义超时
- 提供彩色输出和结构化报告

## 相关资源

- [quota-proxy 文档](../docs/quota-proxy.md)
- [API 使用指南](../docs/quota-proxy-api-usage-guide.md)
- [故障排除指南](../docs/quota-proxy-faq-troubleshooting.md)
- [数据库验证工具](../docs/quota-proxy-database-verification.md)

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个工具。请确保：
1. 遵循现有的代码风格
2. 添加相应的测试用例
3. 更新文档和示例
4. 通过基本的健康检查验证

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。
