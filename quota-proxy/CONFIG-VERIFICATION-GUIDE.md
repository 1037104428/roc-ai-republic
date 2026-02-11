# 配置验证指南

## 概述

`verify-config.sh` 脚本用于验证 quota-proxy 的环境变量配置是否正确。它检查必需的环境变量、验证格式、检查端口可用性、验证数据库文件和管理员令牌。

## 快速开始

### 基本使用

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 基本验证
./verify-config.sh

# 干运行模式（只显示检查项）
./verify-config.sh --dry-run

# 严格模式（任何检查失败都会导致脚本退出）
./verify-config.sh --strict

# 指定环境文件
./verify-config.sh --env-file .env.production
```

### 环境文件示例

创建 `.env` 文件：

```bash
# quota-proxy 环境配置
PORT=8787
ADMIN_TOKEN=your-secure-admin-token-here-32-chars-minimum
DB_PATH=./data/quota-proxy.db
LOG_LEVEL=info
TRIAL_KEY_EXPIRY_DAYS=30
DAILY_QUOTA_LIMIT=1000
```

## 功能特性

### 1. 必需环境变量检查
- **PORT**: 服务端口 (1-65535)
- **ADMIN_TOKEN**: 管理员令牌（至少8字符）

### 2. 环境变量格式验证
- 端口号有效性验证
- 日志级别有效性验证 (debug/info/warn/error)
- 数据库路径目录存在性检查
- 管理员令牌长度和复杂度建议

### 3. 端口可用性检查
- 检查端口是否被其他进程占用
- 支持多种系统工具 (lsof/netstat/ss)

### 4. 数据库文件验证
- 检查数据库文件是否存在
- 验证文件可读写权限
- 检查是否为有效的 SQLite 格式
- 验证目录可写权限（新文件时）

### 5. 管理员令牌验证
- 令牌长度检查（至少8字符）
- 复杂度建议（包含字母和数字）

## 使用场景

### 场景1: 开发环境配置验证

```bash
# 开发环境验证
./verify-config.sh --env-file .env.development

# 输出示例:
# [INFO] 开始 quota-proxy 配置验证
# [INFO] 当前时间: 2026-02-11 23:35:00 CST
# [INFO] 工作目录: /path/to/quota-proxy
# [SUCCESS] 所有必需环境变量都存在
# [SUCCESS] 所有环境变量格式验证通过
# [SUCCESS] 端口 8787 可用
# [SUCCESS] 数据库文件可读写: ./data/quota-proxy.db
# [SUCCESS] 管理员令牌格式基本正确（长度: 32 字符）
```

### 场景2: CI/CD 流水线集成

```bash
# CI/CD 严格验证
./verify-config.sh --strict --env-file .env.production

# 如果验证失败，脚本会退出并返回非零状态码
# 这可以在 CI/CD 流水线中用于阻止部署
```

### 场景3: 故障排查

```bash
# 详细验证，显示所有警告
./verify-config.sh --env-file .env

# 如果发现端口被占用:
# [WARNING] 端口 8787 已被占用
# 解决方案: 更改端口或停止占用进程

# 如果数据库目录不可写:
# [ERROR] 数据库目录不可写: ./data
# 解决方案: chmod +w ./data 或更改 DB_PATH
```

## 配置检查项

### 必需检查项
1. **PORT 存在性** - 必须设置
2. **ADMIN_TOKEN 存在性** - 必须设置
3. **PORT 格式** - 必须是 1-65535 的数字
4. **管理员令牌长度** - 至少8字符

### 可选检查项
1. **DB_PATH 验证** - 如果设置则验证
2. **LOG_LEVEL 验证** - 如果设置则验证
3. **端口占用检查** - 如果工具可用则检查
4. **数据库文件格式** - 如果文件存在则检查

## 退出码

| 退出码 | 说明 | 建议操作 |
|--------|------|----------|
| 0 | 所有检查通过 | 可以正常启动服务 |
| 1 | 检查失败 | 查看错误信息并修复配置 |
| 2 | 参数错误 | 检查命令行参数 |

## 最佳实践

### 1. 开发环境
```bash
# 在启动服务前验证配置
./verify-config.sh && ./start-sqlite-persistent.sh
```

### 2. 生产环境
```bash
# 使用严格模式，任何问题都会阻止启动
./verify-config.sh --strict --env-file .env.production
```

### 3. 自动化部署
```bash
# 在部署脚本中添加验证
#!/bin/bash
set -e

# 验证配置
cd /opt/roc/quota-proxy
./verify-config.sh --strict

# 如果验证通过，启动服务
./start-sqlite-persistent.sh
```

### 4. 监控集成
```bash
# 定期验证配置（cron 作业）
0 * * * * cd /opt/roc/quota-proxy && ./verify-config.sh --env-file .env.production >> /var/log/quota-proxy/config-verify.log 2>&1
```

## 故障排除

### 常见问题

#### 问题1: 端口被占用
```
[WARNING] 端口 8787 已被占用
```
**解决方案:**
```bash
# 查看占用进程
lsof -i :8787
# 或
netstat -tulpn | grep :8787

# 停止占用进程或更改端口
export PORT=8788
```

#### 问题2: 数据库目录不可写
```
[ERROR] 数据库目录不可写: ./data
```
**解决方案:**
```bash
# 创建目录并设置权限
mkdir -p ./data
chmod 755 ./data

# 或更改数据库路径到可写目录
export DB_PATH=/tmp/quota-proxy.db
```

#### 问题3: 管理员令牌太短
```
[ERROR] ADMIN_TOKEN 太短（6 字符），建议至少 16 字符
```
**解决方案:**
```bash
# 生成更强的令牌
export ADMIN_TOKEN=$(openssl rand -base64 32)
# 或
export ADMIN_TOKEN=$(uuidgen)
```

#### 问题4: 环境文件不存在
```
[WARNING] 环境文件 .env 不存在，使用环境变量
```
**解决方案:**
```bash
# 创建环境文件
cp .env.example .env
# 编辑 .env 文件设置正确的值
```

### 调试模式

如果需要更详细的输出，可以设置调试环境变量:

```bash
# 启用详细输出
export VERBOSE=1
./verify-config.sh

# 或直接查看脚本内部
bash -x ./verify-config.sh --dry-run
```

## 集成指南

### 与现有验证工具链集成

`verify-config.sh` 可以与现有的验证工具链无缝集成:

```bash
# 在完整的验证流程中包含配置验证
#!/bin/bash
# complete-verification.sh

echo "=== 开始完整的 quota-proxy 验证 ==="

# 1. 配置验证
echo "步骤1: 配置验证"
./verify-config.sh --strict

# 2. 文档完整性验证
echo "步骤2: 文档完整性验证"
./verify-validation-docs-enhanced.sh

# 3. API 验证
echo "步骤3: API 验证"
./deployment-verification.sh

# 4. 健康检查
echo "步骤4: 健康检查"
./quick-sqlite-health-check.sh

echo "=== 所有验证完成 ==="
```

### 与 CI/CD 集成

GitHub Actions 示例:

```yaml
name: Validate Configuration
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate quota-proxy configuration
        run: |
          cd quota-proxy
          ./verify-config.sh --strict
          
      - name: Run full validation suite
        run: |
          cd quota-proxy
          chmod +x *.sh
          ./complete-verification.sh
```

## 更新日志

### 版本 1.0.0 (2026-02-11)
- 初始版本发布
- 支持必需环境变量检查
- 支持环境变量格式验证
- 支持端口可用性检查
- 支持数据库文件验证
- 支持管理员令牌验证
- 支持干运行模式和严格模式
- 提供完整的配置验证指南

## 支持

如果遇到问题:
1. 查看本指南的故障排除部分
2. 检查环境变量设置是否正确
3. 运行 `./verify-config.sh --help` 查看帮助
4. 查看 quota-proxy 的故障排除指南

---

**注意**: 配置验证是服务稳定运行的重要前提。建议在每次部署前都运行配置验证，特别是在生产环境中。