# install-cn.sh 功能验证指南

本文档详细说明 `scripts/install-cn.sh` 脚本的功能特性、验证方法和使用示例。

## 核心功能特性

### ✅ 已实现功能

1. **国内源优先策略**
   - 默认使用 `https://registry.npmmirror.com`（阿里云镜像）
   - 自动检测CN源可用性
   - 支持自定义CN源地址

2. **智能回退机制**
   - CN源安装失败时自动回退到 `https://registry.npmjs.org`
   - 提供详细的错误信息和调试建议
   - 支持强制使用CN源模式（`--force-cn`）

3. **网络连通性测试**
   - 独立的网络测试模式（`--network-test`）
   - 测试CN源、备用源、GitHub/Gitee可达性
   - 提供网络状态总结和建议

4. **版本管理**
   - 支持指定OpenClaw版本（`--version`）
   - 默认安装最新版本（`latest`）
   - 支持环境变量覆盖（`OPENCLAW_VERSION`）

5. **安全自检**
   - 安装前检查Node.js版本（>=20）
   - 安装后验证 `openclaw --version`
   - 提供PATH问题诊断

6. **干运行模式**
   - 预览安装命令而不执行（`--dry-run`）
   - 用于测试和调试

### 🔧 技术实现

```bash
# 主要函数
run_network_test()      # 网络连通性测试
install_openclaw()      # 安装函数（支持重试）
usage()                 # 帮助信息

# 错误处理
- 语法检查（bash -n）
- 参数验证
- 网络超时处理（5秒超时）
- 安装失败重试机制
```

## 验证方法

### 1. 语法检查
```bash
bash -n scripts/install-cn.sh
```

### 2. 帮助信息验证
```bash
./scripts/install-cn.sh --help
```
预期输出：包含"OpenClaw CN installer"和选项说明

### 3. 网络测试模式
```bash
./scripts/install-cn.sh --network-test
```
预期输出：显示各服务的连通性状态

### 4. 干运行测试
```bash
./scripts/install-cn.sh --dry-run
```
预期输出：显示将要执行的命令（以[dry-run]开头）

### 5. 版本指定测试
```bash
./scripts/install-cn.sh --version 0.3.12 --dry-run
```
预期输出：包含"openclaw@0.3.12"

### 6. 环境变量测试
```bash
OPENCLAW_VERSION=0.3.12 ./scripts/install-cn.sh --dry-run
```
预期输出：使用环境变量指定的版本

### 7. 强制CN模式测试
```bash
./scripts/install-cn.sh --force-cn --dry-run
```
预期输出：包含"Force using CN registry"

## 使用示例

### 基本安装
```bash
# 一键安装（推荐）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 或下载后安装
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o install-cn.sh
bash install-cn.sh
```

### 指定版本
```bash
# 安装特定版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12

# 使用环境变量
OPENCLAW_VERSION=0.3.12 bash install-cn.sh
```

### 网络诊断
```bash
# 仅测试网络（不安装）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --network-test

# 测试并显示详细输出
./scripts/install-cn.sh --network-test --verbose
```

### 调试模式
```bash
# 干运行（预览命令）
./scripts/install-cn.sh --dry-run

# 强制使用CN源（跳过回退）
./scripts/install-cn.sh --force-cn

# 自定义源地址
./scripts/install-cn.sh --registry-cn https://custom.registry.cn
```

## 故障排除

### 常见问题

1. **Node.js版本过低**
   ```
   [cn-pack] ERROR: Node.js version v18.x.x is too old. OpenClaw requires Node.js >= 20.
   ```
   解决方案：升级Node.js到20或更高版本

2. **网络连接问题**
   ```
   [cn-pack] ⚠️ CN registry not reachable
   ```
   解决方案：
   - 检查网络连接
   - 使用 `--network-test` 诊断
   - 尝试备用源（自动回退）

3. **安装后找不到命令**
   ```
   [cn-pack] Install finished but 'openclaw' not found in PATH.
   ```
   解决方案：
   - 重新打开终端
   - 检查npm全局路径：`npm bin -g`
   - 将路径添加到PATH环境变量

### 调试命令

```bash
# 检查Node.js版本
node -v

# 检查npm版本
npm -v

# 测试npm源连通性
curl -fsS https://registry.npmmirror.com/-/ping
curl -fsS https://registry.npmjs.org/-/ping

# 检查全局安装路径
npm config get prefix
npm bin -g

# 验证OpenClaw安装
which openclaw
openclaw --version
```

## 自动化验证脚本

我们提供了自动化验证脚本：
```bash
./scripts/verify-install-cn.sh
```

该脚本执行以下验证：
- 语法检查
- 帮助输出验证
- 网络测试模式验证
- 干运行模式验证
- 版本指定验证
- 环境变量支持验证

## 部署验证

### 服务器端验证
```bash
# 检查quota-proxy服务状态
ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose ps'

# 检查健康端点
ssh root@8.210.185.194 'curl -fsS http://127.0.0.1:8787/healthz'
```

### 客户端验证
```bash
# 验证安装脚本可访问性
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o /dev/null && echo "✅ 脚本可访问"

# 验证安装流程
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run
```

## 更新记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-02-10 | v1.0 | 初始版本，包含完整功能验证文档 |
| 2026-02-10 | v1.1 | 添加自动化验证脚本 |

## 相关文档

- [快速开始指南](../docs/quickstart.md)
- [CN包安装验证指南](../docs/install-cn-quick-verify.md)
- [API网关部署指南](../docs/quota-proxy-deployment.md)
- [故障排除指南](../docs/troubleshooting.md)