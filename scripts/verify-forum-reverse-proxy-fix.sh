#!/bin/bash
# 验证论坛反向代理修复脚本
# 用于检查 forum.clawdrepublic.cn 外网 502 问题是否已修复
# 用法: ./scripts/verify-forum-reverse-proxy-fix.sh [--server IP] [--timeout SECONDS]

set -e

# 默认参数
SERVER_IP=""
TIMEOUT=8
INTERNAL_PORT=8081
EXTERNAL_URL="http://forum.clawdrepublic.cn"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER_IP="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "验证论坛反向代理修复脚本"
            echo "用于检查 forum.clawdrepublic.cn 外网 502 问题是否已修复"
            echo "用法: $0 [--server IP] [--timeout SECONDS]"
            echo ""
            echo "参数:"
            echo "  --server IP     服务器IP地址 (默认从 /tmp/server.txt 读取)"
            echo "  --timeout SEC   超时秒数 (默认: $TIMEOUT)"
            echo "  --help          显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 获取服务器IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "/tmp/server.txt" ]]; then
        SERVER_IP=$(head -1 /tmp/server.txt | sed 's/^ip://;s/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$SERVER_IP" ]]; then
            SERVER_IP=$(head -1 /tmp/server.txt | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
        fi
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "❌ 无法获取服务器IP地址"
    echo "请通过 --server 参数指定，或确保 /tmp/server.txt 包含IP地址"
    exit 1
fi

echo "🔍 开始验证论坛反向代理修复状态..."
echo "服务器IP: $SERVER_IP"
echo "外网URL: $EXTERNAL_URL"
echo "内网端口: $INTERNAL_PORT"
echo "超时设置: ${TIMEOUT}秒"
echo ""

# 检查1: 内网论坛服务是否运行
echo "1. 检查内网论坛服务 (127.0.0.1:$INTERNAL_PORT)..."
if ssh -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" "root@$SERVER_IP" \
   "curl -fsS --max-time $TIMEOUT http://127.0.0.1:$INTERNAL_PORT > /dev/null 2>&1"; then
    echo "   ✅ 内网论坛服务正常"
else
    echo "   ❌ 内网论坛服务不可用"
    echo "     请检查论坛容器是否运行: ssh root@$SERVER_IP 'docker ps | grep flarum'"
    exit 1
fi

# 检查2: 内网论坛页面标题
echo "2. 检查内网论坛页面标题..."
INTERNAL_TITLE=$(ssh -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" "root@$SERVER_IP" \
   "curl -fsS --max-time $TIMEOUT http://127.0.0.1:$INTERNAL_PORT 2>/dev/null | \
    grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo ''")
if [[ -n "$INTERNAL_TITLE" ]]; then
    echo "   ✅ 内网论坛标题: $INTERNAL_TITLE"
else
    echo "   ⚠️  无法获取内网论坛标题"
fi

# 检查3: 外网论坛访问
echo "3. 检查外网论坛访问 ($EXTERNAL_URL)..."
if curl -fsS --max-time "$TIMEOUT" "$EXTERNAL_URL" > /dev/null 2>&1; then
    echo "   ✅ 外网论坛访问正常"
else
    echo "   ❌ 外网论坛访问失败 (可能仍是502错误)"
    echo "     请检查反向代理配置:"
    echo "     1. Caddy/Nginx 配置是否正确"
    echo "     2. 域名解析是否正确"
    echo "     3. 防火墙/安全组是否开放端口"
    exit 1
fi

# 检查4: 外网论坛页面标题
echo "4. 检查外网论坛页面标题..."
EXTERNAL_TITLE=$(curl -fsS --max-time "$TIMEOUT" "$EXTERNAL_URL" 2>/dev/null | \
    grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo '')
if [[ -n "$EXTERNAL_TITLE" ]]; then
    echo "   ✅ 外网论坛标题: $EXTERNAL_TITLE"
else
    echo "   ⚠️  无法获取外网论坛标题"
fi

# 检查5: 对比内外网标题是否一致
echo "5. 对比内外网论坛标题..."
if [[ -n "$INTERNAL_TITLE" && -n "$EXTERNAL_TITLE" ]]; then
    if [[ "$INTERNAL_TITLE" == "$EXTERNAL_TITLE" ]]; then
        echo "   ✅ 内外网论坛标题一致"
    else
        echo "   ⚠️  内外网论坛标题不一致"
        echo "     内网: $INTERNAL_TITLE"
        echo "     外网: $EXTERNAL_TITLE"
    fi
else
    echo "   ⚠️  无法对比标题 (标题获取失败)"
fi

# 检查6: 外网论坛功能检查
echo "6. 检查外网论坛基本功能..."
if curl -fsS --max-time "$TIMEOUT" "$EXTERNAL_URL" 2>/dev/null | grep -q -E '(登录|注册|sign in|sign up|log in|register)' 2>/dev/null; then
    echo "   ✅ 外网论坛登录/注册功能正常"
else
    echo "   ⚠️  外网论坛登录/注册功能异常"
fi

echo ""
echo "📊 验证结果摘要:"
echo "  服务器: $SERVER_IP"
echo "  内网论坛: http://127.0.0.1:$INTERNAL_PORT"
echo "  外网论坛: $EXTERNAL_URL"
echo ""
echo "🎯 修复状态:"

if curl -fsS --max-time "$TIMEOUT" "$EXTERNAL_URL" > /dev/null 2>&1; then
    echo "  ✅ 论坛反向代理修复成功！外网可正常访问"
    echo ""
    echo "📋 下一步建议:"
    echo "  1. 访问 $EXTERNAL_URL 测试论坛功能"
    echo "  2. 检查HTTPS是否自动配置 (Caddy)"
    echo "  3. 运行论坛初始化脚本: ./scripts/init-forum-sticky-posts.sh"
else
    echo "  ❌ 论坛反向代理仍需修复，外网访问失败"
    echo ""
    echo "🔧 修复建议:"
    echo "  1. 运行修复脚本: ./scripts/fix-forum-502-caddy.sh"
    echo "  2. 或运行: ./scripts/fix-forum-reverse-proxy-simple.sh"
    echo "  3. 检查DNS解析: ./scripts/fix-forum-502-dns.sh"
fi

echo ""
echo "🔗 相关文档:"
echo "  - docs/tickets.md (论坛MVP部署任务)"
echo "  - docs/forum-mvp-deployment.md (论坛部署指南)"
echo "  - quota-proxy/README.md (API网关配置)"