# OpenClaw 国内安装网络指南

本文档详细说明 OpenClaw 国内安装脚本的网络可达性检测、回退策略和自检机制。

## 网络架构

```
用户机器
    ├── CN npm 镜像 (registry.npmmirror.com) ← 首选
    ├── npmjs.org 官方源 ← 回退
    ├── GitHub raw ← 脚本/文档源
    └── Gitee raw ← 国内镜像源
```

## 安装脚本特性

### 1. 网络可达性检测

安装前可运行网络测试：

```bash
# 运行网络测试
bash install-cn.sh --network-test

# 或使用独立测试脚本
./scripts/install-cn-network-test.sh
```

测试内容包括：
- CN npm 镜像可达性 (`registry.npmmirror.com/-/ping`)
- npmjs 官方源可达性 (`registry.npmjs.org/-/ping`)
- GitHub raw 可达性（文档/脚本源）
- Gitee raw 可达性（国内镜像源）

### 2. 智能回退策略

默认行为：
1. 优先使用 CN npm 镜像
2. 如果安装失败，自动回退到 npmjs 官方源
3. 两次尝试间隔 2 秒

强制模式：
```bash
# 强制使用 CN 源（不自动回退）
bash install-cn.sh --force-cn

# 指定特定 registry
NPM_REGISTRY=https://registry.npmmirror.com bash install-cn.sh
```

### 3. 自检机制

安装完成后自动检查：
```bash
# 检查 openclaw 命令是否可用
openclaw --version

# 如果命令未找到，显示 PATH 调试信息
npm config get prefix
npm bin -g
```

## 安装选项

### 基础安装
```bash
# 一键安装（推荐）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 指定版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12

# 仅测试网络
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --network-test
```

### 高级选项
```bash
# 使用环境变量
OPENCLAW_VERSION=latest \
NPM_REGISTRY=https://registry.npmmirror.com \
bash install-cn.sh

# 使用参数
bash install-cn.sh \
  --version latest \
  --registry-cn https://registry.npmmirror.com \
  --registry-fallback https://registry.npmjs.org \
  --dry-run
```

## 故障排除

### 网络问题

**症状**: 安装超时或失败

**解决**:
```bash
# 1. 运行网络测试
bash install-cn.sh --network-test

# 2. 手动测试 registry
curl -fsS -m 5 https://registry.npmmirror.com/-/ping
curl -fsS -m 5 https://registry.npmjs.org/-/ping

# 3. 使用代理（如有）
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
bash install-cn.sh
```

### Node.js 版本问题

**症状**: "Node.js version is too old"

**解决**:
```bash
# 检查当前版本
node -v

# 需要 Node.js >= 20
# 升级方法：
# Ubuntu/Debian: nvm install 20 && nvm use 20
# macOS: brew install node@20
# 官方包: https://nodejs.org/
```

### PATH 问题

**症状**: 安装成功但 `openclaw` 命令未找到

**解决**:
```bash
# 1. 检查 npm 全局路径
npm config get prefix
npm bin -g

# 2. 添加到 PATH（临时）
export PATH="$(npm bin -g):$PATH"

# 3. 永久添加到 shell 配置
echo 'export PATH="$(npm bin -g):$PATH"' >> ~/.bashrc
# 或
echo 'export PATH="$(npm bin -g):$PATH"' >> ~/.zshrc

# 4. 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc
```

## 网络测试脚本

独立网络测试脚本：`scripts/install-cn-network-test.sh`

```bash
# 运行测试
./scripts/install-cn-network-test.sh

# 输出示例：
OpenClaw CN Installer - Network Connectivity Test
==================================================
Testing GitHub raw ... ✓ OK
Testing Gitee raw ... ✓ OK
Testing npm registry: https://registry.npmmirror.com ... ✓ OK
Testing npm registry: https://registry.npmjs.org ... ✓ OK

=== Network Test Results ===
✅ Recommended: Use CN registry (https://registry.npmmirror.com)
   Command: NPM_REGISTRY=https://registry.npmmirror.com bash install-cn.sh
```

## 验证安装

安装完成后验证：

```bash
# 1. 检查版本
openclaw --version

# 2. 检查状态
openclaw status

# 3. 测试模型
openclaw models status

# 4. 启动网关
openclaw gateway start
```

## 相关脚本

- `scripts/install-cn.sh` - 主安装脚本
- `scripts/install-cn-network-test.sh` - 网络测试脚本
- `scripts/verify-install-cn.sh` - 安装验证脚本
- `scripts/probe-roc-all.sh` - 全链路探活脚本

## 更新日志

### v1.1.0 (2026-02-09)
- 新增 `--network-test` 选项
- 新增 `--force-cn` 选项
- 增强网络可达性检测
- 添加独立网络测试脚本
- 完善故障排除文档

### v1.0.0 (2026-02-08)
- 初始版本发布
- 基础 CN 镜像支持
- 自动回退机制
- 基础自检功能