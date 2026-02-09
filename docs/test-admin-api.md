# 管理员 API 测试脚本

## 概述

`test-admin-api.sh` 是一个用于测试 quota-proxy 管理员 API 端点的脚本。它验证以下功能：

1. **健康检查** (`GET /healthz`) - 基础服务可用性
2. **生成试用密钥** (`POST /admin/keys`) - 管理员创建试用密钥
3. **查看使用情况** (`GET /admin/usage`) - 监控 API 使用统计
4. **试用密钥验证** - 测试生成的密钥是否可用

## 快速开始

### 基本用法

```bash
# 使用默认服务器和令牌
./scripts/test-admin-api.sh

# 指定服务器
./scripts/test-admin-api.sh --server 8.210.185.194

# 指定管理员令牌
QUOTA_PROXY_ADMIN_TOKEN="your_admin_token_here" ./scripts/test-admin-api.sh
# 或
./scripts/test-admin-api.sh --token "your_admin_token_here"
```

### 查看帮助

```bash
./scripts/test-admin-api.sh --help
```

## 测试场景

### 1. 开发环境测试

```bash
# 本地开发环境（如果 quota-proxy 在本地运行）
./scripts/test-admin-api.sh --server 127.0.0.1
```

### 2. 生产环境验证

```bash
# 生产服务器验证（需要通过SSH隧道）
ssh -L 8787:127.0.0.1:8787 root@clawdrepublic.cn
# 然后在另一个终端中运行：
./scripts/test-admin-api.sh --server 127.0.0.1

# 或者使用环境变量设置令牌
export QUOTA_PROXY_ADMIN_TOKEN="production_admin_token"
./scripts/test-admin-api.sh --server 127.0.0.1
```

### 3. CI/CD 集成

```bash
# 在 CI 流水线中运行
if ./scripts/test-admin-api.sh --server $SERVER_IP; then
    echo "管理员 API 测试通过"
else
    echo "管理员 API 测试失败"
    exit 1
fi
```

## 预期输出

成功运行的输出示例：

```
=== 测试 quota-proxy 管理员 API ===
服务器: 8.210.185.194
API地址: http://8.210.185.194:8787
管理员令牌: test_admin_...

1. 测试健康检查端点 /healthz:
   ✅ 健康检查通过

2. 测试生成试用密钥 /admin/keys:
   ✅ 试用密钥生成成功
   密钥: trial_abc123def456...

3. 测试查看使用情况 /admin/usage:
   ✅ 使用情况查询成功
   响应摘要:
   总请求数: 150
   活跃密钥数: 5
   总用户数: 12

4. 测试试用密钥使用:
   ✅ 试用密钥可用

=== 测试完成 ===
注意: 如果管理员API端点尚未实现，这些测试会显示警告而非错误。
这是预期的，因为API正在开发中。脚本主要用于验证API端点的基础连通性。
```

## 安全说明

### 访问控制

quota-proxy 的管理员 API 设计为**内部访问**，默认只绑定在 `127.0.0.1`。这是出于安全考虑：

1. **外部访问**：需要通过 SSH 端口转发
   ```bash
   ssh -L 8787:127.0.0.1:8787 root@服务器IP
   ```
2. **生产环境**：建议通过 VPN 或内部网络访问
3. **开发环境**：可以临时修改 Docker 配置暴露端口（不推荐生产）

### 错误处理

#### 常见错误

1. **连接失败** - 服务器不可达或端口未开放
   - 检查是否需要 SSH 隧道
   - 确认防火墙规则
2. **认证失败** - 管理员令牌无效或缺失
3. **API 未实现** - 端点尚未开发完成（显示警告）

### 故障排查

```bash
# 1. 检查服务器连通性
ping 8.210.185.194
curl -v http://8.210.185.194:8787/healthz

# 2. 检查管理员令牌
echo "管理员令牌: ${QUOTA_PROXY_ADMIN_TOKEN}"

# 3. 手动测试 API
curl -H "Authorization: Bearer your_token" http://8.210.185.194:8787/admin/usage
```

## 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| `QUOTA_PROXY_ADMIN_TOKEN` | `test_admin_token_123` | 管理员认证令牌 |

## 与现有脚本集成

### 在验证流程中使用

```bash
# 在完整的验证流程中包含管理员 API 测试
./scripts/verify-quota-proxy-full.sh
```

### 监控脚本集成

```bash
# 在状态监控中包含管理员 API 状态
./scripts/status-monitor.sh --include-admin-api
```

## 开发说明

### API 端点规范

脚本测试的 API 端点遵循以下规范：

1. **`GET /healthz`** - 返回 `{"ok":true}`
2. **`POST /admin/keys`** - 需要 Bearer 令牌，接受 JSON 参数：
   ```json
   {
     "name": "用户名",
     "quota": 100,
     "expiry_hours": 24
   }
   ```
   返回：
   ```json
   {
     "key": "trial_abc123def456",
     "name": "用户名",
     "quota": 100,
     "expires_at": "2024-01-01T00:00:00Z"
   }
   ```
3. **`GET /admin/usage`** - 需要 Bearer 令牌，返回使用统计

### 扩展性

脚本设计为模块化，可以轻松扩展以测试更多管理员端点：

```bash
# 未来可以添加的测试：
# - 密钥管理（禁用/启用/删除）
# - 配额调整
# - 用户管理
# - 审计日志查询
```

## 相关文档

- [quota-proxy 管理员指南](../site/pages/quota-proxy/admin-guide.md)
- [API 网关设计文档](../site/pages/quota-proxy/design.md)
- [验证脚本使用示例](../verify-scripts-usage-examples.md)

---

**最后更新**: 2026-02-09  
**脚本版本**: 1.0.0  
**维护者**: 中华AI共和国运维团队