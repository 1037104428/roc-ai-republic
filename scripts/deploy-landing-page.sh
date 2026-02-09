#!/usr/bin/env bash
set -euo pipefail

# Deploy landing page to server
# This script copies the static site files to the server and configures web server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$REPO_ROOT/web"

# Configuration
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_WEB_DIR="${REMOTE_WEB_DIR:-/opt/roc/web}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat <<EOF
Deploy landing page to server

Usage: $0 [OPTIONS]

Options:
  --server-file FILE    Path to server config file (default: /tmp/server.txt)
  --remote-user USER    SSH user (default: root)
  --remote-dir DIR      Remote directory for web files (default: /opt/roc/web)
  --dry-run             Show commands without executing
  --help                Show this help

Environment variables:
  SERVER_FILE      Same as --server-file
  REMOTE_USER      Same as --remote-user
  REMOTE_WEB_DIR   Same as --remote-dir

The server file should contain the server IP address (one per line).
Example:
  8.210.185.194
EOF
}

# Parse arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-file)
            SERVER_FILE="$2"
            shift 2
            ;;
        --remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-dir)
            REMOTE_WEB_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
if ! command -v rsync &> /dev/null; then
    log_error "rsync is required but not installed"
    exit 1
fi

if [[ ! -f "$SERVER_FILE" ]]; then
    log_error "Server file not found: $SERVER_FILE"
    log_info "Create it with: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
fi

# Read server IP
SERVER_IP=$(head -n1 "$SERVER_FILE" | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    log_error "No server IP found in $SERVER_FILE"
    exit 1
fi

log_info "Deploying to server: $SERVER_IP"
log_info "Remote directory: $REMOTE_WEB_DIR"
log_info "Web source: $WEB_DIR"

# Check web directory exists
if [[ ! -d "$WEB_DIR/site" ]]; then
    log_error "Web directory not found: $WEB_DIR/site"
    log_info "Expected structure: web/site/ with HTML files"
    exit 1
fi

# List files to deploy
log_info "Files to deploy:"
find "$WEB_DIR/site" -type f -name "*.html" | while read -r file; do
    log_info "  $(realpath --relative-to="$WEB_DIR" "$file")"
done

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "Dry run - would execute:"
    log_info "  rsync -avz --delete \"$WEB_DIR/site/\" \"$REMOTE_USER@$SERVER_IP:$REMOTE_WEB_DIR/\""
    log_info "  ssh \"$REMOTE_USER@$SERVER_IP\" \"ls -la $REMOTE_WEB_DIR/\""
    exit 0
fi

# Deploy files
log_info "Deploying web files..."
rsync -avz --delete \
    "$WEB_DIR/site/" \
    "$REMOTE_USER@$SERVER_IP:$REMOTE_WEB_DIR/"

# Verify deployment
log_info "Verifying deployment..."
ssh "$REMOTE_USER@$SERVER_IP" "ls -la $REMOTE_WEB_DIR/"

# Check if web server is configured
log_info "Checking web server configuration..."
if ssh "$REMOTE_USER@$SERVER_IP" "test -f /etc/caddy/Caddyfile"; then
    log_info "Caddy configuration found"
    ssh "$REMOTE_USER@$SERVER_IP" "grep -n 'clawdrepublic.cn' /etc/caddy/Caddyfile || true"
elif ssh "$REMOTE_USER@$SERVER_IP" "test -f /etc/nginx/nginx.conf"; then
    log_info "Nginx configuration found"
    ssh "$REMOTE_USER@$SERVER_IP" "grep -n 'server_name' /etc/nginx/sites-enabled/* 2>/dev/null || true"
else
    log_warn "No web server configuration found. You may need to:"
    log_warn "1. Copy web/caddy/Caddyfile or web/nginx/nginx.conf to server"
    log_warn "2. Restart web server"
fi

log_info "Deployment complete!"
log_info "Site should be available at: https://clawdrepublic.cn/"
log_info "To verify: curl -fsS https://clawdrepublic.cn/"