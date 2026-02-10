#!/bin/bash
# 部署带数据持久化的 quota-proxy SQLite 版本
# 用法: ./deploy-quota-proxy-persistent.sh [--help] [--dry-run] [--host <ip>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUOTA_DIR="$REPO_ROOT/quota-proxy"

# 默认参数
DRY_RUN=false
HOST=""
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
REMOTE_DIR="/opt/roc/quota-proxy-persistent"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
部署带数据持久化的 quota-proxy SQLite 版本

用法: $0 [选项]

选项:
  --help          显示此帮助信息
  --dry-run       只显示将要执行的命令，不实际执行
  --host <ip>     指定远程主机IP（默认从 /tmp/server.txt 读取）
  --ssh-key <path> 指定SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）

示例:
  $0                     # 部署到默认服务器
  $0 --dry-run          # 预览部署命令
  $0 --host 1.2.3.4     # 部署到指定主机

功能:
  1. 检查本地文件
  2. 创建远程目录
  3. 复制配置文件
  4. 启动 Docker 容器
  5. 验证部署

注意:
  - 需要提前在服务器上安装 Docker 和 Docker Compose
  - 确保 SSH 密钥可以无密码登录
  - 数据将持久化在 Docker 卷中
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取主机IP
if [[ -z "$HOST" ]]; then
    if [[ -f "/tmp/server.txt" ]]; then
        # 尝试读取IP（支持 ip:8.8.8.8 格式和裸IP格式）
        SERVER_CONTENT=$(cat /tmp/server.txt)
        if [[ "$SERVER_CONTENT" =~ ^ip: ]]; then
            HOST=$(echo "$SERVER_CONTENT" | cut -d: -f2)
        else
            # 假设第一行是IP
            HOST=$(echo "$SERVER_CONTENT" | head -n1 | tr -d '[:space:]')
        fi
    fi
fi

if [[ -z "$HOST" ]]; then
    log_error "未指定主机IP且 /tmp/server.txt 中未找到有效IP"
    log_info "请使用 --host 参数指定主机IP"
    exit 1
fi

log_info "目标主机: $HOST"
log_info "远程目录: $REMOTE_DIR"
log_info "SSH 密钥: $SSH_KEY"
log_info "工作目录: $QUOTA_DIR"

# 检查本地文件
check_local_files() {
    log_info "检查本地文件..."
    
    local required_files=(
        "$QUOTA_DIR/Dockerfile-sqlite-correct"
        "$QUOTA_DIR/server-sqlite.js"
        "$QUOTA_DIR/package.json"
        "$QUOTA_DIR/docker-compose-persistent.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "文件不存在: $file"
            return 1
        fi
        log_info "✓ $(basename "$file")"
    done
    
    # 检查脚本文件
    if [[ ! -f "$QUOTA_DIR/start.sh" ]]; then
        log_warn "start.sh 不存在，将创建默认启动脚本"
    fi
    
    log_success "本地文件检查完成"
}

# 创建远程目录
create_remote_dirs() {
    log_info "创建远程目录..."
    
    local cmd="mkdir -p $REMOTE_DIR"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] ssh -i $SSH_KEY root@$HOST \"$cmd\""
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$HOST" "$cmd"
        log_success "远程目录创建完成"
    fi
}

# 复制文件到远程
copy_files_to_remote() {
    log_info "复制文件到远程主机..."
    
    local files_to_copy=(
        "$QUOTA_DIR/Dockerfile-sqlite-correct"
        "$QUOTA_DIR/server-sqlite.js"
        "$QUOTA_DIR/package.json"
        "$QUOTA_DIR/docker-compose-persistent.yml"
    )
    
    # 创建临时目录用于打包
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # 复制文件到临时目录
    for file in "${files_to_copy[@]}"; do
        cp "$file" "$temp_dir/"
    done
    
    # 创建默认启动脚本（如果不存在）
    if [[ ! -f "$QUOTA_DIR/start.sh" ]]; then
        cat > "$temp_dir/start.sh" << 'EOF'
#!/bin/bash
# quota-proxy 持久化版本启动脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "启动 quota-proxy 持久化版本..."

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装"
    exit 1
fi

# 检查 Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo "错误: Docker Compose 未安装"
    exit 1
fi

# 设置环境变量
export ADMIN_TOKEN=${ADMIN_TOKEN:-86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d}

echo "使用 ADMIN_TOKEN: ${ADMIN_TOKEN:0:8}..."

# 启动服务
cd "$SCRIPT_DIR"
docker compose -f docker-compose-persistent.yml up -d

echo "等待服务启动..."
sleep 5

# 检查服务状态
if docker compose -f docker-compose-persistent.yml ps | grep -q "Up"; then
    echo "✓ quota-proxy 启动成功"
    echo "服务运行在: 127.0.0.1:8787"
    echo "健康检查: curl http://127.0.0.1:8787/healthz"
else
    echo "✗ quota-proxy 启动失败"
    docker compose -f docker-compose-persistent.yml logs
    exit 1
fi
EOF
        chmod +x "$temp_dir/start.sh"
    else
        cp "$QUOTA_DIR/start.sh" "$temp_dir/"
    fi
    
    # 创建环境文件示例
    cat > "$temp_dir/.env.example" << 'EOF'
# quota-proxy 环境变量配置示例
# 复制为 .env 文件并修改

# 管理员令牌（必须修改！）
ADMIN_TOKEN=your-secure-admin-token-here

# 数据库路径
STORE_PATH=/data/quota.db

# 日志级别
LOG_LEVEL=info

# 速率限制
ENABLE_RATE_LIMIT=true
MAX_REQUESTS_PER_MINUTE=60

# IP 白名单
ENABLE_IP_WHITELIST=false

# 操作日志
ENABLE_OPERATION_LOG=true

# 密钥过期时间（天）
KEY_EXPIRY_DAYS=30
EOF
    
    # 创建验证脚本
    cat > "$temp_dir/verify-deployment.sh" << 'EOF'
#!/bin/bash
# 验证 quota-proxy 持久化版本部署

set -e

echo "验证 quota-proxy 持久化版本部署..."

# 检查容器状态
if docker compose -f docker-compose-persistent.yml ps | grep -q "Up"; then
    echo "✓ 容器运行正常"
else
    echo "✗ 容器未运行"
    exit 1
fi

# 检查健康端点
if curl -fsS http://127.0.0.1:8787/healthz > /dev/null; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    exit 1
fi

# 检查数据卷
if docker volume ls | grep -q "quota-proxy-persistent_quota-data"; then
    echo "✓ 数据卷存在"
else
    echo "✗ 数据卷不存在"
fi

# 检查数据库文件（通过容器内命令）
if docker compose -f docker-compose-persistent.yml exec -T quota-proxy sh -c 'ls -la /data/' 2>/dev/null | grep -q "quota.db"; then
    echo "✓ 数据库文件存在"
else
    echo "ℹ️ 数据库文件可能尚未创建（首次运行）"
fi

echo ""
echo "部署验证完成！"
echo "管理接口: http://127.0.0.1:8787/admin/usage"
echo "使用命令: curl -H 'Authorization: Bearer \$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
EOF
    chmod +x "$temp_dir/verify-deployment.sh"
    
    # 创建 README
    cat > "$temp_dir/README.md" << 'EOF'
# quota-proxy 持久化版本

基于 SQLite 数据库的 quota-proxy 持久化版本，数据通过 Docker 卷持久化存储。

## 快速开始

1. 复制环境变量文件：
   ```bash
   cp .env.example .env
   # 编辑 .env 文件，设置 ADMIN_TOKEN
   ```

2. 启动服务：
   ```bash
   ./start.sh
   ```

3. 验证部署：
   ```bash
   ./verify-deployment.sh
   ```

## 管理命令

- 查看服务状态：
  ```bash
  docker compose -f docker-compose-persistent.yml ps
  ```

- 查看日志：
  ```bash
  docker compose -f docker-compose-persistent.yml logs -f
  ```

- 停止服务：
  ```bash
  docker compose -f docker-compose-persistent.yml down
  ```

- 停止并删除数据卷：
  ```bash
  docker compose -f docker-compose-persistent.yml down -v
  ```

## 数据持久化

数据存储在 Docker 卷 `quota-proxy-persistent_quota-data` 中：

- 查看卷信息：
  ```bash
  docker volume inspect quota-proxy-persistent_quota-data
  ```

- 备份数据库：
  ```bash
  docker compose -f docker-compose-persistent.yml exec -T quota-proxy sh -c 'sqlite3 /data/quota.db ".backup /data/quota.backup.db"'
  ```

## 故障排除

1. **容器启动失败**：
   ```bash
   docker compose -f docker-compose-persistent.yml logs
   ```

2. **健康检查失败**：
   ```bash
   curl -v http://127.0.0.1:8787/healthz
   ```

3. **数据库问题**：
   ```bash
   docker compose -f docker-compose-persistent.yml exec quota-proxy sh -c 'sqlite3 /data/quota.db ".tables"'
   ```

## 文件说明

- `docker-compose-persistent.yml` - Docker Compose 配置
- `Dockerfile-sqlite-correct` - Docker 镜像构建文件
- `server-sqlite.js` - 主服务器代码
- `start.sh` - 启动脚本
- `verify-deployment.sh` - 验证脚本
- `.env.example` - 环境变量示例
EOF
    
    # 打包并复制到远程
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] 将复制以下文件到 $HOST:$REMOTE_DIR:"
        find "$temp_dir" -type f -printf "  %P\n"
        echo "[DRY-RUN] scp -i $SSH_KEY -r $temp_dir/* root@$HOST:$REMOTE_DIR/"
    else
        log_info "打包文件..."
        tar -czf "$temp_dir/quota-proxy-persistent.tar.gz" -C "$temp_dir" .
        
        log_info "复制文件到远程主机..."
        scp -i "$SSH_KEY" "$temp_dir/quota-proxy-persistent.tar.gz" root@"$HOST":"$REMOTE_DIR"/
        
        log_info "在远程主机解压文件..."
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$HOST" "
            cd $REMOTE_DIR && \
            tar -xzf quota-proxy-persistent.tar.gz && \
            rm -f quota-proxy-persistent.tar.gz && \
            chmod +x *.sh
        "
        
        log_success "文件复制完成"
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
}

# 启动服务
start_service() {
    log_info "启动 quota-proxy 服务..."
    
    local cmd="cd $REMOTE_DIR && ./start.sh"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] ssh -i $SSH_KEY root@$HOST \"$cmd\""
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$HOST" "$cmd"
        log_success "服务启动完成"
    fi
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    local cmd="cd $REMOTE_DIR && ./verify-deployment.sh"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] ssh -i $SSH_KEY root@$HOST \"$cmd\""
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$HOST" "$cmd"
        log_success "部署验证完成"
    fi
}

# 显示后续步骤
show_next_steps() {
    cat << EOF

${GREEN}部署完成！${NC}

后续步骤：

1. ${BLUE}测试管理接口${NC}：
   ssh -i $SSH_KEY root@$HOST \\
     "curl -H 'Authorization: Bearer \\\$ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"

2. ${BLUE}创建试用密钥${NC}：
   ssh -i $SSH_KEY root@$HOST \\
     "curl -X POST -H 'Authorization: Bearer \\\$ADMIN_TOKEN' \\
      -H 'Content-Type: application/json' \\
      -d '{\"label\":\"测试用户\"}' \\
      http://127.0.0.1:8787/admin/keys"

3. ${BLUE}查看服务日志${NC}：
   ssh -i $SSH_KEY root@$HOST \\
     "cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml logs -f"

4. ${BLUE}数据备份${NC}：
   数据库文件持久化在 Docker 卷中，位置：
   ssh -i $SSH_KEY root@$HOST \\
     "docker volume inspect quota-proxy-persistent_quota-data"

配置文件位置：$HOST:$REMOTE_DIR/
EOF
}

# 主函数
main() {
    log_info "开始部署 quota-proxy 持久化版本"
    
    check_local_files
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "干运行模式 - 只显示命令，不实际执行"
    fi
    
    create_remote_dirs
    copy_files_to_remote
    
    if [[ "$DRY_RUN" != true ]]; then
        start_service
        sleep 3
        verify_deployment
        show_next_steps
    else
        log_info "干运行完成 - 查看上方命令预览"
    fi
    
    log_success "部署流程完成"
}

# 运行主函数
main "$@"