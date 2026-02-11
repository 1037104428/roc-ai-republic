# 环境变量配置验证指南

## 概述

`verify-env-config.sh` 脚本用于验证 quota-proxy 服务的环境变量配置。它帮助用户快速检查部署环境的关键配置变量，诊断配置问题，并提供修复建议。

## 功能特性

- **必需环境变量检查**: 验证 `ADMIN_TOKEN` 等必需环境变量是否设置
- **可选环境变量检查**: 检查 `PORT`, `DATABASE_URL`, `LOG_LEVEL` 等可选环境变量
- **格式验证**: 验证端口格式、URL格式、数据库路径格式
- **配置文件加载**: 支持从 `.env` 文件加载环境变量
- **配置建议**: 提供针对性的配置建议和最佳实践
- **干运行模式**: 支持干运行模式，只显示检查项不实际验证
- **详细输出**: 支持详细输出模式，显示更多调试信息
- **彩色输出**: 使用彩色输出提高可读性

## 快速开始

### 1. 授予执行权限

```bash
chmod +x verify-env-config.sh
```

### 2. 基本使用

```bash
# 干运行模式（只显示检查项）
./verify-env-config.sh --dry-run

# 实际验证
./verify-env-config.sh

# 详细输出模式
./verify-env-config.sh --verbose

# 指定配置文件
./verify-env-config.sh --config-file /path/to/.env
```

### 3. 查看帮助

```bash
./verify-env-config.sh --help
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--dry-run` | 干运行模式，只显示检查项不实际验证 | false |
| `--verbose` | 详细输出模式 | false |
| `--config-file FILE` | 指定配置文件路径 | 当前目录的 `.env` 文件 |
| `--env-file FILE` | 指定环境变量文件路径 | 当前目录的 `.env` 文件 |
| `--help` | 显示帮助信息 | - |

## 环境变量说明

### 必需环境变量

| 变量名 | 描述 | 示例值 | 默认值 |
|--------|------|--------|--------|
| `ADMIN_TOKEN` | 管理员令牌，用于管理API身份验证 | `my-secret-admin-token` | 无，必须设置 |

### 可选环境变量

| 变量名 | 描述 | 示例值 | 默认值 |
|--------|------|--------|--------|
| `PORT` | 服务监听的端口 | `8787` | `8787` |
| `DATABASE_URL` | SQLite数据库文件路径 | `./data/quota.db` | `./data/quota.db` |
| `LOG_LEVEL` | 日志级别 | `info`, `debug`, `warn`, `error` | `info` |
| `CORS_ORIGIN` | CORS允许的源 | `*`, `https://example.com` | `*` |
| `RATE_LIMIT` | 速率限制（请求/分钟） | `100` | `100` |

## 使用示例

### 示例1: 基本验证

```bash
# 设置环境变量
export ADMIN_TOKEN="my-secret-token"
export PORT="8787"
export DATABASE_URL="./data/quota.db"

# 运行验证
./verify-env-config.sh
```

输出示例:
```
[INFO] 开始验证quota-proxy环境变量配置...
[INFO] 环境变量文件不存在: .env (将检查已设置的环境变量)
[INFO] 检查必需环境变量...
[SUCCESS] 环境变量已设置: ADMIN_TOKEN
[INFO] 检查可选环境变量...
[SUCCESS] 环境变量已设置: PORT
[SUCCESS] 环境变量已设置: DATABASE_URL
[WARNING] 可选环境变量未设置: LOG_LEVEL
[WARNING] 可选环境变量未设置: CORS_ORIGIN
[WARNING] 可选环境变量未设置: RATE_LIMIT
[SUCCESS] 端口格式有效: 8787
[SUCCESS] 数据库路径格式有效: ./data/quota.db
[INFO] 配置建议检查...
[INFO] 建议设置LOG_LEVEL环境变量控制日志详细程度（可选：debug, info, warn, error）
[INFO] 验证完成
[INFO] 错误数: 0
[INFO] 警告数: 3
[WARNING] 环境变量配置验证通过，但有警告需要关注
```

### 示例2: 使用.env文件

创建 `.env` 文件:
```bash
cat > .env << EOF
ADMIN_TOKEN=my-secret-admin-token
PORT=8787
DATABASE_URL=./data/quota.db
LOG_LEVEL=info
CORS_ORIGIN=*
RATE_LIMIT=100
EOF
```

运行验证:
```bash
./verify-env-config.sh --verbose
```

### 示例3: 干运行模式

```bash
./verify-env-config.sh --dry-run
```

输出示例:
```
[INFO] === 干运行模式 ===
[INFO] 将执行以下验证步骤:
[INFO] 1. 加载环境变量文件
[INFO] 2. 检查必需环境变量 (ADMIN_TOKEN)
[INFO] 3. 检查可选环境变量 (PORT, DATABASE_URL等)
[INFO] 4. 验证端口格式
[INFO] 5. 验证数据库路径格式
[INFO] 6. 提供配置建议
[INFO] === 干运行结束 ===
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Verify Environment Configuration

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-env:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Verify environment configuration
      run: |
        cd quota-proxy
        chmod +x verify-env-config.sh
        ./verify-env-config.sh --dry-run
      
    - name: Create test environment
      run: |
        cd quota-proxy
        echo "ADMIN_TOKEN=test-token" > .env.test
        echo "PORT=8787" >> .env.test
        echo "DATABASE_URL=./test.db" >> .env.test
        
    - name: Run verification with test env
      run: |
        cd quota-proxy
        ADMIN_TOKEN=test-token PORT=8787 DATABASE_URL=./test.db ./verify-env-config.sh
```

### GitLab CI 示例

```yaml
verify-env:
  stage: test
  script:
    - cd quota-proxy
    - chmod +x verify-env-config.sh
    - ./verify-env-config.sh --dry-run
    - ADMIN_TOKEN=test-token PORT=8787 DATABASE_URL=./test.db ./verify-env-config.sh
```

## 故障排除

### 常见问题

1. **ADMIN_TOKEN未设置错误**
   ```
   [ERROR] 必需环境变量未设置: ADMIN_TOKEN (管理员令牌（用于管理API）)
   ```
   **解决方案**: 设置 `ADMIN_TOKEN` 环境变量
   ```bash
   export ADMIN_TOKEN="your-secret-token"
   ```

2. **端口格式无效错误**
   ```
   [ERROR] 端口格式无效: abc (必须是数字)
   ```
   **解决方案**: 确保端口是有效的数字
   ```bash
   export PORT="8787"  # 正确
   # export PORT="abc"  # 错误
   ```

3. **环境变量文件不可读错误**
   ```
   [ERROR] 环境变量文件不可读: .env
   ```
   **解决方案**: 检查文件权限
   ```bash
   chmod 644 .env
   ```

4. **数据库路径格式警告**
   ```
   [WARNING] 数据库路径可能无效: data/quota (建议使用.db、.sqlite或.sqlite3扩展名)
   ```
   **解决方案**: 使用标准扩展名
   ```bash
   export DATABASE_URL="./data/quota.db"  # 正确
   # export DATABASE_URL="./data/quota"   # 警告
   ```

### 调试技巧

1. **启用详细输出**
   ```bash
   ./verify-env-config.sh --verbose
   ```

2. **检查当前环境变量**
   ```bash
   printenv | grep -E "ADMIN_TOKEN|PORT|DATABASE_URL"
   ```

3. **测试特定配置**
   ```bash
   ADMIN_TOKEN=test PORT=8080 ./verify-env-config.sh
   ```

## 最佳实践

### 1. 生产环境配置

```bash
# 创建生产环境配置文件
cat > /opt/roc/quota-proxy/.env.production << EOF
ADMIN_TOKEN=$(openssl rand -hex 32)
PORT=8787
DATABASE_URL=/opt/roc/quota-proxy/data/quota.db
LOG_LEVEL=info
CORS_ORIGIN=https://your-domain.com
RATE_LIMIT=1000
EOF

# 验证生产配置
./verify-env-config.sh --config-file /opt/roc/quota-proxy/.env.production
```

### 2. 开发环境配置

```bash
# 创建开发环境配置文件
cat > .env.development << EOF
ADMIN_TOKEN=dev-admin-token
PORT=8787
DATABASE_URL=./data/quota-dev.db
LOG_LEVEL=debug
CORS_ORIGIN=*
RATE_LIMIT=100
EOF

# 验证开发配置
./verify-env-config.sh --env-file .env.development
```

### 3. 自动化验证

```bash
#!/bin/bash
# deploy.sh - 部署脚本示例

# 验证环境配置
echo "验证环境配置..."
cd /opt/roc/quota-proxy
if ! ./verify-env-config.sh; then
    echo "环境配置验证失败，请修复错误后重试"
    exit 1
fi

# 继续部署流程
echo "环境配置验证通过，开始部署..."
# ... 部署代码 ...
```

## 相关文档

- [部署指南 - SQLite持久化](./DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md)
- [快速健康检查](./QUICK-HEALTH-CHECK.md)
- [部署验证](./DEPLOY-VERIFICATION.md)
- [管理API完整性验证](./VERIFY-ADMIN-API-COMPLETE.md)

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持必需和可选环境变量检查
- 支持端口格式验证
- 支持数据库路径格式验证
- 支持配置文件加载
- 支持干运行模式
- 支持详细输出模式
- 提供配置建议和最佳实践

## 贡献指南

欢迎提交问题和拉取请求改进此脚本。请确保:
1. 遵循现有的代码风格
2. 添加相应的测试用例
3. 更新文档
4. 验证脚本功能正常

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。