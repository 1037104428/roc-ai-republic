# 管理密钥端点验证指南

## 概述

本文档介绍如何使用 `verify-admin-keys-endpoint.sh` 脚本来验证 quota-proxy 的 `POST /admin/keys` 和 `GET /admin/usage` 端点功能。

## 快速开始

### 1. 前提条件

- quota-proxy 服务正在运行
- 设置 `ADMIN_TOKEN` 环境变量
- 脚本有可执行权限

### 2. 基本使用

```bash
# 添加执行权限
chmod +x verify-admin-keys-endpoint.sh

# 设置管理员令牌
export ADMIN_TOKEN="your-admin-token-here"

# 运行验证
./verify-admin-keys-endpoint.sh
```

### 3. 带参数运行

```bash
# 指定服务器地址和端口
./verify-admin-keys-endpoint.sh --host 127.0.0.1 --port 8787

# 直接指定管理员令牌
./verify-admin-keys-endpoint.sh --admin-token "your-admin-token"

# 干运行模式（只显示命令，不实际执行）
./verify-admin-keys-endpoint.sh --dry-run

# 安静模式（只显示错误和最终结果）
./verify-admin-keys-endpoint.sh --quiet

# 详细模式（显示所有输出）
./verify-admin-keys-endpoint.sh --verbose
```

## 验证项目

脚本会验证以下功能：

### 1. 服务器健康检查
- 检查 `/healthz` 端点是否可用
- 确认服务器正在运行

### 2. API密钥创建 (`POST /admin/keys`)
- 创建新的API密钥
- 验证响应格式
- 提取生成的密钥信息

### 3. 使用情况查询 (`GET /admin/usage`)
- 查询所有密钥的使用情况
- 验证分页信息
- 检查响应结构

### 4. 按密钥过滤查询
- 使用 `key` 参数过滤查询
- 验证只返回指定密钥的信息

### 5. 分页查询
- 使用 `page` 和 `limit` 参数
- 验证分页信息正确性

## 命令行选项

| 选项 | 缩写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--dry-run` | `-d` | 干运行模式，只显示命令 | `false` |
| `--quiet` | `-q` | 安静模式，减少输出 | `false` |
| `--verbose` | `-v` | 详细模式，增加输出 | `false` |
| `--host` | - | 服务器主机地址 | `127.0.0.1` |
| `--port` | - | 服务器端口 | `8787` |
| `--admin-token` | - | 管理员令牌 | 从 `ADMIN_TOKEN` 环境变量读取 |
| `--no-cleanup` | - | 测试后不清理创建的密钥 | `false` |

## 环境变量

| 变量名 | 描述 | 必需 |
|--------|------|------|
| `ADMIN_TOKEN` | 管理员认证令牌 | 是 |

## 使用示例

### 示例1：基本验证
```bash
export ADMIN_TOKEN="my-secret-token"
./verify-admin-keys-endpoint.sh
```

### 示例2：远程服务器验证
```bash
./verify-admin-keys-endpoint.sh \
  --host api.example.com \
  --port 443 \
  --admin-token "production-token"
```

### 示例3：CI/CD集成
```bash
# 在CI/CD流水线中运行
ADMIN_TOKEN="${{ secrets.ADMIN_TOKEN }}" \
  ./verify-admin-keys-endpoint.sh --quiet
  
# 检查退出码
if [ $? -eq 0 ]; then
  echo "验证通过"
else
  echo "验证失败"
  exit 1
fi
```

### 示例4：调试模式
```bash
# 详细输出，便于调试
./verify-admin-keys-endpoint.sh --verbose

# 干运行查看将要执行的命令
./verify-admin-keys-endpoint.sh --dry-run --verbose
```

## 输出说明

### 成功输出示例
```
[INFO] 开始验证 POST /admin/keys 和 GET /admin/usage 端点
[INFO] 服务器: http://127.0.0.1:8787
[INFO] 管理员令牌: test****token
[INFO] 检查服务器是否运行...
[SUCCESS] 服务器运行正常
[INFO] 测试1: 创建API密钥
[SUCCESS] API密钥创建成功
[INFO] 密钥: roc_1741956292000-abc123def
[INFO] 标签: test-key-1741956292
[INFO] 配额: 500
[INFO] 测试2: 查询使用情况
[SUCCESS] 使用情况查询成功
[INFO] 分页信息: 第 1 页，共 15 条记录
[SUCCESS] 创建的密钥在使用情况列表中
[INFO] 测试3: 带密钥过滤查询使用情况
[SUCCESS] 按密钥过滤查询成功，找到指定密钥
[INFO] 测试4: 带分页查询使用情况
[SUCCESS] 分页查询成功
[INFO] 分页信息: 第 1 页，每页 10 条
[INFO] 清理测试创建的密钥: roc_1741956292000-abc123def
[SUCCESS] 测试密钥清理成功
[INFO] 测试完成
[INFO] 通过: 4
[INFO] 失败: 0
[SUCCESS] 所有测试通过！
```

### 失败输出示例
```
[ERROR] 服务器未运行或健康检查失败
[INFO] 测试完成
[INFO] 通过: 0
[INFO] 失败: 1
[ERROR] 有 1 个测试失败
```

## 故障排除

### 常见问题

#### 1. 服务器未运行
```
[ERROR] 服务器未运行或健康检查失败
```
**解决方案：**
- 确保 quota-proxy 服务正在运行
- 检查主机和端口配置
- 运行 `curl http://127.0.0.1:8787/healthz` 测试连接

#### 2. 管理员令牌无效
```
[ERROR] 创建API密钥失败，HTTP状态码: 401
```
**解决方案：**
- 检查 `ADMIN_TOKEN` 环境变量是否正确
- 确认服务器配置的管理员令牌
- 使用 `--admin-token` 参数直接指定

#### 3. 权限不足
```
[ERROR] 脚本没有可执行权限
```
**解决方案：**
```bash
chmod +x verify-admin-keys-endpoint.sh
```

#### 4. 环境变量未设置
```
[ERROR] ADMIN_TOKEN 环境变量未设置
```
**解决方案：**
```bash
export ADMIN_TOKEN="your-token"
# 或
./verify-admin-keys-endpoint.sh --admin-token "your-token"
```

### 调试技巧

1. **使用详细模式**：添加 `--verbose` 参数查看详细输出
2. **干运行模式**：使用 `--dry-run` 查看将要执行的命令
3. **手动测试**：使用 curl 手动测试端点
   ```bash
   curl -X POST http://127.0.0.1:8787/admin/keys \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"label": "test-key", "totalQuota": 500}'
   ```

## 脚本验证

使用 `verify-verify-admin-keys-endpoint.sh` 验证脚本本身的功能：

```bash
# 快速验证
./verify-verify-admin-keys-endpoint.sh --quick

# 完整验证
./verify-verify-admin-keys-endpoint.sh --full

# 干运行模式
./verify-verify-admin-keys-endpoint.sh --dry-run
```

## 相关文档

- [quota-proxy README](../README.md) - 主文档
- [管理API文档](./ADMIN_API.md) - 管理API详细说明
- [部署指南](./DEPLOYMENT.md) - 部署说明
- [故障排除](./TROUBLESHOOTING.md) - 常见问题解决

## 版本历史

| 版本 | 日期 | 描述 |
|------|------|------|
| 1.0.0 | 2026-02-11 | 初始版本，包含基本验证功能 |
| 1.0.1 | 2026-02-11 | 添加脚本验证和文档 |

## 贡献

发现问题或改进建议，请提交 Issue 或 Pull Request。

## 许可证

本项目使用 MIT 许可证。