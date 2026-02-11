# 试用密钥流程验证指南

本文档提供`verify-trial-key-flow.sh`脚本的使用指南，该脚本用于验证quota-proxy试用密钥的完整流程。

## 快速开始

### 基本使用

```bash
# 授予执行权限
chmod +x quota-proxy/verify-trial-key-flow.sh

# 运行验证（使用默认配置）
./quota-proxy/verify-trial-key-flow.sh

# 指定主机和管理员令牌
./quota-proxy/verify-trial-key-flow.sh http://localhost:8787 your-admin-token
```

### 干运行模式

```bash
# 干运行模式，只显示将要执行的命令而不实际执行
./quota-proxy/verify-trial-key-flow.sh --dry-run
```

### 安静模式

```bash
# 安静模式，减少输出信息
./quota-proxy/verify-trial-key-flow.sh --quiet
```

## 功能特性

### 验证步骤

脚本执行以下5个验证步骤：

1. **创建试用密钥** - 通过`POST /admin/keys/trial`创建试用密钥
2. **使用试用密钥** - 使用创建的密钥调用API端点
3. **查询密钥使用情况** - 通过`GET /admin/keys/{key}`查询密钥详细信息
4. **查询所有密钥** - 通过`GET /admin/keys`查询所有密钥列表
5. **删除试用密钥** - 通过`DELETE /admin/keys/{key}`删除创建的试用密钥

### 支持的功能

- ✅ **服务检查** - 自动检查quota-proxy服务是否运行
- ✅ **颜色输出** - 使用颜色区分不同级别的信息
- ✅ **错误处理** - 完善的错误处理和恢复机制
- ✅ **参数配置** - 支持自定义主机和管理员令牌
- ✅ **运行模式** - 支持干运行和安静模式
- ✅ **依赖检查** - 自动检查curl命令是否可用

## 命令行选项

| 选项 | 描述 | 示例 |
|------|------|------|
| `HOST` | 目标主机URL（可选） | `http://localhost:8787` |
| `ADMIN_TOKEN` | 管理员令牌（可选） | `your-admin-token` |
| `--dry-run` | 干运行模式，只显示命令 | `--dry-run` |
| `--quiet` | 安静模式，减少输出 | `--quiet` |
| `--help` | 显示帮助信息 | `--help` |

## 使用示例

### 示例1：完整验证

```bash
# 完整验证流程
./quota-proxy/verify-trial-key-flow.sh http://localhost:8787 my-admin-token
```

**预期输出：**
```
ℹ️  开始验证试用密钥完整流程
ℹ️  目标主机: http://localhost:8787
ℹ️  管理员令牌: my-admin-to...
✅ curl命令可用
ℹ️  检查quota-proxy服务是否运行...
✅ 服务运行正常
ℹ️  步骤1: 创建试用密钥...
✅ 试用密钥创建成功: roc_trial_abc123def456
ℹ️  步骤2: 使用试用密钥调用API...
✅ API调用成功
ℹ️  步骤3: 查询密钥使用情况...
✅ 密钥查询成功
ℹ️  步骤4: 查询所有密钥...
✅ 密钥列表查询成功
ℹ️  步骤5: 删除试用密钥...
✅ 试用密钥删除成功
ℹ️  验证完成
ℹ️  通过步骤: 5/5
✅ 所有验证步骤通过！试用密钥流程完整可用
```

### 示例2：干运行验证

```bash
# 干运行验证
./quota-proxy/verify-trial-key-flow.sh --dry-run
```

**预期输出：**
```
ℹ️  开始验证试用密钥完整流程
ℹ️  目标主机: http://localhost:8787
ℹ️  管理员令牌: dev-admin-t...
✅ curl命令可用
ℹ️  检查quota-proxy服务是否运行...
ℹ️  [干运行] 跳过服务检查
ℹ️  步骤1: 创建试用密钥...
ℹ️  [干运行] 将执行命令:
curl -s -X POST 'http://localhost:8787/admin/keys/trial' ...
预期响应: {"success": true, "key": "roc_trial_..."}
...
```

## 故障排除

### 常见问题

#### 1. 服务未运行

**错误信息：**
```
❌ 服务未运行或无法访问 http://localhost:8787/healthz
```

**解决方案：**
```bash
# 启动quota-proxy服务
cd quota-proxy
npm start
```

#### 2. 管理员令牌错误

**错误信息：**
```
❌ 密钥查询失败
响应: {"success": false, "error": "Invalid admin token"}
```

**解决方案：**
```bash
# 设置正确的ADMIN_TOKEN环境变量
export ADMIN_TOKEN=your-correct-token

# 重新运行验证
./quota-proxy/verify-trial-key-flow.sh http://localhost:8787 $ADMIN_TOKEN
```

#### 3. curl命令未找到

**错误信息：**
```
❌ curl命令未找到，请先安装curl
```

**解决方案：**
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS
brew install curl
```

### 调试模式

如果需要更详细的调试信息，可以修改脚本：

```bash
# 在脚本开头添加
set -x  # 启用调试模式

# 或者运行脚本时启用
bash -x ./quota-proxy/verify-trial-key-flow.sh
```

## CI/CD集成

### GitHub Actions 集成示例

```yaml
name: Verify Trial Key Flow

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install dependencies
      run: |
        cd quota-proxy
        npm ci
    
    - name: Start quota-proxy
      run: |
        cd quota-proxy
        npm start &
        sleep 5
    
    - name: Run verification
      run: |
        chmod +x quota-proxy/verify-trial-key-flow.sh
        ./quota-proxy/verify-trial-key-flow.sh --quiet
```

## 相关文档

- [管理API快速使用示例](./ADMIN_API_QUICK_EXAMPLE.md) - 管理API的详细使用示例
- [部署状态检查](./CHECK_DEPLOYMENT_STATUS.md) - 服务部署状态检查指南
- [环境变量配置验证](./VERIFY_ENV_CONFIG.md) - 环境变量配置验证指南
- [SQLite持久化验证](./VERIFY_SQLITE_PERSISTENCE.md) - SQLite数据库功能验证指南

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持试用密钥完整流程验证
- 包含5个验证步骤：创建、使用、查询、列表、删除
- 支持干运行和安静模式
- 提供颜色输出和错误处理

## 维护说明

### 脚本维护

1. **定期更新** - 随着quota-proxy API的变化更新脚本
2. **测试覆盖** - 确保脚本覆盖所有关键功能
3. **错误处理** - 完善错误处理和恢复机制

### 依赖管理

- **必需依赖**: curl
- **可选依赖**: python3（用于JSON格式化输出）
- **环境要求**: quota-proxy服务运行中

### 贡献指南

欢迎提交问题和改进建议：

1. 在GitHub仓库创建Issue
2. 提交Pull Request
3. 确保代码符合现有风格
4. 更新相关文档