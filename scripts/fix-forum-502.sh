#!/usr/bin/env bash
set -euo pipefail

# Fix forum.clawdrepublic.cn 502 error by redirecting to main domain /forum
# Usage: ./scripts/fix-forum-502.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
REMOTE_USER="${REMOTE_USER:-root}"
DRY_RUN=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "Fix forum.clawdrepublic.cn 502 error by redirecting to main domain /forum"
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

echo "[fix-forum-502] Fixing forum.clawdrepublic.cn 502 on $SERVER_IP"

# Create temporary Caddyfile patch - remove forum.clawdrepublic.cn block
PATCH="Remove forum.clawdrepublic.cn block entirely (users access forum at https://clawdrepublic.cn/forum/)"

echo "Fix to apply:"
echo "========================="
echo "$PATCH"
echo "========================="

if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] Would remove forum.clawdrepublic.cn block from /etc/caddy/Caddyfile on $SERVER_IP"
    exit 0
fi

# Apply fix remotely
echo "Removing forum.clawdrepublic.cn block from /etc/caddy/Caddyfile..."
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "$REMOTE_USER@$SERVER_IP" "
    # Backup current Caddyfile
    cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.\$(date +%s)
    
    # Remove existing forum.clawdrepublic.cn block if present
    sed -i '/^forum\.clawdrepublic\.cn {/,/^}/d' /etc/caddy/Caddyfile
    
    # Reload Caddy
    systemctl reload caddy || systemctl restart caddy
    
    echo 'forum.clawdrepublic.cn block removed and Caddy reloaded'
    echo 'Users should access forum at: https://clawdrepublic.cn/forum/'
"

echo "[fix-forum-502] Done. Forum accessible at: https://clawdrepublic.cn/forum/"