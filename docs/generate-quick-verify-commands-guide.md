# generate-quick-verify-commands.sh 使用指南

## 概述

`generate-quick-verify-commands.sh` 是一个用于生成 OpenClaw 安装验证命令的实用脚本。它可以帮助用户快速生成验证安装是否成功的命令序列，支持多种验证类型和输出格式。

## 功能特性

- **多种验证类型**: 基础验证、完整验证、自定义模板
- **多种输出格式**: 文本、Markdown、JSON
- **灵活的输出选项**: 支持输出到文件或控制台
- **模拟运行模式**: 在不实际生成命令的情况下测试脚本
- **详细模式**: 提供额外的使用建议和信息
- **完整的验证脚本**: 包含 `verify-quick-verify-commands.sh` 用于功能验证

## 快速开始

### 1. 基本用法

```bash
# 生成基础验证命令（文本格式）
./scripts/generate-quick-verify-commands.sh --type basic --format text

# 生成完整验证命令（Markdown格式）
./scripts/generate-quick-verify-commands.sh --type full --format markdown

# 生成自定义验证模板
./scripts/generate-quick-verify-commands.sh --type custom --format text
```

### 2. 输出到文件

```bash
# 将验证命令保存到文件
./scripts/generate-quick-verify-commands.sh --type basic --format text --output verify-commands.txt

# 生成Markdown格式的验证文档
./scripts/generate-quick-verify-commands.sh --type full --format markdown --output VERIFICATION.md
```

### 3. 模拟运行

```bash
# 模拟运行，查看脚本将执行的操作
./scripts/generate-quick-verify-commands.sh --dry-run --verbose
```

## 验证类型详解

### 基础验证 (basic)

基础验证包含最核心的安装检查点：

1. **OpenClaw版本检查** - 验证安装的版本
2. **配置文件检查** - 检查配置文件是否存在和基本内容
3. **服务状态检查** - 检查OpenClaw服务运行状态
4. **工作空间检查** - 验证工作空间目录结构
5. **日志文件检查** - 检查日志文件是否存在
6. **内存文件检查** - 检查记忆文件系统

### 完整验证 (full)

完整验证在基础验证的基础上增加了更多检查点：

1. **所有基础验证检查点**
2. **健康检查** - 执行OpenClaw健康检查
3. **网络连接检查** - 测试与OpenClaw API的连接
4. **节点状态检查** - 检查配对节点状态
5. **技能列表检查** - 查看已安装技能
6. **会话状态检查** - 检查当前会话
7. **Cron作业检查** - 查看计划任务
8. **系统资源检查** - 检查磁盘空间使用情况
9. **安装脚本验证** - 验证安装脚本语法
10. **安装摘要生成** - 生成完整的安装报告

### 自定义模板 (custom)

自定义模板提供了一个框架，用户可以在此基础上添加自己的验证命令：

```bash
# 自定义验证命令模板
# 1. 基础检查
openclaw --version
openclaw status

# 2. 服务检查
# openclaw gateway status
# openclaw health

# 3. 网络检查
# curl -fsS https://api.openclaw.ai/v1/health
# ping -c 3 api.openclaw.ai

# 4. 文件检查
# ls -la ~/.openclaw/
# find ~/.openclaw -name "*.yaml" -type f

# 5. 日志检查
# tail -20 ~/.openclaw/logs/openclaw.log
# grep -i error ~/.openclaw/logs/*.log | head -10

# 6. 自定义检查点
# echo '添加您的自定义检查命令...'
```

## 输出格式

### 文本格式 (text)

纯文本格式，适合直接在终端查看和执行：

```
=== OpenClaw 安装验证命令 (基础验证) ===
生成时间: 2026-02-11 13:05:30
验证类型: 基础验证
使用方法: 复制以下命令到终端执行
==========================================

# 1. 检查OpenClaw版本
openclaw --version

# 2. 检查配置文件
ls -la ~/.openclaw/config.yaml
cat ~/.openclaw/config.yaml | head -20
```

### Markdown格式 (markdown)

Markdown格式，适合文档化和分享：

```markdown
# OpenClaw 安装验证命令

## 基本信息
- **生成时间**: 2026-02-11 13:05:30
- **验证类型**: 基础验证
- **使用方法**: 复制以下命令到终端执行

## 验证命令

```bash
# 1. 检查OpenClaw版本
openclaw --version

# 2. 检查配置文件
ls -la ~/.openclaw/config.yaml
cat ~/.openclaw/config.yaml | head -20
\```
```

### JSON格式 (json)

JSON格式，适合程序化处理：

```json
{
  "metadata": {
    "generated_at": "2026-02-11T13:05:30+08:00",
    "verify_type": "basic",
    "type_name": "基础验证",
    "format": "text"
  },
  "commands": [
    "# 1. 检查OpenClaw版本",
    "openclaw --version",
    "",
    "# 2. 检查配置文件",
    "ls -la ~/.openclaw/config.yaml",
    "cat ~/.openclaw/config.yaml | head -20"
  ]
}
```

## 使用场景

### 场景1: 安装后验证

```bash
# 安装OpenClaw后，快速验证安装是否成功
./scripts/generate-quick-verify-commands.sh --type basic --format text | bash
```

### 场景2: 故障排除

```bash
# 生成完整的验证命令用于故障排除
./scripts/generate-quick-verify-commands.sh --type full --format markdown --output troubleshooting.md
# 然后逐条执行命令排查问题
```

### 场景3: 文档化安装验证

```bash
# 为项目文档生成验证步骤
./scripts/generate-quick-verify-commands.sh --type full --format markdown --output docs/INSTALLATION_VERIFICATION.md
```

### 场景4: CI/CD集成

```bash
# 在CI/CD流水线中生成验证命令
./scripts/generate-quick-verify-commands.sh --type basic --format json --output verify-commands.json
# 然后使用脚本解析并执行
```

## 脚本验证

使用 `verify-quick-verify-commands.sh` 验证脚本功能：

```bash
# 语法检查
./scripts/verify-quick-verify-commands.sh --test syntax

# 基础功能测试
./scripts/verify-quick-verify-commands.sh --test basic --verbose

# 完整功能测试
./scripts/verify-quick-verify-commands.sh --test full --verbose --cleanup
```

## 最佳实践

### 1. 定期验证

建议在以下情况下执行安装验证：
- 安装或升级OpenClaw后
- 修改配置文件后
- 系统更新后
- 遇到问题时

### 2. 保存验证结果

```bash
# 保存验证命令和执行结果
./scripts/generate-quick-verify-commands.sh --type full --format text --output verify-commands.txt
bash verify-commands.txt 2>&1 | tee verification-results.txt
```

### 3. 自定义验证

使用自定义模板创建适合特定环境的验证脚本：

```bash
# 生成自定义模板
./scripts/generate-quick-verify-commands.sh --type custom --format text --output custom-verify.sh

# 编辑自定义模板，添加特定检查
vim custom-verify.sh

# 执行自定义验证
bash custom-verify.sh
```

### 4. 集成到工作流程

将验证脚本集成到日常工作中：
- 添加到项目README
- 集成到部署脚本
- 作为健康检查的一部分
- 用于新团队成员的环境验证

## 故障排除

### 常见问题

1. **脚本没有执行权限**
   ```bash
   chmod +x ./scripts/generate-quick-verify-commands.sh
   chmod +x ./scripts/verify-quick-verify-commands.sh
   ```

2. **输出文件无法创建**
   ```bash
   # 检查目录权限
   ls -la $(dirname output-file)
   # 使用绝对路径
   ./scripts/generate-quick-verify-commands.sh --output /tmp/verify-commands.txt
   ```

3. **验证命令执行失败**
   - 检查OpenClaw是否已安装
   - 检查网络连接
   - 查看错误信息进行针对性解决

### 调试模式

```bash
# 启用详细输出
./scripts/generate-quick-verify-commands.sh --verbose

# 查看脚本内部变量（开发用途）
# 在脚本中添加: set -x
```

## 版本历史

- **v1.0.0** (2026-02-11): 初始版本
  - 支持基础验证、完整验证、自定义模板
  - 支持文本、Markdown、JSON输出格式
  - 包含完整的验证脚本
  - 提供详细的使用指南

## 贡献

欢迎提交问题和改进建议：
1. 在GitHub仓库创建Issue
2. 提交Pull Request
3. 通过邮件联系维护者

## 许可证

本脚本是中华AI共和国 / OpenClaw 小白中文包项目的一部分，遵循项目相同的开源协议。