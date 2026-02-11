# 安装兼容性验证脚本

## 概述

`verify-install-compatibility.sh` 是一个用于验证 OpenClaw 安装后版本兼容性和功能完整性的脚本。它提供了一套标准化的验证流程，确保安装后的系统能够正常工作。

## 功能特性

### 核心验证功能

1. **版本检查**
   - OpenClaw 版本命令验证
   - Node.js 和 npm 版本检查
   - Git 版本验证

2. **系统状态验证**
   - OpenClaw 主状态检查
   - 网关状态验证
   - 配置文件完整性检查

3. **工作空间验证**
   - 配置文件目录检查
   - 工作空间目录检查
   - 关键配置文件存在性验证

4. **工具链验证**
   - 技能系统功能验证
   - 命令可用性测试

### 高级功能

- **干运行模式**: 预览将要执行的命令而不实际执行
- **详细输出**: 显示详细的执行过程和命令
- **彩色输出**: 使用颜色区分不同级别的信息
- **兼容性报告**: 生成完整的兼容性验证报告

## 快速开始

### 基本使用

```bash
# 执行完整验证
./scripts/verify-install-compatibility.sh

# 干运行模式（预览命令）
./scripts/verify-install-compatibility.sh --dry-run

# 详细输出模式
./scripts/verify-install-compatibility.sh --verbose
```

### 验证步骤示例

```bash
$ ./scripts/verify-install-compatibility.sh
[INFO] 开始验证OpenClaw安装兼容性
[INFO] 时间: 2026-02-11 18:57:30

[INFO] 检查: OpenClaw版本命令
[SUCCESS] OpenClaw版本命令 ✓

[INFO] 检查: OpenClaw状态检查
[SUCCESS] OpenClaw状态检查 ✓

[INFO] 检查: 网关状态检查
[SUCCESS] 网关状态检查 ✓

[SUCCESS] 配置文件目录存在: /home/user/.openclaw ✓
[SUCCESS] 配置文件存在: config.yaml ✓
[SUCCESS] 配置文件存在: agents.yaml ✓

[INFO] 检查: Node.js版本
[SUCCESS] Node.js版本 ✓

[INFO] 检查: npm版本
[SUCCESS] npm版本 ✓

[INFO] 检查: Git版本
[SUCCESS] Git版本 ✓

[SUCCESS] 工作空间目录存在: /home/user/.openclaw/workspace ✓
[SUCCESS] 工作空间文件存在: AGENTS.md ✓
[SUCCESS] 工作空间文件存在: SOUL.md ✓
[SUCCESS] 工作空间文件存在: USER.md ✓

[INFO] 检查: 技能列表
[SUCCESS] 技能列表 ✓

[INFO] 兼容性验证完成

=== 兼容性验证摘要 ===
验证时间: 2026-02-11 18:57:31
系统: Linux x86_64
Node.js: v22.22.0
OpenClaw: openclaw/0.1.0
配置文件: 存在
工作空间: 存在
======================
```

## 命令行选项

| 选项 | 描述 | 示例 |
|------|------|------|
| `--dry-run` | 干运行模式，只显示将要执行的命令 | `./verify-install-compatibility.sh --dry-run` |
| `--verbose` | 详细输出模式，显示更多信息 | `./verify-install-compatibility.sh --verbose` |
| `--help` | 显示帮助信息 | `./verify-install-compatibility.sh --help` |

## 验证项目说明

### 1. 版本兼容性验证
- 检查 OpenClaw 版本命令是否正常工作
- 验证 Node.js 和 npm 版本兼容性
- 确保 Git 版本满足要求

### 2. 系统状态验证
- 验证 OpenClaw 主服务状态
- 检查网关服务运行状态
- 确认配置文件目录结构完整

### 3. 配置文件验证
- 检查关键配置文件是否存在
- 验证配置文件目录权限
- 确保工作空间文件完整

### 4. 工具链验证
- 验证技能系统功能
- 检查命令执行权限
- 确认环境变量设置

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: 安装兼容性验证

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-compatibility:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: 安装 OpenClaw
      run: |
        npm install -g openclaw
    
    - name: 运行兼容性验证
      run: |
        chmod +x scripts/verify-install-compatibility.sh
        ./scripts/verify-install-compatibility.sh --verbose
```

### 本地开发验证

```bash
# 在开发过程中定期验证
make verify-compatibility

# 或作为预提交钩子
ln -s ../../scripts/verify-install-compatibility.sh .git/hooks/pre-commit
```

## 故障排除

### 常见问题

1. **"OpenClaw版本命令 ✗"**
   - 原因: OpenClaw 未正确安装
   - 解决: 重新运行 `npm install -g openclaw`

2. **"配置文件目录不存在"**
   - 原因: OpenClaw 未初始化
   - 解决: 运行 `openclaw init` 初始化配置

3. **"工作空间目录不存在"**
   - 原因: 工作空间未创建
   - 解决: 检查 `~/.openclaw/workspace` 目录或重新初始化

### 调试模式

```bash
# 启用详细输出和错误追踪
bash -x ./scripts/verify-install-compatibility.sh --verbose

# 检查特定验证步骤
./scripts/verify-install-compatibility.sh 2>&1 | grep -A5 -B5 "ERROR"
```

## 相关文档

- [安装指南](../README.md#安装)
- [配置说明](../docs/CONFIGURATION.md)
- [故障排除指南](../docs/TROUBLESHOOTING.md)
- [开发指南](../docs/DEVELOPMENT.md)

## 贡献指南

欢迎提交问题和改进建议。请确保：

1. 在提交前运行验证脚本
2. 更新相关文档
3. 添加适当的测试用例

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 添加基本兼容性验证功能
- 支持干运行和详细输出模式
- 生成兼容性验证报告