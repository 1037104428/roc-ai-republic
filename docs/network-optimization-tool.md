# OpenClaw CN 网络优化工具

## 概述

`optimize-network-sources.sh` 是一个智能网络优化脚本，专为国内 OpenClaw 用户设计。它能自动检测最佳的网络镜像源，提供最快的安装和更新体验。

## 功能特性

### 🚀 核心功能
- **智能镜像源检测**：自动测试多个 npm、GitHub、Gitee 镜像源
- **响应时间优化**：基于实际网络延迟选择最佳源
- **一键配置生成**：输出优化的环境变量和安装命令
- **配置持久化**：自动保存最佳配置到用户目录

### 🔧 支持的镜像源

#### npm 镜像源（按优先级测试）
1. `https://registry.npmmirror.com` - 阿里云镜像
2. `https://mirrors.cloud.tencent.com/npm/` - 腾讯云镜像
3. `https://registry.npm.taobao.org` - 淘宝镜像
4. `https://registry.npmjs.org` - 官方源（备用）

#### GitHub 镜像源
- `https://raw.githubusercontent.com` - 官方源
- `https://ghproxy.com/https://raw.githubusercontent.com` - ghproxy 代理
- `https://raw.fastgit.org` - fastgit 镜像

#### Gitee 镜像源
- `https://gitee.com` - 官方源
- `https://mirror.ghproxy.com/https://gitee.com` - 代理镜像

## 使用方法

### 基本使用
```bash
# 运行优化检测
./scripts/optimize-network-sources.sh

# 显示帮助
./scripts/optimize-network-sources.sh --help
```

### 集成到安装流程
```bash
# 在安装前运行优化检测
./scripts/optimize-network-sources.sh

# 使用优化后的配置安装
source ~/.openclaw-network-optimization.conf
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

### 一键安装命令
脚本会生成优化后的一键安装命令，例如：
```bash
NPM_REGISTRY="https://registry.npmmirror.com" \
GITHUB_MIRROR="https://ghproxy.com/https://raw.githubusercontent.com" \
bash -c '$(curl -fsSL "${GITHUB_MIRROR}/openclaw/openclaw/main/scripts/install.sh")'
```

## 输出示例

```
[网络优化] 开始 OpenClaw CN 网络源优化检测
[网络优化] ======================================

[网络优化] 测试 npm 镜像源...
[网络优化] 测试: https://registry.npmmirror.com
[网络优化] ✅ 可达 (128ms)
[网络优化] 测试: https://mirrors.cloud.tencent.com/npm/
[网络优化] ✅ 可达 (156ms)
[网络优化] 测试: https://registry.npm.taobao.org
[网络优化] ⚠️ 不可达
[网络优化] 测试: https://registry.npmjs.org
[网络优化] ✅ 可达 (320ms)
[网络优化] ✅ 最佳 npm 镜像源: https://registry.npmmirror.com

[网络优化] 测试 GitHub 镜像源...
[网络优化] 测试: https://raw.githubusercontent.com
[网络优化] ✅ 可达 (280ms)
[网络优化] 测试: https://ghproxy.com/https://raw.githubusercontent.com
[网络优化] ✅ 可达 (120ms)
[网络优化] 测试: https://raw.fastgit.org
[网络优化] ⚠️ 不可达
[网络优化] ✅ 最佳 GitHub 镜像源: https://ghproxy.com/https://raw.githubusercontent.com

[网络优化] 测试 Gitee 镜像源...
[网络优化] 测试: https://gitee.com
[网络优化] ✅ 可达 (80ms)
[网络优化] 测试: https://mirror.ghproxy.com/https://gitee.com
[网络优化] ✅ 可达 (95ms)
[网络优化] ✅ 最佳 Gitee 镜像源: https://gitee.com

[网络优化] ======================================
[网络优化] ✅ 网络优化检测完成

# ============================================
# 🚀 OpenClaw CN 网络优化配置
# ============================================
# 基于实时网络测试生成的最佳配置
# 复制以下环境变量到安装命令前使用

# 最佳 npm 镜像源
export NPM_REGISTRY="https://registry.npmmirror.com"
export NPM_REGISTRY_FALLBACK="https://registry.npmjs.org"

# 最佳 GitHub 镜像源（用于脚本下载）
export GITHUB_MIRROR="https://ghproxy.com/https://raw.githubusercontent.com"

# 最佳 Gitee 镜像源
export GITEE_MIRROR="https://gitee.com"

# 📦 一键安装命令（复制并执行）：
NPM_REGISTRY="https://registry.npmmirror.com" \
GITHUB_MIRROR="https://ghproxy.com/https://raw.githubusercontent.com" \
bash -c '$(curl -fsSL "${GITHUB_MIRROR}/openclaw/openclaw/main/scripts/install.sh")'

[网络优化] ✅ 配置已保存到: /home/user/.openclaw-network-optimization.conf
[网络优化] ℹ️ 使用方式: source /home/user/.openclaw-network-optimization.conf
```

## 与 install-cn.sh 集成

### 自动集成
`install-cn.sh` 已经内置了基本的网络检测功能。优化工具提供了更全面的检测和更智能的源选择。

### 手动集成示例
```bash
#!/usr/bin/env bash
# install-cn.sh 中的网络优化集成示例

# 如果有优化配置文件，优先使用
if [[ -f "${HOME}/.openclaw-network-optimization.conf" ]]; then
    source "${HOME}/.openclaw-network-optimization.conf"
    echo "[cn-pack] 使用网络优化配置"
fi

# 或者运行时检测
if [[ "${USE_NETWORK_OPTIMIZATION:-0}" == "1" ]]; then
    echo "[cn-pack] 运行网络优化检测..."
    ./scripts/optimize-network-sources.sh
    source "${HOME}/.openclaw-network-optimization.conf"
fi
```

## 高级功能

### 定时优化检测
```bash
# 添加到 crontab，每天检测一次
0 2 * * * /path/to/roc-ai-republic/scripts/optimize-network-sources.sh > /tmp/openclaw-network-optimization.log 2>&1
```

### CI/CD 集成
```bash
# 在 CI 环境中使用
- name: Network optimization
  run: |
    chmod +x ./scripts/optimize-network-sources.sh
    ./scripts/optimize-network-sources.sh
    source ~/.openclaw-network-optimization.conf
    echo "NPM_REGISTRY=$NPM_REGISTRY" >> $GITHUB_ENV
```

### 代理环境支持
脚本自动处理代理环境，如果检测到 `http_proxy` 或 `https_proxy` 环境变量，会使用这些代理进行测试。

## 故障排除

### 常见问题

#### 1. curl 命令未找到
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl

# macOS
brew install curl
```

#### 2. 所有镜像源都不可达
- 检查网络连接
- 检查防火墙设置
- 尝试使用代理：`export https_proxy=http://proxy:port`

#### 3. 测试超时
- 增加超时时间：修改脚本中的 `TEST_TIMEOUT` 变量
- 使用更稳定的网络环境

### 调试模式
```bash
# 手动测试单个镜像源
curl -v -m 10 "https://registry.npmmirror.com/-/ping"

# 查看详细输出
bash -x ./scripts/optimize-network-sources.sh
```

## 性能优化建议

### 缓存优化结果
优化结果会保存到 `~/.openclaw-network-optimization.conf`，可以重复使用，避免每次安装都进行检测。

### 区域化配置
不同地区的用户可能有不同的最佳镜像源：
- **华东地区**：阿里云镜像通常最快
- **华南地区**：腾讯云镜像可能更优
- **海外用户**：直接使用官方源

### 定期更新
网络状况可能变化，建议：
- 每月运行一次优化检测
- 在重大网络变更后重新检测
- 使用不同时间段检测（白天/晚上）

## 安全考虑

### 镜像源可信度
脚本只测试预定义的、可信的镜像源：
- 官方镜像源（npmjs.org, github.com）
- 知名企业镜像（阿里云、腾讯云）
- 社区维护的可靠代理

### 配置安全
生成的配置文件只包含镜像源 URL，不包含敏感信息。用户可以安全地分享优化结果。

### 脚本完整性
建议从官方仓库下载脚本：
```bash
# 从 Gitee 下载
curl -fsSL https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/scripts/optimize-network-sources.sh -o optimize-network-sources.sh

# 验证脚本
sha256sum optimize-network-sources.sh
```

## 扩展开发

### 添加新的镜像源
编辑脚本中的数组变量：
```bash
# 添加新的 npm 镜像源
MIRROR_SOURCES+=(
    "https://your-new-mirror.com"
)

# 添加新的 GitHub 镜像源
GITHUB_MIRRORS+=(
    "https://your-github-mirror.com"
)
```

### 自定义测试端点
```bash
# 修改测试 URL
local test_url="$mirror/your-test-endpoint"
```

### 集成到其他工具
脚本输出结构化信息，可以方便地集成到其他安装工具或管理系统中。

## 版本历史

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持 npm、GitHub、Gitee 镜像源检测
- 响应时间优化算法
- 配置自动保存功能
- 完整的文档和示例

## 贡献指南

欢迎提交 Issue 和 Pull Request：
1. 测试新的镜像源
2. 优化检测算法
3. 添加更多网络测试维度
4. 改进用户体验

## 许可证

MIT License - 详见仓库 LICENSE 文件。

## 相关文档

- [install-cn.sh 使用指南](./install-cn-strategy.md)
- [网络诊断工具](./network-diagnosis-tool.md)
- [OpenClaw CN 安装策略](./install-cn-strategy.md)
- [quota-proxy 部署指南](../docs/quota-proxy-quickstart.md)