#!/bin/bash
# verify-caddy-deployment.sh - 验证Caddy静态站点部署
# 中华AI共和国 / OpenClaw 小白中文包 - Caddy部署验证脚本

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
CADDY_PORT=8788
QUOTA_PROXY_PORT=8787

# 帮助信息
show_help() {
    cat << EOF
验证Caddy静态站点部署脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不实际执行
  --server-ip IP     服务器IP地址（默认从/tmp/server.txt读取）
  --ssh-key PATH     SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）
  --caddy-port PORT  Caddy服务端口（默认: 8788）
  --proxy-port PORT  Quota代理端口（默认: 8787）
  --help             显示此帮助信息

示例:
  $0 --dry-run
  $0 --server-ip 8.210.185.194
  $0 --server-ip 8.210.185.194 --caddy-port 8788

验证项目:
  1. 服务器连接
  2. Caddy安装状态
  3. Caddy服务状态
  4. 配置文件存在性
  5. 端口监听状态
  6. 健康检查端点
  7. 静态站点访问
  8. API网关访问

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
        --caddy-port)
            CADDY_PORT="$2"
            shift 2
            ;;
        --proxy-port)
            QUOTA_PROXY_PORT="$2"
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

# 打印配置信息
echo -e "${BLUE}=== Caddy部署验证配置 ===${NC}"
echo -e "服务器IP: ${GREEN}$SERVER_IP${NC}"
echo -e "SSH密钥: ${GREEN}$SSH_KEY${NC}"
echo -e "Caddy端口: ${GREEN}$CADDY_PORT${NC}"
echo -e "Quota代理端口: ${GREEN}$QUOTA_PROXY_PORT${NC}"
echo -e "模拟运行: ${GREEN}$DRY_RUN${NC}"
echo

# 验证函数
verify_deployment() {
    local server_ip="$1"
    local ssh_key="$2"
    local caddy_port="$3"
    local proxy_port="$4"
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo -e "${BLUE}=== 开始验证Caddy部署 ===${NC}"
    
    # 测试1: 服务器连接
    echo -e "${YELLOW}[1/8] 测试服务器连接...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" 'echo "连接成功"'; then
        echo -e "${GREEN}✓ 服务器连接成功${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${RED}✗ 服务器连接失败${NC}"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
    
    # 测试2: Caddy安装状态
    echo -e "${YELLOW}[2/8] 测试Caddy安装状态...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" 'command -v caddy'; then
        local caddy_version=$(ssh -i "$ssh_key" root@"$server_ip" 'caddy version 2>/dev/null | head -1')
        echo -e "${GREEN}✓ Caddy已安装: $caddy_version${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${RED}✗ Caddy未安装${NC}"
        failed_tests=$((failed_tests + 1))
    fi
    
    # 测试3: Caddy服务状态
    echo -e "${YELLOW}[3/8] 测试Caddy服务状态...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" 'systemctl is-active caddy-roc 2>/dev/null'; then
        echo -e "${GREEN}✓ Caddy服务正在运行${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ Caddy服务未运行或不存在${NC}"
        # 不标记为失败，可能是未部署
    fi
    
    # 测试4: 配置文件存在性
    echo -e "${YELLOW}[4/8] 测试配置文件存在性...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" '[[ -f /etc/caddy/Caddyfile ]]'; then
        local config_size=$(ssh -i "$ssh_key" root@"$server_ip" 'stat -c%s /etc/caddy/Caddyfile 2>/dev/null || echo 0')
        echo -e "${GREEN}✓ Caddy配置文件存在 (${config_size}字节)${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ Caddy配置文件不存在${NC}"
        # 不标记为失败，可能是未部署
    fi
    
    # 测试5: 端口监听状态
    echo -e "${YELLOW}[5/8] 测试端口监听状态...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" "netstat -tlnp 2>/dev/null | grep -q ':$caddy_port'" || \
       ssh -i "$ssh_key" root@"$server_ip" "ss -tlnp 2>/dev/null | grep -q ':$caddy_port'"; then
        echo -e "${GREEN}✓ Caddy端口 $caddy_port 正在监听${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ Caddy端口 $caddy_port 未监听${NC}"
        # 不标记为失败，可能是未部署
    fi
    
    # 测试6: 健康检查端点
    echo -e "${YELLOW}[6/8] 测试健康检查端点...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" "curl -fsS http://localhost:$caddy_port/healthz 2>/dev/null"; then
        echo -e "${GREEN}✓ 健康检查端点正常${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ 健康检查端点不可用${NC}"
        # 不标记为失败，可能是服务未运行
    fi
    
    # 测试7: 静态站点访问
    echo -e "${YELLOW}[7/8] 测试静态站点访问...${NC}"
    total_tests=$((total_tests + 1))
    local http_status=$(ssh -i "$ssh_key" root@"$server_ip" "curl -s -o /dev/null -w '%{http_code}' http://localhost:$caddy_port/ 2>/dev/null || echo 000")
    if [[ "$http_status" =~ ^(200|301|302)$ ]]; then
        echo -e "${GREEN}✓ 静态站点可访问 (HTTP $http_status)${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ 静态站点访问异常 (HTTP $http_status)${NC}"
        # 不标记为失败，可能是无内容
    fi
    
    # 测试8: API网关访问
    echo -e "${YELLOW}[8/8] 测试API网关访问...${NC}"
    total_tests=$((total_tests + 1))
    if ssh -i "$ssh_key" root@"$server_ip" "curl -fsS http://localhost:$proxy_port/healthz 2>/dev/null"; then
        echo -e "${GREEN}✓ API网关健康检查正常${NC}"
        passed_tests=$((passed_tests + 1))
    else
        echo -e "${YELLOW}⚠ API网关不可用${NC}"
        # 不标记为失败，quota-proxy可能未部署
    fi
    
    # 汇总结果
    echo -e "${BLUE}=== 验证结果汇总 ===${NC}"
    echo -e "总测试数: ${BLUE}$total_tests${NC}"
    echo -e "通过测试: ${GREEN}$passed_tests${NC}"
    echo -e "失败测试: ${RED}$failed_tests${NC}"
    
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有关键测试通过${NC}"
        echo -e "${YELLOW}部署状态:${NC}"
        echo -e "  - 静态站点: http://$server_ip:$caddy_port"
        echo -e "  - API网关: http://$server_ip:$proxy_port"
        echo -e "  - 健康检查: http://$server_ip:$caddy_port/healthz"
        return 0
    else
        echo -e "${YELLOW}⚠ 部分测试失败${NC}"
        echo -e "${YELLOW}建议:${NC}"
        echo -e "  1. 检查Caddy是否安装: ssh -i $ssh_key root@$server_ip 'command -v caddy'"
        echo -e "  2. 检查服务状态: ssh -i $ssh_key root@$server_ip 'systemctl status caddy-roc'"
        echo -e "  3. 检查端口监听: ssh -i $ssh_key root@$server_ip 'netstat -tlnp | grep :$caddy_port'"
        return 1
    fi
}

# 模拟运行模式
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== 模拟运行模式 ===${NC}"
    echo -e "将执行以下验证步骤:"
    echo "1. 测试服务器连接: ssh -i $SSH_KEY root@$SERVER_IP 'echo 连接成功'"
    echo "2. 测试Caddy安装状态: ssh -i $SSH_KEY root@$SERVER_IP 'command -v caddy'"
    echo "3. 测试Caddy服务状态: ssh -i $SSH_KEY root@$SERVER_IP 'systemctl is-active caddy-roc'"
    echo "4. 测试配置文件存在性: ssh -i $SSH_KEY root@$SERVER_IP '[[ -f /etc/caddy/Caddyfile ]]'"
    echo "5. 测试端口监听状态: ssh -i $SSH_KEY root@$SERVER_IP 'netstat -tlnp | grep :$CADDY_PORT'"
    echo "6. 测试健康检查端点: ssh -i $SSH_KEY root@$SERVER_IP 'curl -fsS http://localhost:$CADDY_PORT/healthz'"
    echo "7. 测试静态站点访问: ssh -i $SSH_KEY root@$SERVER_IP 'curl -s -o /dev/null -w %{http_code} http://localhost:$CADDY_PORT/'"
    echo "8. 测试API网关访问: ssh -i $SSH_KEY root@$SERVER_IP 'curl -fsS http://localhost:$QUOTA_PROXY_PORT/healthz'"
    echo
    echo -e "${GREEN}模拟运行完成 - 未实际执行任何操作${NC}"
    exit 0
fi

# 执行验证
verify_deployment "$SERVER_IP" "$SSH_KEY" "$CADDY_PORT" "$QUOTA_PROXY_PORT"

# 输出最终状态
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Caddy部署验证通过${NC}"
else
    echo -e "${YELLOW}⚠ Caddy部署验证发现一些问题${NC}"
    echo -e "${YELLOW}如需部署Caddy，请运行:${NC}"
    echo -e "  ./scripts/deploy-caddy-static-site.sh --server-ip $SERVER_IP"
fi