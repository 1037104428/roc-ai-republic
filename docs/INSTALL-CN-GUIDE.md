# OpenClaw CN 安装指南

## 概述

本文档提供 OpenClaw 在中国大陆地区的优化安装方案，包含智能 registry 选择、多层回退策略和完整自检功能。

## 快速开始

### 一键安装（推荐）

```bash
# 使用国内优化脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 或指定版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
```

### 手动安装

```bash
# 下载脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o install-cn.sh

# 运行安装
bash install-cn.sh

# 或指定版本
bash install-cn.sh --version 0.3.12
```

## 安装脚本特性

### 🚀 智能 Registry 选择
脚本自动测试多个 npm registry，选择最快可用的源：

1. **用户指定** (最高优先级，通过 `NPM_REGISTRY` 环境变量)
2. **国内镜像源** (按顺序测试):
   - `https://registry.npmmirror.com` (阿里云镜像)
   - `https://registry.npm.taobao.org` (淘宝镜像)
   - `https://mirrors.cloud.tencent.com/npm/` (腾讯云镜像)
3. **全球备用源**:
   - `https://registry.npmjs.org` (官方源)
   - `https://registry.yarnpkg.com` (Yarn 源)

### 🔄 多层回退策略
安装失败时自动重试，最多 2 次重试机会：

1. **首次尝试**: 使用最优 registry
2. **第一次重试**: 切换到备用 registry (npmmirror.com → npmjs.org)
3. **第二次重试**: 切换到最终备用 registry (npmjs.org → yarnpkg.com)

### ✅ 完整自检功能
安装完成后自动执行 8 项验证：

1. **命令检查**: `openclaw` 命令是否可用
2. **版本验证**: 获取并验证 OpenClaw 版本
3. **帮助命令**: 测试 `openclaw --help`
4. **状态命令**: 测试 `openclaw status`
5. **工作空间**: 检查 `~/.openclaw/workspace` 目录
6. **Gateway 状态**: 检查 OpenClaw gateway 运行状态
7. **技能目录**: 检查已安装的技能
8. **会话功能**: 测试 `openclaw sessions list`

### 📊 安装验证报告
安装完成后生成详细报告，包含：
- 系统信息 (操作系统、架构、Node/NPM 版本)
- 安装路径和工作空间
- 验证结果统计
- 下一步操作建议
- 故障排除指南

## 环境变量配置

### 基本配置
```bash
# 指定 OpenClaw 版本
export OPENCLAW_VERSION="0.3.12"

# 指定 npm registry
export NPM_REGISTRY="https://registry.npmmirror.com"

# 启用 CI 模式 (无颜色输出)
export CI_MODE=1

# 跳过交互式确认
export SKIP_INTERACTIVE=1

# 指定安装日志文件
export INSTALL_LOG="/tmp/openclaw-install-ci.log"
```

### CI/CD 集成示例
```bash
#!/bin/bash
# CI/CD 环境安装脚本

set -euo pipefail

# 配置环境变量
export CI_MODE=1
export SKIP_INTERACTIVE=1
export OPENCLAW_VERSION="latest"
export INSTALL_LOG="/tmp/openclaw-install-$(date +%s).log"

# 运行安装脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 检查安装结果
if [[ $? -eq 0 ]]; then
  echo "✅ OpenClaw 安装成功"
  openclaw --version
else
  echo "❌ OpenClaw 安装失败"
  cat "$INSTALL_LOG" 2>/dev/null || true
  exit 1
fi
```

## 平台支持

### 操作系统
- ✅ **Linux**: Ubuntu, Debian, CentOS, Fedora, Arch Linux
- ✅ **macOS**: Intel & Apple Silicon (M1/M2/M3)
- ⚠️ **Windows**: 通过 WSL2 支持

### Node.js 版本要求
- **OpenClaw 0.3.x**: Node.js ≥ 18.0.0
- **npm**: ≥ 8.0.0 (推荐最新版)

### 系统依赖
- **curl**: 用于下载脚本和测试 registry 连接性
- **npm**: Node.js 包管理器
- **Node.js**: JavaScript 运行时

## 故障排除

### 常见问题

#### 1. 安装速度慢
```bash
# 强制使用国内镜像源
export NPM_REGISTRY="https://registry.npmmirror.com"
bash install-cn.sh
```

#### 2. 网络连接问题
```bash
# 增加超时时间
export NPM_REGISTRY_TIMEOUT=10
# 禁用 registry 测试
export SKIP_REGISTRY_TEST=1
```

#### 3. 版本兼容性问题
```bash
# 检查 Node.js 版本
node --version

# 如果版本过低，升级 Node.js
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew update
brew install node@20
```

#### 4. 权限问题
```bash
# 使用 sudo (不推荐)
sudo bash install-cn.sh

# 或修复 npm 权限
sudo chown -R $(whoami) ~/.npm
sudo chown -R $(whoami) /usr/local/lib/node_modules
```

### 诊断命令
```bash
# 检查网络连接
curl -I https://registry.npmmirror.com
ping -c 3 registry.npmmirror.com

# 检查 Node.js 环境
node --version
npm --version
which node
which npm

# 检查现有 OpenClaw 安装
which openclaw
openclaw --version 2>/dev/null || echo "未安装"
```

### 重新安装
```bash
# 完全卸载并重新安装
npm uninstall -g openclaw
rm -rf ~/.openclaw
bash install-cn.sh
```

## 高级配置

### 自定义 Registry 列表
```bash
# 创建自定义安装脚本
cat > custom-install.sh << 'EOF'
#!/usr/bin/env bash
# 自定义 registry 列表
CUSTOM_REGISTRIES=(
  "https://your-custom-registry.com"
  "https://registry.npmmirror.com"
  "https://registry.npmjs.org"
)

# 修改脚本中的 registry 测试逻辑
# ... 自定义实现 ...
EOF

chmod +x custom-install.sh
./custom-install.sh
```

### 代理配置
```bash
# 通过代理安装
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
bash install-cn.sh
```

### 离线安装
```bash
# 1. 在有网络的环境下载包
npm pack openclaw@0.3.12 --registry=https://registry.npmmirror.com

# 2. 复制到离线环境
scp openclaw-0.3.12.tgz user@offline-machine:/tmp/

# 3. 离线安装
npm install -g /tmp/openclaw-0.3.12.tgz
```

## 验证安装

### 基本验证
```bash
# 检查版本
openclaw --version

# 检查命令
openclaw --help

# 检查状态
openclaw status
```

### 完整验证脚本
```bash
#!/bin/bash
# openclaw-verify.sh

echo "=== OpenClaw 安装验证 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 1. 检查命令
if command -v openclaw > /dev/null 2>&1; then
  echo "✅ openclaw 命令可用"
else
  echo "❌ openclaw 命令未找到"
  exit 1
fi

# 2. 检查版本
VERSION=$(openclaw --version 2>/dev/null || echo "未知")
echo "📦 OpenClaw 版本: $VERSION"

# 3. 检查工作空间
WORKSPACE="$HOME/.openclaw/workspace"
if [[ -d "$WORKSPACE" ]]; then
  echo "📁 工作空间: $WORKSPACE (存在)"
  ls -la "$WORKSPACE" | head -5
else
  echo "⚠️  工作空间不存在"
fi

# 4. 检查 gateway
if openclaw gateway status > /dev/null 2>&1; then
  echo "🟢 Gateway 正在运行"
else
  echo "🟡 Gateway 未运行"
fi

# 5. 检查技能
SKILLS_COUNT=$(openclaw skill list 2>/dev/null | wc -l || echo "0")
echo "🔧 已安装技能: $SKILLS_COUNT"

echo "=== 验证完成 ==="
```

## 更新和维护

### 更新 OpenClaw
```bash
# 使用安装脚本更新
bash install-cn.sh --version latest

# 或直接使用 npm
npm update -g openclaw
```

### 更新安装脚本
```bash
# 下载最新版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh -o install-cn.sh

# 检查更新
bash install-cn.sh --help | grep "版本:"
```

### 清理缓存
```bash
# 清理 npm 缓存
npm cache clean --force

# 清理旧版本
npm ls -g --depth=0 | grep openclaw
```

## 安全注意事项

### 脚本安全性
- 脚本从可信源下载: `https://clawdrepublic.cn/install-cn.sh`
- 支持 SHA256 校验和验证
- 不永久修改系统配置
- 不请求不必要的权限

### 环境安全
```bash
# 验证脚本完整性
curl -fsSL https://clawdrepublic.cn/install-cn.sh.sha256
sha256sum install-cn.sh

# 在沙箱中运行
docker run --rm -it node:20-alpine sh -c \
  "curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
```

### 生产环境建议
1. **固定版本**: 使用特定版本而非 `latest`
2. **隔离环境**: 使用 Docker 或虚拟环境
3. **备份配置**: 定期备份 `~/.openclaw` 目录
4. **监控日志**: 监控 `~/.openclaw/logs/` 目录

## 支持与社区

### 官方资源
- **文档**: https://docs.openclaw.ai
- **GitHub**: https://github.com/openclaw/openclaw
- **Discord**: https://discord.com/invite/clawd
- **问题反馈**: https://github.com/openclaw/openclaw/issues

### 中文社区
- **Gitee 镜像**: https://gitee.com/junkaiWang324/roc-ai-republic
- **中文文档**: 本项目文档目录
- **微信群**: 联系项目维护者获取

### 获取帮助
```bash
# 查看帮助
openclaw --help

# 查看技能
openclaw skill list

# 查看会话
openclaw sessions list

# 查看日志
tail -f ~/.openclaw/logs/gateway.log
```

## 附录

### 脚本版本历史
- **2026.02.11.1839**: 初始版本，包含智能 registry 选择、回退策略和自检功能
- **未来更新**: 计划添加 Docker 支持、离线安装包、更多验证项

### 性能优化建议
1. **使用国内镜像**: 设置 `NPM_REGISTRY="https://registry.npmmirror.com"`
2. **预下载依赖**: 在 CI/CD 中缓存 `~/.npm` 目录
3. **并行安装**: 使用 `npm install --global` 而非多个独立安装
4. **清理缓存**: 定期运行 `npm cache clean --force`

### 相关项目
- **OpenClaw 本体**: https://github.com/openclaw/openclaw
- **中文技能包**: https://clawhub.com
- **API 网关**: 本项目 `quota-proxy` 目录
- **部署工具**: 本项目 `scripts/` 目录

---

**最后更新**: 2026-02-11  
**脚本版本**: 2026.02.11.1839  
**维护者**: 中华AI共和国项目组  
**许可证**: MIT