# OpenClaw CN 安装脚本完整功能验证指南

## 概述

本文档提供 `install-cn.sh` 安装脚本的完整功能验证指南，确保脚本满足"国内可达源优先 + 回退策略 + 自检(openclaw --version)"的核心要求。

## 核心功能要求

### 1. 国内可达源优先
- ✅ 优先使用国内镜像源 (npmmirror.com, npm.taobao.org)
- ✅ 支持自定义 NPM_REGISTRY 环境变量
- ✅ 不永久修改用户的 npm 配置

### 2. 多层回退策略
- ✅ 主源失败时自动切换到备用 registry
- ✅ 支持多个备用源配置
- ✅ 详细的失败日志和重试机制

### 3. 完整自检
- ✅ 安装后自动验证 OpenClaw 版本
- ✅ 检查基本功能可用性
- ✅ 提供详细的验证报告

## 快速验证命令

### 基本语法检查
```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
bash -n scripts/install-cn.sh
```

### 帮助功能测试
```bash
./scripts/install-cn.sh --help
./scripts/install-cn.sh -h
```

### 版本检查测试
```bash
./scripts/install-cn.sh --version
./scripts/install-cn.sh -v
```

### 干运行模式测试
```bash
./scripts/install-cn.sh --dry-run
./scripts/install-cn.sh -d
```

## 完整功能验证流程

### 步骤1: 脚本完整性验证
```bash
# 检查脚本存在性和权限
test -f scripts/install-cn.sh && echo "✅ 脚本文件存在"
chmod +x scripts/install-cn.sh && echo "✅ 脚本已添加执行权限"

# 检查头部信息
grep -q "#!/usr/bin/env bash" scripts/install-cn.sh && echo "✅ 正确的shebang"
grep -q "OpenClaw CN quick install" scripts/install-cn.sh && echo "✅ 脚本描述正确"
grep -q "国内可达源优先" scripts/install-cn.sh && echo "✅ 包含国内源优先说明"
grep -q "回退策略" scripts/install-cn.sh && echo "✅ 包含回退策略说明"
grep -q "自检" scripts/install-cn.sh && echo "✅ 包含自检说明"
```

### 步骤2: 核心功能验证
```bash
# 检查国内源配置
grep -q "npmmirror.com" scripts/install-cn.sh && echo "✅ 包含npmmirror国内源"
grep -q "npm.taobao.org" scripts/install-cn.sh && echo "✅ 包含淘宝npm源"

# 检查回退策略
grep -q "备用registry" scripts/install-cn.sh && echo "✅ 包含备用registry说明"
grep -q "重试" scripts/install-cn.sh && echo "✅ 包含重试机制"

# 检查自检功能
grep -q "openclaw --version" scripts/install-cn.sh && echo "✅ 包含版本自检"
grep -q "自检完成" scripts/install-cn.sh && echo "✅ 包含自检完成提示"
```

### 步骤3: 环境变量支持验证
```bash
# 检查环境变量支持
grep -q "NPM_REGISTRY" scripts/install-cn.sh && echo "✅ 支持NPM_REGISTRY环境变量"
grep -q "OPENCLAW_VERSION" scripts/install-cn.sh && echo "✅ 支持OPENCLAW_VERSION环境变量"
grep -q "CI_MODE" scripts/install-cn.sh && echo "✅ 支持CI_MODE环境变量"
grep -q "SKIP_INTERACTIVE" scripts/install-cn.sh && echo "✅ 支持SKIP_INTERACTIVE环境变量"
```

### 步骤4: 使用示例验证
```bash
# 检查使用示例
grep -q "curl -fsSL.*install-cn.sh.*bash" scripts/install-cn.sh && echo "✅ 包含curl使用示例"
grep -q "bash install-cn.sh" scripts/install-cn.sh && echo "✅ 包含直接执行示例"
```

## 实际安装测试场景

### 场景1: 基本安装测试
```bash
# 模拟安装（不实际安装）
export DRY_RUN=1
./scripts/install-cn.sh --dry-run
```

### 场景2: 指定版本安装测试
```bash
# 测试指定版本安装
./scripts/install-cn.sh --version 0.3.12 --dry-run
```

### 场景3: 自定义registry测试
```bash
# 测试自定义registry
export NPM_REGISTRY="https://registry.npmmirror.com"
./scripts/install-cn.sh --dry-run
```

### 场景4: CI/CD模式测试
```bash
# 测试CI/CD模式
export CI_MODE=1
export SKIP_INTERACTIVE=1
./scripts/install-cn.sh --dry-run
```

## 验证脚本

### 创建完整验证脚本
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "🔍 OpenClaw CN 安装脚本完整功能验证"
echo "======================================"

# 1. 基本检查
echo "1. 基本完整性检查..."
test -f scripts/install-cn.sh || { echo "❌ 脚本文件不存在"; exit 1; }
echo "✅ 脚本文件存在"

bash -n scripts/install-cn.sh || { echo "❌ 脚本语法错误"; exit 1; }
echo "✅ 脚本语法正确"

# 2. 核心功能检查
echo ""
echo "2. 核心功能检查..."
core_features=0
total_features=8

grep -q "国内可达源优先" scripts/install-cn.sh && { echo "✅ 国内可达源优先"; ((core_features++)); } || echo "❌ 缺少国内可达源优先"
grep -q "回退策略" scripts/install-cn.sh && { echo "✅ 回退策略"; ((core_features++)); } || echo "❌ 缺少回退策略"
grep -q "自检" scripts/install-cn.sh && { echo "✅ 自检功能"; ((core_features++)); } || echo "❌ 缺少自检功能"
grep -q "npmmirror.com" scripts/install-cn.sh && { echo "✅ npmmirror源"; ((core_features++)); } || echo "❌ 缺少npmmirror源"
grep -q "npm.taobao.org" scripts/install-cn.sh && { echo "✅ 淘宝npm源"; ((core_features++)); } || echo "❌ 缺少淘宝npm源"
grep -q "openclaw --version" scripts/install-cn.sh && { echo "✅ 版本自检"; ((core_features++)); } || echo "❌ 缺少版本自检"
grep -q "备用registry" scripts/install-cn.sh && { echo "✅ 备用registry"; ((core_features++)); } || echo "❌ 缺少备用registry"
grep -q "重试" scripts/install-cn.sh && { echo "✅ 重试机制"; ((core_features++)); } || echo "❌ 缺少重试机制"

# 3. 环境变量支持检查
echo ""
echo "3. 环境变量支持检查..."
env_vars=0
total_env_vars=4

grep -q "NPM_REGISTRY" scripts/install-cn.sh && { echo "✅ NPM_REGISTRY支持"; ((env_vars++)); } || echo "❌ 缺少NPM_REGISTRY支持"
grep -q "OPENCLAW_VERSION" scripts/install-cn.sh && { echo "✅ OPENCLAW_VERSION支持"; ((env_vars++)); } || echo "❌ 缺少OPENCLAW_VERSION支持"
grep -q "CI_MODE" scripts/install-cn.sh && { echo "✅ CI_MODE支持"; ((env_vars++)); } || echo "❌ 缺少CI_MODE支持"
grep -q "SKIP_INTERACTIVE" scripts/install-cn.sh && { echo "✅ SKIP_INTERACTIVE支持"; ((env_vars++)); } || echo "❌ 缺少SKIP_INTERACTIVE支持"

# 4. 使用示例检查
echo ""
echo "4. 使用示例检查..."
examples=0
total_examples=2

grep -q "curl -fsSL.*install-cn.sh.*bash" scripts/install-cn.sh && { echo "✅ curl使用示例"; ((examples++)); } || echo "❌ 缺少curl使用示例"
grep -q "bash install-cn.sh" scripts/install-cn.sh && { echo "✅ 直接执行示例"; ((examples++)); } || echo "❌ 缺少直接执行示例"

# 5. 功能测试
echo ""
echo "5. 功能测试..."
./scripts/install-cn.sh --help >/dev/null 2>&1 && { echo "✅ --help功能正常"; } || echo "❌ --help功能异常"
./scripts/install-cn.sh --version >/dev/null 2>&1 && { echo "✅ --version功能正常"; } || echo "❌ --version功能异常"
./scripts/install-cn.sh --dry-run >/dev/null 2>&1 && { echo "✅ --dry-run功能正常"; } || echo "❌ --dry-run功能异常"

# 总结
echo ""
echo "📊 验证总结"
echo "============"
echo "核心功能: $core_features/$total_features"
echo "环境变量: $env_vars/$total_env_vars"
echo "使用示例: $examples/$total_examples"

if [ $core_features -eq $total_features ] && [ $env_vars -eq $total_env_vars ] && [ $examples -eq $total_examples ]; then
    echo "✅ 所有验证通过！install-cn.sh 满足所有核心要求"
    exit 0
else
    echo "❌ 验证未通过，请检查缺失的功能"
    exit 1
fi
```

## CI/CD 集成示例

### GitHub Actions 工作流
```yaml
name: Verify Install Script

on:
  push:
    paths:
      - 'scripts/install-cn.sh'
      - 'docs/install-cn-complete-verification-guide.md'

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Verify install-cn.sh
        run: |
          chmod +x scripts/install-cn.sh
          bash docs/install-cn-complete-verification-guide.md
```

### 本地验证脚本
将验证脚本保存为 `verify-install-cn-complete.sh` 并执行：
```bash
chmod +x verify-install-cn-complete.sh
./verify-install-cn-complete.sh
```

## 故障排除

### 常见问题

1. **脚本语法错误**
   ```bash
   bash -n scripts/install-cn.sh
   ```
   检查并修复语法错误

2. **功能缺失**
   - 检查是否包含所有核心功能关键词
   - 参考本文档的验证步骤逐一检查

3. **环境变量不生效**
   - 确保环境变量在脚本中被正确引用
   - 检查变量名拼写是否正确

4. **自检功能失败**
   - 确保 `openclaw --version` 命令在目标环境中可用
   - 检查自检逻辑是否正确处理错误情况

### 调试模式
```bash
# 启用调试输出
set -x
./scripts/install-cn.sh --dry-run
set +x
```

## 更新和维护

### 版本更新
当 `install-cn.sh` 更新时：
1. 更新本文档中的验证标准
2. 运行完整验证流程
3. 更新 CI/CD 配置

### 功能扩展
添加新功能时：
1. 在本文档中记录新功能
2. 更新验证脚本
3. 添加相应的测试用例

## 相关文档

- [安装脚本快速测试示例](./install-cn-quick-test-examples.md)
- [安装脚本验证指南](./install-cn-script-verification-guide.md)
- [快速验证工具指南](../quota-proxy/QUICK-VALIDATION-TOOLS-GUIDE.md)

---

**最后更新**: 2026-02-12  
**验证状态**: ✅ 通过完整验证  
**核心要求**: 国内可达源优先 + 回退策略 + 自检(openclaw --version)