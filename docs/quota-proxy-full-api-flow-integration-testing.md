# Quota-Proxy 完整 API 流程集成测试指南

**创建时间**: 2026-02-10 23:21:00 CST  
**文档版本**: v1.0  
**测试脚本**: `test-quota-proxy-full-api-flow.sh`  
**适用场景**: 生产环境部署验证、CI/CD 集成测试、端到端功能验证

## 概述

本文档提供 quota-proxy 完整 API 流程的集成测试指南，涵盖从健康检查、试用密钥创建、API 网关使用到使用统计查询的完整端到端测试流程。该测试脚本旨在验证 quota-proxy 在生产环境中的完整功能链。

## 测试目标

验证 quota-proxy 的以下核心功能：

1. **健康检查** - 服务可用性验证
2. **Admin API 状态** - 管理接口可访问性
3. **试用密钥创建** - 密钥生成功能
4. **API 网关使用** - 实际 API 调用
5. **使用统计查询** - 配额监控功能
6. **密钥管理** - 密钥列表查看
7. **数据清理** - 测试数据清理

## 测试脚本

### 脚本位置
```
scripts/test-quota-proxy-full-api-flow.sh
```

### 脚本特性
- **完整流程测试**: 覆盖从密钥创建到统计查询的完整流程
- **灵活配置**: 支持环境变量和命令行参数
- **多种运行模式**: 详细模式、安静模式、模拟运行
- **彩色输出**: 清晰的测试结果展示
- **标准化退出码**: 明确的测试状态指示
- **自动清理**: 测试完成后自动清理测试数据

### 脚本版本
```
v2026.02.10.01
```

## 快速开始

### 1. 基本用法
```bash
# 使用默认配置（本地测试）
./scripts/test-quota-proxy-full-api-flow.sh -t "your-admin-token"

# 远程服务器测试
./scripts/test-quota-proxy-full-api-flow.sh \
  -h 8.210.185.194 \
  -p 8787 \
  -t "your-admin-token" \
  -v
```

### 2. 环境变量方式
```bash
# 设置环境变量
export QUOTA_PROXY_HOST="8.210.185.194"
export QUOTA_PROXY_PORT="8787"
export ADMIN_TOKEN="your-admin-token"

# 运行测试
./scripts/test-quota-proxy-full-api-flow.sh -v
```

### 3. 模拟运行（不实际发送请求）
```bash
# 模拟运行，检查脚本逻辑
./scripts/test-quota-proxy-full-api-flow.sh -t "dummy-token" -d -v
```

## 详细使用说明

### 命令行参数

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--host` | `-h` | quota-proxy 主机地址 | `127.0.0.1` |
| `--port` | `-p` | quota-proxy 端口 | `8787` |
| `--token` | `-t` | Admin 令牌（必须） | 无 |
| `--dry-run` | `-d` | 模拟运行，不实际发送请求 | 否 |
| `--verbose` | `-v` | 详细输出模式 | 否 |
| `--quiet` | `-q` | 安静模式，只显示结果 | 否 |
| `--help` | 无 | 显示帮助信息 | 无 |
| `--version` | 无 | 显示版本信息 | 无 |

### 环境变量

| 环境变量 | 说明 | 示例 |
|----------|------|------|
| `QUOTA_PROXY_HOST` | 覆盖主机地址 | `export QUOTA_PROXY_HOST="8.210.185.194"` |
| `QUOTA_PROXY_PORT` | 覆盖端口 | `export QUOTA_PROXY_PORT="8787"` |
| `ADMIN_TOKEN` | 覆盖 Admin 令牌 | `export ADMIN_TOKEN="your-token"` |

### 退出码

| 退出码 | 说明 | 处理建议 |
|--------|------|----------|
| `0` | 所有测试通过 | 正常完成 |
| `1` | 参数错误或配置问题 | 检查参数和配置 |
| `2` | 网络连接失败 | 检查网络和服务状态 |
| `3` | API 测试失败 | 检查 quota-proxy 服务状态 |
| `4` | 数据验证失败 | 检查数据库和 API 逻辑 |

## 测试流程详解

### 1. 健康检查
- **测试目标**: 验证 quota-proxy 服务是否可用
- **测试端点**: `GET /healthz`
- **预期响应**: HTTP 200 OK
- **失败处理**: 如果健康检查失败，停止后续测试

### 2. Admin API 状态检查
- **测试目标**: 验证 Admin API 接口可访问性
- **测试端点**: `GET /admin/usage`
- **请求头**: `Authorization: Bearer {ADMIN_TOKEN}`
- **预期响应**: HTTP 200 OK 带 JSON 数据
- **验证内容**: 响应状态码和数据格式

### 3. 创建试用密钥
- **测试目标**: 验证试用密钥创建功能
- **测试端点**: `POST /admin/keys`
- **请求体**: `{"label": "集成测试-时间戳"}`
- **预期响应**: HTTP 201 Created
- **验证内容**: 响应包含有效的试用密钥

### 4. 使用 API 网关
- **测试目标**: 验证 API 网关功能
- **测试端点**: `GET /api/test` 和 `GET /api/test?param=integration`
- **请求头**: `X-API-Key: {TRIAL_KEY}`
- **预期响应**: HTTP 200 OK
- **验证内容**: 基础请求和带参数请求都能正常响应

### 5. 检查使用统计
- **测试目标**: 验证使用统计功能
- **测试端点**: `GET /admin/usage?key={TRIAL_KEY}`
- **预期响应**: HTTP 200 OK
- **验证内容**: 响应包含使用次数统计，且次数 ≥ 2（两次 API 调用）

### 6. 列出所有密钥
- **测试目标**: 验证密钥列表功能
- **测试端点**: `GET /admin/keys`
- **预期响应**: HTTP 200 OK
- **验证内容**: 响应包含密钥列表，测试密钥在列表中

### 7. 清理测试数据
- **测试目标**: 清理测试创建的密钥
- **测试端点**: `DELETE /admin/keys/{TRIAL_KEY}`
- **预期响应**: HTTP 200 OK 或 204 No Content
- **验证内容**: 测试密钥被成功删除

## 实际使用场景

### 场景 1: 生产环境部署验证
```bash
# 在新服务器部署后验证完整功能
ADMIN_TOKEN="$(cat /opt/roc/quota-proxy/.env | grep ADMIN_TOKEN | cut -d= -f2)"
./scripts/test-quota-proxy-full-api-flow.sh \
  -h 8.210.185.194 \
  -p 8787 \
  -t "$ADMIN_TOKEN" \
  -v
```

### 场景 2: CI/CD 流水线集成
```yaml
# GitHub Actions 示例
jobs:
  quota-proxy-integration-test:
    runs-on: ubuntu-latest
    steps:
      - name: 运行完整 API 流程测试
        run: |
          chmod +x ./scripts/test-quota-proxy-full-api-flow.sh
          ./scripts/test-quota-proxy-full-api-flow.sh \
            -h ${{ secrets.QUOTA_PROXY_HOST }} \
            -p ${{ secrets.QUOTA_PROXY_PORT }} \
            -t ${{ secrets.ADMIN_TOKEN }} \
            -q
```

### 场景 3: 日常运维检查
```bash
# 每日健康检查脚本
#!/bin/bash
LOG_FILE="/var/log/quota-proxy-integration-test.log"
ADMIN_TOKEN="$(cat /opt/roc/quota-proxy/.env | grep ADMIN_TOKEN | cut -d= -f2)"

echo "=== 开始 quota-proxy 集成测试 $(date) ===" >> "$LOG_FILE"
./scripts/test-quota-proxy-full-api-flow.sh \
  -h 127.0.0.1 \
  -p 8787 \
  -t "$ADMIN_TOKEN" \
  -q >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "测试通过" >> "$LOG_FILE"
else
    echo "测试失败，退出码: $EXIT_CODE" >> "$LOG_FILE"
    # 发送告警
    echo "quota-proxy 集成测试失败" | mail -s "quota-proxy 告警" admin@example.com
fi
echo "=== 结束测试 $(date) ===" >> "$LOG_FILE"
```

### 场景 4: 故障排查
```bash
# 详细模式排查问题
./scripts/test-quota-proxy-full-api-flow.sh \
  -h 8.210.185.194 \
  -p 8787 \
  -t "your-token" \
  -v

# 如果失败，检查具体步骤
# 可以单独运行某个测试函数进行调试
```

## 最佳实践

### 1. 安全考虑
- **令牌管理**: 不要将 Admin 令牌硬编码在脚本中
- **环境变量**: 使用环境变量或密钥管理服务
- **访问控制**: 确保测试环境与实际生产环境隔离
- **日志脱敏**: 避免在日志中记录完整的令牌信息

### 2. 性能优化
- **并行测试**: 对于大规模测试，考虑并行执行多个测试实例
- **资源监控**: 测试期间监控服务器资源使用情况
- **超时设置**: 根据网络状况调整 curl 超时时间
- **结果缓存**: 对于重复测试，考虑缓存部分结果

### 3. 维护建议
- **版本控制**: 保持测试脚本与 quota-proxy 版本同步
- **定期更新**: 定期更新测试用例以覆盖新功能
- **文档同步**: 测试脚本更新时同步更新本文档
- **反馈循环**: 将测试失败信息反馈给开发团队

## 故障排除

### 常见问题

#### 问题 1: 健康检查失败
```
[ERROR] 健康检查失败: http://8.210.185.194:8787/healthz
```
**可能原因**:
- quota-proxy 服务未运行
- 防火墙阻止了端口访问
- 网络连接问题

**解决方案**:
1. 检查服务状态: `ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose ps'`
2. 检查端口监听: `ssh root@8.210.185.194 'netstat -tlnp | grep 8787'`
3. 检查防火墙: `ssh root@8.210.185.194 'iptables -L -n'`

#### 问题 2: Admin API 认证失败
```
[ERROR] Admin API 状态检查失败: HTTP 401
```
**可能原因**:
- Admin 令牌错误或过期
- 令牌格式不正确
- 认证中间件配置问题

**解决方案**:
1. 验证令牌: `echo "当前令牌: ${ADMIN_TOKEN:0:8}..."`
2. 检查 .env 文件: `ssh root@8.210.185.194 'cat /opt/roc/quota-proxy/.env | grep ADMIN_TOKEN'`
3. 重新生成令牌: 参考 quota-proxy 部署文档

#### 问题 3: 试用密钥创建失败
```
[ERROR] 创建试用密钥失败: HTTP 400
```
**可能原因**:
- 请求体格式错误
- 数据库连接问题
- 标签字段验证失败

**解决方案**:
1. 检查请求体格式: 确保 JSON 格式正确
2. 检查数据库状态: `ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && sqlite3 /data/quota.db ".tables"'`
3. 简化标签: 使用简单的英文字符标签

#### 问题 4: 使用统计未更新
```
[WARNING] 使用统计可能未正确更新: 0 次
```
**可能原因**:
- 统计更新延迟
- 数据库事务未提交
- API 调用未计入统计

**解决方案**:
1. 增加等待时间: 在检查统计前增加 `sleep` 时间
2. 检查统计逻辑: 验证 quota-proxy 的统计更新逻辑
3. 手动验证: 使用单独的 curl 命令验证统计功能

### 调试技巧

#### 启用详细输出
```bash
# 启用详细模式查看所有请求和响应
./scripts/test-quota-proxy-full-api-flow.sh -t "your-token" -v
```

#### 分步调试
```bash
# 只运行特定测试步骤
source ./scripts/test-quota-proxy-full-api-flow.sh
parse_args -t "your-token"
check_config
health_check  # 单独测试健康检查
```

#### 网络调试
```bash
# 使用 curl 手动测试
curl -v http://8.210.185.194:8787/healthz
curl -v -H "Authorization: Bearer your-token" http://8.210.185.194:8787/admin/usage
```

## 相关文档

- [quota-proxy 快速开始指南](./quota-proxy-quick-start.md)
- [quota-proxy API 使用示例](./quota-proxy-api-usage-examples.md)
- [quota-proxy 验证命令速查表](./quota-proxy-validation-cheat-sheet.md)
- [quota-proxy 管理接口集成测试](./quota-proxy-admin-integration-testing.md)
- [quota-proxy 部署验证指南](./quota-proxy-deployment-verification.md)

## 更新记录

| 日期 | 版本 | 更新内容 | 负责人 |
|------|------|----------|--------|
| 2026-02-10 | v1.0 | 初始版本，创建完整 API 流程集成测试脚本和文档 | 阿爪推进循环 |

## 总结

`test-quota-proxy-full-api-flow.sh` 脚本提供了一个完整的端到端测试解决方案，能够验证 quota-proxy 在生产环境中的完整功能链。通过定期运行此测试，可以确保服务的可靠性和功能的完整性。

建议将此测试集成到 CI/CD 流水线中，作为部署验证的关键步骤，确保每次部署都能满足功能要求。