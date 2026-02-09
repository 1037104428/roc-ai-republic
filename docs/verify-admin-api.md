# 验证 quota-proxy 管理员 API

本文档介绍如何验证 quota-proxy 管理员 API 端点的功能是否正常工作。

## 快速验证脚本

使用 `verify-admin-api.sh` 脚本进行一键验证：

```bash
# 基本验证（使用默认参数）
./scripts/verify-admin-api.sh

# 指定自定义参数
./scripts/verify-admin-api.sh http://127.0.0.1:8787 your_admin_token_here

# 使用环境变量
export ADMIN_TOKEN="your_admin_token_here"
./scripts/verify-admin-api.sh
```

## 验证内容

脚本会检查以下端点：

### 1. 健康检查端点
- `/healthz` - 基础健康检查
- `/healthz/db` - 数据库健康检查（SQLite版本）

### 2. 管理员 API 端点
- `/admin/keys` - 密钥管理（需要认证）
- `/admin/usage` - 使用统计（需要认证）

### 3. 公开 API 端点
- `/v1/models` - 模型列表

## 验证结果解读

### 成功情况
```
✅ 验证完成！
总结:
  - 基础健康检查: 通过
  - 管理员API: 需要有效令牌
  - 公开API: 正常
```

### 常见问题

#### 1. 管理员端点返回 401
```
⚠ 管理员端点需要有效令牌 (HTTP 401)
提示: 请设置正确的 ADMIN_TOKEN 环境变量
```

**解决方案：**
1. 检查 quota-proxy 启动时是否设置了 `ADMIN_TOKEN`
2. 确保验证时使用相同的令牌

#### 2. 数据库健康端点不可用
```
⚠ 数据库健康端点不可用（可能是旧版本）
```

**说明：** 这是正常情况，旧版本的 quota-proxy 可能没有 `/healthz/db` 端点。

#### 3. 使用统计端点返回 404
```
⚠ 使用统计端点未找到 (HTTP 404) - 可能是旧版本
```

**说明：** 旧版本的 quota-proxy 可能没有 `/admin/usage` 端点。

## 手动验证命令

如果脚本不可用，可以手动执行以下命令：

```bash
# 1. 检查健康端点
curl -fsS http://127.0.0.1:8787/healthz

# 2. 检查数据库健康端点
curl -fsS http://127.0.0.1:8787/healthz/db

# 3. 检查管理员密钥列表（需要令牌）
curl -H "Authorization: Bearer your_admin_token" \
  http://127.0.0.1:8787/admin/keys

# 4. 检查使用统计（需要令牌）
curl -H "Authorization: Bearer your_admin_token" \
  http://127.0.0.1:8787/admin/usage

# 5. 检查模型列表
curl -fsS http://127.0.0.1:8787/v1/models
```

## 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `ADMIN_TOKEN` | `test_admin_token` | 管理员认证令牌 |
| `BASE_URL` | `http://127.0.0.1:8787` | quota-proxy 基础URL |

## 集成到 CI/CD

可以将验证脚本集成到持续集成流程中：

```yaml
# GitHub Actions 示例
name: Verify quota-proxy API
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Verify API endpoints
        run: |
          chmod +x ./scripts/verify-admin-api.sh
          ./scripts/verify-admin-api.sh
```

## 故障排除

### 1. 脚本权限问题
```bash
chmod +x ./scripts/verify-admin-api.sh
```

### 2. curl 命令不可用
```bash
# 安装 curl
sudo apt-get update && sudo apt-get install -y curl
```

### 3. 网络连接问题
```bash
# 检查网络连通性
ping -c 3 127.0.0.1

# 检查端口是否开放
netstat -tlnp | grep 8787
```

### 4. quota-proxy 未运行
```bash
# 检查 Docker 容器状态
docker compose ps

# 查看日志
docker compose logs quota-proxy
```

## 相关文档

- [quota-proxy 部署指南](../quota-proxy/README.md)
- [管理员 API 测试脚本](../scripts/test-admin-api.sh)
- [Web 管理界面使用指南](../docs/admin-ui-guide.md)

## 更新日志

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-02-09 | 1.0.0 | 初始版本，包含基本验证功能 |
| 2026-02-09 | 1.0.1 | 添加环境变量支持和错误处理 |

---

**提示：** 定期运行验证脚本可以确保 quota-proxy 服务持续可用，及时发现潜在问题。