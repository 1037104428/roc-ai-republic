# 管理API完整性验证脚本

## 概述

`verify-admin-api-complete.sh` 是一个用于验证 quota-proxy 管理API完整性的脚本。它检查所有关键的管理API端点是否正常工作，确保系统功能完整。

## 功能特性

- ✅ **全面API测试**: 验证所有关键管理API端点
- ✅ **健康检查**: 确保服务器正常运行
- ✅ **状态验证**: 检查系统状态和模型端点
- ✅ **密钥管理**: 测试API密钥创建和管理功能
- ✅ **使用统计**: 验证使用统计和重置功能
- ✅ **系统信息**: 检查系统信息端点
- ✅ **干运行模式**: 支持干运行模式，只显示命令不执行
- ✅ **彩色输出**: 提供清晰的彩色输出，便于识别结果
- ✅ **详细日志**: 显示详细的测试过程和结果

## 快速开始

### 基本使用

```bash
# 确保服务器正在运行
cd quota-proxy
npm start

# 在另一个终端运行验证脚本
chmod +x verify-admin-api-complete.sh
./verify-admin-api-complete.sh
```

### 带环境变量

```bash
# 设置自定义配置
export PORT=8888
export HOST="localhost"
export ADMIN_TOKEN="your-admin-token"
./verify-admin-api-complete.sh
```

### 干运行模式

```bash
# 查看将要执行的测试
./verify-admin-api-complete.sh --dry-run
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--dry-run` | 干运行模式，只显示命令不执行 | `false` |
| `--port PORT` | 服务器端口 | `8787` |
| `--host HOST` | 服务器主机 | `127.0.0.1` |
| `--admin-token TOKEN` | 管理员令牌 | `test-admin-token` |
| `--help` | 显示帮助信息 | - |

## 测试的API端点

脚本验证以下API端点：

### 1. 健康检查端点
- **端点**: `GET /healthz`
- **预期状态码**: `200`
- **描述**: 检查服务器是否健康运行

### 2. 状态端点
- **端点**: `GET /status`
- **预期状态码**: `200`
- **描述**: 获取服务器状态信息

### 3. API密钥管理
- **端点**: `GET /admin/keys`
- **预期状态码**: `200`
- **描述**: 获取所有API密钥列表

### 4. 试用密钥创建
- **端点**: `POST /admin/keys/trial`
- **预期状态码**: `201`
- **描述**: 创建新的试用密钥

### 5. 使用统计
- **端点**: `GET /admin/usage`
- **预期状态码**: `200`
- **描述**: 获取API使用统计信息

### 6. 重置使用统计
- **端点**: `POST /admin/reset-usage`
- **预期状态码**: `200`
- **描述**: 重置指定密钥或所有密钥的使用统计

### 7. 系统信息
- **端点**: `GET /admin/system`
- **预期状态码**: `200`
- **描述**: 获取系统信息（内存、数据库等）

### 8. 模型列表
- **端点**: `GET /v1/models`
- **预期状态码**: `200`
- **描述**: 获取支持的模型列表

## 使用示例

### 示例1: 基本验证

```bash
# 启动服务器
cd quota-proxy
npm start &

# 等待服务器启动
sleep 5

# 运行验证
./verify-admin-api-complete.sh
```

输出示例:
```
[INFO] 开始验证quota-proxy管理API完整性
[INFO] 服务器地址: http://127.0.0.1:8787
[INFO] 管理员令牌: test-adm...
[INFO] 干运行模式: false
[INFO] 服务器正在运行: http://127.0.0.1:8787
[INFO] 测试: 健康检查端点
[SUCCESS]  ✓ 端点 /healthz 返回 200
...
[INFO] 测试完成: 8 通过, 0 失败
[SUCCESS] 所有管理API端点验证通过！
```

### 示例2: 自定义配置

```bash
# 使用自定义配置
./verify-admin-api-complete.sh \
  --port 8888 \
  --host "192.168.1.100" \
  --admin-token "production-admin-token-123"
```

### 示例3: 干运行模式

```bash
# 查看将要执行的测试
./verify-admin-api-complete.sh --dry-run
```

输出示例:
```
[INFO] 开始验证quota-proxy管理API完整性
[INFO] 服务器地址: http://127.0.0.1:8787
[INFO] 管理员令牌: test-adm...
[INFO] 干运行模式: true
[INFO] 干运行: 健康检查端点
[INFO]   命令: curl -s -o /dev/null -w '%{http_code}' -X GET http://127.0.0.1:8787/healthz
[INFO]   预期状态码: 200
...
```

## CI/CD集成

### GitHub Actions 示例

```yaml
name: Verify Admin API

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-admin-api:
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
    
    - name: Start server
      run: |
        cd quota-proxy
        npm start &
        sleep 10
    
    - name: Run API verification
      run: |
        cd quota-proxy
        chmod +x verify-admin-api-complete.sh
        ./verify-admin-api-complete.sh
```

### 环境变量配置

| 环境变量 | 描述 | 默认值 |
|----------|------|--------|
| `PORT` | 服务器端口 | `8787` |
| `HOST` | 服务器主机 | `127.0.0.1` |
| `ADMIN_TOKEN` | 管理员令牌 | `test-admin-token` |
| `DRY_RUN` | 干运行模式 | `false` |

## 故障排除

### 常见问题

#### 1. 服务器未运行
```
[ERROR] 请先启动quota-proxy服务器
[INFO] 启动命令: cd quota-proxy && npm start
```

**解决方案**:
```bash
cd quota-proxy
npm start &
sleep 5  # 等待服务器启动
```

#### 2. 认证失败
```
[ERROR]  ✗ 端点 /admin/keys 返回 401 (预期: 200)
```

**解决方案**:
- 检查 `ADMIN_TOKEN` 环境变量是否正确
- 确保服务器配置了正确的管理员令牌

#### 3. 连接被拒绝
```
[ERROR] 命令 'curl' 失败: Connection refused
```

**解决方案**:
- 检查服务器是否在指定端口运行
- 检查防火墙设置
- 验证主机和端口配置

### 调试模式

```bash
# 启用详细输出
set -x
./verify-admin-api-complete.sh
set +x
```

## 相关文档

- [quota-proxy 部署指南](../docs/quota-proxy-deployment.md)
- [API 文档](../docs/api-reference.md)
- [管理API使用指南](../docs/admin-api-guide.md)
- [验证脚本体系](../README.md#验证脚本)

## 贡献

欢迎提交问题和改进建议！

1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/improve-verification`)
3. 提交更改 (`git commit -am 'Add new verification feature'`)
4. 推送到分支 (`git push origin feature/improve-verification`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。