# install-cn.sh 快速参考指南

**创建时间**: 2026-02-12 05:18 CST  
**最后更新**: 2026-02-12 05:18 CST  
**版本**: v2026.02.12.01

## 概述

`install-cn.sh` 是专为国内环境优化的 OpenClaw 安装脚本，提供国内可达源优先策略、智能回退机制和完整的安装验证功能。

## 快速开始

### 基本安装
```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh -o install-cn.sh
chmod +x install-cn.sh

# 运行安装
./install-cn.sh
```

### 一键安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash
```

## 主要功能选项

### 安装模式
| 选项 | 描述 | 示例 |
|------|------|------|
| `--step-by-step` | 分步安装模式 | `./install-cn.sh --step-by-step` |
| `--steps <steps>` | 指定安装步骤 | `./install-cn.sh --steps=1,3,5` |
| `--ci-mode` | CI/CD 集成模式 | `./install-cn.sh --ci-mode` |
| `--batch-deploy` | 批量部署模式 | `./install-cn.sh --batch-deploy` |

### 网络优化
| 选项 | 描述 | 示例 |
|------|------|------|
| `--offline-mode` | 离线安装模式 | `./install-cn.sh --offline-mode` |
| `--cache-dir <dir>` | 指定缓存目录 | `./install-cn.sh --cache-dir=/tmp/openclaw-cache` |
| `--proxy <url>` | 指定代理服务器 | `./install-cn.sh --proxy=http://proxy.example.com:8080` |

### 验证和调试
| 选项 | 描述 | 示例 |
|------|------|------|
| `--verify-only` | 仅验证不安装 | `./install-cn.sh --verify-only` |
| `--dry-run` | 模拟运行 | `./install-cn.sh --dry-run` |
| `--verbose` | 详细输出 | `./install-cn.sh --verbose` |
| `--debug` | 调试模式 | `./install-cn.sh --debug` |

### 维护功能
| 选项 | 描述 | 示例 |
|------|------|------|
| `--uninstall` | 卸载 OpenClaw | `./install-cn.sh --uninstall` |
| `--check-updates` | 检查更新 | `./install-cn.sh --check-updates` |
| `--generate-config` | 生成配置模板 | `./install-cn.sh --generate-config` |

## 环境变量

### 网络配置
```bash
# 代理设置
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"

# 安装统计（可选）
export ENABLE_INSTALL_STATS="true"
export INSTALL_STATS_URL="https://your-stats-endpoint.com"

# 故障自愈
export ENABLE_FAULT_RECOVERY="true"

# 健康检查
export ENABLE_ENHANCED_HEALTH_CHECK="true"
```

### CI/CD 集成
```bash
# 非交互模式
export CI_MODE="true"

# 跳过交互
export SKIP_INTERACTIVE="true"

# 安装日志
export INSTALL_LOG="/var/log/openclaw-install.log"
```

## 安装步骤详解

### 步骤 1: 系统检查
- 检查操作系统和架构
- 验证 root/非 root 权限
- 检查磁盘空间和内存
- 验证网络连接

### 步骤 2: 依赖安装
- 安装 Node.js (如果未安装)
- 安装 npm 和必要工具
- 配置 npm 镜像源（国内优化）

### 步骤 3: OpenClaw 安装
- 选择最佳下载源（国内 CDN 优先）
- 下载 OpenClaw 包
- 执行 npm 安装
- 配置环境变量

### 步骤 4: 验证安装
- 验证 OpenClaw 命令可用性
- 测试基本功能
- 生成安装报告

## 常见问题

### 网络连接问题
```bash
# 诊断网络
./install-cn.sh --diagnose-network

# 测试 CDN 源
./scripts/test-cdn-sources.sh

# 评估连接质量
./scripts/evaluate-cdn-quality.sh
```

### 权限问题
```bash
# 自动修复权限
./install-cn.sh --auto-fix-permissions

# 手动修复 npm 权限
sudo chown -R $(whoami) ~/.npm
```

### 安装失败恢复
```bash
# 启用故障自愈
export ENABLE_FAULT_RECOVERY="true"
./install-cn.sh

# 查看安装日志
tail -f /var/log/openclaw-install.log
```

## 验证脚本

安装完成后，使用以下脚本验证安装：

```bash
# 基本验证
./scripts/verify-openclaw-install.sh

# 完整验证
./scripts/verify-install-cn.sh

# 快速验证
./scripts/verify-install-cn-quick.sh
```

## 批量部署

### 配置文件示例
创建 `batch-deploy-config.json`:
```json
{
  "servers": [
    {
      "host": "server1.example.com",
      "user": "admin",
      "port": 22
    },
    {
      "host": "server2.example.com",
      "user": "root",
      "port": 2222
    }
  ],
  "options": ["--ci-mode", "--skip-interactive"],
  "parallel": 3
}
```

### 执行批量部署
```bash
./install-cn.sh --batch-deploy --batch-config=batch-deploy-config.json
```

## 配置模板

### 生成配置模板
```bash
# 生成开发环境配置
./install-cn.sh --generate-config=development

# 生成生产环境配置
./install-cn.sh --generate-config=production

# 生成测试环境配置
./install-cn.sh --generate-config=testing
```

## 性能优化

### 缓存优化
```bash
# 使用本地缓存
./install-cn.sh --cache-dir=/opt/openclaw-cache

# 预下载依赖
./install-cn.sh --pre-download
```

### 并行安装
```bash
# 启用并行下载
export PARALLEL_DOWNLOADS="4"
./install-cn.sh
```

## 监控和维护

### 安装统计
```bash
# 启用匿名统计
export ENABLE_INSTALL_STATS="true"
./install-cn.sh

# 查看统计结果
cat ~/.openclaw/install-stats.json
```

### 健康检查
```bash
# 安装后健康检查
./scripts/enhanced-health-check.sh

# 监控 OpenClaw 状态
./scripts/health-monitor-quota-proxy.sh
```

## 更新和升级

### 检查更新
```bash
./install-cn.sh --check-updates
```

### 升级 OpenClaw
```bash
# 重新运行安装脚本
./install-cn.sh --upgrade

# 或使用 npm
npm update -g openclaw
```

## 故障排除

### 查看帮助
```bash
./install-cn.sh --help
```

### 查看版本信息
```bash
./install-cn.sh --version
```

### 查看详细日志
```bash
# 启用调试模式
./install-cn.sh --debug

# 查看安装日志
tail -f /tmp/openclaw-install-debug.log
```

## 相关文档

- [完整安装指南](install-cn-complete-verification-guide.md)
- [功能验证文档](install-cn-feature-verification.md)
- [网络诊断指南](../scripts/README-verification-scripts.md)
- [批量部署指南](../scripts/verify-batch-deploy.sh)

## 支持

如有问题，请参考：
1. 查看详细日志：`tail -f /var/log/openclaw-install.log`
2. 运行诊断：`./install-cn.sh --diagnose`
3. 提交 Issue: [GitHub Issues](https://github.com/1037104428/roc-ai-republic/issues)

---

**注意**: 本脚本持续优化中，最新版本请查看 GitHub 仓库。