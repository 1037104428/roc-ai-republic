#!/bin/bash
# deploy-caddy-static-site.sh - 部署Caddy静态站点
# 中华AI共和国 / OpenClaw 小白中文包 - 静态站点部署脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
DRY_RUN=false
SERVER_IP=""
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
WEB_DIR="/opt/roc/web"
CADDY_CONFIG="configs/caddy-static-site.Caddyfile"
CADDY_PORT=8788
QUOTA_PROXY_PORT=8787

# 帮助信息
show_help() {
    cat << EOF
部署Caddy静态站点脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不实际执行
  --server-ip IP     服务器IP地址（默认从/tmp/server.txt读取）
  --ssh-key PATH     SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）
  --web-dir PATH     服务器web目录（默认: /opt/roc/web）
  --config PATH      Caddy配置文件路径（默认: configs/caddy-static-site.Caddyfile）
  --help             显示此帮助信息

示例:
  $0 --dry-run
  $0 --server-ip 8.210.185.194
  $0 --server-ip 8.210.185.194 --web-dir /opt/roc/web

功能:
  1. 检查Caddy是否安装
  2. 上传配置文件到服务器
  3. 创建systemd服务
  4. 启动Caddy服务
  5. 验证部署结果

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --web-dir)
            WEB_DIR="$2"
            shift 2
            ;;
        --config)
            CADDY_CONFIG="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 获取服务器IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "/tmp/server.txt" ]]; then
        SERVER_IP=$(grep "^ip:" /tmp/server.txt | cut -d: -f2 | tr -d '[:space:]')
        if [[ -z "$SERVER_IP" ]]; then
            echo -e "${RED}错误: 无法从/tmp/server.txt解析服务器IP${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 未指定服务器IP且/tmp/server.txt不存在${NC}"
        echo -e "${YELLOW}请使用 --server-ip 参数指定服务器IP${NC}"
        exit 1
    fi
fi

# 检查SSH密钥
if [[ ! -f "$SSH_KEY" ]]; then
    echo -e "${RED}错误: SSH密钥不存在: $SSH_KEY${NC}"
    exit 1
fi

# 检查配置文件
if [[ ! -f "$CADDY_CONFIG" ]]; then
    echo -e "${RED}错误: Caddy配置文件不存在: $CADDY_CONFIG${NC}"
    exit 1
fi

# 打印配置信息
echo -e "${BLUE}=== Caddy静态站点部署配置 ===${NC}"
echo -e "服务器IP: ${GREEN}$SERVER_IP${NC}"
echo -e "SSH密钥: ${GREEN}$SSH_KEY${NC}"
echo -e "Web目录: ${GREEN}$WEB_DIR${NC}"
echo -e "Caddy配置: ${GREEN}$CADDY_CONFIG${NC}"
echo -e "Caddy端口: ${GREEN}$CADDY_PORT${NC}"
echo -e "Quota代理端口: ${GREEN}$QUOTA_PROXY_PORT${NC}"
echo -e "模拟运行: ${GREEN}$DRY_RUN${NC}"
echo

# 模拟运行模式
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== 模拟运行模式 ===${NC}"
    echo -e "将执行以下步骤:"
    echo "1. 检查Caddy配置文件: $CADDY_CONFIG"
    echo "2. 检查服务器连接: ssh -i $SSH_KEY root@$SERVER_IP 'echo 连接成功'"
    echo "3. 检查服务器Caddy安装: ssh -i $SSH_KEY root@$SERVER_IP 'command -v caddy || echo Caddy未安装'"
    echo "4. 创建web目录: ssh -i $SSH_KEY root@$SERVER_IP 'mkdir -p $WEB_DIR'"
    echo "5. 上传Caddy配置: scp -i $SSH_KEY $CADDY_CONFIG root@$SERVER_IP:/etc/caddy/Caddyfile"
    echo "6. 创建systemd服务文件"
    echo "7. 启动Caddy服务: ssh -i $SSH_KEY root@$SERVER_IP 'systemctl daemon-reload && systemctl enable caddy-roc && systemctl start caddy-roc'"
    echo "8. 验证部署: curl -fsS http://$SERVER_IP:$CADDY_PORT/healthz"
    echo
    echo -e "${GREEN}模拟运行完成 - 未实际执行任何操作${NC}"
    exit 0
fi

# 实际部署函数
deploy_caddy() {
    local server_ip="$1"
    local ssh_key="$2"
    local web_dir="$3"
    local caddy_config="$4"
    
    echo -e "${BLUE}=== 开始部署Caddy静态站点 ===${NC}"
    
    # 1. 检查服务器连接
    echo -e "${YELLOW}[1/8] 检查服务器连接...${NC}"
    if ! ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" 'echo "SSH连接成功"'; then
        echo -e "${RED}错误: 无法连接到服务器${NC}"
        return 1
    fi
    
    # 2. 检查Caddy安装
    echo -e "${YELLOW}[2/8] 检查Caddy安装...${NC}"
    if ! ssh -i "$ssh_key" root@"$server_ip" 'command -v caddy'; then
        echo -e "${YELLOW}Caddy未安装，开始安装...${NC}"
        ssh -i "$ssh_key" root@"$server_ip" 'apt-get update && apt-get install -y curl'
        ssh -i "$ssh_key" root@"$server_ip" 'curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg'
        ssh -i "$ssh_key" root@"$server_ip" 'curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | tee /etc/apt/sources.list.d/caddy-stable.list'
        ssh -i "$ssh_key" root@"$server_ip" 'apt-get update && apt-get install -y caddy'
        echo -e "${GREEN}Caddy安装完成${NC}"
    else
        echo -e "${GREEN}Caddy已安装${NC}"
    fi
    
    # 3. 创建web目录
    echo -e "${YELLOW}[3/8] 创建web目录...${NC}"
    ssh -i "$ssh_key" root@"$server_ip" "mkdir -p '$web_dir'"
    echo -e "${GREEN}Web目录创建完成: $web_dir${NC}"
    
    # 4. 上传Caddy配置
    echo -e "${YELLOW}[4/8] 上传Caddy配置...${NC}"
    scp -i "$ssh_key" "$caddy_config" root@"$server_ip":/etc/caddy/Caddyfile
    echo -e "${GREEN}Caddy配置上传完成${NC}"
    
    # 5. 创建systemd服务文件
    echo -e "${YELLOW}[5/8] 创建systemd服务文件...${NC}"
    cat << EOF | ssh -i "$ssh_key" root@"$server_ip" "cat > /etc/systemd/system/caddy-roc.service"
[Unit]
Description=Caddy for ROC AI Republic Static Site
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}systemd服务文件创建完成${NC}"
    
    # 6. 启动Caddy服务
    echo -e "${YELLOW}[6/8] 启动Caddy服务...${NC}"
    ssh -i "$ssh_key" root@"$server_ip" "systemctl daemon-reload"
    ssh -i "$ssh_key" root@"$server_ip" "systemctl enable caddy-roc"
    ssh -i "$ssh_key" root@"$server_ip" "systemctl restart caddy-roc"
    echo -e "${GREEN}Caddy服务启动完成${NC}"
    
    # 7. 检查服务状态
    echo -e "${YELLOW}[7/8] 检查服务状态...${NC}"
    ssh -i "$ssh_key" root@"$server_ip" "systemctl status caddy-roc --no-pager"
    
    # 8. 验证部署
    echo -e "${YELLOW}[8/8] 验证部署...${NC}"
    if ssh -i "$ssh_key" root@"$server_ip" "curl -fsS http://localhost:$CADDY_PORT/healthz"; then
        echo -e "${GREEN}部署验证成功！${NC}"
        echo -e "${GREEN}静态站点地址: http://$server_ip:$CADDY_PORT${NC}"
        echo -e "${GREEN}API网关地址: http://$server_ip:$QUOTA_PROXY_PORT${NC}"
    else
        echo -e "${RED}警告: 健康检查失败，但服务可能仍在启动中${NC}"
        echo -e "${YELLOW}请稍后检查: curl -fsS http://$server_ip:$CADDY_PORT/healthz${NC}"
    fi
    
    echo -e "${BLUE}=== Caddy静态站点部署完成 ===${NC}"
    return 0
}

# 执行部署
deploy_caddy "$SERVER_IP" "$SSH_KEY" "$WEB_DIR" "$CADDY_CONFIG"

# 检查部署结果
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Caddy静态站点部署成功${NC}"
    echo -e "${YELLOW}下一步:${NC}"
    echo "1. 将状态页面部署到web目录: ./scripts/deploy-status-page.sh"
    echo "2. 访问静态站点: http://$SERVER_IP:$CADDY_PORT"
    echo "3. 配置域名和HTTPS（如需公开访问）"
else
    echo -e "${RED}❌ Caddy静态站点部署失败${NC}"
    exit 1
fi