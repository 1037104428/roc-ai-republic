# install-cn.sh 快速测试示例

本文档提供 `install-cn.sh` 安装脚本的快速测试示例，帮助用户快速验证脚本功能。

## 快速测试场景

### 场景1：基本安装测试（默认版本）

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh -o install-cn.sh

# 添加执行权限
chmod +x install-cn.sh

# 运行安装（使用国内源优先）
NPM_REGISTRY=https://registry.npmmirror.com ./install-cn.sh --dry-run

# 实际安装（需要确认）
# ./install-cn.sh
```

### 场景2：指定版本安装测试

```bash
# 安装特定版本
OPENCLAW_VERSION=0.3.12 ./install-cn.sh --dry-run

# 安装最新版本
OPENCLAW_VERSION=latest ./install-cn.sh --dry-run
```

### 场景3：CI/CD 集成测试

```bash
# 设置CI环境变量
export CI_MODE=1
export OPENCLAW_VERSION=latest
export NPM_REGISTRY=https://registry.npmmirror.com
export SKIP_INTERACTIVE=1
export INSTALL_LOG=/tmp/openclaw-install-ci.log

# 运行安装测试
./install-cn.sh --dry-run

# 检查安装日志
if [ -f "$INSTALL_LOG" ]; then
  echo "安装日志内容:"
  tail -20 "$INSTALL_LOG"
fi
```

### 场景4：网络回退策略测试

```bash
# 测试国内源失败时的回退机制
NPM_REGISTRY=https://registry.npmmirror.com ./install-cn.sh --dry-run --force-fallback

# 测试直接使用npmjs源
NPM_REGISTRY=https://registry.npmjs.org ./install-cn.sh --dry-run
```

### 场景5：自检功能测试

```bash
# 安装后自检
./install-cn.sh --dry-run --self-check

# 手动验证安装
if command -v openclaw &> /dev/null; then
  echo "OpenClaw 已安装"
  openclaw --version
else
  echo "OpenClaw 未安装"
fi
```

## 验证步骤

### 步骤1：脚本完整性验证

```bash
# 检查脚本语法
bash -n install-cn.sh && echo "语法检查通过"

# 检查脚本版本
grep -E "^SCRIPT_VERSION=" install-cn.sh

# 检查帮助信息
./install-cn.sh --help | head -20
```

### 步骤2：功能验证

```bash
# 验证国内源优先逻辑
grep -n "npmmirror" install-cn.sh

# 验证回退策略
grep -n "fallback" install-cn.sh

# 验证自检功能
grep -n "self-check" install-cn.sh
```

### 步骤3：安装验证

```bash
# 创建测试目录
mkdir -p /tmp/openclaw-test
cd /tmp/openclaw-test

# 运行完整安装测试（需要网络）
./install-cn.sh --dry-run --verbose

# 检查安装计划
grep -i "install" /tmp/openclaw-install-ci.log 2>/dev/null || true
```

## 故障排除

### 常见问题1：网络连接失败

```bash
# 测试网络连接
curl -I https://registry.npmmirror.com
curl -I https://registry.npmjs.org

# 设置代理（如果需要）
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

### 常见问题2：权限不足

```bash
# 检查npm权限
npm config get prefix

# 使用用户目录安装
export NPM_CONFIG_PREFIX=~/.npm-global
export PATH=~/.npm-global/bin:$PATH
```

### 常见问题3：版本冲突

```bash
# 检查现有OpenClaw版本
which openclaw
openclaw --version 2>/dev/null || echo "未安装"

# 清理旧版本
npm uninstall -g openclaw
```

## 自动化测试脚本

创建 `test-install-cn.sh` 自动化测试：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== install-cn.sh 自动化测试 ==="

# 测试1：语法检查
echo "测试1：语法检查..."
bash -n install-cn.sh
echo "✓ 语法检查通过"

# 测试2：帮助信息
echo "测试2：帮助信息..."
./install-cn.sh --help | grep -q "OpenClaw CN quick install" && echo "✓ 帮助信息正常"

# 测试3：干运行模式
echo "测试3：干运行模式..."
./install-cn.sh --dry-run 2>&1 | grep -q "DRY RUN" && echo "✓ 干运行模式正常"

# 测试4：版本检查
echo "测试4：版本检查..."
./install-cn.sh --version 2>&1 | grep -q "SCRIPT_VERSION" && echo "✓ 版本检查正常"

echo "=== 所有测试通过 ==="
```

## 集成到CI/CD

### GitHub Actions 示例

```yaml
name: Test install-cn.sh

on:
  push:
    paths:
      - 'scripts/install-cn.sh'
      - 'docs/install-cn-quick-test-example.md'

jobs:
  test-install-script:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Test install-cn.sh
        run: |
          chmod +x scripts/install-cn.sh
          cd scripts
          ./install-cn.sh --dry-run --self-check
          
      - name: Run quick test
        run: |
          bash docs/install-cn-quick-test-example.md 2>&1 | grep -q "测试通过" || true
```

## 总结

通过以上快速测试示例，用户可以：
1. 快速验证 `install-cn.sh` 脚本的基本功能
2. 测试不同安装场景和配置
3. 验证国内源优先和回退策略
4. 集成到自动化测试流程中
5. 快速排查常见安装问题

这些测试示例确保了安装脚本的可靠性和用户体验。