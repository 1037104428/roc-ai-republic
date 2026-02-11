# OpenClaw CN 安装失败恢复指南

## 概述

`install-cn-fallback-recovery.sh` 是一个专门为 OpenClaw CN 安装脚本设计的故障恢复工具。当主安装脚本 `install-cn.sh` 失败时，本工具提供清理、诊断和重试功能，确保安装过程更加健壮。

## 功能特性

### 1. 清理功能 (`--cleanup`)
- 移除失败的全局 npm 包安装
- 清理 nvm 环境中的残留文件
- 删除错误的符号链接
- 备份并移除配置目录
- 为全新安装做好准备

### 2. 诊断功能 (`--diagnose`) - 默认
- 检查系统信息（操作系统、架构）
- 验证 Node.js 和 npm 环境
- 测试网络连通性（npmjs、npmmirror、GitHub、Gitee）
- 检查磁盘空间
- 验证当前 OpenClaw 安装状态

### 3. 重试功能 (`--retry`)
- **策略1**: 使用 npmmirror 国内镜像重试
- **策略2**: 使用 npmjs 官方源重试  
- **策略3**: 直接 npm install 重试
- 多层回退机制，提高成功率

## 使用场景

### 场景1: 安装过程中断后的恢复
```bash
# 诊断问题
bash install-cn-fallback-recovery.sh --diagnose

# 清理残留
bash install-cn-fallback-recovery.sh --cleanup

# 重新尝试安装
bash install-cn-fallback-recovery.sh --retry
```

### 场景2: 网络问题导致的安装失败
```bash
# 检查网络连通性
bash install-cn-fallback-recovery.sh --diagnose

# 如果发现网络问题，使用重试功能会自动尝试不同源
bash install-cn-fallback-recovery.sh --retry
```

### 场景3: 版本冲突或残留文件
```bash
# 彻底清理旧版本
bash install-cn-fallback-recovery.sh --cleanup

# 然后重新运行主安装脚本
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

## 集成到主安装脚本

### 自动故障恢复
可以在 CI/CD 管道中集成自动恢复：

```bash
#!/bin/bash
set -e

# 尝试主安装
if ! curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash; then
    echo "主安装失败，启动恢复流程..."
    
    # 下载恢复脚本
    curl -fsSL https://clawdrepublic.cn/install-cn-fallback-recovery.sh -o recovery.sh
    chmod +x recovery.sh
    
    # 执行恢复
    ./recovery.sh --cleanup
    ./recovery.sh --retry
    
    # 验证安装
    if command -v openclaw >/dev/null 2>&1; then
        echo "恢复成功！OpenClaw 版本: $(openclaw --version)"
    else
        echo "恢复失败，请手动检查"
        exit 1
    fi
fi
```

### 环境变量支持
```bash
# 跳过交互式提示
export SKIP_INTERACTIVE=1

# 指定日志文件
export RECOVERY_LOG=/tmp/openclaw-recovery.log

# 运行恢复
bash install-cn-fallback-recovery.sh --retry 2>&1 | tee "$RECOVERY_LOG"
```

## 故障排除

### 常见问题及解决方案

#### 问题1: "npm: command not found"
**解决方案**:
```bash
# 诊断会显示此问题
bash install-cn-fallback-recovery.sh --diagnose

# 需要先安装 Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts
```

#### 问题2: 网络超时
**解决方案**:
```bash
# 使用重试功能，会自动尝试不同源
bash install-cn-fallback-recovery.sh --retry
```

#### 问题3: 权限不足
**解决方案**:
```bash
# 使用 sudo 运行（谨慎使用）
sudo bash install-cn-fallback-recovery.sh --cleanup
# 或者安装到用户目录
export NPM_CONFIG_PREFIX=~/.npm-global
```

#### 问题4: 磁盘空间不足
**解决方案**:
```bash
# 诊断会显示磁盘使用情况
bash install-cn-fallback-recovery.sh --diagnose

# 清理磁盘空间后重试
bash install-cn-fallback-recovery.sh --cleanup
bash install-cn-fallback-recovery.sh --retry
```

## 验证安装

恢复完成后，验证安装：

```bash
# 检查命令是否可用
command -v openclaw

# 检查版本
openclaw --version

# 运行状态检查
openclaw status

# 测试基本功能
openclaw gateway status
```

## 最佳实践

1. **先诊断后操作**: 总是先运行 `--diagnose` 了解问题
2. **备份重要数据**: 清理前确保重要配置已备份
3. **分步执行**: 不要一次性执行所有操作，分步验证
4. **记录日志**: 重定向输出到日志文件便于排查
5. **测试恢复**: 在测试环境中验证恢复流程

## 相关资源

- [主安装脚本文档](install-cn-complete-verification-guide.md)
- [安装验证脚本](verify-install-cn-complete.sh)
- [项目仓库](https://github.com/1037104428/roc-ai-republic)
- [国内镜像](https://gitee.com/junkaiWang324/roc-ai-republic)

## 更新日志

- **2026-02-12**: 初始版本发布，提供基本清理、诊断和重试功能
- **脚本版本**: 2026.02.12.0429

## 技术支持

如有问题，请参考：
1. 查看诊断输出信息
2. 检查日志文件
3. 查阅相关文档
4. 在项目仓库提交 Issue
