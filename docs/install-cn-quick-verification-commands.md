# install-cn.sh 快速验证命令集

## 概述

本文档提供 `install-cn.sh` 安装脚本的快速验证命令集合，帮助用户在不同场景下快速验证安装是否成功、功能是否正常。

## 基础验证命令

### 1. 脚本语法检查
```bash
# 检查脚本语法
bash -n scripts/install-cn.sh

# 检查脚本中的潜在问题
shellcheck scripts/install-cn.sh
```

### 2. 干运行模式验证
```bash
# 基本干运行
bash scripts/install-cn.sh --dry-run

# 详细输出干运行
bash scripts/install-cn.sh --dry-run --verbose

# CI模式干运行
CI_MODE=1 bash scripts/install-cn.sh --dry-run --ci-mode
```

### 3. 帮助信息验证
```bash
# 检查帮助信息完整性
bash scripts/install-cn.sh --help | grep -q "Usage:" && echo "帮助信息完整"

# 检查版本信息
bash scripts/install-cn.sh --version
```

## 安装后验证命令

### 1. 基本功能验证
```bash
# 验证OpenClaw是否安装成功
openclaw --version

# 验证Gateway是否运行
openclaw gateway status

# 验证配置文件存在
ls -la ~/.openclaw/config.yaml
```

### 2. 网络连接验证
```bash
# 验证国内镜像源可达性
curl -fsS https://registry.npmmirror.com/openclaw

# 验证备用源可达性
curl -fsS https://registry.npmjs.org/openclaw

# 验证脚本更新源
curl -fsS https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | head -5
```

### 3. 安装完整性验证
```bash
# 检查安装目录
ls -la $(which openclaw)

# 检查npm包信息
npm list -g openclaw

# 检查依赖完整性
npm list -g --depth=0
```

## 场景化验证命令

### 场景1：新服务器首次安装验证
```bash
# 完整安装流程验证
export OPENCLAW_VERSION=latest
export NPM_REGISTRY=https://registry.npmmirror.com
export SKIP_INTERACTIVE=1
export INSTALL_LOG=/tmp/openclaw-install.log

# 执行安装
bash scripts/install-cn.sh

# 验证安装结果
if openclaw --version > /dev/null 2>&1; then
    echo "✅ OpenClaw安装成功"
    openclaw gateway status
else
    echo "❌ OpenClaw安装失败"
    tail -20 /tmp/openclaw-install.log
fi
```

### 场景2：CI/CD流水线验证
```bash
# CI环境验证脚本
#!/bin/bash
set -e

echo "开始OpenClaw安装验证..."

# 1. 干运行检查
echo "执行干运行检查..."
bash scripts/install-cn.sh --dry-run --ci-mode

# 2. 实际安装
echo "执行实际安装..."
export CI_MODE=1
export OPENCLAW_VERSION=latest
export NPM_REGISTRY=https://registry.npmmirror.com
export SKIP_INTERACTIVE=1
bash scripts/install-cn.sh

# 3. 功能验证
echo "验证安装结果..."
openclaw --version
openclaw gateway status

# 4. 健康检查
echo "执行健康检查..."
openclaw gateway health-check || true

echo "✅ CI/CD验证完成"
```

### 场景3：批量部署验证
```bash
# 批量部署验证脚本
#!/bin/bash

SERVERS=("server1" "server2" "server3")
INSTALL_LOG_DIR="/tmp/openclaw-install-logs"

mkdir -p "$INSTALL_LOG_DIR"

for server in "${SERVERS[@]}"; do
    echo "在 $server 上验证OpenClaw安装..."
    
    # 远程执行安装验证
    ssh "$server" "bash -s" << 'EOF'
        if command -v openclaw > /dev/null 2>&1; then
            echo "OpenClaw已安装: $(openclaw --version)"
            if systemctl is-active --quiet openclaw-gateway 2>/dev/null || pgrep -f "openclaw gateway" > /dev/null; then
                echo "Gateway服务运行正常"
            else
                echo "Gateway服务未运行"
            fi
        else
            echo "OpenClaw未安装"
        fi
EOF
    
    echo "---"
done
```

### 场景4：故障排查验证
```bash
# 故障排查命令集
#!/bin/bash

echo "=== OpenClaw故障排查 ==="

# 1. 检查系统环境
echo "1. 系统环境检查:"
node --version
npm --version
which node
which npm

# 2. 检查OpenClaw安装
echo "2. OpenClaw安装检查:"
command -v openclaw && openclaw --version || echo "openclaw命令未找到"
npm list -g openclaw 2>/dev/null || echo "OpenClaw未通过npm安装"

# 3. 检查服务状态
echo "3. 服务状态检查:"
pgrep -f "openclaw gateway" && echo "Gateway进程运行中" || echo "Gateway进程未运行"
ps aux | grep -i openclaw | grep -v grep

# 4. 检查网络连接
echo "4. 网络连接检查:"
curl -fsS https://registry.npmmirror.com/openclaw > /dev/null && echo "国内镜像源可达" || echo "国内镜像源不可达"
curl -fsS https://registry.npmjs.org/openclaw > /dev/null && echo "npmjs源可达" || echo "npmjs源不可达"

# 5. 检查配置文件
echo "5. 配置文件检查:"
ls -la ~/.openclaw/ 2>/dev/null || echo "~/.openclaw目录不存在"
[ -f ~/.openclaw/config.yaml ] && echo "配置文件存在" || echo "配置文件不存在"

echo "=== 故障排查完成 ==="
```

## 自动化验证脚本

### 1. 一键验证脚本
```bash
#!/bin/bash
# quick-verify-install.sh

set -e

echo "开始OpenClaw安装快速验证..."

# 检查脚本自身
echo "1. 检查安装脚本..."
bash -n scripts/install-cn.sh && echo "✅ 脚本语法正确" || echo "❌ 脚本语法错误"

# 干运行测试
echo "2. 执行干运行测试..."
bash scripts/install-cn.sh --dry-run --quiet > /dev/null 2>&1 && echo "✅ 干运行测试通过" || echo "❌ 干运行测试失败"

# 检查现有安装
echo "3. 检查现有安装..."
if command -v openclaw > /dev/null 2>&1; then
    echo "✅ OpenClaw已安装: $(openclaw --version)"
    
    # 检查Gateway
    if openclaw gateway status > /dev/null 2>&1; then
        echo "✅ Gateway服务正常"
    else
        echo "⚠️ Gateway服务异常"
    fi
else
    echo "ℹ️ OpenClaw未安装"
fi

echo "验证完成!"
```

### 2. CI集成验证脚本
```bash
#!/bin/bash
# ci-verify-install.sh

set -e

LOG_FILE="/tmp/openclaw-ci-verify-$(date +%Y%m%d_%H%M%S).log"

echo "CI验证开始..." | tee -a "$LOG_FILE"

# 环境变量检查
echo "检查环境变量..." | tee -a "$LOG_FILE"
[ -n "$CI_MODE" ] && echo "CI_MODE: $CI_MODE" || echo "CI_MODE未设置"
[ -n "$OPENCLAW_VERSION" ] && echo "OPENCLAW_VERSION: $OPENCLAW_VERSION" || echo "使用默认版本"

# 执行安装
echo "执行安装..." | tee -a "$LOG_FILE"
bash scripts/install-cn.sh --ci-mode --install-log="$LOG_FILE.install"

# 验证结果
echo "验证安装结果..." | tee -a "$LOG_FILE"
if openclaw --version > /dev/null 2>&1; then
    VERSION=$(openclaw --version)
    echo "✅ 安装成功: $VERSION" | tee -a "$LOG_FILE"
    exit 0
else
    echo "❌ 安装失败" | tee -a "$LOG_FILE"
    tail -20 "$LOG_FILE.install" | tee -a "$LOG_FILE"
    exit 1
fi
```

## 验证结果解读

### 成功标志
1. `openclaw --version` 返回版本号
2. `openclaw gateway status` 显示服务状态
3. 安装日志无ERROR级别错误
4. 网络测试全部通过

### 常见问题及解决方案

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 脚本语法错误 | Bash版本不兼容 | 使用 `bash -n` 检查，确保使用Bash 4.0+ |
| 网络连接失败 | 防火墙/代理限制 | 检查网络设置，使用 `--network-test` 诊断 |
| 安装权限不足 | 非root用户安装全局包 | 使用 `sudo` 或配置npm全局安装目录权限 |
| 版本冲突 | 已安装旧版本 | 先卸载旧版本：`npm uninstall -g openclaw` |
| 依赖缺失 | 系统缺少必要依赖 | 安装Node.js 16+和npm 8+ |

## 最佳实践

1. **安装前验证**：始终先执行 `--dry-run` 检查
2. **记录日志**：使用 `--install-log` 参数保存安装日志
3. **版本固定**：生产环境指定具体版本：`OPENCLAW_VERSION=0.3.12`
4. **网络备用**：配置多个镜像源，确保安装可靠性
5. **定期验证**：建立定期验证机制，确保服务持续可用

## 相关文档

- [install-cn.sh 脚本](../scripts/install-cn.sh) - 主安装脚本
- [install-cn-strategy.md](install-cn-strategy.md) - 安装策略文档
- [install-cn-comprehensive-guide.md](install-cn-comprehensive-guide.md) - 完整安装指南
- [VERIFY_INSTALL_COMPATIBILITY.md](VERIFY_INSTALL_COMPATIBILITY.md) - 兼容性验证指南

---

**最后更新**: 2026-02-11  
**版本**: 1.0  
**维护者**: 阿爪