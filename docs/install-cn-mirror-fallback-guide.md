# install-cn.sh 国内镜像源回退策略指南

## 概述

`install-cn.sh` 安装脚本实现了智能的国内镜像源回退策略，确保在国内网络环境下能够可靠地完成 OpenClaw 的安装。本文档详细说明脚本的镜像源选择机制、回退逻辑和故障排除方法。

## 镜像源优先级策略

脚本按照以下优先级顺序尝试不同的镜像源：

### 1. 国内镜像源（优先）
- **清华大学 TUNA 镜像源** (`https://mirrors.tuna.tsinghua.edu.cn/npm`)
- **淘宝 NPM 镜像源** (`https://registry.npmmirror.com`)
- **华为云镜像源** (`https://mirrors.huaweicloud.com/repository/npm`)

### 2. 官方源（回退）
- **NPM 官方源** (`https://registry.npmjs.org`)

### 3. 备用源（最终回退）
- **Cloudflare 镜像源** (`https://registry.npmmirror.com` 备用)

## 回退机制

### 自动检测与切换
1. **连接测试**：脚本首先测试国内镜像源的连接速度
2. **超时控制**：每个源设置 10 秒超时限制
3. **失败回退**：当前源失败后自动切换到下一个优先级源
4. **最终回退**：所有国内源失败后回退到官方源

### 回退流程
```
清华大学镜像源 → 测试连接（10秒超时）
    ↓ 失败
淘宝镜像源 → 测试连接（10秒超时）
    ↓ 失败
华为云镜像源 → 测试连接（10秒超时）
    ↓ 失败
NPM官方源 → 测试连接（15秒超时）
    ↓ 失败
Cloudflare备用源 → 最终尝试
```

## 配置参数

### 环境变量覆盖
用户可以通过环境变量强制指定镜像源：

```bash
# 强制使用特定镜像源
export NPM_REGISTRY="https://mirrors.tuna.tsinghua.edu.cn/npm"
./scripts/install-cn.sh

# 或使用自定义镜像源
export NPM_REGISTRY="https://your-custom-mirror.com"
./scripts/install-cn.sh
```

### 命令行参数
```bash
# 显示当前使用的镜像源
./scripts/install-cn.sh --show-registry

# 详细模式显示镜像源选择过程
./scripts/install-cn.sh --verbose
```

## 故障排除

### 常见问题

#### 1. 所有镜像源都连接失败
**症状**：安装过程卡在 "Testing mirror sources..." 或超时

**解决方案**：
```bash
# 1. 检查网络连接
ping mirrors.tuna.tsinghua.edu.cn

# 2. 手动指定可用的镜像源
export NPM_REGISTRY="https://registry.npmmirror.com"
./scripts/install-cn.sh

# 3. 使用代理（如有）
export HTTP_PROXY="http://your-proxy:port"
export HTTPS_PROXY="http://your-proxy:port"
./scripts/install-cn.sh
```

#### 2. 镜像源速度慢
**症状**：下载过程缓慢，经常超时

**解决方案**：
```bash
# 1. 增加超时时间
export NPM_TIMEOUT=30000  # 30秒超时
./scripts/install-cn.sh

# 2. 使用本地缓存（如有）
# 脚本会自动使用 npm 缓存，无需额外配置
```

#### 3. 特定包下载失败
**症状**：某个特定包下载失败，但其他包正常

**解决方案**：
```bash
# 1. 清理 npm 缓存后重试
npm cache clean --force
./scripts/install-cn.sh

# 2. 跳过失败包（临时方案）
# 编辑 install-cn.sh，注释掉失败的行
```

### 诊断命令

```bash
# 测试各个镜像源的连接速度
curl -I --connect-timeout 10 https://mirrors.tuna.tsinghua.edu.cn/npm
curl -I --connect-timeout 10 https://registry.npmmirror.com
curl -I --connect-timeout 10 https://registry.npmjs.org

# 查看当前 npm 配置
npm config get registry
npm config list

# 测试 npm 包下载
npm view openclaw --registry=https://mirrors.tuna.tsinghua.edu.cn/npm
```

## 性能优化建议

### 1. 使用本地镜像（企业环境）
对于企业或团队环境，建议搭建本地 npm 镜像：

```bash
# 使用 verdaccio 搭建本地镜像
npm install -g verdaccio
verdaccio &

# 配置脚本使用本地镜像
export NPM_REGISTRY="http://localhost:4873"
./scripts/install-cn.sh
```

### 2. 预下载依赖包
对于批量部署场景，可以预下载依赖包：

```bash
# 创建依赖包缓存目录
mkdir -p ~/.npm-cache

# 预下载 OpenClaw 及其依赖
npm cache add openclaw --cache ~/.npm-cache

# 安装时使用缓存
npm install openclaw --cache ~/.npm-cache --prefer-offline
```

### 3. 使用离线安装包
对于完全离线的环境：

```bash
# 1. 在有网络的环境中打包
npm pack openclaw
tar -czf openclaw-deps.tar.gz node_modules/

# 2. 传输到离线环境
scp openclaw-*.tgz openclaw-deps.tar.gz user@offline-machine:~

# 3. 离线安装
tar -xzf openclaw-deps.tar.gz
npm install openclaw-*.tgz
```

## 监控与日志

### 启用详细日志
```bash
# 保存安装日志到文件
./scripts/install-cn.sh --verbose 2>&1 | tee install.log

# 查看镜像源选择日志
grep -i "mirror\|registry\|source" install.log

# 查看下载时间统计
grep -i "download\|time\|speed" install.log
```

### 性能统计
脚本会自动记录：
- 每个镜像源的连接时间
- 包下载速度
- 总体安装时间
- 失败重试次数

## 最佳实践

### 1. 生产环境部署
```bash
# 使用固定镜像源避免波动
export NPM_REGISTRY="https://mirrors.tuna.tsinghua.edu.cn/npm"
export NPM_TIMEOUT=30000

# 启用详细日志便于排查
./scripts/install-cn.sh --verbose > /var/log/openclaw-install.log 2>&1

# 验证安装结果
./scripts/quick-verify-openclaw.sh
```

### 2. 自动化脚本集成
```bash
#!/bin/bash
# 自动化部署脚本示例

set -e  # 遇到错误立即退出

# 配置镜像源
export NPM_REGISTRY="https://mirrors.tuna.tsinghua.edu.cn/npm"
export NPM_TIMEOUT=30000

# 执行安装
echo "Starting OpenClaw installation..."
if ./scripts/install-cn.sh --quiet; then
    echo "✅ Installation completed successfully"
    
    # 验证安装
    if ./scripts/quick-verify-openclaw.sh --quiet; then
        echo "✅ OpenClaw verification passed"
        exit 0
    else
        echo "❌ OpenClaw verification failed"
        exit 1
    fi
else
    echo "❌ Installation failed"
    exit 1
fi
```

### 3. CI/CD 流水线配置
```yaml
# GitHub Actions 示例
jobs:
  install-openclaw:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install OpenClaw
        env:
          NPM_REGISTRY: "https://mirrors.tuna.tsinghua.edu.cn/npm"
        run: |
          chmod +x ./scripts/install-cn.sh
          ./scripts/install-cn.sh --quiet
          
      - name: Verify Installation
        run: |
          ./scripts/quick-verify-openclaw.sh --quiet
```

## 更新与维护

### 镜像源列表更新
镜像源列表定期更新，最新列表请查看：
- `scripts/install-cn.sh` 中的 `MIRROR_SOURCES` 数组
- 项目文档中的更新说明

### 反馈与贡献
如果您发现新的可用镜像源或遇到问题：
1. 在 GitHub Issues 中报告
2. 提交 Pull Request 更新镜像源列表
3. 联系维护团队获取支持

## 相关资源

- [清华大学 TUNA 镜像源帮助](https://mirrors.tuna.tsinghua.edu.cn/help/npm/)
- [淘宝 NPM 镜像源](https://npmmirror.com)
- [NPM 官方文档](https://docs.npmjs.com/)
- [OpenClaw 安装文档](../README.md#安装)

---

**最后更新**：2026-02-10  
**版本**：1.0.0  
**维护者**：中华AI共和国项目组