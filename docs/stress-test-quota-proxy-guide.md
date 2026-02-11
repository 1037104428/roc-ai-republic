# quota-proxy 压力测试指南

## 概述

本文档提供 quota-proxy 压力测试的详细指南，包括测试脚本使用、配置说明、结果分析和最佳实践。压力测试用于验证系统在高并发场景下的性能和稳定性。

## 快速开始

### 1. 基本压力测试

```bash
# 设置 Admin Token
export ADMIN_TOKEN="your_admin_token_here"

# 运行基本压力测试（默认：10并发，100请求）
./scripts/stress-test-quota-proxy.sh -H 8.210.185.194 -t "$ADMIN_TOKEN"
```

### 2. 自定义配置测试

```bash
# 20并发，200请求，60秒测试时长
./scripts/stress-test-quota-proxy.sh \
  -H 8.210.185.194 \
  -t "$ADMIN_TOKEN" \
  -c 20 \
  -r 200 \
  -d 60 \
  --verbose
```

### 3. 模拟运行（不实际发送请求）

```bash
# 验证脚本配置
./scripts/stress-test-quota-proxy.sh \
  -H 127.0.0.1 \
  -t "test-token" \
  --dry-run \
  --verbose
```

## 测试场景

压力测试脚本模拟以下三种请求类型：

### 1. 健康检查端点 (33%)
- 路径: `GET /healthz`
- 目的: 测试基础服务可用性
- 预期: 快速响应，高成功率

### 2. API 网关端点 (33%)
- 路径: `GET /v1/chat/completions`
- 目的: 测试核心业务功能
- 要求: 有效的试用密钥
- 预期: 正常授权检查，稳定响应

### 3. Admin API 端点 (33%，但仅10%的请求)
- 路径: `GET /admin/usage`
- 目的: 测试管理接口性能
- 要求: 有效的 Admin Token
- 预期: 安全验证，数据统计

## 配置参数

### 命令行参数

| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `--host` | `-H` | `127.0.0.1` | 服务器主机地址 |
| `--port` | `-p` | `8787` | 服务器端口 |
| `--token` | `-t` | (必需) | Admin Token |
| `--concurrent` | `-c` | `10` | 并发请求数 |
| `--requests` | `-r` | `100` | 总请求数 |
| `--duration` | `-d` | `30` | 测试持续时间（秒） |
| `--dry-run` | | `false` | 模拟运行，不发送实际请求 |
| `--verbose` | | `false` | 详细输出模式 |
| `--help` | `-h` | | 显示帮助信息 |

### 环境变量

```bash
# 通过环境变量配置
export HOST="8.210.185.194"
export PORT="8787"
export ADMIN_TOKEN="your_token"
export CONCURRENT="20"
export REQUESTS="500"
export TEST_DURATION="120"
./scripts/stress-test-quota-proxy.sh
```

## 性能标准

### 通过标准

1. **成功率**: ≥95%
2. **响应时间**: 平均 < 2秒
3. **错误率**: <5%
4. **资源使用**: 内存/CPU 无异常增长

### 警告阈值

1. **成功率**: 90-95% (需要优化)
2. **成功率**: <90% (不达标)
3. **请求速率**: <10 请求/秒 (性能较低)

## 结果分析

### 测试报告示例

```
quota-proxy 压力测试报告
=======================

测试时间: 2026-02-11 09:05:30 CST
服务器: 8.210.185.194:8787
测试配置:
  并发数: 10
  总请求数: 100
  测试时长: 30秒

测试结果:
  总请求数: 100
  成功请求: 98
  失败请求: 2
  成功率: 98.00%
  请求速率: 3.33 请求/秒
  测试时长: 30.12 秒

性能评估:
  ✅ 成功率达标 (≥95%)
  ⚠️  请求速率较低 (<10 请求/秒)

建议:
  1. 对于生产环境，建议进行更长时间的压力测试
  2. 监控数据库连接池使用情况
  3. 考虑增加缓存层提高性能
  4. 定期进行压力测试确保系统稳定性
```

### 关键指标解读

1. **成功率**: 反映系统稳定性
2. **请求速率**: 反映系统吞吐量
3. **并发处理能力**: 反映系统扩展性
4. **错误类型**: 帮助定位问题根源

## 故障排除

### 常见问题

#### 1. 服务器不可达
```bash
错误: 服务器不可达 (http://8.210.185.194:8787/healthz)
```
**解决方案**:
- 检查服务器是否运行: `ssh root@8.210.185.194 'docker compose ps'`
- 检查防火墙设置
- 验证网络连通性

#### 2. Admin Token 无效
```bash
错误: 无法生成测试密钥
```
**解决方案**:
- 验证 Admin Token: `curl -H "Authorization: Bearer $ADMIN_TOKEN" http://8.210.185.194:8787/admin/usage`
- 重新生成 Token
- 检查 Token 权限

#### 3. 成功率低
```bash
⚠ 警告: 成功率低于 95%
```
**解决方案**:
- 检查服务器日志: `ssh root@8.210.185.194 'docker compose logs quota-proxy'`
- 降低并发数重新测试
- 检查数据库性能

#### 4. 请求速率低
```bash
⚠ 注意: 请求速率较低 (<10 请求/秒)
```
**解决方案**:
- 优化数据库查询
- 增加服务器资源
- 启用缓存机制

### 调试技巧

1. **详细模式**: 使用 `--verbose` 查看详细进度
2. **逐步测试**: 先测试低并发，逐步增加
3. **日志分析**: 结合服务器日志分析错误原因
4. **资源监控**: 监控服务器 CPU、内存、网络使用情况

## 高级用法

### 1. 自动化测试流水线

```bash
#!/bin/bash
# 自动化压力测试脚本

set -euo pipefail

# 配置
SERVER_HOST="8.210.185.194"
ADMIN_TOKEN="${ADMIN_TOKEN}"

# 测试序列
declare -A test_scenarios=(
    ["low"]="5 50"
    ["medium"]="10 100"
    ["high"]="20 200"
    ["extreme"]="50 500"
)

# 运行所有测试场景
for scenario in "${!test_scenarios[@]}"; do
    read -r concurrent requests <<< "${test_scenarios[$scenario]}"
    
    echo "=== 运行 $scenario 场景测试 ==="
    echo "并发: $concurrent, 请求: $requests"
    
    ./scripts/stress-test-quota-proxy.sh \
        -H "$SERVER_HOST" \
        -t "$ADMIN_TOKEN" \
        -c "$concurrent" \
        -r "$requests" \
        --verbose
    
    echo "=== $scenario 场景测试完成 ==="
    echo
done
```

### 2. 持续集成集成

```yaml
# GitHub Actions 示例
name: Pressure Test

on:
  schedule:
    - cron: '0 2 * * *'  # 每天凌晨2点
  workflow_dispatch:

jobs:
  pressure-test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Run pressure test
        run: |
          chmod +x ./scripts/stress-test-quota-proxy.sh
          ./scripts/stress-test-quota-proxy.sh \
            -H "${{ secrets.QUOTA_PROXY_HOST }}" \
            -t "${{ secrets.ADMIN_TOKEN }}" \
            -c 10 \
            -r 100 \
            --verbose
          
      - name: Upload test report
        uses: actions/upload-artifact@v3
        with:
          name: pressure-test-report
          path: stress-test-report-*.txt
```

### 3. 监控集成

```bash
# 结合 Prometheus 监控
#!/bin/bash

# 运行压力测试
./scripts/stress-test-quota-proxy.sh -H 8.210.185.194 -t "$ADMIN_TOKEN" -c 20 -r 200

# 提取指标
success_rate=$(grep "成功率:" stress-test-report-*.txt | awk '{print $2}' | sed 's/%//')
rps=$(grep "请求速率:" stress-test-report-*.txt | awk '{print $2}')

# 推送到 Prometheus Pushgateway
cat << EOF | curl --data-binary @- http://localhost:9091/metrics/job/pressure_test
# TYPE pressure_test_success_rate gauge
pressure_test_success_rate $success_rate
# TYPE pressure_test_requests_per_second gauge
pressure_test_requests_per_second $rps
EOF
```

## 最佳实践

### 1. 测试策略

- **渐进测试**: 从低并发开始，逐步增加
- **多样化场景**: 混合不同类型的请求
- **长时间测试**: 发现内存泄漏和资源积累问题
- **峰值测试**: 模拟突发流量场景

### 2. 环境准备

- **生产镜像**: 使用与生产环境相同的 Docker 镜像
- **独立环境**: 避免影响线上服务
- **数据准备**: 准备足够的测试数据
- **监控就绪**: 确保监控系统正常运行

### 3. 结果分析

- **趋势分析**: 对比历史测试结果
- **瓶颈定位**: 识别系统瓶颈（CPU、内存、IO、网络）
- **优化验证**: 验证性能优化效果
- **容量规划**: 为容量规划提供数据支持

### 4. 安全考虑

- **测试隔离**: 使用独立的测试环境
- **数据安全**: 不包含真实用户数据
- **权限控制**: 使用测试专用的 Token
- **资源限制**: 避免耗尽系统资源

## 相关资源

### 脚本文件
- `scripts/stress-test-quota-proxy.sh` - 压力测试主脚本
- `scripts/check-admin-api-status.sh` - Admin API 状态检查
- `scripts/test-admin-api-basic.sh` - Admin API 基础测试

### 文档
- [Admin API 快速指南](./admin-api-quick-guide.md)
- [quota-proxy 部署指南](./deploy-quota-proxy-guide.md)
- [SQLite 版本部署指南](./deploy-quota-proxy-sqlite-guide.md)

### 监控工具
- Prometheus + Grafana - 性能监控
- ELK Stack - 日志分析
- Docker Stats - 容器监控

## 更新记录

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-02-11 | 1.0.0 | 初始版本，创建压力测试脚本和指南 |
| 2026-02-11 | 1.0.1 | 添加故障排除和最佳实践章节 |

## 支持与反馈

如有问题或建议，请：
1. 查看服务器日志: `docker compose logs quota-proxy`
2. 检查测试报告: `cat stress-test-report-*.txt`
3. 提交 Issue: [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)

---

**注意**: 压力测试可能会对系统造成较大负载，建议在非高峰时段进行，并确保有足够的系统资源。