# Quota-Proxy 使用统计脚本

## 概述

`show-quota-usage.sh` 脚本用于查询 quota-proxy API 网关的使用统计信息，包括：
- API 调用次数统计
- 活跃密钥及其剩余配额
- 服务健康状态

## 快速开始

### 1. 设置管理员令牌

```bash
# 设置环境变量
export ADMIN_TOKEN="your_admin_token_here"

# 或者直接传递参数
./scripts/show-quota-usage.sh --admin-token "your_admin_token_here"
```

### 2. 运行脚本

```bash
# 使用默认服务器 (8.210.185.194)
./scripts/show-quota-usage.sh

# 指定服务器
./scripts/show-quota-usage.sh --server "192.168.1.100" --admin-token "your_token"
```

## 输出示例

```
正在查询 quota-proxy 使用统计...
服务器: 8.210.185.194
端口: 8787

=== API 使用统计 ===
{
  "total_requests": 1542,
  "successful_requests": 1498,
  "failed_requests": 44,
  "last_24h": 312
}
查询成功

=== 活跃密钥统计 ===
trial_key_abc123: 950
premium_key_xyz789: unlimited
查询完成

=== 健康状态 ===
true
服务健康
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--server` | 服务器 IP 地址 | `8.210.185.194` |
| `--admin-token` | 管理员令牌 | 从 `ADMIN_TOKEN` 环境变量读取 |
| `--help` | 显示帮助信息 | - |

## 环境变量

- `ADMIN_TOKEN`: 管理员令牌，用于认证 API 请求

## 使用场景

### 1. 日常监控

```bash
# 每日检查使用情况
./scripts/show-quota-usage.sh | tee /tmp/quota-usage-$(date +%Y%m%d).log
```

### 2. 集成到监控系统

```bash
# 检查服务健康状态
if ./scripts/show-quota-usage.sh | grep -q "服务健康"; then
    echo "✅ Quota-proxy 运行正常"
else
    echo "❌ Quota-proxy 异常"
fi
```

### 3. 密钥管理

```bash
# 查看所有活跃密钥及其剩余配额
./scripts/show-quota-usage.sh | grep -A 20 "活跃密钥统计"
```

## 注意事项

1. **安全性**: 管理员令牌具有完全访问权限，请妥善保管
2. **网络要求**: 脚本需要能够访问 quota-proxy 服务器
3. **依赖**: 需要 `curl` 和 `jq` 命令
4. **错误处理**: 如果查询失败，脚本会显示错误信息并退出

## 故障排除

### 常见问题

1. **权限被拒绝**
   ```
   错误: 需要管理员令牌
   ```
   解决方案：设置 `ADMIN_TOKEN` 环境变量或使用 `--admin-token` 参数

2. **连接超时**
   ```
   查询失败或暂无数据
   ```
   解决方案：检查网络连接和服务器状态

3. **JSON 解析错误**
   ```
   parse error: Invalid numeric literal at line 1, column 10
   ```
   解决方案：检查 API 响应格式，确保 quota-proxy 服务正常运行

### 调试模式

```bash
# 显示详细请求信息
set -x
./scripts/show-quota-usage.sh
set +x
```

## 相关脚本

- `test-admin-api.sh`: 测试管理员 API 端点
- `check-quota-proxy-response-time.sh`: 检查响应时间
- `ssh-healthz-quota-proxy.sh`: 远程健康检查

## 更新日志

- **2026-02-09**: 初始版本发布，支持基本使用统计查询