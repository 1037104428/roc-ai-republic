# install-cn.sh 快速测试示例

本文档提供 `install-cn.sh` 安装脚本的快速测试示例，展示不同使用场景下的命令和预期输出。

## 1. 基本测试场景

### 1.1 查看帮助信息
```bash
# 查看完整帮助
./scripts/install-cn.sh --help

# 查看简短帮助
./scripts/install-cn.sh -h
```

**预期输出：**
```
中华AI共和国 / OpenClaw 小白中文包安装脚本

用法: ./scripts/install-cn.sh [选项]

选项:
  --version <version>    指定安装版本 (默认: latest)
  --dry-run             只显示安装步骤，不实际执行
  --force-cn            强制使用国内镜像源
  --network-test        测试网络连通性
  --help, -h            显示此帮助信息
  --verbose, -v         显示详细输出
```

### 1.2 干运行测试（推荐）
```bash
# 测试最新版本安装
./scripts/install-cn.sh --dry-run --version latest

# 测试特定版本安装
./scripts/install-cn.sh --dry-run --version 0.3.12

# 测试强制国内源
./scripts/install-cn.sh --dry-run --force-cn
```

**预期输出：**
```
[DRY RUN] 将执行以下操作：
1. 检测系统环境...
2. 检查网络连通性...
3. 下载 OpenClaw 版本 0.3.12...
4. 安装到 /usr/local/bin...
5. 验证安装...
6. 显示完成信息...
```

## 2. 网络测试场景

### 2.1 网络连通性测试
```bash
# 测试所有网络源
./scripts/install-cn.sh --dry-run --network-test

# 仅测试国内源
./scripts/install-cn.sh --dry-run --force-cn --network-test
```

**预期输出：**
```
网络连通性测试结果：
✓ GitHub: 可达 (延迟: 120ms)
✓ Gitee: 可达 (延迟: 45ms)
✓ npm 官方源: 可达 (延迟: 180ms)
✓ 淘宝 npm 源: 可达 (延迟: 50ms)
推荐使用源: Gitee + 淘宝 npm 源
```

### 2.2 离线环境测试
```bash
# 模拟离线环境
export OFFLINE_MODE=1
./scripts/install-cn.sh --dry-run
```

**预期输出：**
```
⚠️ 检测到离线模式
将使用本地缓存（如果可用）
或显示离线安装指南
```

## 3. 实际安装场景

### 3.1 标准安装（最新版）
```bash
# 实际安装最新版本
sudo ./scripts/install-cn.sh --version latest
```

### 3.2 国内环境安装
```bash
# 强制使用国内源安装
sudo ./scripts/install-cn.sh --force-cn
```

### 3.3 指定版本安装
```bash
# 安装特定版本
sudo ./scripts/install-cn.sh --version 0.3.10
```

## 4. 验证安装结果

### 4.1 验证安装
```bash
# 验证 OpenClaw 安装
openclaw --version

# 验证 CLI 功能
openclaw help

# 验证网关状态
openclaw gateway status
```

**预期输出：**
```
OpenClaw v0.3.12
Node.js v22.22.0
Platform: linux/x64
```

### 4.2 快速健康检查
```bash
# 使用验证脚本
./scripts/quick-verify-install-cn.sh

# 或使用完整验证
./scripts/verify-install-cn.sh
```

## 5. 故障排除示例

### 5.1 权限问题
```bash
# 错误：权限不足
./scripts/install-cn.sh
# 输出：需要 sudo 权限

# 解决方案
sudo ./scripts/install-cn.sh --dry-run
```

### 5.2 网络问题
```bash
# 错误：网络超时
./scripts/install-cn.sh --dry-run
# 输出：网络连接失败

# 解决方案
./scripts/install-cn.sh --dry-run --force-cn
```

### 5.3 版本不兼容
```bash
# 错误：版本不支持
./scripts/install-cn.sh --dry-run --version 0.1.0
# 输出：版本 0.1.0 不再支持

# 解决方案
./scripts/install-cn.sh --dry-run --version latest
```

## 6. CI/CD 集成示例

### 6.1 GitHub Actions 测试
```yaml
name: Test install-cn.sh
on: [push, pull_request]
jobs:
  test-install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test dry-run
        run: ./scripts/install-cn.sh --dry-run
      - name: Test network
        run: ./scripts/install-cn.sh --dry-run --network-test
```

### 6.2 本地开发测试
```bash
#!/bin/bash
# test-install-local.sh
set -e

echo "=== 开始测试 install-cn.sh ==="

# 测试1: 语法检查
echo "1. 语法检查..."
bash -n scripts/install-cn.sh

# 测试2: 干运行
echo "2. 干运行测试..."
./scripts/install-cn.sh --dry-run

# 测试3: 网络测试
echo "3. 网络测试..."
./scripts/install-cn.sh --dry-run --network-test

echo "=== 所有测试通过 ==="
```

## 7. 快速参考卡片

### 一键测试命令
```bash
# 完整测试套件
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run --network-test
```

### 常用组合
```bash
# 开发测试
./scripts/install-cn.sh --dry-run --verbose

# 生产预览
./scripts/install-cn.sh --dry-run --force-cn

# 问题诊断
./scripts/install-cn.sh --dry-run --network-test --verbose
```

## 总结

这些示例覆盖了 `install-cn.sh` 的主要使用场景，从简单的语法检查到完整的安装验证。建议在部署前至少执行一次干运行测试，确保脚本在目标环境中正常工作。

对于生产环境，推荐使用 `--force-cn` 选项确保在国内网络环境下的稳定性。