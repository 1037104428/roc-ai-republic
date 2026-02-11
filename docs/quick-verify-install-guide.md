# OpenClaw CN 快速验证指南

## 概述

`quick-verify-install.sh` 是一个轻量级验证脚本，专门用于快速检查 OpenClaw CN 安装的关键功能。适用于 CI/CD 环境、自动化测试或快速安装验证场景。

## 特性

- **快速执行**: 5秒内完成所有检查
- **关键检查**: 仅验证最关键的功能点
- **CI/CD 友好**: 返回明确的退出码 (0=成功, 1=失败)
- **颜色编码输出**: 绿色=成功, 红色=错误, 黄色=警告
- **详细日志**: 每个检查步骤都有明确的状态反馈

## 检查项目

脚本检查以下关键功能：

1. **openclaw 命令存在性** - 验证 `openclaw` 命令是否在 PATH 中
2. **OpenClaw 版本** - 获取并显示当前安装的 OpenClaw 版本
3. **快速状态检查** - 运行 `openclaw status` 检查基本状态
4. **工作空间目录** - 验证 `~/.openclaw/workspace` 目录是否存在
5. **Gateway 服务状态** - 检查 OpenClaw Gateway 服务状态

## 使用方法

### 基本使用

```bash
# 下载并运行快速验证
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash --verify

# 或直接运行本地脚本
./scripts/quick-verify-install.sh
```

### CI/CD 集成示例

```bash
#!/bin/bash
# GitHub Actions / GitLab CI 示例

# 安装 OpenClaw CN
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 快速验证安装
if ./scripts/quick-verify-install.sh; then
  echo "✅ OpenClaw CN 安装验证通过"
  exit 0
else
  echo "❌ OpenClaw CN 安装验证失败"
  exit 1
fi
```

### Dockerfile 集成示例

```dockerfile
FROM ubuntu:22.04

# 安装依赖
RUN apt-get update && apt-get install -y curl bash

# 安装 OpenClaw CN
RUN curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash

# 复制快速验证脚本
COPY scripts/quick-verify-install.sh /usr/local/bin/

# 验证安装
RUN quick-verify-install.sh

# 设置工作目录
WORKDIR /app
```

## 命令行选项

```bash
# 显示帮助信息
./scripts/quick-verify-install.sh --help

# 显示脚本版本
./scripts/quick-verify-install.sh --version

# 运行快速验证（默认）
./scripts/quick-verify-install.sh
```

## 退出码

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 所有关键检查通过 |
| 1 | 失败 | 发现关键问题（如 openclaw 命令不存在） |
| 其他 | 错误 | 脚本执行错误 |

## 输出示例

### 成功示例
```
=== OpenClaw CN 快速验证 ===
脚本版本: 2026.02.11.2253
开始时间: 2026-02-11 22:55:14 CST

[INFO] 1. 检查 openclaw 命令...
[SUCCESS]   ✓ openclaw 命令存在
[INFO] 2. 检查 openclaw 版本...
[SUCCESS]   ✓ OpenClaw 版本: 2026.2.9
[INFO] 3. 快速状态检查...
[SUCCESS]   ✓ OpenClaw 状态正常
[INFO] 4. 检查工作空间目录...
[SUCCESS]   ✓ 工作空间目录存在: /home/user/.openclaw/workspace
[INFO] 5. 检查 Gateway 服务状态...
[SUCCESS]   ✓ Gateway 服务正常

=== 验证结果 ===
✅ 快速验证通过 - 所有关键检查正常
```

### 失败示例
```
=== OpenClaw CN 快速验证 ===
脚本版本: 2026.02.11.2253
开始时间: 2026-02-11 22:55:14 CST

[INFO] 1. 检查 openclaw 命令...
[ERROR]   ✗ openclaw 命令未找到

=== 验证结果 ===
❌ 快速验证失败 - 发现关键问题
```

## 故障排除

### 常见问题

1. **openclaw 命令未找到**
   ```bash
   # 检查 PATH 环境变量
   echo $PATH
   
   # 手动查找 openclaw
   find ~ -name "openclaw" -type f 2>/dev/null
   
   # 重新安装
   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
   ```

2. **Gateway 服务未运行**
   ```bash
   # 启动 Gateway 服务
   openclaw gateway start
   
   # 检查服务状态
   openclaw gateway status
   ```

3. **工作空间目录不存在**
   ```bash
   # 创建工作空间目录
   mkdir -p ~/.openclaw/workspace
   
   # 初始化工作空间
   openclaw init
   ```

## 与完整验证的对比

| 特性 | 快速验证 | 完整验证 |
|------|----------|----------|
| 检查时间 | <5秒 | 30-60秒 |
| 检查项目 | 5个关键点 | 20+个项目 |
| 适用场景 | CI/CD、快速检查 | 完整安装验证、故障排除 |
| 输出详细程度 | 中等 | 详细 |
| 退出码 | 简单 (0/1) | 详细错误码 |

## 更新日志

### v2026.02.11.2253
- 初始版本发布
- 包含5个关键检查项目
- 支持 CI/CD 集成
- 颜色编码输出

## 相关资源

- [完整验证命令文档](install-cn-quick-verification-commands.md) - 详细的安装验证指南
- [安装脚本](../scripts/install-cn.sh) - OpenClaw CN 主安装脚本
- [GitHub 仓库](https://github.com/1037104428/roc-ai-republic) - 项目源代码
- [在线文档](https://clawdrepublic.cn/docs) - 在线文档和教程