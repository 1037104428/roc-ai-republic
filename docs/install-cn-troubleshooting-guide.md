# install-cn.sh 故障排除指南

**创建时间**: 2026-02-11 13:25 CST  
**最后更新**: 2026-02-11 13:25 CST  
**适用版本**: install-cn.sh v2026.02.11.12+

## 概述

本指南提供 `install-cn.sh` 安装脚本的详细故障排除步骤，涵盖网络问题、权限问题、环境配置和脚本功能使用。

## 快速诊断

### 1. 运行诊断模式

```bash
# 运行完整诊断（不安装）
./scripts/install-cn.sh --dry-run --verbose

# 仅检查网络连通性
./scripts/install-cn.sh --network-test

# 检查系统依赖
./scripts/install-cn.sh --steps dependency-check --dry-run
```

### 2. 查看脚本帮助

```bash
# 查看所有可用选项
./scripts/install-cn.sh --help

# 查看版本信息
./scripts/install-cn.sh --version-check

# 查看更新日志
./scripts/install-cn.sh --changelog
```

## 常见问题分类

### 网络连接问题

#### 症状
- 安装超时
- 网络连接失败错误
- 镜像源不可达

#### 解决方案

**1. 使用代理检测功能**
```bash
# 自动检测代理设置
./scripts/install-cn.sh --proxy-mode auto --dry-run

# 手动指定代理
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
./scripts/install-cn.sh --proxy-mode manual --dry-run
```

**2. 测试CDN源连接质量**
```bash
# 运行CDN源测试脚本
./scripts/test-cdn-sources.sh --timeout 3 --retries 1

# 评估CDN连接质量
./scripts/evaluate-cdn-quality.sh --format json
```

**3. 使用离线模式**
```bash
# 从本地缓存安装
./scripts/install-cn.sh --offline-mode --cache-dir ~/.openclaw-cache

# 下载缓存文件
./scripts/install-cn.sh --cache-dir ~/.openclaw-cache --dry-run
```

**4. 强制使用特定源**
```bash
# 强制使用国内源
./scripts/install-cn.sh --force-cn

# 强制使用国际源
./scripts/install-cn.sh --force-international
```

### 权限问题

#### 症状
- npm权限错误
- 文件写入权限不足
- 全局安装失败

#### 解决方案

**1. 启用权限自动修复**
```bash
# 脚本会自动检测并修复权限问题
./scripts/install-cn.sh --step-by-step --dry-run

# 或仅运行权限检查步骤
./scripts/install-cn.sh --steps dependency-check --dry-run
```

**2. 手动修复npm权限**
```bash
# 检查npm配置
npm config get prefix

# 修复npm全局安装权限
sudo chown -R $(whoami) $(npm config get prefix)/{lib/node_modules,bin,share}

# 或配置npm使用用户目录
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**3. 使用故障自愈功能**
```bash
# 启用故障自愈
export ENABLE_FAULT_RECOVERY=true
./scripts/install-cn.sh --dry-run
```

### 环境配置问题

#### 症状
- Node.js版本不兼容
- 磁盘空间不足
- 内存不足
- 系统依赖缺失

#### 解决方案

**1. 运行增强依赖检查**
```bash
# 运行完整的系统依赖检查
./scripts/install-cn.sh --steps dependency-check --dry-run

# 或使用验证脚本
./scripts/verify-dependency-check.sh --all
```

**2. 检查Node.js版本**
```bash
# 检查当前Node.js版本
node --version

# 脚本要求Node.js ≥ 20
# 如需升级，建议使用nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 22
nvm use 22
```

**3. 检查系统资源**
```bash
# 检查磁盘空间
df -h /tmp
df -h ~

# 检查内存
free -h

# 检查系统依赖
command -v curl
command -v wget
command -v git
```

### 脚本功能问题

#### 症状
- 特定选项不工作
- 功能异常
- 脚本错误

#### 解决方案

**1. 验证脚本语法**
```bash
# 检查脚本语法
bash -n ./scripts/install-cn.sh

# 查看脚本版本
grep "SCRIPT_VERSION=" ./scripts/install-cn.sh

# 查看功能状态
./scripts/install-cn.sh --version-check
```

**2. 使用分步安装模式**
```bash
# 分步安装，便于定位问题
./scripts/install-cn.sh --step-by-step --dry-run

# 指定特定步骤
./scripts/install-cn.sh --steps "network-check,proxy-check,dependency-check" --dry-run
```

**3. 查看安装日志**
```bash
# 保存安装日志
./scripts/install-cn.sh --install-log /tmp/openclaw-install.log

# 查看日志文件
tail -f /tmp/openclaw-install.log
```

### 安装后问题

#### 症状
- openclaw命令找不到
- 版本验证失败
- 配置问题

#### 解决方案

**1. 运行安装后验证**
```bash
# 运行健康检查
export ENABLE_ENHANCED_HEALTH_CHECK=true
./scripts/install-cn.sh --dry-run

# 或直接运行健康检查脚本
./scripts/enhanced-health-check.sh --all
```

**2. 检查PATH配置**
```bash
# 检查openclaw是否在PATH中
which openclaw

# 检查npm全局路径
npm config get prefix

# 手动添加PATH
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 对于zsh用户
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**3. 查看安装摘要报告**
```bash
# 安装完成后会生成摘要报告
# 报告位置：/tmp/openclaw-install-summary-*.txt

# 查看最近的摘要报告
ls -la /tmp/openclaw-install-summary-*.txt | tail -1
cat $(ls -t /tmp/openclaw-install-summary-*.txt | head -1)
```

## 高级故障排除

### 使用CI/CD模式

```bash
# 在CI/CD环境中使用
export CI=true
./scripts/install-cn.sh --ci-mode --skip-interactive

# 或使用验证脚本
./scripts/test-ci-integration.sh
```

### 批量部署问题

```bash
# 测试批量部署配置
./scripts/install-cn.sh --batch-dry-run --batch-deploy config-templates/batch-deploy-config.example.txt

# 验证批量部署脚本
./scripts/verify-batch-deploy.sh --all
```

### 配置模板问题

```bash
# 生成配置模板
./scripts/install-cn.sh --generate-config dev --dry-run

# 查看配置模板指南
cat docs/config-templates-guide.md
```

## 错误代码参考

| 错误代码 | 含义 | 详细说明 |
|----------|------|----------|
| 1 | 脚本参数错误 | 检查参数格式，使用 `--help` 查看帮助 |
| 2 | 网络连接失败 | 使用 `--network-test` 或 `--proxy-mode` 诊断 |
| 3 | npm安装失败 | 检查npm权限，使用 `--steps dependency-check` |
| 4 | 版本验证失败 | 检查Node.js版本，需要 ≥ 20 |
| 5 | 环境配置问题 | 按照提示配置PATH环境变量 |
| 6 | 权限问题 | 使用权限自动修复或手动修复npm权限 |
| 7 | 磁盘空间不足 | 清理磁盘空间，至少需要500MB可用 |
| 8 | 内存不足 | 关闭其他应用，释放内存 |
| 9 | 系统依赖缺失 | 安装缺失的系统工具（curl/wget/git） |
| 10 | 代理配置错误 | 检查代理设置，使用 `--proxy-mode` 测试 |

## 诊断工具

### 1. 代理检测脚本
```bash
./scripts/detect-proxy.sh detect
./scripts/detect-proxy.sh test
./scripts/detect-proxy.sh report
```

### 2. 网络测试脚本
```bash
./scripts/test-network-connectivity.sh --all
./scripts/test-cdn-sources.sh --verbose
```

### 3. 系统检查脚本
```bash
./scripts/check-system-requirements.sh
./scripts/verify-dependency-check.sh --all
```

### 4. 安装验证脚本
```bash
./scripts/verify-install-cn.sh --all
./scripts/enhanced-health-check.sh --all
```

## 获取帮助

### 1. 查看文档
```bash
# 查看综合指南
cat docs/install-cn-comprehensive-guide.md

# 查看功能验证文档
cat docs/install-cn-feature-verification.md

# 查看快速验证备忘单
cat docs/install-cn-verification-cheat-sheet.md
```

### 2. 生成验证命令
```bash
# 生成验证命令
./scripts/generate-install-cn-verification-commands.sh --batch "quick,basic,full" --format markdown

# 生成自定义验证命令
./scripts/generate-install-cn-verification-commands.sh --template custom --dry-run
```

### 3. 提交问题
- GitHub Issues: https://github.com/1037104428/roc-ai-republic/issues
- Gitee Issues: https://gitee.com/junkaiWang324/roc-ai-republic/issues
- 项目论坛: https://clawdrepublic.cn/forum/

## 预防措施

### 1. 定期更新脚本
```bash
# 检查脚本更新
./scripts/install-cn.sh --check-update

# 查看更新日志
./scripts/install-cn.sh --changelog
```

### 2. 启用安装统计（可选）
```bash
# 启用匿名安装统计
export ENABLE_INSTALL_STATS=true
export INSTALL_STATS_URL=https://clawdrepublic.cn/api/install-stats
./scripts/install-cn.sh --dry-run
```

### 3. 使用安装回滚
```bash
# 安装脚本内置回滚机制
# 如果安装失败，会自动回滚到之前状态

# 查看回滚目录
ls -la /tmp/openclaw-rollback-*
```

## 最佳实践

1. **始终先运行dry-run模式**
   ```bash
   ./scripts/install-cn.sh --dry-run --verbose
   ```

2. **使用分步安装定位问题**
   ```bash
   ./scripts/install-cn.sh --step-by-step --dry-run
   ```

3. **保存安装日志便于调试**
   ```bash
   ./scripts/install-cn.sh --install-log /tmp/install.log
   ```

4. **安装后运行健康检查**
   ```bash
   export ENABLE_ENHANCED_HEALTH_CHECK=true
   ./scripts/install-cn.sh --dry-run
   ```

5. **定期检查脚本更新**
   ```bash
   ./scripts/install-cn.sh --version-check
   ./scripts/install-cn.sh --check-update
   ```

---

**提示**: 如果以上步骤无法解决问题，请收集以下信息并提交问题报告：
1. 操作系统版本：`uname -a`
2. Node.js版本：`node --version`
3. npm版本：`npm --version`
4. 安装日志：`cat /tmp/openclaw-install-summary-*.txt`
5. 错误信息：完整的错误输出