#!/bin/bash
set -e

# 部署中华AI共和国 landing page 到服务器
# 用法: ./scripts/deploy-landing-page.sh [--dry-run] [--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat <<EOF
部署中华AI共和国 landing page 到服务器

用法: $0 [选项]

选项:
  --dry-run     只显示将要执行的命令，不实际执行
  --help        显示此帮助信息
  --server-ip IP  指定服务器IP（覆盖 SERVER_FILE）
  --web-dir DIR   指定服务器上的web目录（默认: /opt/roc/web）

环境变量:
  SERVER_FILE    服务器信息文件路径（默认: /tmp/server.txt）
  SSH_KEY        可选的SSH私钥路径

示例:
  $0                     # 使用默认配置部署
  $0 --dry-run           # 预览部署命令
  $0 --server-ip 1.2.3.4 --web-dir /var/www/html

EOF
}

# 解析参数
DRY_RUN=false
SERVER_IP=""
WEB_DIR="/opt/roc/web"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
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
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取服务器IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "$SERVER_FILE" ]]; then
        # 支持格式: ip=1.2.3.4 或 裸IP
        SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2)
        if [[ -z "$SERVER_IP" ]]; then
            # 尝试读取第一行作为裸IP
            SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        fi
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 无法获取服务器IP"
    echo "请设置 --server-ip 参数或确保 $SERVER_FILE 包含IP地址"
    exit 1
fi

echo "服务器IP: $SERVER_IP"
echo "Web目录: $WEB_DIR"
echo "源目录: $REPO_ROOT/web-landing"

# 检查源文件
if [[ ! -f "$REPO_ROOT/web-landing/index.html" ]]; then
    echo "错误: 找不到 landing page 源文件: $REPO_ROOT/web-landing/index.html"
    exit 1
fi

# 构建SSH命令
SSH_CMD="ssh -o BatchMode=yes -o ConnectTimeout=10 root@$SERVER_IP"
if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
    SSH_CMD="ssh -i '$SSH_KEY' -o BatchMode=yes -o ConnectTimeout=10 root@$SERVER_IP"
fi

# 部署函数
deploy() {
    echo "正在部署 landing page..."
    
    # 1. 在服务器上创建目录
    echo "创建目录: $WEB_DIR"
    if [[ "$DRY_RUN" = true ]]; then
        echo "[dry-run] $SSH_CMD \"mkdir -p $WEB_DIR\""
    else
        $SSH_CMD "mkdir -p $WEB_DIR"
    fi
    
    # 2. 复制文件
    echo "复制 index.html"
    if [[ "$DRY_RUN" = true ]]; then
        echo "[dry-run] scp $REPO_ROOT/web-landing/index.html root@$SERVER_IP:$WEB_DIR/"
    else
        scp "$REPO_ROOT/web-landing/index.html" "root@$SERVER_IP:$WEB_DIR/"
    fi
    
    # 3. 设置权限
    echo "设置文件权限"
    if [[ "$DRY_RUN" = true ]]; then
        echo "[dry-run] $SSH_CMD \"chmod 644 $WEB_DIR/index.html\""
    else
        $SSH_CMD "chmod 644 $WEB_DIR/index.html"
    fi
    
    # 4. 验证部署
    echo "验证部署..."
    if [[ "$DRY_RUN" = true ]]; then
        echo "[dry-run] $SSH_CMD \"ls -la $WEB_DIR/ && curl -fsS http://127.0.0.1:80/ 2>/dev/null | head -5 || echo 'Web服务可能未运行'\""
    else
        $SSH_CMD "ls -la $WEB_DIR/ && echo && echo '文件内容预览:' && head -20 $WEB_DIR/index.html"
    fi
    
    echo "✅ Landing page 部署完成"
    echo "访问地址: http://$SERVER_IP/"
    echo "或配置域名后访问: https://your-domain.com/"
}

# 执行部署
deploy

# 提供后续步骤
cat <<EOF

后续步骤:
1. 配置Web服务器 (Nginx/Caddy) 指向 $WEB_DIR
2. 配置SSL证书 (Let's Encrypt)
3. 配置域名解析到 $SERVER_IP
4. 测试访问: curl -fsS http://$SERVER_IP/

现有配置参考:
- Nginx: $REPO_ROOT/web/nginx/nginx.conf
- Caddy: $REPO_ROOT/web/caddy/Caddyfile
- 部署脚本: $REPO_ROOT/scripts/deploy-web-server-config.sh

EOF