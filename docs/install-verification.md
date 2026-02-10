# OpenClaw 安装验证指南

本文档介绍如何验证 OpenClaw 安装是否成功，并提供故障排除指南。

## 验证脚本

我们提供了一个完整的安装验证脚本，可以检查 OpenClaw 安装的各个方面：

```bash
# 基本验证
./scripts/verify-openclaw-install.sh

# 详细诊断（包括网络和配置检查）
./scripts/verify-openclaw-install.sh --detailed

# 安静模式（仅输出错误和摘要）
./scripts/verify-openclaw-install.sh --quiet

# 显示帮助
./scripts/verify-openclaw-install.sh --help
```

## 手动验证步骤

### 1. 基本命令检查

```bash
# 检查 openclaw 命令是否存在
command -v openclaw

# 检查版本
openclaw --version

# 预期输出示例：
# openclaw/0.3.12 linux-x64 node-v22.22.0
```

### 2. 网关状态检查

```bash
# 检查网关状态
openclaw gateway status

# 启动网关（如果未运行）
openclaw gateway start

# 查看网关日志
openclaw gateway logs
```

### 3. 配置文件检查

```bash
# 检查配置文件是否存在
ls -la ~/.openclaw/openclaw.json

# 检查配置文件语法（需要 jq）
jq empty ~/.openclaw/openclaw.json

# 查看配置文件内容
cat ~/.openclaw/openclaw.json | jq .
```

### 4. 工作空间检查

```bash
# 检查工作空间目录
ls -la ~/.openclaw/workspace/

# 检查重要文件
ls -la ~/.openclaw/workspace/AGENTS.md
ls -la ~/.openclaw/workspace/SOUL.md
ls -la ~/.openclaw/workspace/USER.md
```

### 5. 模型状态检查

```bash
# 检查模型状态
openclaw models status

# 列出可用模型
openclaw models list
```

## 验证脚本功能详解

### 检查项目

验证脚本执行以下检查：

1. **基本命令检查**
   - `openclaw` 命令是否存在
   - `openclaw --version` 是否正常工作
   - 版本输出是否有效

2. **网关状态检查**
   - 网关是否正在运行
   - 网关状态查询是否正常

3. **配置文件检查**
   - 配置文件是否存在
   - 配置文件是否有有效的 JSON 语法

4. **工作空间检查**
   - 工作空间目录是否存在
   - 重要工作空间文件是否存在

5. **详细诊断（可选）**
   - Node.js 版本检查（需要 >= 20）
   - npm 全局安装检查
   - 网络连通性检查（npm 注册表、API 端点）
   - PATH 环境变量分析

### 输出示例

**成功安装：**
```
=== OpenClaw Installation Verification ===
Timestamp: 2026-02-10 17:20:15 CST

=== 1. Basic Command Checks ===
✅ openclaw command exists
✅ openclaw --version works
✅ Valid OpenClaw version detected

=== 2. Gateway Status ===
✅ Gateway is running

=== 3. Configuration ===
✅ Config file exists: ~/.openclaw/openclaw.json
✅ Config file has valid JSON syntax

=== 4. Workspace ===
✅ Workspace directory exists
✅ AGENTS.md exists in workspace

=== Verification Summary ===
Passed: 7
Failed: 0
Warnings: 0
✅ All checks passed! OpenClaw is properly installed.
```

**有警告的安装：**
```
=== Verification Summary ===
Passed: 5
Failed: 0
Warnings: 2
✅ Core installation is functional (with 2 warnings).
```

**失败的安装：**
```
=== Verification Summary ===
Passed: 2
Failed: 3
Warnings: 1
❌ Installation verification failed (3 errors).
```

## 故障排除

### 常见问题及解决方案

#### 1. "openclaw: command not found"

**原因：** npm 全局二进制目录不在 PATH 中。

**解决方案：**
```bash
# 查找 npm 全局二进制目录
npm bin -g

# 添加到 PATH（临时）
export PATH="$PATH:$(npm bin -g)"

# 永久添加到 shell 配置文件
echo 'export PATH="$PATH:$(npm bin -g)"' >> ~/.bashrc
source ~/.bashrc

# 或者使用 npx
npx openclaw --version
```

#### 2. 网关无法启动

**原因：** 端口被占用或配置错误。

**解决方案：**
```bash
# 检查端口占用
sudo lsof -i :3000  # 默认端口

# 停止现有网关
openclaw gateway stop

# 查看错误日志
openclaw gateway logs

# 使用不同端口启动
openclaw gateway start --port 3001
```

#### 3. 配置文件错误

**原因：** JSON 语法错误或配置无效。

**解决方案：**
```bash
# 验证 JSON 语法
jq empty ~/.openclaw/openclaw.json

# 备份并重新初始化配置
mv ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
openclaw config init

# 使用示例配置
curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/examples/config.json -o ~/.openclaw/openclaw.json
```

#### 4. 网络连接问题

**原因：** 防火墙、代理或 DNS 问题。

**解决方案：**
```bash
# 运行网络测试
./scripts/install-cn.sh --network-test

# 检查网络连通性
curl -fsS https://registry.npmmirror.com/-/ping
curl -fsS https://registry.npmjs.org/-/ping

# 使用代理（如果需要）
npm config set proxy http://proxy.example.com:8080
npm config set https-proxy http://proxy.example.com:8080
```

#### 5. Node.js 版本过旧

**原因：** OpenClaw 需要 Node.js >= 20。

**解决方案：**
```bash
# 检查当前版本
node -v

# 升级 Node.js
# 使用 nvm（推荐）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 22
nvm use 22

# 或使用官方安装包
# 访问 https://nodejs.org/
```

## 集成到 CI/CD

验证脚本可以集成到 CI/CD 流程中：

```yaml
# GitHub Actions 示例
name: Verify OpenClaw Installation

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '22'
        
    - name: Install OpenClaw
      run: npm install -g openclaw@latest
      
    - name: Verify installation
      run: ./scripts/verify-openclaw-install.sh --quiet
      
    - name: Run detailed diagnostics
      run: ./scripts/verify-openclaw-install.sh --detailed
```

## 自动化监控

可以将验证脚本添加到 cron 作业进行定期检查：

```bash
# 每天检查一次
0 9 * * * cd /path/to/roc-ai-republic && ./scripts/verify-openclaw-install.sh --quiet > /tmp/openclaw-health.log 2>&1

# 检查结果并发送通知
if [ $? -ne 0 ]; then
  echo "OpenClaw installation check failed" | mail -s "OpenClaw Health Alert" admin@example.com
fi
```

## 相关资源

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [安装脚本 (install-cn.sh)](./install-cn.md)
- [配置指南](./openclaw-cn-pack-deepseek-v0.md)
- [故障排除指南](./troubleshooting.md)

## 更新日志

- **2026-02-10**: 创建安装验证脚本和文档
- **功能**: 提供完整的安装验证、详细诊断和故障排除指南
- **目标**: 确保 OpenClaw 安装质量，减少用户支持请求