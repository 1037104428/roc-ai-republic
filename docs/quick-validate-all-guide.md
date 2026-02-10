# quick-validate-all.sh 快速验证指南

## 概述

`quick-validate-all.sh` 是一个一键式快速验证脚本，用于验证 quota-proxy 的所有核心功能。它提供了一个统一的入口，可以快速检查服务的健康状况、管理界面、API接口和网关功能。

## 功能特点

- **一键验证**: 单个命令验证所有核心功能
- **灵活配置**: 支持命令行参数和环境变量配置
- **多种模式**: 支持详细输出模式和模拟运行模式
- **彩色输出**: 提供直观的彩色输出，便于识别结果
- **标准化退出码**: 明确的退出码表示不同的验证结果

## 验证项目

脚本验证以下核心功能：

1. **基础健康检查** - `/healthz` 接口
2. **管理界面访问** - `/admin/` HTML 界面
3. **管理接口验证** - `/admin/keys` 密钥列表获取
4. **试用密钥创建** - `POST /admin/keys` 创建新密钥
5. **API网关验证** - `/api/*` 接口访问控制
6. **使用情况统计** - `/admin/usage` 使用统计获取

## 使用方法

### 基本用法

```bash
# 本地验证（默认配置）
./scripts/quick-validate-all.sh

# 远程服务器验证
./scripts/quick-validate-all.sh -H 8.210.185.194 -t "your-admin-token"

# 详细输出模式
./scripts/quick-validate-all.sh -v

# 模拟运行（不实际执行）
./scripts/quick-validate-all.sh -d
```

### 环境变量配置

```bash
# 使用环境变量配置
export HOST="8.210.185.194"
export ADMIN_TOKEN="your-secret-token"
export VERBOSE=true
./scripts/quick-validate-all.sh
```

### 参数说明

| 参数 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--host` | `-H` | 主机地址 | `127.0.0.1` |
| `--port` | `-p` | 端口号 | `8787` |
| `--token` | `-t` | 管理员令牌 | `dummy-token` |
| `--verbose` | `-v` | 详细输出模式 | `false` |
| `--dry-run` | `-d` | 模拟运行模式 | `false` |
| `--no-color` | - | 禁用彩色输出 | - |

## 实际使用场景

### 场景1：日常运维检查

```bash
# 快速检查服务状态
./scripts/quick-validate-all.sh -H 8.210.185.194 -t "$ADMIN_TOKEN"
```

### 场景2：部署后验证

```bash
# 部署后完整验证
export HOST="new-server.example.com"
export ADMIN_TOKEN="$(cat /path/to/token)"
export VERBOSE=true
./scripts/quick-validate-all.sh
```

### 场景3：CI/CD 集成

```bash
# 在CI/CD流水线中使用
if ./scripts/quick-validate-all.sh -H "$DEPLOY_HOST" -t "$CI_ADMIN_TOKEN"; then
    echo "✅ 服务验证通过"
else
    echo "❌ 服务验证失败"
    exit 1
fi
```

## 输出示例

### 正常输出

```
=== 快速验证配置 ===
主机: 8.210.185.194
端口: 8787
令牌: dummy-to...
详细模式: true
模拟运行: false
===================

=== 开始快速验证 ===

--- 基础健康检查 ---
[验证] 健康检查接口
命令: curl -fsS http://8.210.185.194:8787/healthz
[通过] 健康检查接口

--- 管理界面验证 ---
[验证] 管理界面HTML访问
命令: curl -fsS http://8.210.185.194:8787/admin/ | grep -q '<!DOCTYPE html>'
[通过] 管理界面HTML访问

=== 验证结果汇总 ===
总测试数: 6
通过数: 6
失败数: 0

✅ 所有验证通过！
```

### 失败输出

```
=== 验证结果汇总 ===
总测试数: 6
通过数: 4
失败数: 2

❌ 有 2 个验证失败
```

## 退出码说明

| 退出码 | 说明 |
|--------|------|
| 0 | 所有验证通过 |
| 1 | 参数错误 |
| 2 | 基础健康检查失败 |
| 3 | 管理接口验证失败 |
| 4 | API网关验证失败 |
| 5 | 集成测试失败 |

## 故障排除

### 常见问题

1. **连接超时**
   ```bash
   # 检查网络连接
   ping 8.210.185.194
   
   # 检查端口访问
   nc -zv 8.210.185.194 8787
   ```

2. **令牌错误**
   ```bash
   # 确认令牌正确
   echo "令牌: ${ADMIN_TOKEN}"
   
   # 测试令牌有效性
   curl -H "Authorization: Bearer $ADMIN_TOKEN" http://8.210.185.194:8787/admin/keys
   ```

3. **服务未运行**
   ```bash
   # 检查Docker容器状态
   ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose ps"
   ```

### 调试模式

```bash
# 启用详细输出
./scripts/quick-validate-all.sh -v

# 结合set -x调试
bash -x ./scripts/quick-validate-all.sh -v
```

## 与其他脚本的关系

`quick-validate-all.sh` 是其他验证脚本的简化汇总版本：

| 脚本 | 功能 | 关系 |
|------|------|------|
| `quick-validate-all.sh` | 快速一键验证 | 本脚本 |
| `test-quota-proxy-admin-integration.sh` | 详细管理接口测试 | 更详细的测试 |
| `verify-trial-key-manual-process.sh` | 手动发放流程验证 | 专门的流程验证 |
| `test-quota-proxy-full-api-flow.sh` | 完整API流程测试 | 端到端测试 |

## 最佳实践

1. **定期验证**: 建议每天至少运行一次快速验证
2. **变更后验证**: 每次配置变更后运行验证
3. **监控集成**: 将验证脚本集成到监控系统中
4. **日志记录**: 保存验证结果到日志文件
5. **告警设置**: 验证失败时发送告警通知

## 更新记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0.0 | 2026-02-10 | 初始版本，提供基本验证功能 |
| - | - | 支持命令行参数和环境变量配置 |
| - | - | 提供彩色输出和标准化退出码 |

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment-guide.md)
- [管理接口测试文档](../docs/quota-proxy-admin-interfaces-testing.md)
- [完整API流程测试文档](../docs/quota-proxy-full-api-flow-integration-testing.md)
- [验证命令速查表](../docs/quota-proxy-validation-cheat-sheet.md)