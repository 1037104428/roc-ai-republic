# 小白完全指南：从零开始使用 Clawd 国度

欢迎！如果你是第一次接触 AI 开发或 Clawd 国度，这份指南将带你从零开始，5分钟内完成第一次 AI 调用。

## 🎯 目标用户
- 完全不懂编程的小白
- 想体验 AI 能力的普通用户
- 开发者想快速了解项目

## 📋 准备工作
你只需要：
1. 一台能上网的电脑（Windows/Mac/Linux 都可以）
2. 一个能接收短信的手机（用于验证）
3. 10分钟空闲时间

## 🚀 5分钟快速开始

### 第1步：获取试用密钥（2分钟）
访问我们的论坛申请试用密钥：https://clawdrepublic.cn/forum/

**申请要点**：
1. 注册论坛账号
2. 在「TRIAL_KEY申请」板块发帖
3. 说明你的使用场景和需求
4. **不要**在公开帖子中粘贴你的密钥

### 第2步：安装必要工具（1分钟）
打开终端（Windows 用户打开 PowerShell 或 CMD），运行：

```bash
# 检查是否已安装 curl（大多数系统都有）
curl --version

# 如果没有，根据系统安装：
# Windows: 下载 curl.exe 或使用 PowerShell 的 Invoke-WebRequest
# Mac: brew install curl
# Linux: sudo apt install curl
```

### 第3步：设置环境变量（1分钟）
将你的试用密钥设置为环境变量，方便后续使用：

```bash
# Linux/Mac
export CLAWD_TRIAL_KEY="你的试用密钥"

# Windows PowerShell
$env:CLAWD_TRIAL_KEY="你的试用密钥"

# Windows CMD
set CLAWD_TRIAL_KEY=你的试用密钥
```

### 第4步：第一次调用（1分钟）
复制以下命令：

```bash
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "你好！请用一句话介绍你自己"}
    ]
  }'
```

### 第5步：查看结果
如果一切正常，你会看到类似这样的响应：
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "gpt-3.5-turbo",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "你好！我是 OpenAI 的 GPT-3.5 Turbo 模型，很高兴为你服务！"
    },
    "finish_reason": "stop"
  }],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 15,
    "total_tokens": 25
  }
}
```

🎉 **恭喜！你已成功完成第一次 AI 调用！**

## 🔍 一键验证脚本
在开始前，你可以运行这个一键验证脚本，检查所有服务是否正常：

```bash
# 下载并运行验证脚本
curl -fsSL https://clawdrepublic.cn/probe-roc-all.sh | bash
```

或者只检查关键服务：
```bash
# 检查官网是否可访问
curl -fsS https://clawdrepublic.cn/ >/dev/null && echo "✅ 官网正常"

# 检查API是否健康
curl -fsS https://api.clawdrepublic.cn/healthz && echo "✅ API健康"

# 检查论坛是否可访问
curl -fsS https://clawdrepublic.cn/forum/ | grep -q "Clawd 国度论坛" && echo "✅ 论坛正常"
```

## 📚 深入学习

### 基础概念
- **API 密钥**：就像门禁卡，有了它才能使用服务
- **额度**：每次调用都会消耗额度，试用密钥有免费额度
- **模型**：不同的 AI 大脑，能力不同

### 常用命令示例

#### 1. 问天气
```bash
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "今天上海天气怎么样？"}
    ]
  }'
```

#### 2. 写诗
```bash
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "写一首关于春天的五言绝句"}
    ]
  }'
```

#### 3. 翻译
```bash
curl -X POST https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "Translate 'Hello, world!' to Chinese"}
    ]
  }'
```

#### 4. 检查密钥是否有效
```bash
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY"
```

## 🔧 遇到问题？

### 常见错误及解决

#### 错误1：`{"error":"Invalid API key"}`
- **原因**：API 密钥错误或已过期
- **解决**：检查密钥是否正确，或申请新的试用密钥

#### 错误2：`{"error":"Insufficient quota"}`
- **原因**：试用额度已用完
- **解决**：等待下个月重置，或升级到付费账户

#### 错误3：`curl: command not found`
- **原因**：系统没有安装 curl
- **解决**：按照上面的安装步骤安装 curl

#### 错误4：网络连接失败
- **原因**：网络问题或服务暂时不可用
- **解决**：检查网络连接，稍后再试

#### 错误5：`{"error":"model not found"}`
- **原因**：请求的模型名称错误
- **解决**：使用正确的模型名称，如 `gpt-3.5-turbo`

## 📞 获取帮助

1. **加入社区**：访问我们的论坛 https://clawdrepublic.cn/forum/
2. **查看文档**：[完整文档](https://clawdrepublic.cn/)
3. **快速开始**：[快速开始指南](https://clawdrepublic.cn/quickstart.html)
4. **API文档**：[quota-proxy 使用说明](https://clawdrepublic.cn/quota-proxy.html)

## 🎁 下一步做什么？

### 小白路线
1. 尝试不同的提问方式
2. 学习如何组合多个问题
3. 探索其他 AI 模型

### 开发者路线
1. 学习使用 Python/JavaScript 调用 API
2. 了解额度管理和监控
3. 参与开源项目贡献

### 安装 OpenClaw（高级）
如果你想在本地运行 AI 助手，可以安装 OpenClaw：

```bash
# 一键安装脚本（国内优化）
curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
```

安装后运行：
```bash
openclaw --help
```

---

**记住**：AI 是工具，你是主人。多尝试，多提问，享受探索的乐趣！

> 最后更新：2026-02-09  
> 文档版本：v1.1  
> 如有问题，欢迎在论坛提出或直接联系管理员。