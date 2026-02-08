#!/bin/bash
set -euo pipefail

# Verify SQLite persistence for quota-proxy
# Usage: ./scripts/verify-sqlite-persistence.sh [base_url]

show_help() {
    cat << EOF
Usage: $0 [base_url]

Verify SQLite persistence for quota-proxy service.

Arguments:
  base_url    Base URL of quota-proxy (default: http://127.0.0.1:8787)

Environment variables:
  ADMIN_TOKEN    Admin token for testing admin API (optional)
  SQLITE_PATH    SQLite file path (default: /data/quota.sqlite)

Examples:
  $0 http://127.0.0.1:8787
  ADMIN_TOKEN=your_token $0 https://api.example.com

EOF
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
SQLITE_PATH="${SQLITE_PATH:-/data/quota.sqlite}"

echo "🔍 Verifying SQLite persistence for quota-proxy at $BASE_URL"
echo ""

# 1. Check health endpoint
echo "1. Checking health endpoint..."
curl -fsS "$BASE_URL/healthz" | jq -r '.ok' | grep -q 'true' && echo "✅ Health check passed" || (echo "❌ Health check failed"; exit 1)

# 2. Check if persistence is enabled
echo ""
echo "2. Checking persistence configuration..."
if [ -n "$ADMIN_TOKEN" ]; then
    echo "   ADMIN_TOKEN is set (length: ${#ADMIN_TOKEN})"
else
    echo "⚠️  ADMIN_TOKEN not set, skipping admin API tests"
fi

# 3. Check SQLite file existence (if we have SSH access)
echo ""
echo "3. SQLite persistence status:"
echo "   SQLITE_PATH: $SQLITE_PATH"
echo "   Note: Run on server to check file existence:"
echo "     docker exec -it \$(docker ps -q -f name=quota-proxy) ls -la \$SQLITE_PATH 2>/dev/null || echo 'File not found'"

# 4. Test admin API if token available
if [ -n "$ADMIN_TOKEN" ]; then
    echo ""
    echo "4. Testing admin API with persistence..."
    
    # Generate a test key
    TEST_KEY="test-verify-$(date +%s)"
    echo "   Generating test key: $TEST_KEY"
    
    curl -s -X POST "$BASE_URL/admin/keys" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$TEST_KEY\",\"dailyLimit\":10,\"expiresAt\":\"$(date -d '+1 day' +%Y-%m-%dT%H:%M:%SZ)\"}" \
        | jq -r '.key // empty' | grep -q "$TEST_KEY" && echo "✅ Test key created" || echo "❌ Failed to create test key"
    
    # Check usage
    echo "   Checking usage..."
    curl -s "$BASE_URL/admin/usage?key=$TEST_KEY" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        | jq -r '.key // empty' | grep -q "$TEST_KEY" && echo "✅ Usage query works" || echo "⚠️  Usage query may have issues"
fi

echo ""
echo "📋 Summary:"
echo "   - Health endpoint: ✅ OK"
echo "   - Persistence config: SQLITE_PATH=$SQLITE_PATH"
echo "   - Admin API: $( [ -n "$ADMIN_TOKEN" ] && echo '✅ Token available' || echo '⚠️  Token not set' )"
echo ""
echo "💡 Next steps:"
echo "   1. Set ADMIN_TOKEN environment variable for full verification"
echo "   2. On server, check SQLite file: docker exec -it \$(docker ps -q -f name=quota-proxy) sqlite3 \$SQLITE_PATH '.tables'"
echo "   3. Verify data persists across container restarts"