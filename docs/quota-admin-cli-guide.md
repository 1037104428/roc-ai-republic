# quota-proxy 命令行管理工具指南

## 概述

`quota-admin-cli.js` 是一个方便管理员管理 quota-proxy 的命令行工具，支持：
- 快速创建 API 密钥
- 查看所有密钥列表
- 查看使用情况统计
- 检查服务健康状态

## 安装与配置

### 1. 安装依赖

```bash
cd /path/to/roc-ai-republic/scripts
npm install
```

或者直接使用（需要已安装 axios 和 yargs）：

```bash
npm install axios yargs
```

### 2. 设置环境变量

```bash
# 设置 quota-proxy 地址（默认：http://127.0.0.1:8787）
export QUOTA_PROXY_URL="http://127.0.0.1:8787"

# 设置管理员令牌（必须）
export ADMIN_TOKEN="your-admin-token-here"
```

或者一次性设置：

```bash
QUOTA_PROXY_URL=http://127.0.0.1:8787 ADMIN_TOKEN=your-token node quota-admin-cli.js --help
```

## 使用方法

### 基本命令

```bash
# 显示帮助
node quota-admin-cli.js --help

# 检查服务健康状态
node quota-admin-cli.js health

# 创建新的 API 密钥
node quota-admin-cli.js create-key --label "测试用户" --quota 1000

# 列出所有密钥
node quota-admin-cli.js list-keys

# 查看使用情况（默认显示最近50条）
node quota-admin-cli.js usage --limit 100
```

### 快捷方式

可以将脚本设为可执行并添加到 PATH：

```bash
# 设为可执行
chmod +x quota-admin-cli.js

# 创建软链接（可选）
ln -s $(pwd)/quota-admin-cli.js /usr/local/bin/quota-admin

# 之后可以直接使用
quota-admin --help
```

## 示例

### 示例 1：创建测试密钥

```bash
export ADMIN_TOKEN="dev-admin-token-change-in-production"
node quota-admin-cli.js create-key --label "开发测试" --quota 500
```

输出：
```
✅ 密钥创建成功：
   Key: sk-test-abc123def456
   Label: 开发测试
   总配额: 500
   创建时间: 2026-02-10T13:50:00.000Z
```

### 示例 2：查看所有密钥

```bash
node quota-admin-cli.js list-keys
```

输出：
```
📋 共 3 个密钥：
================================================================================
1. sk-test-abc123def456
   标签: 开发测试
   使用量: 150/500 (30%)
   创建时间: 2026-02-10T13:50:00.000Z
----------------------------------------
2. sk-test-xyz789uvw012
   标签: 生产用户
   使用量: 890/1000 (89%)
   创建时间: 2026-02-09T10:30:00.000Z
   过期时间: 2026-03-10T10:30:00.000Z (剩余 28 天)
----------------------------------------
```

### 示例 3：查看使用统计

```bash
node quota-admin-cli.js usage --limit 20
```

输出：
```
📊 使用情况统计：
================================================================================
共 20 条记录（最近 20 条）：
1. sk-test-abc123def456 (开发测试)
   使用量: 150/500
   剩余: 350
   创建: 2026-02-10T13:50:00.000Z
   最后使用: 2026-02-10T14:30:00.000Z
----------------------------------------

📈 汇总信息：
   总密钥数: 3
   活跃密钥: 2
   总使用量: 1040
   总配额: 2500
   使用率: 41.6%
```

## 服务器端使用

在 quota-proxy 服务器上使用（假设已部署）：

```bash
# SSH 登录服务器
ssh root@8.210.185.194

# 进入项目目录
cd /opt/roc/quota-proxy

# 设置环境变量（从 docker-compose 环境获取）
export ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2)
export QUOTA_PROXY_URL="http://127.0.0.1:8787"

# 运行管理命令
node /path/to/quota-admin-cli.js list-keys
```

## 集成到运维脚本

可以将 CLI 工具集成到现有的运维脚本中：

```bash
#!/bin/bash
# check-quota-usage.sh

export ADMIN_TOKEN="${ADMIN_TOKEN}"
export QUOTA_PROXY_URL="http://127.0.0.1:8787"

# 检查健康状态
if ! node quota-admin-cli.js health > /dev/null 2>&1; then
    echo "❌ quota-proxy 服务异常"
    exit 1
fi

# 获取使用情况
echo "=== quota-proxy 使用情况报告 ==="
node quota-admin-cli.js usage --limit 10

# 检查是否有密钥即将用完
# （这里可以添加自定义逻辑）
```

## 故障排除

### 1. 连接失败

错误信息：
```
❌ 服务健康检查失败：connect ECONNREFUSED 127.0.0.1:8787
```

解决方法：
- 检查 quota-proxy 是否运行：`docker compose ps`
- 检查端口是否正确：`netstat -tlnp | grep 8787`
- 确认 QUOTA_PROXY_URL 环境变量设置正确

### 2. 认证失败

错误信息：
```
❌ 创建密钥失败：Unauthorized
```

解决方法：
- 检查 ADMIN_TOKEN 环境变量是否正确
- 确认令牌与 quota-proxy 配置一致
- 检查 docker-compose 环境变量配置

### 3. 依赖缺失

错误信息：
```
Error: Cannot find module 'axios'
```

解决方法：
```bash
cd /path/to/scripts
npm install axios yargs
```

## 安全建议

1. **保护 ADMIN_TOKEN**：不要将管理员令牌提交到版本控制
2. **限制访问**：CLI 工具应在受信任的环境中使用
3. **审计日志**：所有管理操作都会记录在 quota-proxy 的审计日志中
4. **定期轮换**：定期更换管理员令牌

## 相关文档

- [quota-proxy 管理接口规范](../docs/quota-proxy-v1-admin-spec.md)
- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [运维健康检查](../docs/ops-server-healthcheck.md)

## 更新日志

- v1.0.0 (2026-02-10): 初始版本，支持基本的管理功能