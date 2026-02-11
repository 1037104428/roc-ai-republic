#!/bin/bash

# Start quota-proxy with SQLite persistence
# Usage: ./start-sqlite-persistent.sh [port]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default port
PORT=${1:-8787}

# Check if node is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed or not in PATH"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "⚠️  DEEPSEEK_API_KEY is not set"
    echo "💡 You can set it via: export DEEPSEEK_API_KEY='your-api-key'"
    echo "💡 Or create a .env file with: DEEPSEEK_API_KEY=your-api-key"
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "⚠️  ADMIN_TOKEN is not set"
    echo "💡 Generating a random admin token..."
    export ADMIN_TOKEN="admin_$(openssl rand -hex 16 2>/dev/null || echo "dev-admin-token-$(date +%s)")"
    echo "   ADMIN_TOKEN=$ADMIN_TOKEN"
fi

# Load environment from .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading environment from .env file"
    export $(grep -v '^#' .env | xargs)
fi

# Set default environment variables
export PORT=$PORT
export SQLITE_DB_PATH="${SQLITE_DB_PATH:-./quota-proxy-sqlite.db}"
export DAILY_REQ_LIMIT="${DAILY_REQ_LIMIT:-200}"

echo "🚀 Starting quota-proxy with SQLite persistence..."
echo "   Port: $PORT"
echo "   Database: $SQLITE_DB_PATH"
echo "   Daily limit: $DAILY_REQ_LIMIT"
echo "   Admin token: ${ADMIN_TOKEN:0:10}..."

# Check if server file exists
if [ ! -f "server-sqlite-persistent.js" ]; then
    echo "❌ server-sqlite-persistent.js not found"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install sqlite3 sqlite
fi

# Start the server
node server-sqlite-persistent.js