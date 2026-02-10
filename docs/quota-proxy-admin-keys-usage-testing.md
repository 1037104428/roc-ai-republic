# quota-proxy Admin Keys & Usage API 专项测试指南

## 概述

本文档提供 `quota-proxy` 服务中优先级 A 核心接口的专项测试指南，专门针对：
- `POST /admin/keys` - 创建 trial key
- `GET /admin/usage` - 获取使用情况统计

这些接口是 `quota-proxy` 的核心管理功能，用于实现 API 密钥管理和使用情况跟踪。

## 测试脚本

### 脚本位置
```
scripts/test-quota-proxy-admin-keys-usage.sh
```

### 功能特性
- **专项测试**: 专门测试 `POST /admin/keys` 和 `GET /admin/usage` 接口
- **完整覆盖**: 包括创建、列出、使用统计、错误处理、数据清理
- **持久化验证**: 验证数据在数据库中的持久化存储
- **彩色输出**: 清晰的彩色终端输出，便于识别测试状态
- **标准化退出码**: 明确的退出码表示测试结果

### 使用示例

#### 基本用法
```bash
# 使用默认地址和管理员令牌
./scripts/test-quota-proxy-admin-keys-usage.sh http://127.0.0.1:8787 your_admin_token_here

# 使用自定义测试标签
TEST_LABEL="ci-test-001" ./scripts/test-quota-proxy-admin-keys-usage.sh http://127.0.0.1:8787 token123
```

#### 服务器测试
```bash
# 测试远程服务器
./scripts/test-quota-proxy-admin-keys-usage.sh http://8.210.185.194:8787 $(cat /path/to/admin-token.txt)
```

### 测试流程

脚本按以下顺序执行测试：

1. **健康检查** - 验证服务是否正常运行
2. **未授权访问保护** - 验证接口需要管理员权限
3. **POST /admin/keys** - 创建新的 trial key
4. **GET /admin/keys** - 列出所有 keys，验证新创建的 key 存在
5. **GET /admin/usage** - 获取使用情况统计
6. **GET /admin/usage?day=YYYY-MM-DD** - 获取指定日期的使用情况
7. **错误处理测试** - 测试无效日期格式的错误处理
8. **数据清理** - 删除测试创建的 trial key
9. **验证清理** - 验证 key 已成功删除

## API 接口详细说明

### POST /admin/keys

**功能**: 创建新的 trial key

**请求**:
```bash
curl -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{"label":"test-key-001"}'
```

**响应**:
```json
{
  "key": "sk-7f3a9b1c5d8e2f4a6b9c1d3e5f7a9b2c",
  "label": "test-key-001",
  "created_at": 1739203200000
}
```

### GET /admin/keys

**功能**: 列出所有 trial keys

**请求**:
```bash
curl -X GET "http://127.0.0.1:8787/admin/keys" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

**响应**:
```json
{
  "keys": [
    {
      "key": "sk-7f3a9b1c5d8e2f4a6b9c1d3e5f7a9b2c",
      "label": "test-key-001",
      "created_at": 1739203200000
    }
  ]
}
```

### GET /admin/usage

**功能**: 获取使用情况统计

**请求**:
```bash
# 获取所有日期的使用情况
curl -X GET "http://127.0.0.1:8787/admin/usage" \
  -H "Authorization: Bearer ADMIN_TOKEN"

# 获取指定日期的使用情况
curl -X GET "http://127.0.0.1:8787/admin/usage?day=2026-02-10" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

**响应**:
```json
{
  "usage": {
    "2026-02-10": [
      {
        "trial_key": "sk-7f3a9b1c5d8e2f4a6b9c1d3e5f7a9b2c",
        "requests": 42
      }
    ]
  },
  "total": 42
}
```

## 测试场景

### 场景 1: 正常流程测试
```bash
# 1. 创建 trial key
./scripts/test-quota-proxy-admin-keys-usage.sh http://127.0.0.1:8787 admin_token

# 2. 验证 key 在列表中
# 3. 检查使用情况统计
# 4. 清理测试数据
```

### 场景 2: 错误处理测试
```bash
# 测试无效的管理员令牌
curl -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer INVALID_TOKEN" \
  -d '{"label":"test"}'

# 预期响应: {"error":{"message":"admin auth required"}}
```

### 场景 3: 持久化验证
```bash
# 1. 创建 trial key
KEY_RESPONSE=$(curl -sS -X POST "http://127.0.0.1:8787/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{"label":"persistence-test"}')

# 2. 重启 quota-proxy 服务
docker compose restart quota-proxy

# 3. 验证 key 仍然存在
curl -X GET "http://127.0.0.1:8787/admin/keys" \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

## 集成测试

### 与 CI/CD 集成
```yaml
# GitHub Actions 示例
name: Test quota-proxy Admin APIs
on: [push, pull_request]

jobs:
  test-admin-apis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Start quota-proxy
        run: |
          cd quota-proxy
          docker compose up -d
          sleep 10
      
      - name: Run admin keys & usage tests
        run: |
          chmod +x scripts/test-quota-proxy-admin-keys-usage.sh
          ./scripts/test-quota-proxy-admin-keys-usage.sh http://127.0.0.1:8787 ${{ secrets.ADMIN_TOKEN }}
```

### 与监控系统集成
```bash
# 定期检查 admin 接口健康状态
#!/bin/bash
BASE_URL="http://127.0.0.1:8787"
ADMIN_TOKEN="your_token_here"

# 运行测试脚本
if ./scripts/test-quota-proxy-admin-keys-usage.sh "$BASE_URL" "$ADMIN_TOKEN"; then
  echo "$(date): quota-proxy admin APIs healthy" >> /var/log/quota-proxy-health.log
else
  echo "$(date): quota-proxy admin APIs FAILED" >> /var/log/quota-proxy-health.log
  # 发送告警
  curl -X POST "https://hooks.slack.com/services/..." \
    -d '{"text":"quota-proxy admin APIs 测试失败"}'
fi
```

## 故障排除

### 常见问题

#### 1. 管理员令牌无效
**症状**: 收到 "admin auth required" 错误
**解决方案**:
- 检查 `ADMIN_TOKEN` 环境变量是否正确设置
- 验证 quota-proxy 启动时是否配置了正确的管理员令牌
- 检查令牌是否包含特殊字符需要转义

#### 2. 服务未运行
**症状**: 连接被拒绝或超时
**解决方案**:
```bash
# 检查服务状态
cd /opt/roc/quota-proxy && docker compose ps

# 启动服务
cd /opt/roc/quota-proxy && docker compose up -d

# 检查日志
cd /opt/roc/quota-proxy && docker compose logs quota-proxy
```

#### 3. 数据库连接问题
**症状**: 数据库相关错误
**解决方案**:
```bash
# 检查数据库文件权限
ls -la /data/quota.db

# 检查数据库完整性
sqlite3 /data/quota.db "PRAGMA integrity_check;"

# 重新初始化数据库
./scripts/init-quota-db.sh --force
```

#### 4. 测试脚本权限问题
**症状**: "Permission denied" 错误
**解决方案**:
```bash
chmod +x scripts/test-quota-proxy-admin-keys-usage.sh
```

## 最佳实践

### 测试环境
1. **隔离环境**: 在独立的测试环境中运行测试
2. **数据清理**: 测试完成后清理所有测试数据
3. **令牌管理**: 使用环境变量或密钥管理工具存储管理员令牌
4. **版本控制**: 将测试脚本和文档纳入版本控制

### 生产环境
1. **定期测试**: 定期运行测试脚本验证接口健康状态
2. **监控告警**: 集成到监控系统，失败时发送告警
3. **备份验证**: 测试数据库备份和恢复流程
4. **性能测试**: 定期进行负载测试验证接口性能

### 安全考虑
1. **令牌保护**: 不要将管理员令牌硬编码在脚本中
2. **访问控制**: 确保只有授权人员可以访问管理接口
3. **日志审计**: 记录所有管理操作日志
4. **输入验证**: 验证所有输入参数，防止注入攻击

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [SQLite 数据库初始化指南](../docs/quota-db-initialization.md)
- [API 使用情况监控指南](../docs/quota-usage-monitoring.md)
- [数据库备份与恢复指南](../docs/quota-db-backup.md)

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-02-10 | 1.0.0 | 初始版本，创建专项测试脚本和文档 |
| 2026-02-10 | 1.0.1 | 添加故障排除和最佳实践章节 |

## 贡献指南

欢迎提交改进建议和问题报告：
1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。