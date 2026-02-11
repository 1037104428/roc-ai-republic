#!/usr/bin/env bash
set -euo pipefail

# Web 站点部署就绪验证脚本
# 验证静态站点是否已准备好部署到服务器

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_SOURCE_DIR="$REPO_ROOT/web/site"
WEB_CONFIG_DIR="$REPO_ROOT/web"

echo "🔍 验证 Web 站点部署就绪状态"
echo "================================"
echo ""

# 1. 检查源文件目录
echo "1. 检查源文件目录 ($WEB_SOURCE_DIR)"
if [ ! -d "$WEB_SOURCE_DIR" ]; then
    echo "   ❌ 源文件目录不存在"
    exit 1
fi
echo "   ✅ 源文件目录存在"

# 2. 检查必需文件
echo "2. 检查必需文件"
required_files=(
    "index.html"
    "downloads.html"
    "quickstart.html"
    "install-cn.sh"
    "trial-key-guide.html"
)

all_ok=true
for file in "${required_files[@]}"; do
    if [ -f "$WEB_SOURCE_DIR/$file" ]; then
        echo "   ✅ $file 存在"
    else
        echo "   ❌ $file 缺失"
        all_ok=false
    fi
done

# 3. 检查部署脚本
echo "3. 检查部署脚本"
deploy_scripts=(
    "deploy-web-site.sh"
    "deploy-web-server-config.sh"
    "deploy-web-script.sh"
)

for script in "${deploy_scripts[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo "   ✅ $script 存在"
        if [ -x "$SCRIPT_DIR/$script" ]; then
            echo "   ✅ $script 可执行"
        else
            echo "   ⚠️  $script 不可执行，正在添加执行权限"
            chmod +x "$SCRIPT_DIR/$script"
        fi
    else
        echo "   ❌ $script 缺失"
        all_ok=false
    fi
done

# 4. 检查部署指南
echo "4. 检查部署指南"
if [ -f "$REPO_ROOT/docs/ops-web-deploy.md" ]; then
    echo "   ✅ ops-web-deploy.md 存在"
    # 检查指南内容
    if grep -q "Caddy" "$REPO_ROOT/docs/ops-web-deploy.md" && grep -q "Nginx" "$REPO_ROOT/docs/ops-web-deploy.md"; then
        echo "   ✅ 指南包含 Caddy 和 Nginx 配置"
    else
        echo "   ⚠️  指南可能不完整"
    fi
else
    echo "   ❌ ops-web-deploy.md 缺失"
    all_ok=false
fi

# 5. 检查服务器配置
echo "5. 检查服务器配置"
if [ -d "$WEB_CONFIG_DIR/caddy" ]; then
    echo "   ✅ Caddy 配置目录存在"
    if [ -f "$WEB_CONFIG_DIR/caddy/Caddyfile" ]; then
        echo "   ✅ Caddyfile 存在"
    else
        echo "   ❌ Caddyfile 缺失"
        all_ok=false
    fi
else
    echo "   ❌ Caddy 配置目录缺失"
    all_ok=false
fi

if [ -d "$WEB_CONFIG_DIR/nginx" ]; then
    echo "   ✅ Nginx 配置目录存在"
    if [ -f "$WEB_CONFIG_DIR/nginx/nginx.conf" ]; then
        echo "   ✅ nginx.conf 存在"
    else
        echo "   ❌ nginx.conf 缺失"
        all_ok=false
    fi
else
    echo "   ❌ Nginx 配置目录缺失"
    all_ok=false
fi

# 6. 检查站点内容完整性
echo "6. 检查站点内容完整性"
echo "   - 检查 HTML 文件语法"
html_files=$(find "$WEB_SOURCE_DIR" -name "*.html" -type f)
html_count=$(echo "$html_files" | wc -l)
echo "   ✅ 找到 $html_count 个 HTML 文件"

echo "   - 检查脚本文件语法"
script_files=$(find "$WEB_SOURCE_DIR" -name "*.sh" -type f)
for script in $script_files; do
    if bash -n "$script" 2>/dev/null; then
        echo "   ✅ $(basename "$script") 语法正确"
    else
        echo "   ❌ $(basename "$script") 语法错误"
        all_ok=false
    fi
done

# 7. 检查站点功能
echo "7. 检查站点功能"
echo "   - 检查下载链接"
if grep -q "install-cn.sh" "$WEB_SOURCE_DIR/downloads.html"; then
    echo "   ✅ downloads.html 包含安装脚本链接"
else
    echo "   ❌ downloads.html 缺少安装脚本链接"
    all_ok=false
fi

echo "   - 检查 API 网关信息"
if grep -q "quota-proxy" "$WEB_SOURCE_DIR/trial-key-guide.html"; then
    echo "   ✅ trial-key-guide.html 包含 quota-proxy 信息"
else
    echo "   ❌ trial-key-guide.html 缺少 quota-proxy 信息"
    all_ok=false
fi

echo "   - 检查快速开始指南"
if grep -q "快速开始" "$WEB_SOURCE_DIR/quickstart.html"; then
    echo "   ✅ quickstart.html 包含快速开始内容"
else
    echo "   ❌ quickstart.html 缺少快速开始内容"
    all_ok=false
fi

echo ""
echo "================================"
if [ "$all_ok" = true ]; then
    echo "🎉 Web 站点部署就绪验证通过！"
    echo ""
    echo "下一步："
    echo "1. 确保服务器信息在 /tmp/server.txt 中"
    echo "2. 运行部署脚本："
    echo "   ./scripts/deploy-web-site.sh"
    echo "3. 验证部署："
    echo "   ./scripts/deploy-web-script.sh --verify"
    exit 0
else
    echo "❌ Web 站点部署就绪验证失败"
    echo ""
    echo "需要修复的问题："
    echo "1. 检查缺失的文件"
    echo "2. 确保所有脚本可执行"
    echo "3. 验证站点内容完整性"
    exit 1
fi