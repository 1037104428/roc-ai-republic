# Admin API性能检查脚本指南

## 概述

`check-admin-performance.sh` 是一个用于快速检查 quota-proxy Admin API 响应时间性能的脚本。它测量关键端点的性能，提供性能基准报告，并支持干运行模式。

## 快速开始

### 基本用法
```bash
# 使用默认配置运行
./check-admin-performance.sh

# 指定自定义配置
./check-admin-performance.sh --url http://localhost:8787 --token myadmin

# 干运行模式（模拟测试）
./check-admin-performance.sh --dry-run
```

### 环境变量配置
```bash
# 设置环境变量
export ADMIN_TOKEN="myadmin123"
export BASE_URL="http://localhost:8787"

# 运行脚本
./check-admin-performance.sh
```

## 功能特性

### 1. 性能测试端点
脚本测试以下关键端点：
- `GET /admin/keys` - 获取所有API密钥
- `GET /admin/usage` - 获取使用统计
- `POST /admin/keys` - 创建新API密钥
- `GET /healthz` - 健康检查端点

### 2. 性能评级系统
基于平均响应时间提供性能评级：
- < 100ms: 优秀
- 100-300ms: 良好
- 300-500ms: 一般
- > 500ms: 较慢

### 3. 干运行模式
支持干运行模式，显示测试步骤但不实际执行：
```bash
./check-admin-performance.sh --dry-run
```

在干运行模式下：
- 跳过实际HTTP请求
- 模拟响应时间（50-150ms）
- 显示所有测试步骤
- 不检查服务状态
- 不验证依赖

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `-t, --token TOKEN` | Admin令牌 | `admin123` |
| `-u, --url URL` | quota-proxy基础URL | `http://127.0.0.1:8787` |
| `-d, --dry-run` | 干运行模式 | `false` |
| `-h, --help` | 显示帮助信息 | - |

## 使用示例

### 示例1：基本性能检查
```bash
./check-admin-performance.sh
```

输出示例：
```
[INFO] 开始Admin API性能检查
[INFO] 配置:
[INFO]   Base URL: http://127.0.0.1:8787
[INFO]   Timeout: 10s
[SUCCESS] 服务运行正常
...
[SUCCESS] 平均响应时间: 85ms (优秀)
```

### 示例2：干运行模式
```bash
./check-admin-performance.sh --dry-run
```

输出示例：
```
[INFO] 开始Admin API性能检查
[INFO] 配置:
[INFO]   Base URL: http://127.0.0.1:8787
[INFO]   Timeout: 10s
[INFO]   模式: 干运行 (模拟测试)
[SUCCESS] 干运行模式: 跳过实际服务检查
...
[INFO]   干运行模式: 模拟测试 GET /admin/keys
[SUCCESS]   成功 (HTTP 200) - 响应时间: 67ms
```

### 示例3：自定义配置
```bash
./check-admin-performance.sh \
  --url http://192.168.1.100:8787 \
  --token my-secret-admin-token
```

## CI/CD集成

### 环境变量配置
在CI/CD流水线中配置环境变量：
```yaml
# GitHub Actions 示例
env:
  ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
  BASE_URL: http://localhost:8787
```

### 性能检查步骤
```yaml
steps:
  - name: 检查Admin API性能
    run: |
      chmod +x quota-proxy/check-admin-performance.sh
      ./quota-proxy/check-admin-performance.sh
```

### 干运行验证
```yaml
steps:
  - name: 验证性能检查脚本
    run: |
      ./quota-proxy/check-admin-performance.sh --dry-run
```

## 故障排除

### 常见问题

1. **服务未运行**
   ```
   [ERROR] 服务未运行或无法访问: http://127.0.0.1:8787/healthz
   ```
   解决方案：确保quota-proxy服务正在运行。

2. **缺少依赖**
   ```
   [ERROR] 缺少依赖: curl jq
   ```
   解决方案：安装缺少的命令：
   ```bash
   sudo apt-get install curl jq  # Ubuntu/Debian
   sudo yum install curl jq      # CentOS/RHEL
   ```

3. **权限被拒绝**
   ```
   bash: ./check-admin-performance.sh: Permission denied
   ```
   解决方案：添加执行权限：
   ```bash
   chmod +x check-admin-performance.sh
   ```

### 诊断命令

1. 检查服务状态：
   ```bash
   curl -f http://127.0.0.1:8787/healthz
   ```

2. 验证Admin令牌：
   ```bash
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://127.0.0.1:8787/admin/keys
   ```

3. 测试单个端点性能：
   ```bash
   time curl -H "Authorization: Bearer $ADMIN_TOKEN" \
             http://127.0.0.1:8787/healthz
   ```

## 最佳实践

### 1. 定期性能检查
建议定期运行性能检查，建立性能基线：
```bash
# 每日检查
0 2 * * * cd /opt/roc/quota-proxy && ./check-admin-performance.sh

# 每周报告
0 3 * * 1 cd /opt/roc/quota-proxy && ./check-admin-performance.sh >> /var/log/quota-proxy/performance.log
```

### 2. 性能监控
结合监控工具使用：
- 将响应时间指标导出到Prometheus
- 设置性能告警阈值
- 记录历史性能数据

### 3. 优化建议
根据性能评级采取相应措施：

**优秀 (<100ms)**
- 保持当前配置
- 定期监控

**良好 (100-300ms)**
- 检查数据库索引
- 优化查询语句
- 考虑添加缓存

**一般 (300-500ms)**
- 分析慢查询
- 优化API逻辑
- 考虑分页或限制数据量

**较慢 (>500ms)**
- 紧急性能优化
- 数据库调优
- 考虑水平扩展

## 脚本输出说明

### 成功输出
```
[SUCCESS] 成功 (HTTP 200) - 响应时间: 85ms
```

### 警告输出
```
[WARNING] 非成功状态码: HTTP 404 - 响应时间: 120ms
```

### 错误输出
```
[ERROR] 请求失败 - 响应时间: 5000ms
```

### 性能报告
```
[SUCCESS] 平均响应时间: 120ms (良好)
[SUCCESS] 成功测试数: 4/4
```

## 更新日志

### v1.1.0 (2026-02-11)
- 添加干运行模式支持
- 改进错误处理
- 添加性能评级系统
- 创建详细文档

### v1.0.0 (初始版本)
- 基础性能检查功能
- 支持关键端点测试
- 彩色输出和日志

## 支持与贡献

### 问题反馈
如遇问题，请提供：
1. 脚本版本和配置
2. 完整错误输出
3. 环境信息（OS、依赖版本）

### 功能建议
欢迎提出改进建议：
1. 新的性能测试端点
2. 额外的性能指标
3. 集成监控工具

### 贡献指南
1. Fork仓库
2. 创建功能分支
3. 提交更改
4. 创建Pull Request