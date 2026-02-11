# 快速文档完整性检查指南

## 概述

`quick-docs-check.sh` 是一个轻量级的文档完整性检查工具，用于快速验证 quota-proxy 项目中所有核心文档的完整性和互引用关系。它提供了快速的状态检查，帮助开发者和维护者确保文档体系的一致性。

## 快速开始

```bash
# 进入 quota-proxy 目录
cd /path/to/roc-ai-republic/quota-proxy

# 运行快速文档检查
./quick-docs-check.sh
```

## 功能特性

### 1. 核心文档存在性检查
- 检查以下核心文档是否存在：
  - `README.md` - 主文档
  - `VALIDATION-QUICK-INDEX.md` - 验证快速索引
  - `VALIDATION-EXAMPLES.md` - 验证示例
  - `ENHANCED-VALIDATION-DOCS-CHECK.md` - 增强版检查指南
  - `TROUBLESHOOTING.md` - 故障排除指南
  - `QUICK-VERIFICATION-COMMANDS.md` - 快速验证命令集合

### 2. 文档互引用检查
- 验证 `README.md` 是否引用了关键文档
- 检查文档之间的引用关系是否完整

### 3. 脚本可执行权限检查
- 检查验证脚本的可执行权限
- 自动修复不可执行的脚本权限

### 4. 增强版检查集成
- 如果存在增强版检查脚本，自动运行并显示前20行结果

### 5. 快速命令参考
- 提供相关的快速命令参考，方便用户使用

## 使用场景

### 开发环境检查
```bash
# 在开发新功能后，快速检查文档完整性
./quick-docs-check.sh
```

### CI/CD 集成
```bash
# 在 CI/CD 流水线中添加文档检查步骤
./quick-docs-check.sh || exit 1
```

### 项目维护
```bash
# 定期运行以确保文档体系的一致性
./quick-docs-check.sh
```

## 输出示例

```
🔍 quota-proxy 文档完整性快速检查
==================================

📄 检查核心文档文件...
  ✅ README.md - 主文档
  ✅ VALIDATION-QUICK-INDEX.md - 验证快速索引
  ✅ VALIDATION-EXAMPLES.md - 验证示例
  ✅ ENHANCED-VALIDATION-DOCS-CHECK.md - 增强版检查指南
  ✅ TROUBLESHOOTING.md - 故障排除指南
  ✅ QUICK-VERIFICATION-COMMANDS.md - 快速验证命令集合

🔗 检查文档互引用...
  ✅ README.md 引用 VALIDATION-QUICK-INDEX.md
  ✅ README.md 引用 TROUBLESHOOTING.md

⚙️  检查验证脚本...
  ✅ verify-validation-docs.sh (可执行)
  ✅ verify-validation-docs-enhanced.sh (可执行)

📊 运行增强版文档检查...
🔍 增强版文档完整性检查...
==================================
📄 检查文档文件...
  ✅ README.md (主文档)
  ✅ VALIDATION-QUICK-INDEX.md (验证快速索引)
  ✅ VALIDATION-EXAMPLES.md (验证示例)
  ✅ ENHANCED-VALIDATION-DOCS-CHECK.md (增强版检查指南)
  ✅ TROUBLESHOOTING.md (故障排除指南)
  ✅ QUICK-VERIFICATION-COMMANDS.md (快速验证命令集合)

📋 检查总结:
  ✅ 所有核心文档都存在

💡 快速命令参考:
  ./quick-docs-check.sh              # 运行本检查
  ./verify-validation-docs.sh        # 基础文档检查
  ./verify-validation-docs-enhanced.sh # 增强版检查
  cat VALIDATION-QUICK-INDEX.md      # 查看验证工具索引
```

## 与其他工具的关系

### 与基础文档检查的关系
- `verify-validation-docs.sh` - 基础文档检查，提供基本的文件存在性检查
- `quick-docs-check.sh` - 快速检查，包含互引用和权限检查

### 与增强版检查的关系
- `verify-validation-docs-enhanced.sh` - 增强版检查，提供详细的文档结构分析
- `quick-docs-check.sh` - 快速检查，集成增强版检查的部分功能

### 与验证工具索引的关系
- `VALIDATION-QUICK-INDEX.md` - 提供所有验证工具的索引
- `quick-docs-check.sh` - 快速检查工具之一，在索引中被引用

## 最佳实践

### 1. 定期运行
建议在以下情况下运行快速文档检查：
- 添加新文档后
- 修改现有文档后
- 项目发布前
- 定期维护时

### 2. 结合其他检查工具
```bash
# 结合其他检查工具进行全面验证
./quick-docs-check.sh
./verify-validation-docs-enhanced.sh
./run-all-verifications.sh
```

### 3. 自动化集成
可以将快速文档检查集成到：
- Git 钩子（pre-commit, pre-push）
- CI/CD 流水线
- 定期维护脚本

## 故障排除

### 常见问题

#### 1. 脚本不可执行
```bash
# 修复脚本权限
chmod +x quick-docs-check.sh
```

#### 2. 文档缺失
如果检查报告文档缺失：
1. 确认文档是否在正确目录
2. 检查文档文件名是否正确
3. 如果需要，从备份或版本控制中恢复

#### 3. 互引用错误
如果互引用检查失败：
1. 更新 `README.md` 添加正确的引用
2. 确保引用路径正确

### 调试模式
```bash
# 查看详细输出
bash -x ./quick-docs-check.sh
```

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 包含核心文档存在性检查
- 包含文档互引用检查
- 包含脚本权限检查
- 集成增强版检查功能

## 贡献指南

欢迎贡献改进建议和 bug 报告。请通过以下方式贡献：
1. Fork 项目仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。