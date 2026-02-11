# 快速SQLite健康检查指南

## 概述

`quick-sqlite-health-check.sh` 是一个轻量级的健康检查脚本，用于快速验证 SQLite 持久化配额代理服务器的运行状态。它检查所有关键端点，提供即时反馈。

## 特性

- **快速检查**: 5秒内完成所有检查
- **详细反馈**: 每个检查步骤都有明确的状态指示
- **故障排除**: 提供具体的故障排除建议
- **颜色编码**: 使用颜色区分成功/失败/警告
- **最小依赖**: 只需要 curl 和 bash

## 使用方法

### 基本使用

```bash
cd quota-proxy
./quick-sqlite-health-check.sh
```

### 指定管理员令牌

```bash
ADMIN_TOKEN="your-admin-token" ./quick-sqlite-health-check.sh
# 或
./quick-sqlite-health-check.sh --admin-token "your-admin-token"
```

### 指定服务器地址

```bash
./quick-sqlite-health-check.sh --base-url "http://your-server:8787"
```

## 检查内容

脚本会依次检查以下内容：

1. **服务器状态** - 检查 `/healthz` 端点
2. **数据库连接** - 验证数据库连接状态
3. **管理员API** - 检查 `/admin/keys` 端点（需要管理员令牌）
4. **试用密钥API** - 检查 `/trial-key` 端点
5. **配额API** - 检查 `/quota-check` 端点

## 输出示例

### 成功情况

```
🔍 SQLite持久化服务器快速健康检查
================================
服务器地址: http://localhost:8787
管理员令牌: test-admin...

开始健康检查...

1. 检查服务器状态... ✓ 运行正常
2. 检查数据库连接... ✓ 数据库连接正常
3. 检查管理员API... ✓ 管理员API正常
4. 检查试用密钥API... ✓ 试用密钥API正常
5. 检查配额API... ✓ 配额API正常

检查完成
========
✅ 所有检查通过！SQLite持久化服务器运行正常。

可用端点:
  • http://localhost:8787/healthz - 健康检查
  • http://localhost:8787/admin/keys - 管理员密钥管理
  • http://localhost:8787/trial-key - 获取试用密钥
  • http://localhost:8787/quota-check - 配额检查

详细验证: ./verify-sqlite-persistent-api.sh --admin-token "test-admin..."
```

### 失败情况

```
🔍 SQLite持久化服务器快速健康检查
================================
服务器地址: http://localhost:8787
管理员令牌: test-admin...

开始健康检查...

1. 检查服务器状态... ✗ 服务器未运行
   提示: 请先运行 ./start-sqlite-persistent.sh
2. 检查数据库连接... ⚠ 数据库状态未知
3. 检查管理员API... ✗ 管理员API失败
4. 检查试用密钥API... ✗ 试用密钥API失败
5. 检查配额API... ✗ 配额API失败

检查完成
========
❌ 4 项检查失败

故障排除:
  1. 确保服务器运行: ./start-sqlite-persistent.sh
  2. 检查环境变量: DEEPSEEK_API_KEY, ADMIN_TOKEN
  3. 查看日志: tail -f quota-proxy.log
  4. 详细验证: ./verify-sqlite-persistent-api.sh --dry-run
```

## 故障排除

### 常见问题

1. **服务器未运行**
   ```
   错误: 检查服务器状态... ✗ 服务器未运行
   解决: ./start-sqlite-persistent.sh
   ```

2. **管理员令牌错误**
   ```
   错误: 检查管理员API... ✗ 管理员API失败
   解决: 设置正确的 ADMIN_TOKEN 环境变量
   ```

3. **数据库连接问题**
   ```
   错误: 检查数据库连接... ⚠ 数据库状态未知
   解决: 检查数据库文件权限和路径
   ```

### 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `ADMIN_TOKEN` | 管理员认证令牌 | 自动生成测试令牌 |
| `BASE_URL` | 服务器地址 | `http://localhost:8787` |

## 相关脚本

- `./start-sqlite-persistent.sh` - 启动 SQLite 持久化服务器
- `./verify-sqlite-persistent-api.sh` - 完整的 API 验证
- `./quick-health-check.sh` - 通用快速健康检查

## 集成到 CI/CD

```bash
# 在部署后运行健康检查
cd quota-proxy
if ./quick-sqlite-health-check.sh --admin-token "$DEPLOY_ADMIN_TOKEN"; then
    echo "部署验证成功"
else
    echo "部署验证失败"
    exit 1
fi
```

## 许可证

MIT License - 参见项目主 LICENSE 文件