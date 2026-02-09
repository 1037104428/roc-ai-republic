# test-sqlite-full-cycle.sh 使用要点

## 快速开始

```bash
# 1. 设置管理员 token
export ADMIN_TOKEN="your_admin_token_here"

# 2. 运行完整测试（默认使用 http://127.0.0.1:8787）
./scripts/test-sqlite-full-cycle.sh

# 3. 或指定远程服务器
PROXY_URL="http://your-server:8787" ./scripts/test-sqlite-full-cycle.sh
```

## 测试覆盖范围

此脚本验证以下 SQLite 持久化功能：

1. ✅ **健康检查** - `/healthz`
2. ✅ **密钥创建** - `POST /admin/keys` (带 label)
3. ✅ **密钥列表** - `GET /admin/keys`
4. ✅ **用量查询** - `GET /admin/usage`
5. ✅ **用量重置** - `POST /admin/usage/reset`
6. ✅ **密钥吊销** - `DELETE /admin/keys/:key`
7. ✅ **持久化验证** - 重启后数据不丢失

## 输出解读

- **绿色 ✅** - 测试通过
- **红色 ❌** - 测试失败（会显示具体错误）
- **黄色 ⚠️** - 警告或跳过（如缺少 jq）

## 故障排查

### 常见问题

1. **401 Unauthorized**
   ```bash
   # 检查 ADMIN_TOKEN 是否正确
   echo "ADMIN_TOKEN=$ADMIN_TOKEN"
   ```

2. **连接失败**
   ```bash
   # 先验证代理是否运行
   curl -fsS "$PROXY_URL/healthz"
   ```

3. **SQLite 文件权限**
   ```bash
   # 检查 SQLite 文件是否存在且有写权限
   ls -la /opt/roc/quota-proxy/data/quota.db
   ```

### 调试模式

```bash
# 显示详细输出
set -x
./scripts/test-sqlite-full-cycle.sh
set +x
```

## 集成到 CI/CD

```bash
# 示例：在部署后自动运行
deploy_quota_proxy_sqlite() {
  # ... 部署代码 ...
  
  # 等待服务启动
  sleep 5
  
  # 运行验证测试
  if ADMIN_TOKEN="$ADMIN_TOKEN" ./scripts/test-sqlite-full-cycle.sh; then
    echo "✅ SQLite 持久化验证通过"
  else
    echo "❌ SQLite 持久化验证失败"
    exit 1
  fi
}
```

## 相关文档

- [quota-proxy SQLite 部署指南](../quota-proxy/README.md#sqlite-版本)
- [管理员接口规范](../docs/quota-proxy-v1-admin-spec.md)
- [验证清单](../docs/verify.md#sqlite-持久化验证)