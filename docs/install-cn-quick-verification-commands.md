# OpenClaw CN 安装脚本快速验证命令

本文档提供 OpenClaw CN 安装脚本 (`install-cn.sh`) 的快速验证命令和故障排除指南。

## 快速验证命令

### 1. 基础安装验证

```bash
# 验证 openclaw 命令是否可用
openclaw --version

# 验证帮助命令
openclaw --help

# 验证状态命令
openclaw status
```

### 2. Gateway 服务验证

```bash
# 检查 gateway 状态
openclaw gateway status

# 启动 gateway 服务
openclaw gateway start

# 停止 gateway 服务
openclaw gateway stop

# 重启 gateway 服务
openclaw gateway restart
```

### 3. 工作空间验证

```bash
# 检查工作空间目录
ls -la ~/.openclaw/workspace/

# 检查重要配置文件
cat ~/.openclaw/workspace/AGENTS.md
cat ~/.openclaw/workspace/SOUL.md
cat ~/.openclaw/workspace/USER.md
```

### 4. 技能和功能验证

```bash
# 查看已安装的技能
ls -la ~/.nvm/versions/node/$(node --version | sed 's/v//')/lib/node_modules/openclaw/skills/

# 查看会话列表
openclaw sessions list --limit 5

# 查看可用工具
openclaw tools list
```

## 安装脚本使用示例

### 基本安装

```bash
# 使用默认设置安装最新版
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 安装特定版本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12

# 安装并自动验证
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --verify
```

### 高级安装选项

```bash
# 使用自定义 npm registry
NPM_REGISTRY=https://registry.npmmirror.com bash install-cn.sh

# CI/CD 环境安装
CI_MODE=1 SKIP_INTERACTIVE=1 OPENCLAW_VERSION=latest bash install-cn.sh --verify

# 干运行模式（只显示步骤，不实际执行）
bash install-cn.sh --dry-run

# 检查脚本更新
bash install-cn.sh --check-update
```

## 故障排除

### 常见问题

#### 1. "npm 未安装" 错误

```bash
# 安装 Node.js 和 npm
# Ubuntu/Debian
sudo apt update
sudo apt install nodejs npm

# macOS
brew install node

# 验证安装
node --version
npm --version
```

#### 2. "curl 未安装" 错误

```bash
# 安装 curl
# Ubuntu/Debian
sudo apt install curl

# macOS
brew install curl

# 验证安装
curl --version
```

#### 3. OpenClaw 命令找不到

```bash
# 检查 npm 全局安装路径
npm config get prefix

# 添加 npm 全局路径到 PATH
export PATH="$PATH:$(npm config get prefix)/bin"

# 重新安装 OpenClaw
npm uninstall -g openclaw
npm install -g openclaw
```

#### 4. Gateway 启动失败

```bash
# 查看 gateway 日志
tail -f ~/.openclaw/logs/gateway.log

# 检查端口占用
netstat -tlnp | grep :3000

# 清理并重新启动
openclaw gateway stop
rm -rf ~/.openclaw/workspace/.gateway
openclaw gateway start
```

### 网络问题

#### 1. npm registry 连接失败

```bash
# 测试 registry 连接
curl -I https://registry.npmmirror.com
curl -I https://registry.npmjs.org

# 临时使用特定 registry
NPM_REGISTRY=https://registry.npmmirror.com bash install-cn.sh

# 配置 npm 使用镜像源
npm config set registry https://registry.npmmirror.com
```

#### 2. 脚本下载失败

```bash
# 使用备用下载方式
wget https://clawdrepublic.cn/install-cn.sh -O install-cn.sh
bash install-cn.sh

# 从 GitHub 直接下载
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash
```

## 验证脚本

### 完整验证脚本

创建一个验证脚本 `verify-openclaw-install.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== OpenClaw 安装验证脚本 ==="
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 1. 检查命令
echo "1. 检查 openclaw 命令..."
if command -v openclaw > /dev/null 2>&1; then
    echo "   ✅ openclaw 命令可用"
    openclaw --version
else
    echo "   ❌ openclaw 命令未找到"
    exit 1
fi

echo ""

# 2. 检查 gateway
echo "2. 检查 OpenClaw Gateway..."
if openclaw gateway status > /dev/null 2>&1; then
    echo "   ✅ Gateway 正在运行"
else
    echo "   ℹ️ Gateway 未运行"
    echo "   运行: openclaw gateway start"
fi

echo ""

# 3. 检查工作空间
echo "3. 检查工作空间..."
workspace_dir="$HOME/.openclaw/workspace"
if [[ -d "$workspace_dir" ]]; then
    echo "   ✅ 工作空间目录存在: $workspace_dir"
    echo "   文件数量: $(find "$workspace_dir" -type f | wc -l)"
else
    echo "   ℹ️ 工作空间目录不存在 (首次安装正常)"
fi

echo ""

# 4. 检查技能
echo "4. 检查已安装技能..."
node_version=$(node --version 2>/dev/null | sed 's/v//' || echo "")
if [[ -n "$node_version" ]]; then
    skills_dir="$HOME/.nvm/versions/node/$node_version/lib/node_modules/openclaw/skills"
    if [[ -d "$skills_dir" ]]; then
        skill_count=$(find "$skills_dir" -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo "   ✅ 找到 $((skill_count - 1)) 个技能"
    else
        echo "   ℹ️ 技能目录不存在"
    fi
else
    echo "   ℹ️ 无法获取 Node.js 版本"
fi

echo ""

# 5. 快速功能测试
echo "5. 快速功能测试..."
echo "   测试状态命令..."
if openclaw status > /dev/null 2>&1; then
    echo "   ✅ 状态命令可用"
else
    echo "   ℹ️ 状态命令失败 (可能需要启动 gateway)"
fi

echo "   测试会话列表..."
if openclaw sessions list --limit 1 > /dev/null 2>&1; then
    echo "   ✅ 会话列表可用"
else
    echo "   ℹ️ 会话列表不可用"
fi

echo ""
echo "=== 验证完成 ==="
echo "结束时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo "建议下一步:"
echo "1. 启动 gateway: openclaw gateway start"
echo "2. 查看状态: openclaw status"
echo "3. 配置代理: 编辑 ~/.openclaw/workspace/SOUL.md"
echo "4. 安装技能: openclaw skill install <技能名称>"
echo "5. 加入社区: https://discord.com/invite/clawd"
```

### 使用验证脚本

```bash
# 下载验证脚本
curl -fsSL https://clawdrepublic.cn/verify-openclaw-install.sh -o verify-openclaw-install.sh
chmod +x verify-openclaw-install.sh

# 运行验证
./verify-openclaw-install.sh

# 或直接运行
curl -fsSL https://clawdrepublic.cn/verify-openclaw-install.sh | bash
```

## 性能优化

### 1. 加速 npm 安装

```bash
# 配置 npm 使用并行安装
npm config set maxsockets 5

# 禁用 npm 进度条（CI 环境）
npm config set progress false

# 使用淘宝镜像加速
npm config set registry https://registry.npmmirror.com
npm config set disturl https://npmmirror.com/dist
npm config set electron_mirror https://npmmirror.com/mirrors/electron/
npm config set puppeteer_download_host https://npmmirror.com/mirrors
npm config set chromedriver_cdnurl https://npmmirror.com/mirrors/chromedriver
npm config set operadriver_cdnurl https://npmmirror.com/mirrors/operadriver
npm config set phantomjs_cdnurl https://npmmirror.com/mirrors/phantomjs
npm config set sass_binary_site https://npmmirror.com/mirrors/node-sass
npm config set node_sass_mirror https://npmmirror.com/mirrors/node-sass
```

### 2. 优化 OpenClaw 启动

```bash
# 配置环境变量
export OPENCLAW_LOG_LEVEL=info
export OPENCLAW_CACHE_DIR="$HOME/.cache/openclaw"
export OPENCLAW_MAX_WORKERS=4

# 创建缓存目录
mkdir -p "$HOME/.cache/openclaw"
```

## 监控和维护

### 1. 监控脚本

创建监控脚本 `monitor-openclaw.sh`：

```bash
#!/usr/bin/env bash

echo "=== OpenClaw 系统监控 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 检查进程
echo "进程状态:"
ps aux | grep -E "(openclaw|gateway)" | grep -v grep

echo ""

# 检查端口
echo "端口监听:"
netstat -tlnp | grep -E "(:3000|:8080)" || echo "无相关端口监听"

echo ""

# 检查日志
echo "日志文件:"
ls -la ~/.openclaw/logs/ 2>/dev/null || echo "日志目录不存在"

echo ""

# 检查磁盘使用
echo "磁盘使用:"
du -sh ~/.openclaw/ 2>/dev/null || echo "OpenClaw 目录不存在"

echo ""
echo "监控完成"
```

### 2. 定期维护

```bash
# 清理旧日志（保留最近7天）
find ~/.openclaw/logs -name "*.log" -mtime +7 -delete

# 清理缓存
rm -rf ~/.cache/openclaw/*

# 更新 OpenClaw
npm update -g openclaw

# 更新技能
openclaw skill update --all
```

## 支持资源

- **官方文档**: https://docs.openclaw.ai
- **GitHub 仓库**: https://github.com/openclaw/openclaw
- **社区 Discord**: https://discord.com/invite/clawd
- **问题反馈**: https://github.com/openclaw/openclaw/issues
- **CN 镜像站**: https://clawdrepublic.cn
- **CN 文档镜像**: https://docs.clawdrepublic.cn

## 更新日志

### 脚本版本: 2026.02.11.1839
- 添加智能 registry 选择算法
- 增强自检功能
- 添加 CI/CD 支持
- 优化错误处理和回退策略
- 添加详细验证命令文档

### 后续计划
- 添加自动故障转移
- 支持更多包管理器 (yarn, pnpm)
- 添加系统健康检查
- 支持离线安装模式
- 添加性能基准测试

---

**注意**: 本文档会随着 OpenClaw CN 安装脚本的更新而更新。最新版本请参考 [GitHub 仓库](https://github.com/1037104428/roc-ai-republic/blob/main/docs/install-cn-quick-verification-commands.md)。