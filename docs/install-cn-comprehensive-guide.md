# OpenClaw 国内一键安装脚本综合指南

## 概述

`install-cn.sh` 是专为国内网络环境优化的 OpenClaw 一键安装脚本，提供：

1. **国内源优先** - 默认使用 npmmirror.com 镜像加速
2. **智能回退** - 当国内源不可达时自动切换到 npmjs.org
3. **完整自检** - 安装后自动验证 `openclaw --version`
4. **网络诊断** - 提供网络连通性测试选项
5. **环境兼容** - 支持 bash/zsh，提供 Windows PowerShell 等效命令

## 快速开始

### 基础安装（推荐）

```bash
# 一键安装最新版
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

### 指定版本

```bash
# 安装特定版本（如 0.3.12）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
```

### 仅测试（不安装）

```bash
# 查看脚本会执行的操作
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run
```

## 高级选项

### 自定义镜像源

```bash
# 使用自定义国内镜像
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- \
  --registry-cn https://registry.npmmirror.com \
  --registry-fallback https://registry.npmjs.org
```

### 环境变量方式

```bash
# 通过环境变量控制
NPM_REGISTRY=https://registry.npmmirror.com \
OPENCLAW_VERSION=latest \
bash <(curl -fsSL https://clawdrepublic.cn/install-cn.sh)
```

### 网络诊断模式

```bash
# 安装前测试网络连通性
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --network-test
```

## 安装流程详解

### 1. 网络检测阶段
- 检查 curl/wget 可用性
- 测试国内镜像源可达性（可选）
- 评估网络延迟和稳定性

### 2. 安装阶段
1. **优先尝试国内源**：使用 npmmirror.com 加速下载
2. **智能回退机制**：如果国内源失败，自动切换到 npmjs.org
3. **版本锁定**：支持特定版本或最新版安装

### 3. 验证阶段
1. **PATH 检测**：检查 openclaw 命令是否在 PATH 中
2. **版本验证**：运行 `openclaw --version` 确认安装成功
3. **环境配置**：提示用户如何配置 shell 环境

## 故障排查

### 常见问题

#### Q1: 安装后提示 "command not found: openclaw"
```bash
# 解决方案1：重新加载 shell 配置
source ~/.bashrc  # 或 source ~/.zshrc

# 解决方案2：使用 npx 运行
npx openclaw --version

# 解决方案3：手动添加 PATH
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Q2: 网络连接超时
```bash
# 使用 --network-test 诊断
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --network-test

# 强制使用回退源
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --force-cn
```

#### Q3: 权限问题
```bash
# 如果遇到权限错误，尝试使用 sudo（不推荐）
# 更好的方案：配置 npm 使用用户目录
npm config set prefix ~/.npm-global
```

### 错误代码说明

| 代码 | 含义 | 解决方案 |
|------|------|----------|
| 1 | 脚本参数错误 | 检查参数格式，使用 `--help` 查看帮助 |
| 2 | 网络连接失败 | 检查网络，使用 `--network-test` 诊断 |
| 3 | npm 安装失败 | 尝试 `--force-cn` 或手动配置镜像源 |
| 4 | 版本验证失败 | 检查 Node.js 版本（需要 ≥ 20） |
| 5 | 环境配置问题 | 按照提示配置 PATH 环境变量 |

## 网络优化建议

### 国内镜像加速

```bash
# 永久配置 npm 使用国内镜像（可选）
npm config set registry https://registry.npmmirror.com
npm config set disturl https://npmmirror.com/dist
```

### 代理配置

如果处于企业网络环境，可能需要配置代理：

```bash
# 临时使用代理
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# 然后运行安装脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

## Windows 用户指南

### PowerShell 安装

```powershell
# 下载脚本
Invoke-WebRequest -Uri "https://clawdrepublic.cn/install-cn.sh" -OutFile "install-cn.ps1"

# 查看帮助
.\install-cn.ps1 --help

# 安装最新版
.\install-cn.ps1 --version latest
```

### 环境变量设置

```powershell
# 设置环境变量（当前会话）
$env:OPENCLAW_VERSION = "latest"
$env:NPM_REGISTRY = "https://registry.npmmirror.com"

# 永久设置环境变量
[System.Environment]::SetEnvironmentVariable("OPENCLAW_VERSION", "latest", "User")
[System.Environment]::SetEnvironmentVariable("NPM_REGISTRY", "https://registry.npmmirror.com", "User")
```

## 开发者指南

### 脚本架构

```
install-cn.sh
├── 参数解析
├── 网络检测
├── 安装函数（支持重试）
├── 验证函数
└── 环境配置
```

### 扩展开发

如需扩展脚本功能，可修改以下部分：

1. **添加新的镜像源**：修改 `NPM_REGISTRY_CN_DEFAULT` 和 `NPM_REGISTRY_FALLBACK_DEFAULT`
2. **增加安装前检查**：在 `main()` 函数开始处添加
3. **支持更多包管理器**：扩展 `install_openclaw()` 函数

### 测试脚本

仓库中提供了验证脚本：

```bash
# 运行完整测试
./scripts/verify-install-cn.sh --all

# 仅测试网络连通性
./scripts/verify-install-cn.sh --network

# 仅测试安装流程
./scripts/verify-install-cn.sh --install
```

## 相关资源

- [官网安装页面](https://clawdrepublic.cn/quickstart.html)
- [GitHub 仓库](https://github.com/1037104428/roc-ai-republic)
- [Gitee 镜像](https://gitee.com/junkaiWang324/roc-ai-republic)
- [问题反馈论坛](https://clawdrepublic.cn/forum/)

## 更新日志

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0 | 2026-02-09 | 初始版本，支持基础安装和回退 |
| 1.1 | 2026-02-10 | 增加网络测试、dry-run 模式 |
| 1.2 | 2026-02-10 | 完善故障排查和 Windows 支持 |

---

**提示**：安装完成后，请访问 [快速开始指南](https://clawdrepublic.cn/quickstart.html) 获取 TRIAL_KEY 并开始使用 OpenClaw。