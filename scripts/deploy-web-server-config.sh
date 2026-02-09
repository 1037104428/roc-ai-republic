#!/usr/bin/env bash
set -euo pipefail

# Deploy web server configuration (Caddy/Nginx) to ROC server
# Usage: ./scripts/deploy-web-server-config.sh [--caddy|--nginx] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
REMOTE_USER="${REMOTE_USER:-root}"
DRY_RUN=0
SERVER_TYPE="caddy"  # default: caddy

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --caddy) SERVER_TYPE="caddy"; shift ;;
        --nginx) SERVER_TYPE="nginx"; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--caddy|--nginx] [--dry-run]"
            echo "Deploy web server configuration to ROC server"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Read server IP from file
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "Error: Server file not found: $SERVER_FILE"
    echo "Create file with format: ip=8.210.185.194 or ip:8.210.185.194"
    exit 1
fi

SERVER_IP=$(grep -E '^(ip=|ip:)' "$SERVER_FILE" | head -1 | sed 's/^ip[=:]//')
if [[ -z "$SERVER_IP" ]]; then
    echo "Error: Could not extract IP from $SERVER_FILE"
    exit 1
fi

echo "[web-server] Deploying $SERVER_TYPE configuration to $SERVER_IP"

# Local paths
LOCAL_CONFIG_DIR="$SCRIPT_DIR/../web/$SERVER_TYPE"
LOCAL_CONFIG_FILE="$LOCAL_CONFIG_DIR/$([[ "$SERVER_TYPE" == "caddy" ]] && echo "Caddyfile" || echo "nginx.conf")"

# Remote paths
REMOTE_BASE_DIR="/opt/roc/web"
REMOTE_CONFIG_DIR="$REMOTE_BASE_DIR/$SERVER_TYPE"
REMOTE_CONFIG_FILE="$REMOTE_CONFIG_DIR/$([[ "$SERVER_TYPE" == "caddy" ]] && echo "Caddyfile" || echo "nginx.conf")"

# Check local files exist
if [[ ! -f "$LOCAL_CONFIG_FILE" ]]; then
    echo "Error: Local config file not found: $LOCAL_CONFIG_FILE"
    exit 1
fi

# Deploy function
deploy_config() {
    local cmd
    
    echo "[web-server] Creating remote directory..."
    cmd="ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 \"$REMOTE_USER@$SERVER_IP\" \"mkdir -p $REMOTE_CONFIG_DIR\""
    [[ $DRY_RUN -eq 1 ]] && echo "DRY RUN: $cmd" || eval "$cmd"
    
    echo "[web-server] Copying config file..."
    cmd="scp -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 \"$LOCAL_CONFIG_FILE\" \"$REMOTE_USER@$SERVER_IP:$REMOTE_CONFIG_FILE\""
    [[ $DRY_RUN -eq 1 ]] && echo "DRY RUN: $cmd" || eval "$cmd"
    
    echo "[web-server] Setting permissions..."
    cmd="ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 \"$REMOTE_USER@$SERVER_IP\" \"chmod 644 $REMOTE_CONFIG_FILE\""
    [[ $DRY_RUN -eq 1 ]] && echo "DRY RUN: $cmd" || eval "$cmd"
    
    # Create validation script
    local validation_script="verify-web-server-$SERVER_TYPE.sh"
    cat > "/tmp/$validation_script" << EOF
#!/bin/bash
set -e

echo "[verify] Checking $SERVER_TYPE configuration..."
CONFIG_FILE="$REMOTE_CONFIG_FILE"

# Check config file exists
if [[ ! -f "\$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: \$CONFIG_FILE"
    exit 1
fi

# Validate config syntax
if [[ "$SERVER_TYPE" == "caddy" ]]; then
    if command -v caddy >/dev/null 2>&1; then
        caddy validate --config "\$CONFIG_FILE" && echo "[verify] Caddy config syntax: OK"
    else
        echo "[verify] Caddy not installed, skipping syntax check"
    fi
elif [[ "$SERVER_TYPE" == "nginx" ]]; then
    if command -v nginx >/dev/null 2>&1; then
        nginx -t -c "\$CONFIG_FILE" && echo "[verify] Nginx config syntax: OK"
    else
        echo "[verify] Nginx not installed, skipping syntax check"
    fi
fi

# Check site files exist
if [[ -d "/opt/roc/web/site" ]]; then
    SITE_FILES=\$(find /opt/roc/web/site -name "*.html" | wc -l)
    echo "[verify] Site HTML files: \$SITE_FILES"
    
    if [[ \$SITE_FILES -gt 0 ]]; then
        echo "[verify] Site files: OK"
    else
        echo "WARNING: No HTML files found in /opt/roc/web/site"
    fi
else
    echo "WARNING: Site directory not found: /opt/roc/web/site"
fi

echo "[verify] $SERVER_TYPE configuration deployed successfully"
EOF
    
    chmod +x "/tmp/$validation_script"
    
    echo "[web-server] Uploading validation script..."
    cmd="scp -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 \"/tmp/$validation_script\" \"$REMOTE_USER@$SERVER_IP:$REMOTE_BASE_DIR/\""
    [[ $DRY_RUN -eq 1 ]] && echo "DRY RUN: $cmd" || eval "$cmd"
    
    echo "[web-server] Running validation..."
    cmd="ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 \"$REMOTE_USER@$SERVER_IP\" \"cd $REMOTE_BASE_DIR && chmod +x $validation_script && ./$validation_script\""
    [[ $DRY_RUN -eq 1 ]] && echo "DRY RUN: $cmd" || eval "$cmd"
    
    rm -f "/tmp/$validation_script"
}

# Execute deployment
deploy_config

echo "[web-server] Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Install $SERVER_TYPE on server if not already installed"
echo "2. Configure SSL certificates for clawdrepublic.cn"
echo "3. Start/Restart $SERVER_TYPE service"
echo "4. Test: curl -fsS https://clawdrepublic.cn/healthz"