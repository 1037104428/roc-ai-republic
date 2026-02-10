# OpenClaw 安装验证指南

本文档介绍如何验证 OpenClaw 安装是否成功，以及如何诊断常见问题。

## 验证脚本

我们提供了一个完整的安装验证脚本，可以检查 OpenClaw 的各个组件：

### 基本验证
```bash
# 运行验证脚本
./scripts/verify-openclaw-install.sh

# 详细输出
./scripts/verify-openclaw-install.sh --verbose

# 完整检查（包括API连通性）
./scripts/verify-openclaw-install.sh --full
```

### 验证脚本检查的项目

1. **openclaw 命令** - 检查命令是否在 PATH 中
2. **配置文件** - 检查 `~/.openclaw/openclaw.json` 是否存在且有效
3. **Gateway 状态** - 检查 gateway 是否运行
4. **Workspace 目录** - 检查 workspace 目录是否存在
5. **Models 状态** - 检查 models 是否可用
6. **API 连通性** - 检查相关 API 是否可达（可选）
7. **功能测试** - 测试基本命令功能

## 手动验证步骤

如果验证脚本无法运行，可以手动执行以下检查：

### 1. 检查 openclaw 命令
```bash
# 检查命令是否存在
which openclaw

# 检查版本
openclaw --version

# 检查帮助
openclaw help
```

### 2. 检查配置文件
```bash
# 检查配置文件是否存在
ls -la ~/.openclaw/openclaw.json

# 查看配置文件内容（如果有 jq）
jq . ~/.openclaw/openclaw.json

# 检查是否有 providers 配置
grep -A5 -B5 "providers" ~/.openclaw/openclaw.json
```

### 3. 检查 gateway 状态
```bash
# 检查 gateway 状态
openclaw gateway status

# 启动 gateway（如果未运行）
openclaw gateway start

# 重启 gateway
openclaw gateway restart
```

### 4. 检查 workspace
```bash
# 检查 workspace 目录
ls -la ~/.openclaw/workspace/

# 检查重要文件
ls -la ~/.openclaw/workspace/*.md
```

### 5. 检查 models 状态
```bash
# 检查 models 状态
openclaw models status

# 列出可用 models
openclaw models list
```

## 常见问题诊断

### 问题1: openclaw 命令未找到
**症状**: `bash: openclaw: command not found`

**解决方案**:
```bash
# 检查 npm 全局安装路径
npm bin -g

# 将 npm 全局 bin 路径添加到 PATH
export PATH="$PATH:$(npm bin -g)"

# 永久添加到 shell 配置（如 ~/.bashrc 或 ~/.zshrc）
echo 'export PATH="$PATH:$(npm bin -g)"' >> ~/.bashrc
source ~/.bashrc
```

### 问题2: 配置文件不存在
**症状**: 验证脚本提示配置文件不存在

**解决方案**:
```bash
# 初始化配置
openclaw config init

# 或者手动创建配置文件
mkdir -p ~/.openclaw
cat > ~/.openclaw/openclaw.json << 'EOF'
{
  "providers": {
    "deepseek": {
      "apiKey": "your-deepseek-api-key-here",
      "baseUrl": "https://api.deepseek.com"
    }
  }
}
EOF
```

### 问题3: Gateway 无法启动
**症状**: `openclaw gateway start` 失败

**解决方案**:
```bash
# 检查端口占用
sudo lsof -i :3000  # 默认端口

# 查看 gateway 日志
openclaw gateway logs

# 尝试使用不同端口
openclaw gateway start --port 3001
```

### 问题4: Models 不可用
**症状**: `openclaw models status` 显示不可用

**解决方案**:
```bash
# 检查 provider 配置
cat ~/.openclaw/openclaw.json

# 测试 API key 有效性
curl -X POST https://api.deepseek.com/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Hello"}]}'

# 检查网络连接
curl -fsS https://api.deepseek.com
```

## 安装后测试

安装完成后，建议运行以下测试确保一切正常：

### 测试1: 基本功能测试
```bash
# 运行完整验证
./scripts/verify-openclaw-install.sh --full

# 测试 status 命令
openclaw status

# 测试 models 命令
openclaw models status
```

### 测试2: 简单对话测试
```bash
# 通过支持的渠道发送测试消息
# 例如，如果配置了 WhatsApp，发送消息到绑定的号码
```

### 测试3: 健康检查
```bash
# 检查 gateway 健康状态
curl http://localhost:3000/health  # 默认端口

# 检查 quota-proxy API
curl https://api.clawdrepublic.cn/healthz
```

## 自动化验证

### 定时验证脚本
可以设置定时任务定期验证 OpenClaw 状态：

```bash
# 创建定时验证脚本
cat > ~/check-openclaw.sh << 'EOF'
#!/bin/bash
LOG_FILE="$HOME/openclaw-health-check.log"
echo "=== OpenClaw Health Check $(date) ===" >> "$LOG_FILE"
./scripts/verify-openclaw-install.sh --skip-api >> "$LOG_FILE" 2>&1
echo "" >> "$LOG_FILE"
EOF

chmod +x ~/check-openclaw.sh

# 添加到 crontab（每小时检查一次）
(crontab -l 2>/dev/null; echo "0 * * * * cd /path/to/roc-ai-republic && ~/check-openclaw.sh") | crontab -
```

### 监控告警
如果验证失败，可以发送告警：

```bash
# 在验证脚本中添加告警逻辑
if ! ./scripts/verify-openclaw-install.sh --skip-api > /dev/null 2>&1; then
  echo "OpenClaw 验证失败！" | mail -s "OpenClaw Alert" admin@example.com
  # 或者发送到 Slack/Telegram 等
fi
```

## 故障排除流程

1. **运行验证脚本** - 获取详细的错误信息
2. **检查日志** - 查看 gateway 和安装日志
3. **验证网络** - 确保 API 端点可达
4. **检查配置** - 验证配置文件格式和内容
5. **重启服务** - 尝试重启 gateway
6. **重新安装** - 如果问题持续，考虑重新安装

## 支持与反馈

如果遇到无法解决的问题：

1. 查看项目文档: `docs/` 目录
2. 检查 GitHub Issues: https://github.com/openclaw/openclaw/issues
3. 访问论坛: https://clawdrepublic.cn/forum/
4. 通过验证脚本生成诊断报告

**诊断报告生成**:
```bash
# 生成详细的诊断报告
./scripts/verify-openclaw-install.sh --verbose --full > openclaw-diagnostic-report.txt 2>&1
```

将诊断报告附在问题报告中，有助于快速定位问题。