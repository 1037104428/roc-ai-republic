#!/bin/bash
# 小白一条龙教程的快速验证脚本
# 用法：./scripts/verify-quickstart.sh [--key TRIAL_KEY]

set -e

echo "=== OpenClaw 小白一条龙验证脚本 ==="
echo "包含：官网、API、论坛、安装脚本、TRIAL_KEY（可选）"
echo ""

# 检查参数
KEY=""
if [[ "$1" == "--key" && -n "$2" ]]; then
    KEY="$2"
    echo "使用提供的 TRIAL_KEY 进行验证"
elif [[ -n "$CLAWD_TRIAL_KEY" ]]; then
    KEY="$CLAWD_TRIAL_KEY"
    echo "使用环境变量 CLAWD_TRIAL_KEY 进行验证"
elif [[ -n "$OPENAI_API_KEY" ]]; then
    KEY="$OPENAI_API_KEY"
    echo "使用环境变量 OPENAI_API_KEY 进行验证"
else
    echo "警告：未找到 TRIAL_KEY，只能进行基础健康检查"
fi

echo ""

# 1. 检查官网可达性
echo "1. 检查官网可达性..."
if curl -fsS -m 10 https://clawdrepublic.cn/ > /dev/null 2>&1; then
    echo "   ✅ 官网可访问"
else
    echo "   ❌ 官网不可访问"
    exit 1
fi

# 2. 检查 API 健康状态
echo "2. 检查 API 健康状态..."
API_HEALTH=$(curl -fsS -m 10 https://api.clawdrepublic.cn/healthz 2>/dev/null || echo "{}")
if echo "$API_HEALTH" | grep -q '"ok":true'; then
    echo "   ✅ API 健康检查通过"
else
    echo "   ❌ API 健康检查失败"
    echo "   响应: $API_HEALTH"
    exit 1
fi

# 3. 检查论坛可达性（新增）
echo "3. 检查论坛可达性..."
FORUM_CHECK=$(curl -fsS -m 10 https://clawdrepublic.cn/forum/ 2>/dev/null || echo "")
if echo "$FORUM_CHECK" | grep -q "Clawd 国度论坛"; then
    echo "   ✅ 论坛可访问，标题正确"
    
    # 检查论坛是否返回502错误（历史问题修复验证）
    if echo "$FORUM_CHECK" | head -1 | grep -q "<!doctype html>"; then
        echo "   ✅ 论坛无502错误（历史问题已修复）"
    else
        echo "   ⚠️  论坛返回非标准响应，但标题正确"
    fi
else
    echo "   ❌ 论坛不可访问或标题不正确"
    echo "   提示：论坛曾出现502错误，现已修复。如仍失败请检查网络。"
    exit 1
fi

# 4. 如果有 key，检查模型列表
if [[ -n "$KEY" ]]; then
    echo "4. 检查 TRIAL_KEY 有效性..."
    MODELS_RESPONSE=$(curl -fsS -m 10 https://api.clawdrepublic.cn/v1/models \
        -H "Authorization: Bearer $KEY" 2>/dev/null || echo "{}")
    
    if echo "$MODELS_RESPONSE" | grep -q '"object":"list"'; then
        echo "   ✅ TRIAL_KEY 有效，可获取模型列表"
        
        # 提取模型数量
        MODEL_COUNT=$(echo "$MODELS_RESPONSE" | grep -o '"id"' | wc -l)
        echo "   发现 $MODEL_COUNT 个可用模型"
    else
        echo "   ❌ TRIAL_KEY 无效或权限不足"
        echo "   响应: $MODELS_RESPONSE"
        exit 1
    fi
else
    echo "4. 跳过 TRIAL_KEY 验证（未提供 key）"
fi

# 5. 检查安装脚本可达性
echo "5. 检查安装脚本可达性..."
if curl -fsS -m 10 https://clawdrepublic.cn/install-cn.sh > /dev/null 2>&1; then
    echo "   ✅ 安装脚本可下载"
else
    echo "   ❌ 安装脚本不可下载"
    exit 1
fi

echo ""
echo "=== 验证完成 ==="
echo "✅ 所有检查通过"
echo ""
echo "总结："
echo "- 官网: ✅ 可访问"
echo "- API网关: ✅ 健康"
echo "- 论坛: ✅ 可访问（502错误已修复）"
echo "- 安装脚本: ✅ 可下载"
if [[ -n "$KEY" ]]; then
    echo "- TRIAL_KEY: ✅ 有效"
fi
echo ""
echo "下一步："
echo "1. 运行安装脚本: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
echo "2. 配置环境变量: export CLAWD_TRIAL_KEY=\"你的key\""
echo "3. 启动OpenClaw: openclaw gateway start"
echo "4. 遇到问题？去论坛提问: https://clawdrepublic.cn/forum/"