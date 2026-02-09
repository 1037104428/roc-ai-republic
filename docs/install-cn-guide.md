# OpenClaw 国内一键安装脚本指南

## 概述

`install-cn.sh` 是一个专为国内用户优化的 OpenClaw 安装脚本，具有以下特点：

- **国内镜像优先**：默认使用 npmmirror.com 镜像源
- **智能回退策略**：当国内镜像不可用时自动回退到 npmjs.org
- **完整自检**：安装后自动验证 `openclaw --version` 是否可用
- **无侵入**：不会永久修改用户的 npm 配置

## 快速开始

### 一键安装（推荐）

```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

### 指定版本安装

```bash
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
```

### 本地运行

```bash
# 下载脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o install-cn.sh
chmod +x install-cn.sh

# 运行（支持所有参数）
./install-cn.sh --version latest --dry-run
```

## 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--version <ver>` | 安装指定版本 | `latest` |
| `--registry-cn <url>` | 国内镜像地址 | `https://registry.npmmirror.com` |
| `--registry-fallback <url>` | 回退镜像地址 | `https://registry.npmjs.org` |
| `--dry-run` | 仅显示命令不执行 | - |
| `-h, --help` | 显示帮助信息 | - |

## 环境变量

也可以通过环境变量配置：

```bash
# 设置版本
export OPENCLAW_VERSION="0.3.12"

# 设置镜像源
export NPM_REGISTRY="https://registry.npmmirror.com"
export NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"

# 运行脚本
bash install-cn.sh
```

## 回退策略详解

脚本采用三级回退策略确保安装成功：

1. **首选国内镜像** (`npmmirror.com`)
   - 网络延迟低，下载速度快
   - 支持断点续传
   - 每日同步 npmjs.org

2. **回退到官方源** (`npmjs.org`)
   - 当国内镜像不可用时自动切换
   - 确保安装总能成功

3. **最终检查** 
   - 验证 `openclaw` 命令是否可用
   - 检查网关服务状态
   - 验证配置文件

## 自检功能

安装完成后，脚本会自动运行以下检查：

### 1. 命令验证
```bash
openclaw --version
```
期望输出：`openclaw/x.x.x`

### 2. 网关状态检查
```bash
openclaw gateway status
```
期望输出：包含 "running" 或 "active"

### 3. 配置文件检查
检查 `~/.openclaw/openclaw.json` 是否存在

### 4. 全局安装验证
```bash
npm list -g openclaw
```
验证 npm 全局安装是否成功

## 故障排除

### 问题：`openclaw: command not found`

**原因**：npm 全局 bin 目录不在 PATH 中

**解决方案**：
```bash
# 查看 npm 全局 bin 目录
npm bin -g

# 添加到 PATH（临时）
export PATH="$PATH:$(npm bin -g)"

# 永久添加到 shell 配置（~/.bashrc 或 ~/.zshrc）
echo 'export PATH="$PATH:$(npm bin -g)"' >> ~/.bashrc
source ~/.bashrc
```

### 问题：安装超时

**原因**：网络连接问题

**解决方案**：
```bash
# 使用超时参数
./install-cn.sh --registry-cn "https://registry.npmmirror.com" --registry-fallback "https://registry.npmjs.org"

# 或者使用代理
export https_proxy="http://127.0.0.1:7890"
export http_proxy="http://127.0.0.1:7890"
./install-cn.sh
```

### 问题：版本不兼容

**原因**：Node.js 版本过低

**解决方案**：
```bash
# 检查 Node.js 版本
node --version  # 需要 >= 20.0.0

# 升级 Node.js（使用 nvm）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 22
nvm use 22
```

## 高级用法

### 自定义镜像源

```bash
# 使用腾讯云镜像
./install-cn.sh --registry-cn "https://mirrors.cloud.tencent.com/npm/"

# 使用华为云镜像  
./install-cn.sh --registry-cn "https://repo.huaweicloud.com/repository/npm/"
```

### 批量安装（CI/CD）

```bash
#!/bin/bash
# install-openclaw-ci.sh

set -e

# 下载安装脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o /tmp/install-cn.sh
chmod +x /tmp/install-cn.sh

# 安装指定版本
/tmp/install-cn.sh --version "0.3.12"

# 验证安装
openclaw --version
openclaw gateway status

# 初始化配置（如果需要）
if [[ ! -f ~/.openclaw/openclaw.json ]]; then
  openclaw config init --defaults
fi
```

### Docker 环境安装

```dockerfile
FROM node:22-alpine

# 安装 OpenClaw
RUN curl -fsSL https://clawdrepublic.cn/install-cn.sh | sh

# 验证安装
RUN openclaw --version
```

## 验证安装成功

安装完成后，运行以下命令验证：

```bash
# 1. 检查版本
openclaw --version

# 2. 检查网关状态
openclaw gateway status

# 3. 运行简单命令
openclaw chat "Hello, OpenClaw!"

# 4. 检查工作空间
ls -la ~/.openclaw/workspace/
```

## 更新 OpenClaw

```bash
# 更新到最新版本
./install-cn.sh --version latest

# 或者使用 npm 更新
npm update -g openclaw --registry https://registry.npmmirror.com
```

## 贡献与反馈

如果在使用中遇到问题：

1. **查看日志**：安装时添加 `set -x` 查看详细输出
2. **报告问题**：在 [论坛](https://clawdrepublic.cn/forum/) 发帖
3. **提交改进**：在 [GitHub](https://github.com/1037104428/roc-ai-republic) 提交 PR

## 相关资源

- [官网](https://clawdrepublic.cn/)
- [快速开始](https://clawdrepublic.cn/quickstart.html)
- [API 网关](https://clawdrepublic.cn/quota-proxy.html)
- [论坛](https://clawdrepublic.cn/forum/)

---

**最后更新**：2026-02-09  
**脚本版本**：v1.2.0  
**兼容性**：Node.js >= 20, npm >= 8