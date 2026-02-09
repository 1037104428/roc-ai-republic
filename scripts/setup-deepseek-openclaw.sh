#!/bin/bash
# OpenClaw 小白中文包 - DeepSeek 一键配置脚本
# 目标：让用户复制粘贴一条命令就能配置好 DeepSeek 作为 OpenClaw 默认模型

set -e

echo "=== OpenClaw 小白中文包 - DeepSeek 一键配置 ==="
echo ""

# 检查 OpenClaw 是否已安装
if ! command -v openclaw &> /dev/null; then
    echo "❌ OpenClaw 未安装。请先运行："
    echo "   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
    exit 1
fi

echo "✅ OpenClaw 已安装：$(openclaw --version 2>/dev/null || echo '版本未知')"
echo ""

# 检查配置文件目录
OPENCLAW_DIR="$HOME/.openclaw"
CONFIG_FILE="$OPENCLAW_DIR/openclaw.json"
ENV_FILE="$OPENCLAW_DIR/.env"

mkdir -p "$OPENCLAW_DIR"

# 询问 DeepSeek API Key
echo "🔑 请输入你的 DeepSeek API Key（输入后按回车）："
read -r DEEPSEEK_KEY

if [ -z "$DEEPSEEK_KEY" ]; then
    echo "⚠️  未输入 API Key，跳过环境变量设置"
    echo "   你可以在配置完成后手动设置："
    echo "   echo 'DEEPSEEK_API_KEY=你的Key' >> ~/.openclaw/.env"
else
    # 写入 .env 文件
    echo "DEEPSEEK_API_KEY=$DEEPSEEK_KEY" >> "$ENV_FILE"
    echo "✅ DeepSeek API Key 已保存到 $ENV_FILE"
    
    # 在当前会话中设置环境变量
    export DEEPSEEK_API_KEY="$DEEPSEEK_KEY"
fi

echo ""

# 创建或更新配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "📄 创建新的 OpenClaw 配置文件..."
    cat > "$CONFIG_FILE" << 'EOF'
{
  agents: {
    defaults: {
      // 设为默认模型
      model: { primary: "deepseek/deepseek-chat" },

      // 可选：给模型一个人类友好的别名
      models: {
        "deepseek/deepseek-chat": { alias: "DeepSeek Chat" },
        "deepseek/deepseek-reasoner": { alias: "DeepSeek Reasoner" },
      },
    },
  },

  models: {
    mode: "merge",
    providers: {
      deepseek: {
        // DeepSeek 的 OpenAI-compatible base URL
        baseUrl: "https://api.deepseek.com/v1",
        apiKey: "${DEEPSEEK_API_KEY}",
        api: "openai-completions",
        models: [
          { id: "deepseek-chat", name: "DeepSeek Chat" },
          { id: "deepseek-reasoner", name: "DeepSeek Reasoner" },
        ],
      },
    },
  },
}
EOF
    echo "✅ 配置文件已创建：$CONFIG_FILE"
else
    echo "📄 检测到现有配置文件：$CONFIG_FILE"
    echo "⚠️  请手动添加 DeepSeek 配置（参考下面的配置片段）"
    echo ""
    echo "配置片段："
    cat << 'EOF'
{
  agents: {
    defaults: {
      model: { primary: "deepseek/deepseek-chat" },
      models: {
        "deepseek/deepseek-chat": { alias: "DeepSeek Chat" },
        "deepseek/deepseek-reasoner": { alias: "DeepSeek Reasoner" },
      },
    },
  },

  models: {
    mode: "merge",
    providers: {
      deepseek: {
        baseUrl: "https://api.deepseek.com/v1",
        apiKey: "${DEEPSEEK_API_KEY}",
        api: "openai-completions",
        models: [
          { id: "deepseek-chat", name: "DeepSeek Chat" },
          { id: "deepseek-reasoner", name: "DeepSeek Reasoner" },
        ],
      },
    },
  },
}
EOF
    echo ""
    echo "💡 提示：你可以运行以下命令查看当前配置："
    echo "   openclaw config.get"
fi

echo ""
echo "=== 验证步骤 ==="
echo ""

# 检查 Gateway 状态
echo "1. 检查 OpenClaw Gateway 状态："
if openclaw gateway status &> /dev/null; then
    echo "   ✅ Gateway 正在运行"
else
    echo "   ⚠️  Gateway 未运行，正在启动..."
    if openclaw gateway start &> /dev/null; then
        echo "   ✅ Gateway 已启动"
    else
        echo "   ❌ Gateway 启动失败，请手动运行：openclaw gateway start"
    fi
fi

echo ""
echo "2. 检查模型配置："
echo "   运行以下命令查看模型状态："
echo "   openclaw models status"
echo ""
echo "3. 测试聊天（可选）："
echo "   运行以下命令开始聊天："
echo "   openclaw chat"
echo ""
echo "=== 配置完成 ==="
echo ""
echo "📝 重要提示："
echo "   - 如果遇到问题，请访问论坛获取帮助："
echo "     https://clawdrepublic.cn/forum/"
echo "   - 需要试用 Key？请访问："
echo "     https://clawdrepublic.cn/quota-proxy.html"
echo ""
echo "🎉 现在你可以使用 DeepSeek 作为 OpenClaw 的默认模型了！"