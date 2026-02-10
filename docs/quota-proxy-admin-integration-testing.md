# quota-proxy 管理接口集成测试指南

## 概述

本文档提供 quota-proxy 核心管理接口（POST /admin/keys 和 GET /admin/usage）的集成测试指南。这些接口是优先级 A（quota-proxy）的核心功能，用于试用密钥管理和使用情况统计。

## 测试脚本

### 脚本位置
- `scripts/test-quota-proxy-admin-integration.sh`

### 功能特性
- 完整的端到端测试流程
- 支持多种运行模式（详细/安静/模拟）
- 自动清理测试数据
- 彩色输出和标准化退出码
- 灵活的配置选项

## 快速开始

### 1. 基本用法

```bash
# 设置管理员令牌
export ADMIN_TOKEN="69737790cbc6c9dddcec99b3909cb91dfc6988d995558528837ac9d538d3d1a6"

# 运行测试
./scripts/test-quota-proxy-admin-integration.sh -t "$ADMIN_TOKEN"
```

### 2. 远程服务器测试

```bash
# 测试远程服务器
./scripts/test-quota-proxy-admin-integration.sh \
  -H 8.210.185.194 \
  -p 8787 \
  -t "$ADMIN_TOKEN" \
  -v
```

### 3. 模拟运行

```bash
# 模拟运行，不实际发送请求
./scripts/test-quota-proxy-admin-integration.sh \
  -t "dummy-token" \
  -d \
  -v
```

## 测试流程

脚本执行以下测试步骤：

### 1. 健康检查
- 检查 `/healthz` 端点
- 验证服务是否正常运行

### 2. POST /admin/keys 测试
- 创建新的试用密钥
- 验证响应格式和状态码
- 提取生成的密钥用于后续测试

### 3. GET /admin/keys 测试
- 获取所有密钥列表
- 验证响应格式和状态码
- 检查返回的密钥数量

### 4. GET /admin/usage 测试
- 获取所有密钥的使用情况统计
- 验证响应格式和状态码

### 5. GET /admin/usage?key=... 测试
- 获取指定密钥的使用情况
- 验证带参数的查询功能

### 6. 数据清理
- 删除测试创建的密钥
- 保持数据库整洁

## 配置选项

### 命令行参数

| 参数 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--host` | `-H` | quota-proxy 主机地址 | `127.0.0.1` |
| `--port` | `-p` | quota-proxy 端口 | `8787` |
| `--token` | `-t` | 管理员令牌（必需） | - |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | `-d` | 模拟运行模式 | `false` |
| `--help` | `-h` | 显示帮助信息 | - |
| `--version` | - | 显示版本信息 | - |

### 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `QUOTA_PROXY_HOST` | quota-proxy 主机地址 | `127.0.0.1` |
| `QUOTA_PROXY_PORT` | quota-proxy 端口 | `8787` |
| `ADMIN_TOKEN` | 管理员令牌 | - |
| `VERBOSE` | 详细输出模式 | `false` |
| `DRY_RUN` | 模拟运行模式 | `false` |

## 使用示例

### 示例 1：本地测试

```bash
# 设置环境变量
export ADMIN_TOKEN="your-admin-token-here"

# 运行测试
./scripts/test-quota-proxy-admin-integration.sh -v

# 输出示例
[INFO] 开始 quota-proxy 管理接口集成测试
[INFO] 检查 quota-proxy 服务健康状态...
[SUCCESS] 服务健康状态正常
[INFO] 测试 POST /admin/keys 接口...
[SUCCESS] 成功创建试用密钥
[INFO] 测试 GET /admin/keys 接口...
[SUCCESS] 成功获取密钥列表
[INFO] 测试 GET /admin/usage 接口...
[SUCCESS] 成功获取使用情况统计
[INFO] 清理测试数据: sk-1770736577740-test-key
[SUCCESS] 成功删除测试密钥
[SUCCESS] 🎉 所有测试通过！
```

### 示例 2：CI/CD 集成

```bash
#!/bin/bash
# CI/CD 测试脚本

set -e

# 配置
QUOTA_PROXY_HOST="8.210.185.194"
QUOTA_PROXY_PORT="8787"
ADMIN_TOKEN="$SECRET_ADMIN_TOKEN"

# 运行测试
if ./scripts/test-quota-proxy-admin-integration.sh \
  -H "$QUOTA_PROXY_HOST" \
  -p "$QUOTA_PROXY_PORT" \
  -t "$ADMIN_TOKEN"; then
  echo "✅ quota-proxy 管理接口测试通过"
  exit 0
else
  echo "❌ quota-proxy 管理接口测试失败"
  exit 1
fi
```

### 示例 3：定时监控

```bash
#!/bin/bash
# 定时监控脚本

# 配置
ADMIN_TOKEN="69737790cbc6c9dddcec99b3909cb91dfc6988d995558528837ac9d538d3d1a6"
LOG_FILE="/var/log/quota-proxy-test.log"

# 运行测试并记录日志
echo "[$(date)] 开始 quota-proxy 管理接口测试" >> "$LOG_FILE"
if ./scripts/test-quota-proxy-admin-integration.sh -t "$ADMIN_TOKEN" >> "$LOG_FILE" 2>&1; then
  echo "[$(date)] ✅ 测试通过" >> "$LOG_FILE"
else
  echo "[$(date)] ❌ 测试失败" >> "$LOG_FILE"
  # 发送告警
  echo "quota-proxy 管理接口测试失败，请检查服务状态" | mail -s "quota-proxy 告警" admin@example.com
fi
```

## 退出码

| 退出码 | 描述 |
|--------|------|
| 0 | 所有测试通过 |
| 1 | 测试失败 |
| 2 | 参数错误 |
| 3 | 网络连接失败 |

## 故障排除

### 常见问题

#### 1. 连接失败
```
[ERROR] 无法连接到服务: http://127.0.0.1:8787/healthz
```
**解决方案：**
- 检查 quota-proxy 服务是否运行：`docker compose ps`
- 检查端口是否正确：`netstat -tlnp | grep 8787`
- 检查防火墙设置

#### 2. 令牌无效
```
[ERROR] POST /admin/keys 返回非200状态码: 401
```
**解决方案：**
- 检查 ADMIN_TOKEN 是否正确
- 查看服务器上的 .env 文件：`cat /opt/roc/quota-proxy/.env`
- 重新生成令牌并更新配置

#### 3. 依赖缺失
```
[ERROR] 缺少依赖: curl jq
```
**解决方案：**
```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

# macOS
brew install curl jq
```

### 调试技巧

1. **启用详细输出**
   ```bash
   ./scripts/test-quota-proxy-admin-integration.sh -t "$ADMIN_TOKEN" -v
   ```

2. **手动测试接口**
   ```bash
   # 健康检查
   curl -f http://127.0.0.1:8787/healthz
   
   # 创建密钥
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -X POST \
        -d '{"label":"test","totalQuota":1000}' \
        http://127.0.0.1:8787/admin/keys
   
   # 获取使用情况
   curl -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://127.0.0.1:8787/admin/usage
   ```

3. **查看服务日志**
   ```bash
   # 查看 Docker 容器日志
   docker compose logs quota-proxy
   
   # 实时查看日志
   docker compose logs -f quota-proxy
   ```

## 最佳实践

### 1. 安全考虑
- 不要在脚本中硬编码管理员令牌
- 使用环境变量或密钥管理服务
- 定期轮换管理员令牌

### 2. 测试策略
- 在部署前运行集成测试
- 定期运行监控测试
- 记录测试结果用于审计

### 3. 性能考虑
- 测试脚本设计为轻量级
- 自动清理测试数据
- 支持并行测试

### 4. 可维护性
- 清晰的错误消息
- 标准化的退出码
- 完整的文档

## 相关资源

### 文档
- [quota-proxy API 使用示例](../docs/quota-proxy-api-usage-examples.md)
- [quota-proxy 快速开始指南](../docs/quota-proxy-quick-start.md)
- [quota-proxy 工具链概览](../docs/quota-proxy-toolchain-overview.md)

### 脚本
- `scripts/test-post-admin-keys.sh` - POST /admin/keys 专项测试
- `scripts/test-quota-proxy-admin-keys-usage.sh` - 管理接口测试
- `scripts/check-quota-proxy-health.sh` - 健康检查

### API 参考
- `POST /admin/keys` - 创建试用密钥
- `GET /admin/keys` - 获取密钥列表
- `GET /admin/usage` - 获取使用情况统计
- `DELETE /admin/keys/:key` - 删除密钥

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持完整的集成测试流程
- 包含健康检查、接口测试、数据清理
- 支持详细输出和模拟运行模式
- 提供完整的文档和示例

## 贡献指南

欢迎贡献改进和 bug 修复：

1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

中华AI共和国项目 - 开源许可证