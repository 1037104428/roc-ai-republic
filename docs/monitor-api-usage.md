# quota-proxy API使用情况监控脚本

## 概述

`monitor-api-usage.sh` 是一个用于监控 quota-proxy API 密钥使用情况的脚本。它提供实时监控、阈值告警和多格式输出功能，帮助管理员及时发现和处理配额使用异常。

## 功能特性

- **实时监控**: 获取所有API密钥的当前使用情况
- **阈值告警**: 支持警告和严重两级阈值配置
- **多格式输出**: 支持文本、JSON、CSV三种输出格式
- **彩色显示**: 终端彩色输出，状态一目了然
- **多种模式**: 支持安静模式、详细模式、干运行模式
- **退出码**: 提供标准化的退出码，便于集成到监控系统

## 安装与使用

### 前置要求

1. **quota-proxy 服务**: 确保 quota-proxy 服务正在运行
2. **管理员令牌**: 需要有效的管理员令牌 (ADMIN_TOKEN)
3. **依赖工具**: 
   - `curl`: 用于HTTP请求
   - `jq`: 用于JSON解析
   - `bc`: 用于浮点数计算

### 基本使用

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token-here"

# 基本监控
./scripts/monitor-api-usage.sh

# 指定URL和令牌
./scripts/monitor-api-usage.sh --url http://localhost:8787 --token your-token

# 使用环境变量
ADMIN_TOKEN=your-token ./scripts/monitor-api-usage.sh
```

### 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--url` | `-u` | quota-proxy基础URL | `http://127.0.0.1:8787` |
| `--token` | `-t` | 管理员令牌 | 从环境变量读取 |
| `--format` | `-f` | 输出格式: text, json, csv | `text` |
| `--warning` | `-w` | 警告阈值 (百分比) | `80` |
| `--critical` | `-c` | 严重阈值 (百分比) | `95` |
| `--quiet` | `-q` | 安静模式，只输出摘要 | `false` |
| `--verbose` | `-v` | 详细模式，显示所有信息 | `false` |
| `--dry-run` | `-d` | 干运行模式，不实际调用API | `false` |
| `--no-color` | - | 禁用彩色输出 | `false` |

### 输出格式示例

#### 文本格式 (默认)
```
=== quota-proxy API使用情况监控报告 ===
监控时间: 2026-02-10 19:56:52 CST
基础URL: http://127.0.0.1:8787
总密钥数: 3
阈值配置: 警告=80%, 严重=95%

密钥: demo-key-1
  状态: 正常
  使用率: 15.0% (已用: 150/1000, 剩余: 850)
  创建时间: 2026-02-10T10:00:00Z
  最后使用: 2026-02-10T19:30:00Z

密钥: demo-key-2
  状态: 警告
  使用率: 90.0% (已用: 450/500, 剩余: 50)
  创建时间: 2026-02-10T11:00:00Z
  最后使用: 2026-02-10T19:45:00Z

=== 监控摘要 ===
总配额: 3500
总使用量: 650
总剩余量: 2850
平均使用率: 35.83%

状态统计:
  正常密钥: 2
  警告密钥: 1
  严重密钥: 0

注意: 发现 1 个密钥使用率超过警告阈值 (80%)
```

#### JSON格式
```json
{
  "keys": [...],
  "total_keys": 3,
  "total_quota": 3500,
  "total_used": 650,
  "total_remaining": 2850,
  "average_usage_percent": 35.83,
  "monitoring": {
    "warning_threshold": 80,
    "critical_threshold": 95,
    "monitored_at": "2026-02-10T19:56:52+08:00",
    "warning_count": 1,
    "critical_count": 0,
    "status": "warning"
  }
}
```

#### CSV格式
```csv
key,total_quota,used,remaining,usage_percent,status,created_at,last_used
demo-key-1,1000,150,850,15.0,normal,2026-02-10T10:00:00Z,2026-02-10T19:30:00Z
demo-key-2,500,450,50,90.0,warning,2026-02-10T11:00:00Z,2026-02-10T19:45:00Z
demo-key-3,2000,50,1950,2.5,normal,2026-02-10T12:00:00Z,2026-02-10T18:20:00Z
```

## 集成与自动化

### 定时监控 (cron)

```bash
# 每小时检查一次
0 * * * * ADMIN_TOKEN=your-token /path/to/scripts/monitor-api-usage.sh --quiet --url http://localhost:8787

# 每15分钟检查一次，只输出警告和严重情况
*/15 * * * * ADMIN_TOKEN=your-token /path/to/scripts/monitor-api-usage.sh --quiet --url http://localhost:8787 --warning 70 --critical 90
```

### 监控系统集成

```bash
# 获取退出码
./scripts/monitor-api-usage.sh --quiet
exit_code=$?

case $exit_code in
  0) echo "所有密钥正常" ;;
  1) echo "有密钥超过警告阈值" ;;
  2) echo "有密钥超过严重阈值" ;;
  3) echo "监控脚本执行出错" ;;
esac
```

### 与现有监控工具集成

```bash
# 输出到监控系统
./scripts/monitor-api-usage.sh --format json | jq '.monitoring' > /var/lib/monitoring/quota-proxy-status.json

# 发送告警到Slack/Telegram
if ./scripts/monitor-api-usage.sh --quiet; then
  if [ $? -eq 2 ]; then
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"quota-proxy: 发现严重配额使用情况!"}' \
      https://hooks.slack.com/services/...
  fi
fi
```

## 退出码说明

| 退出码 | 含义 | 描述 |
|--------|------|------|
| 0 | 正常 | 所有密钥使用率正常 |
| 1 | 警告 | 有密钥使用率超过警告阈值 |
| 2 | 严重 | 有密钥使用率超过严重阈值 |
| 3 | 错误 | 脚本执行出错 |

## 最佳实践

### 1. 安全配置
```bash
# 使用环境变量存储敏感信息
export ADMIN_TOKEN="secure-token-here"
chmod 600 ~/.quota-proxy-token

# 在脚本中引用
source ~/.quota-proxy-token
./scripts/monitor-api-usage.sh
```

### 2. 阈值调优
```bash
# 生产环境建议配置
./scripts/monitor-api-usage.sh --warning 70 --critical 90

# 开发环境可以放宽
./scripts/monitor-api-usage.sh --warning 85 --critical 98
```

### 3. 监控频率
- **高频监控**: 每5-15分钟，用于关键业务
- **常规监控**: 每小时，用于一般业务
- **低频监控**: 每天，用于报表和趋势分析

### 4. 告警策略
```bash
# 组合使用阈值和通知
./scripts/monitor-api-usage.sh --quiet --warning 70 --critical 90

# 根据退出码触发不同级别的告警
case $? in
  1) send_warning_notification ;;
  2) send_critical_notification ;;
esac
```

## 故障排除

### 常见问题

1. **权限错误**
   ```
   错误: 获取API使用情况失败
   ```
   **解决方案**: 检查管理员令牌是否正确，确保有访问 `/admin/usage` 端点的权限。

2. **服务不可达**
   ```
   curl: (7) Failed to connect to 127.0.0.1 port 8787: Connection refused
   ```
   **解决方案**: 检查 quota-proxy 服务是否正在运行，端口是否正确。

3. **JSON解析错误**
   ```
   jq: error: syntax error, unexpected ...
   ```
   **解决方案**: 检查 API 响应格式是否正确，确保安装了正确版本的 jq。

### 调试模式

```bash
# 启用详细输出
./scripts/monitor-api-usage.sh --verbose

# 干运行测试
./scripts/monitor-api-usage.sh --dry-run --verbose

# 检查依赖
which curl jq bc
```

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持文本、JSON、CSV三种输出格式
- 实现警告和严重两级阈值告警
- 提供标准化的退出码
- 支持安静模式、详细模式、干运行模式

## 相关文档

- [quota-proxy API 文档](./quota-proxy-api-guide.md)
- [管理员接口测试脚本](./test-admin-endpoints.md)
- [部署验证脚本](./full-deployment-verification.md)
- [API使用情况查询脚本](./query-api-usage.md)

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个监控脚本。

### 开发要求
- 遵循现有的代码风格
- 添加适当的测试用例
- 更新相关文档
- 确保向后兼容性

### 测试
```bash
# 运行测试
./scripts/monitor-api-usage.sh --dry-run --verbose
./scripts/monitor-api-usage.sh --dry-run --format json
./scripts/monitor-api-usage.sh --dry-run --format csv
```

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。