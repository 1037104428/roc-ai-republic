# 安装脚本验证命令生成器指南

## 概述

安装脚本验证命令生成器是一个辅助工具，用于快速生成 `install-cn.sh` 脚本的验证命令。它支持不同的验证级别、运行模式和输出格式，帮助用户根据需求快速生成合适的验证命令，提高安装脚本的验证效率和用户体验。

## 功能特性

- **多种验证级别**: 支持 quick、basic、full、complete 四种验证级别
- **批量验证模式**: 支持一次性生成多个验证级别的命令
- **灵活的运行模式**: 支持 dry-run 和 verbose 模式
- **多种输出格式**: 支持 text、markdown、json 三种输出格式
- **详细的说明信息**: 提供验证级别说明、退出码说明和实际执行命令
- **用户友好的界面**: 彩色输出、清晰的帮助信息和错误提示

## 快速开始

### 基本使用

```bash
# 显示帮助信息
./scripts/generate-install-cn-verification-commands.sh --help

# 生成快速验证命令
./scripts/generate-install-cn-verification-commands.sh

# 生成完整验证命令（dry-run模式）
./scripts/generate-install-cn-verification-commands.sh --verify-level full --dry-run

# 生成详细输出（verbose模式）
./scripts/generate-install-cn-verification-commands.sh --verbose --format markdown
```

### 常用命令组合

```bash
# 快速验证（默认）
./scripts/generate-install-cn-verification-commands.sh

# 基础验证 + dry-run
./scripts/generate-install-cn-verification-commands.sh -l basic -d

# 完整验证 + verbose + markdown输出
./scripts/generate-install-cn-verification-commands.sh -l full -v -f markdown

# 完全验证 + json输出
./scripts/generate-install-cn-verification-commands.sh -l complete -f json

# 批量验证模式（生成多个级别的命令）
./scripts/generate-install-cn-verification-commands.sh -b "quick,basic,full"

# 批量验证 + dry-run + markdown输出
./scripts/generate-install-cn-verification-commands.sh -b "basic,full,complete" -d -f markdown
```

## 验证级别详解

### 1. quick（快速验证）
**默认级别**，检查脚本语法和基本功能
- 脚本语法检查
- 参数解析验证
- 帮助信息显示
- 基本功能测试

**适用场景**: 快速检查脚本是否可正常运行

### 2. basic（基础验证）
检查依赖和网络连接
- 包含 quick 验证的所有项目
- 系统依赖检查
- 网络连接测试
- 权限检查
- 环境变量验证

**适用场景**: 检查安装环境是否满足基本要求

### 3. full（完整验证）
模拟完整安装流程
- 包含 basic 验证的所有项目
- 包管理器检测
- 下载源测试
- 安装模拟
- 回退策略验证

**适用场景**: 模拟完整安装过程，检查所有功能

### 4. complete（完全验证）
包含所有检查项
- 包含 full 验证的所有项目
- 环境兼容性检查
- 配置验证
- 性能测试
- 错误处理测试

**适用场景**: 全面验证脚本的所有功能和边界情况

## 输出格式说明

### 1. text（文本格式）
默认格式，适合在终端中直接查看
- 彩色输出，易于阅读
- 清晰的章节分隔
- 详细的说明信息

### 2. markdown（Markdown格式）
适合生成文档或报告
- 标准的 Markdown 语法
- 表格和列表格式
- 代码块高亮

### 3. json（JSON格式）
适合程序化处理
- 结构化的 JSON 数据
- 完整的配置信息
- 机器可读的格式

## 参数说明

### 命令行参数

| 参数 | 简写 | 说明 | 默认值 | 可选值 |
|------|------|------|--------|--------|
| `--verify-level` | `-l` | 验证级别 | `quick` | `quick`, `basic`, `full`, `complete` |
| `--batch` | `-b` | 批量验证模式，生成多个级别的命令 | `false` | 逗号分隔的级别列表，如 "quick,basic,full" |
| `--dry-run` | `-d` | 启用 dry-run 模式 | `false` | 无（标志参数） |
| `--verbose` | `-v` | 启用 verbose 模式 | `false` | 无（标志参数） |
| `--format` | `-f` | 输出格式 | `text` | `text`, `markdown`, `json` |
| `--help` | `-h` | 显示帮助信息 | `false` | 无（标志参数） |

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SCRIPT_DIR` | 脚本所在目录 | 自动检测 |
| `PROJECT_ROOT` | 项目根目录 | 自动检测 |

## 使用示例

### 示例 1：快速生成验证命令

```bash
# 生成快速验证命令
./scripts/generate-install-cn-verification-commands.sh

# 输出示例：
# === 安装脚本验证命令生成器 ===
# 
# 验证级别: quick
# Dry-run模式: false
# Verbose模式: false
# 
# 生成的验证命令:
#   /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh --verify-level quick
# 
# 说明: 快速验证 - 检查脚本语法和基本功能
#   包含: 脚本语法检查、参数解析、帮助信息显示
# 
# 实际执行命令:
#   cd "/home/kai/.openclaw/workspace/roc-ai-republic" && ./scripts/install-cn.sh --verify-level quick
```

### 示例 2：生成完整验证报告

```bash
# 生成完整验证报告（Markdown格式）
./scripts/generate-install-cn-verification-commands.sh \
  --verify-level full \
  --dry-run \
  --verbose \
  --format markdown > verification-report.md

# 查看生成的报告
cat verification-report.md
```

### 示例 3：批量验证模式

```bash
# 批量生成多个验证级别的命令
./scripts/generate-install-cn-verification-commands.sh \
  --batch "quick,basic,full" \
  --dry-run \
  --format text

# 批量生成完整验证报告（Markdown格式）
./scripts/generate-install-cn-verification-commands.sh \
  --batch "basic,full,complete" \
  --verbose \
  --format markdown > batch-verification-report.md

# 批量生成JSON配置
BATCH_CONFIG=$(./scripts/generate-install-cn-verification-commands.sh \
  --batch "quick,basic" \
  --format json)

# 提取批量生成的命令列表
echo "$BATCH_CONFIG" | jq -r '.generated_commands[].command'
```

### 示例 4：程序化处理

```bash
# 生成JSON格式的命令配置
CONFIG_JSON=$(./scripts/generate-install-cn-verification-commands.sh \
  --verify-level basic \
  --format json)

# 提取生成的命令
COMMAND=$(echo "$CONFIG_JSON" | jq -r '.generated_command.full_command')
echo "生成的命令: $COMMAND"

# 执行生成的命令
eval "$COMMAND"
```

## 退出码说明

| 退出码 | 说明 | 可能原因 |
|--------|------|----------|
| 0 | 成功 | 命令生成成功 |
| 1 | 参数错误 | 无效的命令行参数 |
| 2 | 脚本执行错误 | 脚本内部错误 |

## 批量验证模式详解

批量验证模式允许用户一次性生成多个验证级别的命令，特别适合需要执行多级验证的场景。

### 批量验证的优势

1. **效率提升**: 一次性生成所有需要的验证命令，避免重复执行
2. **一致性保证**: 所有验证命令使用相同的配置参数
3. **报告生成**: 生成统一的验证报告，便于审查和存档
4. **自动化集成**: 方便集成到CI/CD流水线和自动化测试中

### 批量验证使用场景

1. **多级验证流程**: 从快速验证到完整验证的渐进式验证流程
2. **环境适配测试**: 在不同环境中执行不同级别的验证
3. **回归测试**: 定期执行多级验证确保安装脚本稳定性
4. **用户支持**: 为用户提供多级验证选项，便于问题诊断

### 批量验证示例输出

```bash
# 批量验证输出示例（text格式）
=== 安装脚本批量验证命令生成器 ===

批量验证级别: quick,basic,full
Dry-run模式: false
Verbose模式: false

=== quick 级别验证命令 ===
  /path/to/install-cn.sh --verify-level quick

说明: 快速验证 - 检查脚本语法和基本功能
  包含: 脚本语法检查、参数解析、帮助信息显示

实际执行命令:
  cd "/path/to/project" && ./scripts/install-cn.sh --verify-level quick

---

=== basic 级别验证命令 ===
  /path/to/install-cn.sh --verify-level basic

说明: 基础验证 - 检查依赖和网络连接
  包含: 快速验证 + 依赖检查、网络连接测试、权限检查

实际执行命令:
  cd "/path/to/project" && ./scripts/install-cn.sh --verify-level basic

---
```

## 最佳实践

### 1. 集成到工作流中

```bash
# 在CI/CD流水线中使用
./scripts/generate-install-cn-verification-commands.sh \
  --verify-level complete \
  --dry-run \
  --format json \
  > verification-config.json

# 使用生成的配置执行验证
CONFIG=$(cat verification-config.json)
VERIFY_CMD=$(echo "$CONFIG" | jq -r '.generated_command.execution_command')
eval "$VERIFY_CMD"
```

### 2. 批量生成验证命令

```bash
# 使用批量验证模式（推荐）
./scripts/generate-install-cn-verification-commands.sh \
  --batch "quick,basic,full" \
  --dry-run \
  --format markdown \
  > all-verification-commands.md

# 传统循环方式（兼容性）
for level in quick basic full complete; do
  echo "=== 验证级别: $level ==="
  ./scripts/generate-install-cn-verification-commands.sh \
    --verify-level "$level" \
    --dry-run
  echo ""
done
```

### 3. 创建验证命令速查表

```bash
# 生成所有验证级别的命令速查表
./scripts/generate-install-cn-verification-commands.sh \
  --verify-level quick \
  --format markdown > quick-verification.md

./scripts/generate-install-cn-verification-commands.sh \
  --verify-level basic \
  --format markdown > basic-verification.md

./scripts/generate-install-cn-verification-commands.sh \
  --verify-level full \
  --format markdown > full-verification.md

./scripts/generate-install-cn-verification-commands.sh \
  --verify-level complete \
  --format markdown > complete-verification.md
```

## 故障排除

### 常见问题

1. **脚本权限问题**
   ```bash
   # 添加执行权限
   chmod +x ./scripts/generate-install-cn-verification-commands.sh
   ```

2. **参数错误**
   ```bash
   # 显示帮助信息，检查参数格式
   ./scripts/generate-install-cn-verification-commands.sh --help
   ```

3. **输出格式不支持**
   ```bash
   # 检查支持的输出格式
   ./scripts/generate-install-cn-verification-commands.sh --help | grep -A5 "输出格式"
   ```

### 调试模式

```bash
# 启用详细输出
set -x
./scripts/generate-install-cn-verification-commands.sh --verbose
set +x
```

## 更新记录

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持四种验证级别
- 支持三种输出格式
- 完整的文档和示例

## 相关文档

- [install-cn.sh 安装脚本](../scripts/install-cn.sh)
- [install-cn.sh 验证命令速查表](./install-cn-verification-cheat-sheet.md)
- [验证工具概览与使用指南](./verification-tools-overview.md)

---

**提示**: 使用 `--help` 参数查看最新的帮助信息，获取所有可用选项的详细说明。