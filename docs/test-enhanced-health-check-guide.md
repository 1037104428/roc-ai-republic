# 增强健康检查端点测试指南

## 概述

本指南介绍如何使用 `test-enhanced-health-check.sh` 脚本来测试 quota-proxy 的增强健康检查端点。增强健康检查端点 (`/healthz`) 提供了更详细的健康状态信息，包括数据库连接状态和表结构检查。

## 功能特性

- **全面的健康检查**: 检查服务器状态、数据库连接和表结构
- **多种输出格式**: 支持 text、json、markdown 格式输出
- **灵活的配置**: 可配置主机、端口、超时时间和重试次数
- **详细的错误报告**: 提供详细的错误信息和调试信息
- **表结构验证**: 验证必需的表结构是否完整

## 快速开始

### 基本用法

```bash
# 测试本地服务器
chmod +x ./scripts/test-enhanced-health-check.sh
./scripts/test-enhanced-health-check.sh

# 测试远程服务器
./scripts/test-enhanced-health-check.sh --host 8.210.185.194 --port 8787
```

### 详细输出模式

```bash
# 启用详细输出
./scripts/test-enhanced-health-check.sh --verbose

# 使用JSON格式输出
./scripts/test-enhanced-health-check.sh --format json

# 使用Markdown格式输出
./scripts/test-enhanced-health-check.sh --format markdown
```

## 命令行选项

| 选项 | 缩写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--host` | `-H` | 服务器主机名或IP地址 | `localhost` |
| `--port` | `-p` | 服务器端口 | `8787` |
| `--timeout` | `-t` | 请求超时时间（秒） | `5` |
| `--retries` | `-r` | 重试次数 | `3` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | `-d` | 只显示命令，不执行 | `false` |
| `--format` | `-f` | 输出格式：text/json/markdown | `text` |
| `--no-color` | - | 禁用颜色输出 | `false` |

## 健康检查端点响应格式

增强健康检查端点返回详细的JSON响应：

```json
{
  "ok": true,
  "timestamp": "2026-02-11T10:11:53.123Z",
  "service": "quota-proxy",
  "version": "1.0.0",
  "checks": {
    "server": {
      "ok": true,
      "message": "Express server is running"
    },
    "database": {
      "ok": true,
      "message": "Database connection is healthy",
      "queryTest": "SELECT 1 executed successfully",
      "tables": {
        "ok": true,
        "message": "Found 2 tables",
        "tables": ["api_keys", "usage_log"],
        "requiredTables": ["api_keys", "usage_log"]
      }
    }
  }
}
```

## 验证标准

### 通过标准

健康检查被认为通过的条件：

1. **整体状态**: `ok` 字段为 `true`
2. **数据库连接**: `checks.database.ok` 为 `true`
3. **表结构**: `checks.database.tables.ok` 为 `true`
4. **必需的表**: 包含 `api_keys` 和 `usage_log` 两个表

### 失败场景

健康检查失败的常见原因：

1. **服务器未运行**: 无法连接到指定端口
2. **数据库连接失败**: SQLite 数据库文件损坏或权限问题
3. **表结构不完整**: 缺少必需的表
4. **数据库查询错误**: SQL 语法错误或数据库损坏

## 使用示例

### 示例1：基本测试

```bash
./scripts/test-enhanced-health-check.sh --host localhost --port 8787
```

输出示例：
```
=== 健康检查结果 ===
服务: quota-proxy v1.0.0
时间戳: 2026-02-11T10:11:53.123Z
整体状态: ✅ 正常

详细检查:
  数据库连接: ✅ 正常 - Database connection is healthy
  表结构检查: ✅ 正常 - Found 2 tables
  表数量: 2
```

### 示例2：JSON格式输出

```bash
./scripts/test-enhanced-health-check.sh --format json
```

### 示例3：集成到CI/CD流程

```bash
#!/bin/bash
# CI/CD健康检查脚本

set -e

echo "开始健康检查..."
if ./scripts/test-enhanced-health-check.sh --host production-server --port 8787 --timeout 10; then
    echo "健康检查通过，可以继续部署"
    exit 0
else
    echo "健康检查失败，停止部署"
    exit 1
fi
```

## 故障排除

### 常见问题

#### 1. 连接超时

**症状**: 脚本报告连接超时
**解决方案**:
- 检查服务器是否正在运行
- 检查防火墙设置
- 增加超时时间：`--timeout 10`

#### 2. 数据库连接失败

**症状**: 数据库检查失败
**解决方案**:
- 检查数据库文件路径和权限
- 验证数据库文件是否损坏
- 检查数据库连接配置

#### 3. 表结构不完整

**症状**: 缺少必需的表
**解决方案**:
- 运行数据库初始化脚本
- 检查数据库迁移是否成功
- 验证表创建SQL语句

### 调试技巧

```bash
# 启用详细输出查看详细信息
./scripts/test-enhanced-health-check.sh --verbose

# 使用干运行模式查看将要执行的命令
./scripts/test-enhanced-health-check.sh --dry-run

# 手动测试健康检查端点
curl -v http://localhost:8787/healthz
```

## 与旧版本的区别

### 旧版本健康检查
```json
{ "ok": true }
```

### 新版本增强健康检查
```json
{
  "ok": true,
  "timestamp": "...",
  "service": "quota-proxy",
  "version": "1.0.0",
  "checks": {
    "server": { ... },
    "database": { ... }
  }
}
```

## 最佳实践

1. **生产环境监控**: 将健康检查集成到监控系统（如 Prometheus、Nagios）
2. **自动化测试**: 在CI/CD流程中加入健康检查
3. **告警配置**: 根据健康检查结果配置告警
4. **定期检查**: 设置定时任务定期执行健康检查
5. **日志记录**: 记录健康检查结果用于问题排查

## 相关资源

- [quota-proxy 服务器代码](../quota-proxy/server-sqlite.js)
- [TODO清单](../docs/TODO-quota-proxy-sqlite-improvements.md)
- [Admin API 指南](../docs/admin-api-quick-guide.md)
- [数据库恢复测试指南](../docs/test-database-recovery-guide.md)

## 更新记录

| 日期 | 版本 | 描述 |
|------|------|------|
| 2026-02-11 | 1.0.0 | 创建增强健康检查端点测试脚本和指南 |
| 2026-02-11 | 1.0.0 | 更新健康检查端点，包含数据库状态检查 |

---

**注意**: 本脚本是 quota-proxy 验证工具链的一部分，用于确保生产环境的稳定性和可靠性。