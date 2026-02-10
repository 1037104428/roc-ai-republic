# OpenClaw安装验证命令参考

本文档提供OpenClaw安装验证的完整命令参考，包括各种验证场景和故障排除命令。

## 快速验证命令

### 1. 基本安装验证
```bash
# 检查OpenClaw命令是否可用
openclaw --version

# 检查网关状态
openclaw gateway status

# 检查配置文件
openclaw config.get
```

### 2. 使用验证脚本
```bash
# 使用内置验证脚本（推荐）
cd /path/to/roc-ai-republic
./scripts/verify-openclaw-install.sh

# 详细模式
./scripts/verify-openclaw-install.sh --verbose

# 干运行模式（只检查不执行）
./scripts/verify-openclaw-install.sh --dry-run

# 安静模式（仅输出错误）
./scripts/verify-openclaw-install.sh --quiet
```

### 3. 安装脚本验证
```bash
# 安装脚本的验证功能
./scripts/install-cn.sh --verify

# 带网络优化的验证
./scripts/install-cn.sh --verify --network-optimize

# 使用自定义验证脚本
export OPENCLAW_VERIFY_SCRIPT=/path/to/custom-verify.sh
./scripts/install-cn.sh --verify
```

## 分步验证命令

### 步骤1: 环境检查
```bash
# 检查Node.js版本
node --version

# 检查npm版本
npm --version

# 检查系统架构
uname -m

# 检查可用内存
free -h

# 检查磁盘空间
df -h /home
```

### 步骤2: 依赖检查
```bash
# 检查Docker（如果使用容器）
docker --version
docker compose version

# 检查Git
git --version

# 检查curl/wget
curl --version
wget --version
```

### 步骤3: OpenClaw核心检查
```bash
# 检查OpenClaw安装位置
which openclaw

# 检查全局安装
npm list -g openclaw

# 检查工作空间
ls -la ~/.openclaw/workspace/

# 检查配置文件
cat ~/.openclaw/config.json | jq .
```

### 步骤4: 网关服务检查
```bash
# 检查网关进程
ps aux | grep openclaw-gateway

# 检查网关日志
tail -f ~/.openclaw/logs/gateway.log

# 检查网关端口
netstat -tlnp | grep 3000
```

### 步骤5: 功能测试
```bash
# 测试基本命令
openclaw status
openclaw help

# 测试技能加载
openclaw skills list

# 测试工具可用性
openclaw tools list
```

## 故障排除命令

### 1. 安装失败排查
```bash
# 查看安装日志
tail -f /tmp/openclaw-install.log

# 检查网络连接
./scripts/diagnose-network.sh

# 检查镜像源
./scripts/optimize-network-sources.sh --test-only

# 清理缓存重新安装
npm cache clean --force
rm -rf ~/.openclaw
```

### 2. 服务启动失败排查
```bash
# 检查错误日志
journalctl -u openclaw-gateway -n 50

# 手动启动网关调试
openclaw gateway start --verbose

# 检查端口冲突
lsof -i :3000

# 检查权限问题
ls -la ~/.openclaw/
```

### 3. 配置问题排查
```bash
# 验证配置文件语法
openclaw config.validate

# 重置为默认配置
openclaw config.reset

# 导出当前配置
openclaw config.get > config-backup.json

# 比较配置差异
diff config-backup.json ~/.openclaw/config.json
```

## 自动化验证脚本

### 1. 一键验证脚本
```bash
#!/bin/bash
# 一键验证OpenClaw安装
set -e

echo "=== OpenClaw安装验证开始 ==="
echo "时间: $(date)"

# 检查基本命令
echo "1. 检查基本命令..."
openclaw --version || { echo "❌ OpenClaw命令不可用"; exit 1; }

# 检查网关状态
echo "2. 检查网关状态..."
openclaw gateway status || { echo "⚠️ 网关可能未运行"; }

# 检查工作空间
echo "3. 检查工作空间..."
if [ -d ~/.openclaw/workspace ]; then
    echo "✅ 工作空间存在"
    ls -la ~/.openclaw/workspace/ | head -10
else
    echo "❌ 工作空间不存在"
fi

# 检查配置文件
echo "4. 检查配置文件..."
if [ -f ~/.openclaw/config.json ]; then
    echo "✅ 配置文件存在"
    jq '.version' ~/.openclaw/config.json
else
    echo "❌ 配置文件不存在"
fi

echo "=== 验证完成 ==="
echo "状态: ✅ 安装验证通过"
```

### 2. CI/CD集成示例
```yaml
# GitHub Actions示例
name: Verify OpenClaw Installation

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install OpenClaw
        run: |
          curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/install-cn.sh | bash
          
      - name: Run verification
        run: |
          ./scripts/verify-openclaw-install.sh --verbose
          
      - name: Check gateway status
        run: |
          openclaw gateway status
```

## 验证退出码说明

验证脚本使用标准化退出码：

| 退出码 | 含义 | 说明 |
|--------|------|------|
| 0 | 成功 | 所有检查通过 |
| 1 | 警告 | 部分非关键检查失败 |
| 2 | 严重 | 关键功能检查失败 |
| 3 | 错误 | 验证脚本自身错误 |
| 4 | 配置错误 | 环境配置问题 |
| 5 | 依赖错误 | 系统依赖缺失 |

## 最佳实践

### 1. 生产环境验证
```bash
# 生产环境完整验证
./scripts/verify-openclaw-install.sh --verbose 2>&1 | tee verification.log

# 检查验证结果
if [ $? -eq 0 ]; then
    echo "✅ 生产环境验证通过"
else
    echo "❌ 生产环境验证失败，查看日志: verification.log"
    exit 1
fi
```

### 2. 定期监控
```bash
# 添加到cron定期检查
0 */6 * * * /path/to/roc-ai-republic/scripts/verify-openclaw-install.sh --quiet
```

### 3. 告警配置
```bash
# 验证失败时发送告警
./scripts/verify-openclaw-install.sh --quiet
if [ $? -gt 1 ]; then
    # 发送邮件或通知
    echo "OpenClaw验证失败" | mail -s "OpenClaw告警" admin@example.com
fi
```

## 常见问题验证命令

### Q1: OpenClaw命令找不到
```bash
# 检查PATH
echo $PATH
which openclaw

# 重新链接
npm link openclaw

# 检查全局安装
npm list -g openclaw
```

### Q2: 网关无法启动
```bash
# 检查端口占用
lsof -i :3000

# 检查日志
tail -f ~/.openclaw/logs/gateway.log

# 使用调试模式
openclaw gateway start --debug
```

### Q3: 配置文件错误
```bash
# 验证配置语法
openclaw config.validate

# 备份并重置
cp ~/.openclaw/config.json ~/.openclaw/config.json.backup
openclaw config.reset

# 逐步恢复配置
openclaw config.patch '{"agent": {"model": "deepseek/deepseek-chat"}}'
```

## 总结

使用这些验证命令可以确保OpenClaw安装的完整性和可用性。建议在以下场景运行验证：

1. **安装后**：立即验证安装是否成功
2. **升级后**：验证新版本功能正常
3. **定期检查**：确保服务持续可用
4. **故障恢复后**：确认恢复成功

通过自动化验证，可以大大减少人工排查时间，提高系统可靠性。