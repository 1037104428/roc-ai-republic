# 快速验证OpenClaw安装指南

## 概述

`quick-verify-openclaw.sh` 是一个轻量级的OpenClaw安装验证脚本，用于在安装后快速检查OpenClaw是否安装成功。它提供了比完整验证脚本更简单、更快速的验证功能。

## 功能特性

- ✅ **快速检查**: 6项核心检查，执行时间<2秒
- ✅ **多种输出模式**: 支持安静模式、详细模式和JSON输出
- ✅ **智能诊断**: 自动检测常见安装问题并提供解决方案
- ✅ **标准化退出码**: 明确的成功/失败状态
- ✅ **彩色输出**: 易于阅读的彩色终端输出

## 检查项目

脚本执行以下6项核心检查：

1. **openclaw命令检查** - 验证`openclaw`命令是否在PATH中可用
2. **版本检查** - 获取并显示OpenClaw版本信息
3. **配置文件检查** - 检查`~/.openclaw/openclaw.json`配置文件是否存在
4. **工作空间目录检查** - 验证工作空间目录结构
5. **Gateway状态检查** - 检查OpenClaw Gateway是否正在运行
6. **模型状态检查** - 检查模型配置状态

## 使用方法

### 基本使用

```bash
# 运行快速验证
./scripts/quick-verify-openclaw.sh

# 安静模式（只输出关键信息）
./scripts/quick-verify-openclaw.sh --quiet

# 详细模式（输出所有检查细节）
./scripts/quick-verify-openclaw.sh --verbose

# JSON输出模式（用于自动化脚本）
./scripts/quick-verify-openclaw.sh --json
```

### 在安装脚本中自动调用

`install-cn.sh` 安装脚本会自动检测并运行快速验证：

```bash
# 安装OpenClaw并自动验证
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

如果完整验证脚本不可用，安装脚本会自动回退到快速验证。

### 环境变量

```bash
# 指定openclaw可执行文件路径
OPENCLAW_PATH=/usr/local/bin/openclaw ./scripts/quick-verify-openclaw.sh
```

## 输出示例

### 成功验证
```
[快速验证] 开始OpenClaw快速验证...
[快速验证] 时间: 2026-02-10 22:15:30 CST

[快速验证] ✅ openclaw命令在PATH中找到: /usr/local/bin/openclaw
[快速验证] ✅ OpenClaw版本: openclaw/0.3.12 linux-x64 node-v22.22.0
[快速验证] ✅ 配置文件存在: /home/user/.openclaw/openclaw.json (大小: 1024字节)
[快速验证] ✅ 工作空间目录存在: /home/user/.openclaw/workspace (包含 15 个.md文件)
[快速验证] ✅ Gateway正在运行
[快速验证] ✅ 模型状态检查完成

[快速验证] 检查统计:
  ✅ 成功: 6
  ⚠️  警告: 0
  ❌ 错误: 0
  ℹ️  信息: 0

[快速验证] ✅ 所有检查通过！OpenClaw安装验证成功。
```

### 有警告的验证
```
[快速验证] ⚠️ Gateway未运行。运行 'openclaw gateway start' 启动
[快速验证] ⚠️ 配置文件不存在: /home/user/.openclaw/openclaw.json。运行 'openclaw config init' 创建

[快速验证] 检查统计:
  ✅ 成功: 4
  ⚠️  警告: 2
  ❌ 错误: 0
  ℹ️  信息: 0

[快速验证] ⚠️ 安装基本成功，但有警告需要关注。
```

### JSON输出
```json
{
  "timestamp": "2026-02-10T22:15:30+08:00",
  "checks": {
    "openclaw_command": {
      "status": "success",
      "message": "openclaw命令在PATH中找到: /usr/local/bin/openclaw"
    },
    "openclaw_version": {
      "status": "success",
      "message": "OpenClaw版本: openclaw/0.3.12 linux-x64 node-v22.22.0"
    }
  },
  "summary": {
    "success": 6,
    "warning": 0,
    "error": 0,
    "info": 0
  }
}
```

## 退出码

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 所有检查通过或只有警告 |
| 1 | 失败 | 有错误检查项 |
| 2 | 参数错误 | 命令行参数错误 |

## 故障排除

### 常见问题

1. **openclaw命令未找到**
   ```bash
   # 检查npm全局bin路径
   npm bin -g
   
   # 添加到PATH
   export PATH="$PATH:$(npm bin -g)"
   ```

2. **Gateway未运行**
   ```bash
   # 启动Gateway
   openclaw gateway start
   
   # 检查状态
   openclaw gateway status
   ```

3. **配置文件不存在**
   ```bash
   # 初始化配置
   openclaw config init
   
   # 或手动创建
   mkdir -p ~/.openclaw
   echo '{}' > ~/.openclaw/openclaw.json
   ```

### 手动验证命令

如果脚本不可用，可以手动运行以下命令验证安装：

```bash
# 1. 检查版本
openclaw --version

# 2. 检查状态
openclaw status

# 3. 检查Gateway
openclaw gateway status

# 4. 检查模型
openclaw models status

# 5. 检查配置文件
ls -la ~/.openclaw/openclaw.json

# 6. 检查工作空间
ls -la ~/.openclaw/workspace/
```

## 与完整验证脚本的比较

| 特性 | 快速验证脚本 | 完整验证脚本 |
|------|-------------|-------------|
| 检查项目 | 6项核心检查 | 20+项全面检查 |
| 执行时间 | <2秒 | 5-10秒 |
| 输出详细程度 | 适中 | 详细 |
| 诊断深度 | 基本诊断 | 深度诊断 |
| 适用场景 | 安装后快速验证 | 全面问题排查 |
| 自动化支持 | JSON输出 | JSON输出+HTML报告 |

## 集成到CI/CD

### GitHub Actions示例

```yaml
name: Verify OpenClaw Installation

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install OpenClaw
        run: npm install -g openclaw@latest
        
      - name: Run quick verification
        run: ./scripts/quick-verify-openclaw.sh --json
        id: verify
        
      - name: Upload verification results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: verification-results
          path: verification-results.json
```

### 本地自动化脚本

```bash
#!/bin/bash
# auto-verify.sh

# 运行快速验证并保存结果
./scripts/quick-verify-openclaw.sh --json > verification-results.json

# 解析结果
if jq -e '.summary.error == 0' verification-results.json >/dev/null 2>&1; then
  echo "✅ 验证通过"
  exit 0
else
  echo "❌ 验证失败"
  jq '.checks | to_entries[] | select(.value.status == "error") | .value.message' verification-results.json
  exit 1
fi
```

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 6项核心检查功能
- 支持安静/详细/JSON输出模式
- 集成到install-cn.sh安装脚本
- 完整的文档和示例

## 贡献指南

欢迎提交问题和改进建议：

1. Fork仓库
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建Pull Request

## 许可证

MIT License