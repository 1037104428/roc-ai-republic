# 管理密钥和使用统计端点验证指南

## 概述

`verify-admin-keys-usage.sh` 是一个快速验证脚本，专门用于测试 quota-proxy 的管理密钥创建和使用统计查询功能。该脚本验证以下核心管理端点：

1. `POST /admin/keys` - 创建管理密钥
2. `GET /admin/usage` - 查看使用统计
3. `GET /admin/usage` 带分页参数
4. `GET /admin/usage` 按密钥筛选

## 快速开始

### 前提条件

1. quota-proxy 正在运行（SQLite 模式）
2. 已设置 `ADMIN_TOKEN` 环境变量或使用默认值
3. `curl` 命令可用

### 基本使用

```bash
# 进入quota-proxy目录
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy

# 启动quota-proxy（如果未运行）
node server-sqlite.js &

# 运行验证脚本
./verify-admin-keys-usage.sh
```

### 带参数使用

```bash
# 指定端口（如果quota-proxy运行在其他端口）
./verify-admin-keys-usage.sh --port 8888

# 指定管理员令牌
./verify-admin-keys-usage.sh --admin-token "my-secret-admin-token"

# 干运行模式（只显示命令，不实际执行）
./verify-admin-keys-usage.sh --dry-run

# 显示帮助信息
./verify-admin-keys-usage.sh --help
```

## 验证流程

脚本按以下顺序执行验证：

1. **检查依赖** - 验证 `curl` 命令是否可用
2. **检查服务器** - 验证 quota-proxy 是否运行正常（通过 `/healthz` 端点）
3. **创建管理密钥** - 测试 `POST /admin/keys` 端点
4. **查看使用统计** - 测试 `GET /admin/usage` 端点（默认最近1天，限制10条）
5. **带分页的使用统计** - 测试 `GET /admin/usage?page=1&limit=5`
6. **按密钥筛选** - 测试 `GET /admin/usage?key=<测试密钥>`
7. **清理测试数据** - 删除创建的测试密钥

## 预期输出

成功运行时，您将看到类似以下输出：

```
[INFO] 开始验证quota-proxy管理密钥和使用统计端点
[INFO] 基础URL: http://localhost:8787
[INFO] 管理员令牌: dev-admin-tok...
[SUCCESS] curl命令可用
[INFO] 检查服务器健康状态: http://localhost:8787/healthz
[SUCCESS] 服务器运行正常
[INFO] 运行测试 1/4: 创建管理密钥
[INFO] 测试创建管理密钥: 测试管理密钥-1770657652
[SUCCESS] 管理密钥创建成功: sk-1770657652-abc123xyz
{
  "success": true,
  "key": "sk-1770657652-abc123xyz",
  "label": "测试管理密钥-1770657652",
  "totalQuota": 500,
  "expiresAt": null,
  "id": 15
}
[INFO] 运行测试 2/4: 查看使用统计
[SUCCESS] 使用统计查询成功
{
  "total": 12,
  "page": 1,
  "limit": 10,
  "totalPages": 2,
  "keys": [...]
}
[INFO] 运行测试 3/4: 带分页的使用统计
[SUCCESS] 分页使用统计查询成功
{
  "total": 12,
  "page": 1,
  "limit": 5,
  "totalPages": 3,
  "keys": [...]
}
[INFO] 运行测试 4/4: 按密钥筛选使用统计
[SUCCESS] 按密钥筛选使用统计成功
{
  "total": 1,
  "page": 1,
  "limit": 50,
  "totalPages": 1,
  "keys": [...]
}
[INFO] 清理测试密钥: sk-1770657652-abc123xyz
[SUCCESS] 测试密钥清理成功
[INFO] 验证完成: 4/4 个测试通过
[SUCCESS] 所有管理密钥和使用统计端点验证通过！
```

## 故障排除

### 服务器未运行

错误信息：
```
[ERROR] 服务器未运行或健康检查失败
[INFO] 请确保quota-proxy正在运行: cd quota-proxy && node server-sqlite.js
```

解决方案：
```bash
# 启动quota-proxy
cd quota-proxy
node server-sqlite.js &
```

### 管理员令牌错误

错误信息：
```
[ERROR] 管理密钥创建失败
{"error":"Unauthorized"}
```

解决方案：
```bash
# 使用正确的管理员令牌
export ADMIN_TOKEN="your-actual-admin-token"
./verify-admin-keys-usage.sh

# 或者直接指定
./verify-admin-keys-usage.sh --admin-token "your-actual-admin-token"
```

### curl命令未找到

错误信息：
```
[ERROR] curl命令未找到，请先安装curl
```

解决方案：
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS
brew install curl
```

## 集成到CI/CD流程

此验证脚本可以集成到持续集成流程中，确保管理端点的基本功能正常：

```bash
#!/bin/bash
# CI/CD验证脚本示例

set -e

echo "开始quota-proxy管理端点验证..."

# 启动quota-proxy
cd quota-proxy
node server-sqlite.js &
SERVER_PID=$!

# 等待服务器启动
sleep 3

# 运行验证
if ./verify-admin-keys-usage.sh; then
    echo "✅ 管理端点验证通过"
else
    echo "❌ 管理端点验证失败"
    kill $SERVER_PID
    exit 1
fi

# 清理
kill $SERVER_PID
echo "验证完成"
```

## 相关文档

- [ADMIN-INTERFACE.md](./ADMIN-INTERFACE.md) - 完整的管理界面文档
- [verify-admin-api.sh](./verify-admin-api.sh) - 完整的管理API验证脚本
- [server-sqlite.js](./server-sqlite.js) - 服务器源代码
- [QUICKSTART.md](./QUICKSTART.md) - 快速开始指南

## 版本历史

- **2026.02.11.1721** - 初始版本，创建快速验证脚本
- 功能：验证管理密钥创建、使用统计查询、分页和筛选功能
- 特性：彩色输出、干运行模式、自动清理测试数据