# Admin API 状态检查指南

本文档介绍如何使用 `check-admin-api-status.sh` 脚本检查 quota-proxy 的 Admin API 状态。

## 脚本功能

`check-admin-api-status.sh` 脚本提供以下功能：

1. **检查健康端点** (`/healthz`)
2. **检查 Admin API 端点** (`/admin/keys`)
3. **检查 Usage API 端点** (`/admin/usage`)
4. **支持本地和远程环境检查**
5. **通过 SSH 隧道安全访问远程服务器**

## 使用方法

### 基本用法

```bash
# 设置 ADMIN_TOKEN 环境变量
export ADMIN_TOKEN="your-admin-token-here"

# 检查本地开发环境
./scripts/check-admin-api-status.sh --local

# 检查远程服务器环境
./scripts/check-admin-api-status.sh --remote

# 指定服务器 IP
./scripts/check-admin-api-status.sh --remote --server 192.168.1.100

# 指定 ADMIN_TOKEN
./scripts/check-admin-api-status.sh --remote --admin-token "my-secret-token"
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--local` | 检查本地开发环境 | 默认模式 |
| `--remote` | 检查远程服务器环境 | - |
| `--server IP` | 指定服务器 IP 地址 | `8.210.185.194` |
| `--admin-token TOKEN` | 指定 ADMIN_TOKEN | 从环境变量读取 |
| `--help` | 显示帮助信息 | - |

## 检查流程

脚本执行以下检查步骤：

1. **连接验证**：检查服务器 SSH 连接
2. **容器状态**：检查 quota-proxy 容器是否运行
3. **健康检查**：验证 `/healthz` 端点
4. **Admin API 检查**：验证 `/admin/keys` 端点（需要 ADMIN_TOKEN）
5. **Usage API 检查**：验证 `/admin/usage` 端点（需要 ADMIN_TOKEN）

## 输出示例

```
开始检查 quota-proxy admin API 状态
模式: remote
检查远程服务器: 8.210.185.194
检查服务器连接...
检查 quota-proxy 容器状态...
通过 SSH 隧道检查 Admin API...
检查 Admin API 端点: http://localhost:8787
========================================
1. 检查 /healthz:
   ✅ 健康检查通过
2. 检查 /admin/keys:
   ✅ Admin API 响应正常
   响应: {"keys":[...]}
3. 检查 /admin/usage:
   ✅ Usage API 响应正常
   响应: {"usage":[...]}
========================================
✅ Admin API 状态检查完成
```

## 故障排除

### 1. ADMIN_TOKEN 未设置

**错误信息**：
```
警告: ADMIN_TOKEN 未设置
请设置环境变量: export ADMIN_TOKEN='your-admin-token'
```

**解决方案**：
```bash
export ADMIN_TOKEN="your-actual-admin-token"
```

### 2. 服务器连接失败

**错误信息**：
```
❌ 无法连接到服务器: 8.210.185.194
```

**解决方案**：
- 检查服务器 IP 是否正确
- 检查 SSH 密钥配置
- 检查网络连接

### 3. quota-proxy 容器未运行

**错误信息**：
```
❌ quota-proxy 容器未运行
```

**解决方案**：
```bash
# 登录服务器启动容器
ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose up -d"
```

### 4. Admin API 无响应

**错误信息**：
```
❌ Admin API 无响应或认证失败
```

**解决方案**：
1. 确认 ADMIN_TOKEN 正确
2. 检查 quota-proxy 是否已启用 Admin API
3. 检查防火墙/安全组设置

## 集成到 CI/CD

可以将此脚本集成到 CI/CD 流程中，自动检查 Admin API 状态：

```yaml
# GitHub Actions 示例
name: Check Admin API
on: [push]

jobs:
  check-admin-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check Admin API
        run: |
          chmod +x ./scripts/check-admin-api-status.sh
          ./scripts/check-admin-api-status.sh --remote \
            --admin-token "${{ secrets.ADMIN_TOKEN }}"
        env:
          ADMIN_TOKEN: ${{ secrets.ADMIN_TOKEN }}
```

## 相关文档

- [quota-proxy Admin API 规范](../docs/quota-proxy-v1-admin-spec.md)
- [Admin API 测试指南](../docs/admin-api-testing.md)
- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)

## 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-02-09 | v1.0 | 初始版本，支持本地/远程 Admin API 状态检查 |