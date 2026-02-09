#!/bin/bash
# 验证论坛访问状态（子域名 + 路径）

set -e

echo "=== 论坛访问验证脚本 ==="
echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查参数
JSON_OUTPUT=false
if [[ "$1" == "--json" ]]; then
    JSON_OUTPUT=true
fi

# 结果变量
FORUM_SUBDOMAIN_OK=false
FORUM_PATH_OK=false
FORUM_INTERNAL_OK=false
FORUM_TITLE=""
ERROR_MSG=""

# 1. 验证论坛子域名 (forum.clawdrepublic.cn)
echo "1. 验证论坛子域名访问..."
if curl -fsS -m 10 https://forum.clawdrepublic.cn/ >/tmp/forum_subdomain.html 2>/dev/null; then
    FORUM_SUBDOMAIN_OK=true
    FORUM_TITLE=$(grep -o '<title>[^<]*</title>' /tmp/forum_subdomain.html 2>/dev/null | sed 's/<title>//;s/<\/title>//' || echo "")
    echo "  ✓ 子域名访问成功"
    if [[ -n "$FORUM_TITLE" ]]; then
        echo "  ✓ 论坛标题: $FORUM_TITLE"
    fi
else
    ERROR_MSG="子域名访问失败"
    echo "  ✗ 子域名访问失败 (HTTPS)"
    
    # 尝试HTTP
    if curl -fsS -m 10 http://forum.clawdrepublic.cn/ >/dev/null 2>/dev/null; then
        echo "  ⚠  HTTP访问成功（HTTPS证书可能有问题）"
    fi
fi

# 2. 验证论坛路径 (clawdrepublic.cn/forum/)
echo "2. 验证论坛路径访问..."
if curl -fsS -m 10 https://clawdrepublic.cn/forum/ >/tmp/forum_path.html 2>/dev/null; then
    FORUM_PATH_OK=true
    echo "  ✓ 路径访问成功"
else
    ERROR_MSG="${ERROR_MSG:+$ERROR_MSG; }路径访问失败"
    echo "  ✗ 路径访问失败"
fi

# 3. 验证服务器内部访问（需要服务器IP）
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -1 "$SERVER_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "")
    if [[ -n "$SERVER_IP" ]]; then
        echo "3. 验证服务器内部论坛访问..."
        if ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
            "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null" 2>/dev/null; then
            FORUM_INTERNAL_OK=true
            echo "  ✓ 服务器内部访问正常"
        else
            ERROR_MSG="${ERROR_MSG:+$ERROR_MSG; }服务器内部访问失败"
            echo "  ✗ 服务器内部访问失败"
        fi
    else
        echo "3. 跳过服务器内部检查（无法解析IP）"
    fi
else
    echo "3. 跳过服务器内部检查（服务器文件不存在）"
fi

# 4. 检查DNS解析
echo "4. 检查DNS解析..."
if dig +short forum.clawdrepublic.cn >/dev/null 2>&1; then
    DNS_IP=$(dig +short forum.clawdrepublic.cn | head -1)
    echo "  ✓ DNS解析成功: $DNS_IP"
else
    ERROR_MSG="${ERROR_MSG:+$ERROR_MSG; }DNS解析失败"
    echo "  ✗ DNS解析失败"
fi

# 输出结果
echo ""
echo "=== 验证结果汇总 ==="
echo "论坛子域名访问: $( [[ $FORUM_SUBDOMAIN_OK == true ]] && echo '✓ 成功' || echo '✗ 失败' )"
echo "论坛路径访问: $( [[ $FORUM_PATH_OK == true ]] && echo '✓ 成功' || echo '✗ 失败' )"
echo "服务器内部访问: $( [[ $FORUM_INTERNAL_OK == true ]] && echo '✓ 成功' || echo '✗ 失败' )"
if [[ -n "$FORUM_TITLE" ]]; then
    echo "论坛标题: $FORUM_TITLE"
fi
if [[ -n "$ERROR_MSG" ]]; then
    echo "错误信息: $ERROR_MSG"
fi

# JSON输出（用于CI/监控）
if [[ "$JSON_OUTPUT" == true ]]; then
    cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "forum": {
    "subdomain_ok": $FORUM_SUBDOMAIN_OK,
    "path_ok": $FORUM_PATH_OK,
    "internal_ok": $FORUM_INTERNAL_OK,
    "title": "$FORUM_TITLE",
    "errors": "$ERROR_MSG"
  },
  "dns_resolved": $( [[ -n "$DNS_IP" ]] && echo "true" || echo "false" ),
  "overall_ok": $( [[ $FORUM_SUBDOMAIN_OK == true || $FORUM_PATH_OK == true ]] && echo "true" || echo "false" )
}
EOF
fi

# 清理
rm -f /tmp/forum_subdomain.html /tmp/forum_path.html 2>/dev/null || true

# 退出码
if [[ $FORUM_SUBDOMAIN_OK == true || $FORUM_PATH_OK == true ]]; then
    exit 0
else
    exit 1
fi