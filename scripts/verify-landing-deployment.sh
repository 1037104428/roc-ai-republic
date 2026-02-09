#!/bin/bash
set -e

# 验证 landing page 部署
# 用法: ./scripts/verify-landing-deployment.sh [--server-ip IP] [--web-dir DIR]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat <<EOF
验证 landing page 部署状态

用法: $0 [选项]

选项:
  --help        显示此帮助信息
  --server-ip IP  指定服务器IP（覆盖 SERVER_FILE）
  --web-dir DIR   指定服务器上的web目录（默认: /opt/roc/web）
  --url URL       直接测试URL（覆盖 server-ip/web-dir）
  --timeout SEC   超时时间（默认: 10秒）

环境变量:
  SERVER_FILE    服务器信息文件路径（默认: /tmp/server.txt）

示例:
  $0                     # 使用默认配置验证
  $0 --server-ip 1.2.3.4 # 验证特定服务器
  $0 --url http://example.com/ # 直接测试URL

EOF
}

# 解析参数
SERVER_IP=""
WEB_DIR="/opt/roc/web"
TEST_URL=""
TIMEOUT=10

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --web-dir)
            WEB_DIR="$2"
            shift 2
            ;;
        --url)
            TEST_URL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 构建测试URL
if [[ -n "$TEST_URL" ]]; then
    URL="$TEST_URL"
elif [[ -n "$SERVER_IP" ]]; then
    URL="http://$SERVER_IP/"
else
    # 从文件获取服务器IP
    if [[ -f "$SERVER_FILE" ]]; then
        SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2)
        if [[ -z "$SERVER_IP" ]]; then
            SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        fi
    fi
    
    if [[ -z "$SERVER_IP" ]]; then
        echo "错误: 无法获取服务器IP"
        echo "请设置 --server-ip 参数或确保 $SERVER_FILE 包含IP地址"
        exit 1
    fi
    URL="http://$SERVER_IP/"
fi

echo "验证 landing page 部署..."
echo "测试URL: $URL"
echo "超时: ${TIMEOUT}秒"

# 验证函数
verify() {
    local success=true
    
    # 1. 测试HTTP访问
    echo -n "1. HTTP访问测试... "
    if curl -fsS -m "$TIMEOUT" "$URL" >/dev/null 2>&1; then
        echo "✅ 通过"
    else
        echo "❌ 失败"
        success=false
    fi
    
    # 2. 检查页面内容（如果HTTP访问成功）
    if [[ "$success" = true ]]; then
        echo -n "2. 页面内容检查... "
        if curl -fsS -m "$TIMEOUT" "$URL" | grep -q "中华AI共和国"; then
            echo "✅ 找到标题"
        else
            echo "⚠️  标题未找到（可能页面内容不同）"
        fi
        
        # 检查关键元素
        echo -n "3. 关键元素检查... "
        CONTENT=$(curl -fsS -m "$TIMEOUT" "$URL" 2>/dev/null || echo "")
        MISSING_ELEMENTS=""
        
        if ! echo "$CONTENT" | grep -q "OpenClaw"; then
            MISSING_ELEMENTS="${MISSING_ELEMENTS}OpenClaw "
        fi
        
        if ! echo "$CONTENT" | grep -q "一键安装"; then
            MISSING_ELEMENTS="${MISSING_ELEMENTS}一键安装 "
        fi
        
        if [[ -z "$MISSING_ELEMENTS" ]]; then
            echo "✅ 所有关键元素存在"
        else
            echo "⚠️  缺少元素: $MISSING_ELEMENTS"
        fi
    fi
    
    # 3. 服务器文件检查（如果知道服务器IP且不是直接测试URL）
    if [[ -n "$SERVER_IP" && -z "$TEST_URL" ]]; then
        echo -n "4. 服务器文件检查... "
        SSH_CMD="ssh -o BatchMode=yes -o ConnectTimeout=10 root@$SERVER_IP"
        
        if $SSH_CMD "test -f $WEB_DIR/index.html" 2>/dev/null; then
            echo "✅ index.html 存在"
            
            # 检查文件大小
            FILE_SIZE=$($SSH_CMD "stat -c%s $WEB_DIR/index.html 2>/dev/null || echo 0")
            if [[ "$FILE_SIZE" -gt 1000 ]]; then
                echo "   文件大小: ${FILE_SIZE} 字节 ✅"
            else
                echo "   文件大小: ${FILE_SIZE} 字节 ⚠️ (可能过小)"
            fi
            
            # 检查文件权限
            PERMS=$($SSH_CMD "stat -c%a $WEB_DIR/index.html 2>/dev/null || echo ''")
            if [[ "$PERMS" = "644" ]]; then
                echo "   文件权限: $PERMS ✅"
            else
                echo "   文件权限: $PERMS ⚠️ (建议644)"
            fi
        else
            echo "❌ index.html 不存在"
            success=false
        fi
    fi
    
    # 总结
    echo ""
    echo "=== 验证总结 ==="
    if [[ "$success" = true ]]; then
        echo "✅ Landing page 部署验证通过"
        echo "访问地址: $URL"
        
        # 提供快速测试命令
        echo ""
        echo "快速测试命令:"
        echo "  curl -fsS -m 5 '$URL' | grep -o '中华AI共和国'"
        echo "  curl -fsS -m 5 '$URL' | head -5"
        
        return 0
    else
        echo "❌ Landing page 部署验证失败"
        echo "请检查:"
        echo "  1. Web服务器是否运行"
        echo "  2. 防火墙设置"
        echo "  3. 文件是否正确部署"
        echo "  4. 网络连接"
        
        return 1
    fi
}

# 执行验证
verify