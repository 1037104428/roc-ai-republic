# 快速验证示例 - 中华AI共和国项目

本文档提供中华AI共和国项目的快速验证示例，帮助用户快速验证核心功能。

## 快速开始

### 1. 验证项目完整性

```bash
# 进入项目目录
cd /home/kai/.openclaw/workspace/roc-ai-republic

# 运行增强版验证文档检查
cd quota-proxy && ./verify-validation-docs-enhanced.sh
```

### 2. 验证安装脚本

```bash
# 验证安装脚本基本功能
./scripts/quick-verify-install-cn.sh

# 增强版验证（更全面）
./scripts/quick-verify-install-cn-enhanced.sh

# 完整验证（所有功能）
./scripts/verify-install-cn.sh
```

### 3. 验证Admin API

```bash
# 快速验证Admin API
cd quota-proxy && ./quick-verify-admin-api.sh

# 快速测试Admin API（Bash脚本）
cd quota-proxy && ./quick-test-admin-api.sh

# Node.js测试脚本
cd quota-proxy && node test-admin-api-quick.js
```

### 4. 验证SQLite持久化

```bash
# 验证SQLite持久化功能
cd quota-proxy && ./verify-sqlite-persistence.sh

# 验证数据库初始化
cd quota-proxy && ./check-db.sh --init
```

### 5. 验证环境配置

```bash
# 验证环境变量
cd quota-proxy && ./verify-env.sh --dry-run

# 验证完整配置
cd quota-proxy && ./verify-config.sh --dry-run
```

### 6. 验证Web站点部署就绪

```bash
# 验证Web站点部署就绪状态
./scripts/verify-web-deployment-ready.sh
```

## 场景示例

### 场景1：初次部署验证

```bash
# 1. 验证环境配置
cd quota-proxy && ./verify-env.sh

# 2. 验证数据库初始化
cd quota-proxy && ./check-db.sh --init

# 3. 启动Admin API服务器
cd quota-proxy && node server-sqlite-admin.js &

# 4. 验证Admin API功能
cd quota-proxy && ./quick-verify-admin-api.sh

# 5. 验证安装脚本
./scripts/quick-verify-install-cn.sh
```

### 场景2：日常健康检查

```bash
# 1. 快速健康检查
cd quota-proxy && ./verify-admin-api.sh --health

# 2. 验证数据库状态
cd quota-proxy && ./check-db.sh --status

# 3. 验证配置完整性
cd quota-proxy && ./verify-config.sh --quick

# 4. 验证安装脚本状态
./scripts/quick-verify-install-cn.sh --basic
```

### 场景3：Admin API测试

```bash
# 1. 启动测试服务器
cd quota-proxy && node server-sqlite-admin.js &

# 2. 运行完整测试
cd quota-proxy && ./quick-test-admin-api.sh

# 3. 验证密钥管理
cd quota-proxy && ./test-admin-keys-usage.sh

# 4. 验证使用统计
cd quota-proxy && ./verify-admin-api.sh --usage
```

## 验证工具链概览

### 安装脚本验证工具
- `quick-verify-install-cn.sh` - 快速验证
- `quick-verify-install-cn-enhanced.sh` - 增强版验证
- `verify-install-cn.sh` - 完整验证

### Admin API验证工具
- `quick-verify-admin-api.sh` - 快速验证
- `quick-test-admin-api.sh` - Bash脚本测试
- `test-admin-api-quick.js` - Node.js测试
- `test-admin-keys-usage.sh` - 密钥管理测试

### 数据库验证工具
- `verify-sqlite-persistence.sh` - SQLite持久化验证
- `check-db.sh` - 数据库检查工具
- `verify-env.sh` - 环境变量验证
- `verify-config.sh` - 配置验证

### 部署验证工具
- `verify-web-deployment-ready.sh` - Web站点部署就绪验证
- `verify-admin-api.sh` - Admin API部署验证

## 故障排除

### 常见问题

1. **验证脚本权限问题**
   ```bash
   chmod +x scripts/*.sh quota-proxy/*.sh
   ```

2. **环境变量未设置**
   ```bash
   export ADMIN_TOKEN=your_admin_token
   export PORT=8787
   export DATABASE_PATH=./quota-proxy.db
   ```

3. **数据库初始化失败**
   ```bash
   cd quota-proxy && sqlite3 quota-proxy.db < init-db.sql
   ```

4. **Admin API服务器启动失败**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :8787
   
   # 检查Node.js版本
   node --version
   ```

### 验证结果解读

- **✅ 通过** - 功能正常
- **⚠️ 警告** - 需要注意的问题
- **❌ 失败** - 需要修复的问题
- **ℹ️ 信息** - 参考信息

## CI/CD集成示例

### GitHub Actions

```yaml
name: 验证测试

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: 验证安装脚本
      run: |
        chmod +x scripts/*.sh
        ./scripts/quick-verify-install-cn.sh
    
    - name: 验证Admin API
      run: |
        cd quota-proxy
        chmod +x *.sh
        ./quick-verify-admin-api.sh --dry-run
    
    - name: 验证SQLite持久化
      run: |
        cd quota-proxy
        ./verify-sqlite-persistence.sh --quick
```

### 本地CI脚本

```bash
#!/bin/bash
# local-ci.sh - 本地持续集成验证

set -e

echo "=== 开始验证测试 ==="

# 1. 验证安装脚本
echo "1. 验证安装脚本..."
./scripts/quick-verify-install-cn.sh

# 2. 验证Admin API
echo "2. 验证Admin API..."
cd quota-proxy
./quick-verify-admin-api.sh --dry-run

# 3. 验证SQLite持久化
echo "3. 验证SQLite持久化..."
./verify-sqlite-persistence.sh --quick

# 4. 验证Web部署就绪
echo "4. 验证Web部署就绪..."
cd ..
./scripts/verify-web-deployment-ready.sh

echo "=== 所有验证通过 ==="
```

## 相关文档

- [验证工具链概览](validation-toolchain-overview.md)
- [快速验证工具指南](../quota-proxy/QUICK-VALIDATION-TOOLS-GUIDE.md)
- [验证快速索引](../quota-proxy/VALIDATION-QUICK-INDEX.md)
- [Admin API使用指南](../quota-proxy/ADMIN-API-GUIDE.md)
- [安装脚本验证指南](install-cn-script-verification-guide.md)

## 更新日志

### 2026-02-12
- 创建快速验证示例文档
- 添加快速开始场景
- 添加验证工具链概览
- 添加故障排除指南
- 添加CI/CD集成示例