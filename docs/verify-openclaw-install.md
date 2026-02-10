# OpenClaw 安装验证脚本

## 概述

`verify-openclaw-install.sh` 是一个全面的 OpenClaw 安装验证工具，用于检查 OpenClaw 是否正确安装并可正常运行。该脚本提供多级验证，从基础命令检查到系统兼容性测试。

## 功能特性

- ✅ **全面验证**：检查 OpenClaw 命令、版本、配置、依赖
- ✅ **多级输出**：支持安静模式、详细模式、干运行模式
- ✅ **标准化退出码**：提供清晰的验证结果指示
- ✅ **彩色输出**：直观的彩色终端输出（可禁用）
- ✅ **故障排除**：提供详细的错误信息和修复建议

## 使用方法

### 基本使用

```bash
# 运行完整验证
./scripts/verify-openclaw-install.sh

# 安静模式（仅显示错误）
./scripts/verify-openclaw-install.sh --quiet

# 详细模式（显示调试信息）
./scripts/verify-openclaw-install.sh --verbose

# 干运行模式（仅打印命令不执行）
./scripts/verify-openclaw-install.sh --dry-run

# 显示帮助
./scripts/verify-openclaw-install.sh --help
```

### 在安装脚本中自动使用

`install-cn.sh` 安装脚本会自动调用验证脚本：

```bash
# 安装完成后自动验证
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

## 验证项目

脚本检查以下项目：

### 1. 命令可用性
- `openclaw` 命令是否在 PATH 中
- 基础命令（--version, --help）是否正常工作

### 2. 版本检查
- OpenClaw 版本信息
- Node.js 版本兼容性（需要 >= 18.x）

### 3. 系统状态
- `openclaw status` 命令输出
- Gateway 状态检查
- 模型配置检查

### 4. 文件系统
- 工作空间目录 (`~/.openclaw/workspace`)
- 配置文件 (`~/.openclaw/config.json`)

### 5. 依赖检查
- Node.js 安装和版本
- npm/npx 命令可用性

## 退出码

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 安装验证通过，无问题 |
| 1 | 警告 | 发现次要问题，不影响基本功能 |
| 2 | 严重问题 | 发现关键问题，需要修复 |
| 3 | 验证错误 | 验证过程本身出错 |

## 示例输出

### 成功验证
```
🔍 OpenClaw Installation Verification
=========================================
[verify] Checking openclaw command availability...
[verify]✅ openclaw command found
[verify] Checking openclaw version...
[verify]✅ Version: openclaw/0.3.12 linux-x64 node-v22.22.0
[verify] Checking Node.js version...
[verify]✅ Node.js: v22.22.0
[verify]✅ Node.js version compatible (>= 18.x)

📊 Verification Summary
=========================================
✅ Basic installation: Verified
✅ Command availability: Verified
✅ Node.js compatibility: Verified

💡 Next steps:
   1. Run 'openclaw gateway start' to start the gateway
   2. Run 'openclaw status' to check system status
   3. Configure models with 'openclaw models add'
   4. Visit https://docs.openclaw.ai for documentation
=========================================
```

### 发现问题
```
[verify] Checking openclaw command availability...
[verify]❌ openclaw command not found in PATH
[verify] Checking Node.js version...
[verify]✅ Node.js: v16.20.2
[verify]⚠️ Node.js version v16.20.2 may be too old (needs >= 18.x)
```

## 故障排除

### 常见问题

#### 1. "openclaw command not found"
- 确保 OpenClaw 已正确安装：`npm list -g openclaw`
- 检查 PATH 环境变量：`echo $PATH`
- 尝试重新安装：`npm install -g openclaw@latest`

#### 2. "Node.js version too old"
- 升级 Node.js 到 18.x 或更高版本
- 使用 nvm 管理 Node.js 版本：`nvm install 18 && nvm use 18`

#### 3. "Workspace directory not found"
- 首次运行 OpenClaw 时会自动创建
- 运行：`openclaw --help` 或 `openclaw status`

#### 4. "Gateway not running"
- 启动 Gateway：`openclaw gateway start`
- 检查状态：`openclaw gateway status`

## 集成指南

### 与 CI/CD 集成

```yaml
# GitHub Actions 示例
name: Verify OpenClaw Installation
on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install OpenClaw
        run: npm install -g openclaw@latest
        
      - name: Verify installation
        run: ./scripts/verify-openclaw-install.sh --quiet
```

### 与监控系统集成

```bash
# 定期验证并发送告警
#!/bin/bash
if ! ./scripts/verify-openclaw-install.sh --quiet; then
  # 发送告警
  curl -X POST https://hooks.slack.com/services/... \
    -d '{"text": "OpenClaw installation verification failed!"}'
fi
```

## 开发说明

### 添加新的检查项

要添加新的验证检查，在脚本中添加相应的检查函数：

```bash
# 示例：检查特定配置文件
check_config_file() {
  info "Checking specific config file..."
  if [[ -f "/path/to/config" ]]; then
    success "Config file exists"
  else
    warning "Config file missing"
  fi
}
```

### 测试验证脚本

```bash
# 测试各种模式
./scripts/verify-openclaw-install.sh --dry-run
./scripts/verify-openclaw-install.sh --verbose
./scripts/verify-openclaw-install.sh --quiet

# 测试错误情况（临时重命名命令）
mv $(which openclaw) $(which openclaw).bak 2>/dev/null || true
./scripts/verify-openclaw-install.sh
mv $(which openclaw).bak $(which openclaw) 2>/dev/null || true
```

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 基础命令验证
- 系统兼容性检查
- 多模式输出支持
- 标准化退出码

## 相关文档

- [OpenClaw 中文安装指南](./install-cn-guide.md)
- [OpenClaw 配置文档](./configuration.md)
- [故障排除指南](./troubleshooting.md)

## 许可证

本脚本遵循 MIT 许可证。详见项目根目录 LICENSE 文件。