#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 快速配置向导
# 帮助用户快速设置 API 网关和试用密钥

CONFIG_FILE="${HOME}/.openclaw/config.json"
WORKSPACE_DIR="${HOME}/.openclaw/workspace"

echo "🎯 OpenClaw 快速配置向导"
echo "=========================="
echo ""

# 检查 OpenClaw 是否安装
if ! command -v openclaw >/dev/null 2>&1; then
  echo "❌ OpenClaw 未安装或不在 PATH 中"
  echo "请先运行: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
  exit 1
fi

echo "✅ OpenClaw 已安装: $(openclaw --version 2>/dev/null || echo 'unknown version')"
echo ""

# 显示当前配置状态
if [[ -f "$CONFIG_FILE" ]]; then
  echo "📁 当前配置文件: $CONFIG_FILE"
  echo "配置摘要:"
  if grep -q "gateway" "$CONFIG_FILE"; then
    echo "  ✅ API 网关已配置"
  else
    echo "  ⚠️  API 网关未配置"
  fi
  
  if grep -q "quotaProxy" "$CONFIG_FILE"; then
    echo "  ✅ 配额代理已配置"
  else
    echo "  ⚠️  配额代理未配置"
  fi
else
  echo "📁 配置文件不存在: $CONFIG_FILE"
  echo "将创建新配置"
fi

echo ""
echo "请选择配置选项:"
echo "1) 配置 API 网关 (quota-proxy)"
echo "2) 获取试用密钥 (TRIAL_KEY)"
echo "3) 测试当前配置"
echo "4) 显示帮助信息"
echo "5) 退出"
echo ""

read -p "请输入选项 [1-5]: " choice

case "$choice" in
  1)
    echo ""
    echo "🔧 配置 API 网关"
    echo "----------------"
    echo "默认网关地址: https://clawdrepublic.cn/api"
    echo "如需自定义，请输入完整 URL (例如: http://localhost:8787)"
    echo ""
    
    read -p "请输入 API 网关地址 [默认: https://clawdrepublic.cn/api]: " gateway_url
    gateway_url="${gateway_url:-https://clawdrepublic.cn/api}"
    
    echo ""
    echo "正在创建/更新配置文件..."
    
    # 创建配置目录
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 创建或更新配置文件
    if [[ ! -f "$CONFIG_FILE" ]]; then
      cat > "$CONFIG_FILE" << EOF
{
  "gateway": {
    "baseUrl": "$gateway_url",
    "timeout": 30000
  },
  "quotaProxy": {
    "enabled": true,
    "baseUrl": "$gateway_url"
  }
}
EOF
    else
      # 使用 jq 更新现有配置
      if command -v jq >/dev/null 2>&1; then
        jq --arg url "$gateway_url" '
          .gateway.baseUrl = $url |
          .quotaProxy.baseUrl = $url |
          .quotaProxy.enabled = true
        ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
      else
        echo "⚠️  jq 未安装，无法更新现有配置文件"
        echo "请手动编辑 $CONFIG_FILE 并添加:"
        echo '  "gateway": { "baseUrl": "'"$gateway_url"'" },'
        echo '  "quotaProxy": { "enabled": true, "baseUrl": "'"$gateway_url"'" }'
      fi
    fi
    
    echo "✅ API 网关配置完成: $gateway_url"
    echo "配置文件: $CONFIG_FILE"
    ;;
    
  2)
    echo ""
    echo "🔑 获取试用密钥"
    echo "--------------"
    echo "试用密钥获取方式:"
    echo "1) 访问: https://clawdrepublic.cn/trial-key-guide.html"
    echo "2) 或运行: curl -fsS https://clawdrepublic.cn/api/admin/keys/trial"
    echo ""
    
    read -p "是否现在获取试用密钥? [y/N]: " get_key
    if [[ "$get_key" =~ ^[Yy]$ ]]; then
      echo ""
      echo "正在获取试用密钥..."
      
      if command -v curl >/dev/null 2>&1; then
        trial_key=$(curl -fsS -X POST "https://clawdrepublic.cn/api/admin/keys/trial" \
          -H "Content-Type: application/json" \
          -d '{"name":"trial-user","expiresIn":"7d"}' 2>/dev/null | \
          grep -o '"key":"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [[ -n "$trial_key" ]]; then
          echo "✅ 试用密钥获取成功!"
          echo "密钥: $trial_key"
          echo ""
          echo "使用方法:"
          echo "1. 在 OpenClaw 配置中添加:"
          echo '   "quotaProxy": { "apiKey": "'"$trial_key"'" }'
          echo "2. 或设置环境变量:"
          echo "   export OPENCLAW_QUOTA_PROXY_API_KEY='$trial_key'"
        else
          echo "❌ 获取试用密钥失败"
          echo "请手动访问: https://clawdrepublic.cn/trial-key-guide.html"
        fi
      else
        echo "❌ curl 未安装，无法自动获取"
        echo "请手动访问: https://clawdrepublic.cn/trial-key-guide.html"
      fi
    fi
    ;;
    
  3)
    echo ""
    echo "🧪 测试当前配置"
    echo "--------------"
    
    # 测试 OpenClaw 基本功能
    echo "1. 测试 OpenClaw 版本:"
    openclaw --version 2>&1 || echo "❌ 无法获取版本"
    
    echo ""
    echo "2. 测试配置文件:"
    if [[ -f "$CONFIG_FILE" ]]; then
      echo "✅ 配置文件存在: $CONFIG_FILE"
      echo "   文件大小: $(wc -l < "$CONFIG_FILE") 行"
    else
      echo "⚠️  配置文件不存在"
    fi
    
    echo ""
    echo "3. 测试 API 网关连接:"
    if grep -q "baseUrl" "$CONFIG_FILE" 2>/dev/null; then
      gateway_url=$(grep -o '"baseUrl":"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4)
      echo "   网关地址: $gateway_url"
      
      if command -v curl >/dev/null 2>&1; then
        if curl -fsS -m 5 "$gateway_url/healthz" >/dev/null 2>&1; then
          echo "   ✅ 网关健康检查通过"
        else
          echo "   ⚠️  网关连接失败"
        fi
      else
        echo "   ℹ️  curl 未安装，跳过连接测试"
      fi
    else
      echo "   ⚠️  未配置网关地址"
    fi
    
    echo ""
    echo "4. 测试工作空间:"
    if [[ -d "$WORKSPACE_DIR" ]]; then
      echo "   ✅ 工作空间存在: $WORKSPACE_DIR"
      echo "   包含文件: $(find "$WORKSPACE_DIR" -type f | wc -l) 个"
    else
      echo "   ℹ️  工作空间不存在，将在首次运行时创建"
    fi
    ;;
    
  4)
    echo ""
    echo "📖 帮助信息"
    echo "----------"
    echo "OpenClaw 中华AI共和国 / 小白中文包"
    echo ""
    echo "主要功能:"
    echo "• API 网关配置 - 连接到配额代理服务"
    echo "• 试用密钥获取 - 获取7天免费试用密钥"
    echo "• 配置测试 - 验证当前设置"
    echo ""
    echo "相关链接:"
    echo "• 官网: https://clawdrepublic.cn"
    echo "• 文档: https://clawdrepublic.cn/docs"
    echo "• 论坛: https://clawdrepublic.cn/forum"
    echo "• GitHub: https://github.com/1037104428/roc-ai-republic"
    echo "• Gitee: https://gitee.com/junkaiWang324/roc-ai-republic"
    echo ""
    echo "安装命令:"
    echo "  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
    ;;
    
  5)
    echo "退出配置向导"
    exit 0
    ;;
    
  *)
    echo "无效选项"
    exit 1
    ;;
esac

echo ""
echo "🎉 配置完成!"
echo "下一步建议:"
echo "1. 运行 'openclaw status' 检查状态"
echo "2. 运行 'openclaw gateway start' 启动本地网关"
echo "3. 访问 https://clawdrepublic.cn 获取更多资源"
echo ""