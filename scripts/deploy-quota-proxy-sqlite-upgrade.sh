#!/bin/bash
set -e

# 升级服务器上的 quota-proxy 到 SQLite 版本
# 用法: ./scripts/deploy-quota-proxy-sqlite-upgrade.sh [--dry-run]

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[INFO] Dry run mode enabled"
fi

# 读取服务器信息
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "[ERROR] Server file not found: $SERVER_FILE"
    echo "Create it with: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
fi

SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
if [[ -z "$SERVER_IP" ]]; then
    echo "[ERROR] Could not extract IP from $SERVER_FILE"
    exit 1
fi

echo "[INFO] Target server: $SERVER_IP"

# 检查当前状态
echo "[INFO] Checking current quota-proxy status..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps"
else
    echo "[DRY-RUN] Would run: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose ps'"
fi

# 备份当前配置
echo "[INFO] Backing up current configuration..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && cp -n compose.yaml compose.yaml.backup.$(date +%Y%m%d_%H%M%S)"
else
    echo "[DRY-RUN] Would backup compose.yaml"
fi

# 创建 SQLite 数据目录
echo "[INFO] Creating SQLite data directory..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@$SERVER_IP "mkdir -p /opt/roc/quota-proxy/data && chmod 755 /opt/roc/quota-proxy/data"
else
    echo "[DRY-RUN] Would create /opt/roc/quota-proxy/data directory"
fi

# 复制 SQLite 版本文件
echo "[INFO] Copying SQLite version files..."
LOCAL_DIR="/home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy"
if [[ "$DRY_RUN" == "false" ]]; then
    scp $LOCAL_DIR/server-sqlite.js root@$SERVER_IP:/opt/roc/quota-proxy/
    scp $LOCAL_DIR/package.json root@$SERVER_IP:/opt/roc/quota-proxy/
    scp $LOCAL_DIR/Dockerfile root@$SERVER_IP:/opt/roc/quota-proxy/
else
    echo "[DRY-RUN] Would copy: server-sqlite.js, package.json, Dockerfile"
fi

# 更新 compose.yaml 使用 SQLite 版本
echo "[INFO] Updating compose.yaml for SQLite version..."
COMPOSE_CONTENT=$(cat << 'EOF'
services:
  quota-proxy:
    build: .
    image: quota-proxy-quota-proxy
    container_name: quota-proxy-quota-proxy
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - DEEPSEEK_BASE_URL=${DEEPSEEK_BASE_URL:-https://api.deepseek.com/v1}
      - DAILY_REQ_LIMIT=${DAILY_REQ_LIMIT:-200}
      - SQLITE_PATH=/data/quota.db
      - ADMIN_TOKEN=${ADMIN_TOKEN}
    volumes:
      - ./data:/data
EOF
)

if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@$SERVER_IP "cat > /opt/roc/quota-proxy/compose.yaml" <<< "$COMPOSE_CONTENT"
else
    echo "[DRY-RUN] Would write compose.yaml with SQLite configuration"
fi

# 创建 .env 文件（如果不存在）
echo "[INFO] Ensuring .env file exists..."
ENV_CHECK=$(ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && if [ -f .env ]; then echo 'exists'; else echo 'missing'; fi")
if [[ "$ENV_CHECK" == "missing" ]]; then
    echo "[WARN] .env file missing. Creating template..."
    ENV_TEMPLATE=$(cat << 'EOF'
# DeepSeek API Key (required)
DEEPSEEK_API_KEY=your_deepseek_api_key_here

# Optional: Custom DeepSeek base URL
# DEEPSEEK_BASE_URL=https://api.deepseek.com/v1

# Daily request limit per trial key
DAILY_REQ_LIMIT=200

# Admin token for /admin endpoints
ADMIN_TOKEN=your_admin_token_here
EOF
)
    if [[ "$DRY_RUN" == "false" ]]; then
        ssh root@$SERVER_IP "cat > /opt/roc/quota-proxy/.env" <<< "$ENV_TEMPLATE"
        echo "[WARN] Please edit /opt/roc/quota-proxy/.env with actual values"
    else
        echo "[DRY-RUN] Would create .env template"
    fi
fi

# 重建并重启服务
echo "[INFO] Rebuilding and restarting quota-proxy..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose down && docker compose build --no-cache && docker compose up -d"
else
    echo "[DRY-RUN] Would run: docker compose down && docker compose build --no-cache && docker compose up -d"
fi

# 验证部署
echo "[INFO] Verifying deployment..."
if [[ "$DRY_RUN" == "false" ]]; then
    sleep 5
    ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps"
    
    echo "[INFO] Testing health endpoint..."
    ssh root@$SERVER_IP "curl -fsS http://127.0.0.1:8787/healthz"
    
    echo "[INFO] Checking SQLite database..."
    ssh root@$SERVER_IP "docker compose exec quota-proxy ls -la /data/"
else
    echo "[DRY-RUN] Would verify deployment with health check and database check"
fi

echo "[SUCCESS] SQLite upgrade script ready"
echo ""
echo "To run: ./scripts/deploy-quota-proxy-sqlite-upgrade.sh"
echo "Dry run: ./scripts/deploy-quota-proxy-sqlite-upgrade.sh --dry-run"