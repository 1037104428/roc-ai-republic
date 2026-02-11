# OpenClaw CN 安装脚本验证指南

## 概述

本文档提供 `install-cn.sh` 安装脚本的完整验证指南，包括验证工具的使用、验证步骤、常见问题和最佳实践。

## 验证工具

### verify-install-cn.sh

我们提供了一个专门的验证脚本 `verify-install-cn.sh`，用于全面验证安装脚本的功能和完整性。

#### 安装验证脚本

```bash
# 下载验证脚本
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-install-cn.sh -o verify-install-cn.sh
chmod +x verify-install-cn.sh
```

#### 使用验证脚本

```bash
# 完整验证并生成报告
./verify-install-cn.sh --full --report

# 快速验证
./verify-install-cn.sh --quick

# 显示帮助
./verify-install-cn.sh --help
```

## 验证步骤

### 1. 基本验证

#### 1.1 脚本存在性和权限检查

```bash
# 检查脚本是否存在
test -f install-cn.sh && echo "✅ 脚本存在" || echo "❌ 脚本不存在"

# 检查脚本权限
test -x install-cn.sh && echo "✅ 脚本可执行" || chmod +x install-cn.sh
```

#### 1.2 语法检查

```bash
# 检查bash语法
bash -n install-cn.sh && echo "✅ 语法正确" || echo "❌ 语法错误"
```

### 2. 功能验证

#### 2.1 帮助功能

```bash
# 测试帮助功能
./install-cn.sh --help | grep -q "OpenClaw CN 快速安装脚本" && echo "✅ 帮助功能正常" || echo "❌ 帮助功能异常"
```

#### 2.2 干运行模式

```bash
# 测试干运行模式
./install-cn.sh --dry-run | grep -q "干运行模式" && echo "✅ 干运行模式正常" || echo "❌ 干运行模式异常"
```

#### 2.3 版本参数

```bash
# 测试版本参数
./install-cn.sh --dry-run --version 0.3.12 | grep -q "安装OpenClaw版本: 0.3.12" && echo "✅ 版本参数正常" || echo "❌ 版本参数异常"
```

#### 2.4 更新检查

```bash
# 测试更新检查
./install-cn.sh --check-update 2>&1 | grep -q "检查 OpenClaw CN 安装脚本更新" && echo "✅ 更新检查正常" || echo "⚠️ 更新检查异常或网络不可用"
```

#### 2.5 验证功能

```bash
# 测试验证功能
./install-cn.sh --dry-run --verify | grep -q "开始验证 OpenClaw 安装" && echo "✅ 验证功能正常" || echo "❌ 验证功能异常"
```

### 3. 完整性验证

#### 3.1 必需函数检查

```bash
# 检查必需函数
required_functions=(
    "main_install"
    "show_help"
    "color_log"
    "select_best_npm_registry"
    "install_with_fallback"
    "self_check_openclaw"
)

for func in "${required_functions[@]}"; do
    grep -q "^$func()" install-cn.sh && echo "✅ 函数存在: $func" || echo "❌ 函数缺失: $func"
done
```

#### 3.2 必需变量检查

```bash
# 检查必需变量
required_variables=(
    "SCRIPT_VERSION"
    "SCRIPT_UPDATE_URL"
)

for var in "${required_variables[@]}"; do
    grep -q "^$var=" install-cn.sh && echo "✅ 变量存在: $var" || echo "❌ 变量缺失: $var"
done
```

### 4. 文档验证

#### 4.1 相关文档检查

```bash
# 检查相关文档
required_docs=(
    "install-cn-guide.md"
    "install-cn-troubleshooting.md"
    "install-cn-quick-verification-commands.md"
    "install-cn-script-verification-guide.md"  # 本文档
)

for doc in "${required_docs[@]}"; do
    test -f "docs/$doc" && echo "✅ 文档存在: $doc" || echo "⚠️ 文档缺失: $doc"
done
```

## 验证报告

验证脚本会生成详细的验证报告，包含以下内容：

### 报告示例

```
OpenClaw CN 安装脚本验证报告
============================
验证时间: 2026-02-12 00:56:01 CST
验证脚本版本: 2026.02.12.0056
安装脚本路径: /path/to/install-cn.sh

验证结果:
  - check_script_exists: 通过
  - check_script_permissions: 通过
  - check_script_syntax: 通过
  - check_script_version: 通过
  - check_help_function: 通过
  - check_dry_run: 通过
  - check_version_param: 通过
  - check_update_check: 通过
  - check_verify_function: 通过
  - check_script_integrity: 通过
  - check_documentation_links: 通过

统计:
  总检查数: 11
  通过数: 11
  失败数: 0
  通过率: 100%

建议:
  所有检查通过，安装脚本状态良好。

下一步:
  1. 查看详细日志: 重新运行验证脚本
  2. 修复问题: 根据失败检查修复安装脚本
  3. 测试安装: 运行 ./install-cn.sh --dry-run
  4. 更新文档: 确保相关文档同步更新
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: Verify Install Script

on:
  push:
    paths:
      - 'scripts/install-cn.sh'
      - 'scripts/verify-install-cn.sh'
  pull_request:
    paths:
      - 'scripts/install-cn.sh'

jobs:
  verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Verify install script
      run: |
        chmod +x scripts/verify-install-cn.sh
        ./scripts/verify-install-cn.sh --full --report
        
    - name: Upload verification report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: install-script-verification-report
        path: /tmp/install-cn-verification-report-*.txt
```

### 本地 CI 脚本

```bash
#!/usr/bin/env bash
# ci-verify-install.sh

set -euo pipefail

echo "=== OpenClaw CN 安装脚本 CI 验证 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 运行验证
./scripts/verify-install-cn.sh --full --report

# 检查退出码
if [[ $? -eq 0 ]]; then
    echo "✅ CI 验证通过"
    exit 0
else
    echo "❌ CI 验证失败"
    exit 1
fi
```

## 故障排除

### 常见问题

#### 问题1: 脚本语法错误

**症状**: `bash -n install-cn.sh` 报告语法错误

**解决方案**:
```bash
# 检查具体错误
bash -n install-cn.sh 2>&1

# 常见问题:
# 1. 缺少引号: 检查所有字符串引号
# 2. 括号不匹配: 检查所有 if/for/while 语句
# 3. 变量引用错误: 检查所有 $variable 引用
```

#### 问题2: 函数缺失

**症状**: 验证报告显示某些函数缺失

**解决方案**:
```bash
# 检查函数定义
grep -n "function_name()" install-cn.sh

# 添加缺失函数
# 参考: https://github.com/1037104428/roc-ai-republic/blob/main/scripts/install-cn.sh
```

#### 问题3: 文档链接失效

**症状**: 验证报告显示文档缺失

**解决方案**:
```bash
# 检查文档目录
ls -la docs/

# 创建缺失文档
# 参考现有文档模板
```

### 调试模式

启用调试模式获取更多信息：

```bash
# 设置调试模式
export DEBUG=1

# 运行验证
./scripts/verify-install-cn.sh --full 2>&1 | tee verification-debug.log
```

## 最佳实践

### 1. 定期验证

建议在以下情况下运行验证：
- 安装脚本更新后
- 发布新版本前
- CI/CD 流水线中
- 每月定期检查

### 2. 版本管理

保持脚本版本同步：
```bash
# 更新脚本版本
sed -i 's/SCRIPT_VERSION="[^"]*"/SCRIPT_VERSION="2026.02.12.0056"/' install-cn.sh

# 更新验证脚本版本
sed -i 's/SCRIPT_VERSION="[^"]*"/SCRIPT_VERSION="2026.02.12.0056"/' verify-install-cn.sh
```

### 3. 文档同步

确保文档与脚本功能同步：
- 更新 `install-cn-guide.md` 反映新功能
- 更新 `install-cn-troubleshooting.md` 添加新问题
- 更新本文档添加新验证步骤

### 4. 测试覆盖

确保测试覆盖所有功能：
- 基本功能测试
- 参数测试
- 错误处理测试
- 边界条件测试

## 更新日志

### 2026-02-12
- 创建验证指南文档
- 添加验证脚本 `verify-install-cn.sh`
- 提供完整的验证步骤和示例
- 添加 CI/CD 集成示例
- 添加故障排除指南

## 相关文档

- [install-cn-guide.md](./install-cn-guide.md) - 安装脚本使用指南
- [install-cn-troubleshooting.md](./install-cn-troubleshooting.md) - 故障排除指南
- [install-cn-quick-verification-commands.md](./install-cn-quick-verification-commands.md) - 快速验证命令
- [install-cn-comprehensive-guide.md](./install-cn-comprehensive-guide.md) - 完整安装指南
- [../quota-proxy/VALIDATION-QUICK-INDEX.md](../quota-proxy/VALIDATION-QUICK-INDEX.md) - 验证脚本快速索引

## 贡献指南

欢迎贡献验证脚本和文档：

1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request
5. 确保所有验证通过

## 支持

如有问题，请：
1. 查看故障排除指南
2. 检查验证报告
3. 提交 Issue
4. 加入社区讨论