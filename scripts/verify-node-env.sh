#!/bin/bash
# 验证Node.js环境（OpenClaw小白一条龙前置检查）
# 用法：./scripts/verify-node-env.sh [--verbose]

set -e

VERBOSE=false
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

echo "=== Node.js环境验证（OpenClaw安装前置检查）==="
echo "检查项目：Node.js版本、npm、npx、OpenClaw CLI、网络代理（可选）"
echo ""

# 检查Node.js是否安装
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo "✅ Node.js 已安装: $NODE_VERSION"
    
    # 检查Node.js版本
    NODE_MAJOR=$(node --version | cut -d'.' -f1 | tr -d 'v')
    if [ "$NODE_MAJOR" -ge 16 ]; then
        echo "✅ Node.js 版本符合要求 (>=16，推荐v18+)"
        
        # 详细版本检查
        if [ "$NODE_MAJOR" -ge 18 ]; then
            echo "   👍 版本优秀（v18+，支持ES2022+特性）"
        elif [ "$NODE_MAJOR" -eq 16 ]; then
            echo "   ⚠ 版本较低（v16，建议升级到v18+以获得更好性能）"
        fi
    else
        echo "❌ Node.js 版本过低: $NODE_VERSION (需要>=16)"
        echo "   请从 https://nodejs.org/ 下载最新LTS版本"
        exit 1
    fi
    
    # 检查npm
    if command -v npm >/dev/null 2>&1; then
        NPM_VERSION=$(npm --version)
        echo "✅ npm 已安装: $NPM_VERSION"
        
        # 检查npm配置（国内用户友好）
        if $VERBOSE; then
            echo "   npm配置检查："
            npm config get registry 2>/dev/null | head -1 | while read REG; do
                if [[ "$REG" == *"taobao"* ]] || [[ "$REG" == *"npmmirror"* ]]; then
                    echo "   👍 npm registry已配置为国内镜像: $REG"
                elif [[ "$REG" == *"registry.npmjs.org"* ]]; then
                    echo "   ℹ️  npm registry为官方源，国内用户可能较慢"
                    echo "   建议设置国内镜像：npm config set registry https://registry.npmmirror.com"
                else
                    echo "   ℹ️  npm registry: $REG"
                fi
            done
        fi
    else
        echo "❌ npm 未安装"
        echo "   通常Node.js安装包会包含npm，请检查安装是否完整"
        exit 1
    fi
    
    # 检查npx
    if command -v npx >/dev/null 2>&1; then
        echo "✅ npx 可用"
    else
        echo "⚠ npx 不可用（某些旧版本Node.js可能不包含npx）"
        echo "   可通过 npm install -g npx 安装"
    fi
    
    # 检查OpenClaw CLI是否已安装
    echo ""
    echo "=== OpenClaw CLI检查 ==="
    if command -v openclaw >/dev/null 2>&1; then
        OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
        echo "✅ OpenClaw CLI 已安装: $OPENCLAW_VERSION"
        
        # 检查配置文件目录
        if [ -d "$HOME/.openclaw" ]; then
            echo "   👍 OpenClaw配置目录存在: ~/.openclaw/"
            
            # 检查配置文件
            if [ -f "$HOME/.openclaw/config.yaml" ]; then
                echo "   👍 OpenClaw配置文件存在"
                if $VERBOSE; then
                    echo "   配置文件路径: $HOME/.openclaw/config.yaml"
                fi
            else
                echo "   ℹ️  OpenClaw配置文件不存在（首次运行时会创建）"
            fi
        else
            echo "   ℹ️  OpenClaw配置目录不存在（首次安装后运行 openclaw 命令会自动创建）"
        fi
    else
        echo "ℹ️  OpenClaw CLI 未安装"
        echo "   安装命令：npm install -g openclaw"
        echo "   或使用国内镜像：npm install -g openclaw --registry=https://registry.npmmirror.com"
    fi
    
    # 网络连接检查（可选）
    echo ""
    echo "=== 网络连接检查（可选）==="
    echo "检查与关键服务的连接性："
    
    # 检查npm registry连接
    if curl -fsS -m 5 https://registry.npmjs.org/openclaw >/dev/null 2>&1; then
        echo "✅ npm registry 可访问"
    else
        echo "⚠ npm registry 连接较慢或不可达"
        echo "   国内用户建议设置镜像：npm config set registry https://registry.npmmirror.com"
    fi
    
    # 检查GitHub（OpenClaw源码）
    if curl -fsS -m 5 https://raw.githubusercontent.com/openclaw/openclaw/main/package.json >/dev/null 2>&1; then
        echo "✅ GitHub raw 可访问"
    else
        echo "⚠ GitHub raw 连接较慢或不可达"
        echo "   国内用户可通过Gitee镜像：https://gitee.com/mirrors/openclaw"
    fi
    
    # 检查中华AI共和国官网
    if curl -fsS -m 5 https://clawdrepublic.cn/ >/dev/null 2>&1; then
        echo "✅ 中华AI共和国官网可访问"
    else
        echo "⚠ 中华AI共和国官网连接较慢或不可达"
        echo "   备用检查：curl -fsS -m 10 https://clawdrepublic.cn/"
    fi
    
else
    echo "❌ Node.js 未安装"
    echo ""
    echo "安装指南："
    echo "1. 推荐使用 Node.js LTS 版本（v18+）"
    echo "2. 下载地址：https://nodejs.org/"
    echo "3. 国内镜像：https://npmmirror.com/mirrors/node/"
    echo ""
    echo "安装后验证："
    echo "  node --version  # 应显示版本号"
    echo "  npm --version   # 应显示版本号"
    exit 1
fi

echo ""
echo "=== 验证完成 ==="
echo "✅ Node.js环境验证完成"
echo ""
echo "下一步建议："
echo "1. 如果未安装OpenClaw：npm install -g openclaw"
echo "2. 国内用户可加速：npm config set registry https://registry.npmmirror.com"
echo "3. 安装后运行：openclaw --help"
echo "4. 获取TRIAL_KEY：访问 https://clawdrepublic.cn/forum/ 发帖申请"
echo ""
echo "更多帮助："
echo "- 官网：https://clawdrepublic.cn/"
echo "- 论坛：https://clawdrepublic.cn/forum/"
echo "- 小白一条龙教程：https://clawdrepublic.cn/quickstart.html"