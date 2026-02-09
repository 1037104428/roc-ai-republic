# Admin API 头部统一规范

## 问题背景
在 quota-proxy 的管理接口文档中，存在两种不同的认证头部格式：
1. `X-Admin-Token: $ADMIN_TOKEN`（旧格式）
2. `Authorization: Bearer $ADMIN_TOKEN`（新格式，统一标准）

## 统一规范
**所有 Admin API 调用应统一使用：**
```bash
Authorization: Bearer $ADMIN_TOKEN
```

## 为什么统一？
1. **标准兼容**：`Authorization: Bearer` 是 OAuth 2.0 和大多数 API 的标准认证方式
2. **反代友好**：某些反向代理可能会过滤或重写自定义头部（如 `X-Admin-Token`）
3. **工具兼容**：标准头部更容易与 curl、Postman、HTTP 客户端库等工具集成
4. **安全最佳实践**：遵循行业标准减少安全风险

## 迁移指南

### 旧格式（已废弃）
```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "用户试用"}'
```

### 新格式（推荐）
```bash
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label": "用户试用"}'
```

## 向后兼容性
当前 quota-proxy 实现同时支持两种头部格式，但**新代码和文档应统一使用 `Authorization: Bearer` 格式**。

## 验证命令
```bash
# 验证两种头部格式都有效
ADMIN_TOKEN="your_admin_token_here"

# 使用 Authorization: Bearer
curl -X GET http://localhost:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -w "HTTP %{http_code}\n"

# 使用 X-Admin-Token（向后兼容）
curl -X GET http://localhost:8787/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -w "HTTP %{http_code}\n"
```

## 更新清单
- [ ] 更新所有文档示例（包括 README.md、ADMIN-INTERFACE.md 等）
- [ ] 更新脚本工具（如 quota-proxy-admin.sh）
- [ ] 更新网站页面（quota-proxy.html）
- [ ] 更新快速开始指南
- [ ] 更新 API 测试脚本

## 服务器验证
```bash
# 在服务器上验证两种头部格式
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && \
  ADMIN_TOKEN=$(cat .env | grep ADMIN_TOKEN | cut -d= -f2) && \
  echo "Testing Authorization: Bearer..." && \
  curl -s -X GET http://127.0.0.1:8787/admin/keys \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -w "Status: %{http_code}\n" && \
  echo "Testing X-Admin-Token..." && \
  curl -s -X GET http://127.0.0.1:8787/admin/keys \
    -H "X-Admin-Token: $ADMIN_TOKEN" \
    -w "Status: %{http_code}\n"'
```