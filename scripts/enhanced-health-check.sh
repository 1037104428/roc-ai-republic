#!/bin/bash
# Enhanced health check for quota-proxy with database and API response time monitoring
# Usage: ./scripts/enhanced-health-check.sh [--verbose] [--timeout 5]

set -euo pipefail

# Configuration
DEFAULT_TIMEOUT=5
VERBOSE=false
TIMEOUT=$DEFAULT_TIMEOUT
HEALTHZ_URL="http://127.0.0.1:8787/healthz"
DB_PATH="/opt/roc/quota-proxy/data/quota.db"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "Enhanced health check for quota-proxy"
            echo "Usage: $0 [--verbose] [--timeout SECONDS]"
            echo ""
            echo "Options:"
            echo "  --verbose     Show detailed output"
            echo "  --timeout N   Set timeout in seconds (default: 5)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "success")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "warning")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "error")
            echo -e "${RED}✗${NC} $message"
            ;;
        "info")
            echo -e "  $message"
            ;;
    esac
}

# Main health check function
main() {
    echo "=== Enhanced Health Check for quota-proxy ==="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    # 1. Check if quota-proxy service is running
    print_status "info" "1. Checking quota-proxy service status..."
    if docker compose ps quota-proxy 2>/dev/null | grep -q "Up"; then
        print_status "success" "quota-proxy service is running"
    else
        print_status "error" "quota-proxy service is not running"
        exit 1
    fi
    
    # 2. Check healthz endpoint
    print_status "info" "2. Checking healthz endpoint..."
    start_time=$(date +%s%N)
    if response=$(curl -fsS --max-time $TIMEOUT "$HEALTHZ_URL" 2>/dev/null); then
        end_time=$(date +%s%N)
        response_time_ms=$(( (end_time - start_time) / 1000000 ))
        print_status "success" "Healthz endpoint responded: $response"
        print_status "info" "Response time: ${response_time_ms}ms"
        
        # Check response time threshold
        if [ $response_time_ms -gt 1000 ]; then
            print_status "warning" "Response time is high (>1000ms)"
        fi
    else
        print_status "error" "Healthz endpoint failed or timed out"
        exit 1
    fi
    
    # 3. Check database file existence and permissions
    print_status "info" "3. Checking database file..."
    if [ -f "$DB_PATH" ]; then
        print_status "success" "Database file exists: $DB_PATH"
        
        # Check file permissions
        perms=$(stat -c "%A" "$DB_PATH")
        size=$(stat -c "%s" "$DB_PATH")
        print_status "info" "  Permissions: $perms"
        print_status "info" "  Size: ${size} bytes"
        
        # Check if file is readable
        if [ -r "$DB_PATH" ]; then
            print_status "success" "  Database file is readable"
        else
            print_status "error" "  Database file is not readable"
        fi
        
        # Check if file is writable (for quota updates)
        if [ -w "$DB_PATH" ]; then
            print_status "success" "  Database file is writable"
        else
            print_status "warning" "  Database file is not writable (may affect quota updates)"
        fi
    else
        print_status "warning" "Database file not found: $DB_PATH"
        print_status "info" "  This may be normal if using in-memory storage"
    fi
    
    # 4. Check database connection (if SQLite is available)
    print_status "info" "4. Checking database connection..."
    if command -v sqlite3 >/dev/null 2>&1 && [ -f "$DB_PATH" ]; then
        if sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null | grep -qE '^[0-9]+$'; then
            key_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null)
            print_status "success" "Database connection successful"
            print_status "info" "  API keys in database: $key_count"
            
            # Check quota_usage table if exists
            if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='quota_usage';" 2>/dev/null | grep -q "quota_usage"; then
                usage_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM quota_usage;" 2>/dev/null)
                print_status "info" "  Quota usage records: $usage_count"
            fi
        else
            print_status "warning" "Could not query api_keys table"
            print_status "info" "  This may be normal if table doesn't exist yet"
        fi
    else
        print_status "info" "  SQLite3 not available or database not found, skipping connection test"
    fi
    
    # 5. Check disk space
    print_status "info" "5. Checking disk space..."
    disk_usage=$(df -h /opt/roc 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ -n "$disk_usage" ]; then
        print_status "info" "  Disk usage: ${disk_usage}%"
        if [ "$disk_usage" -gt 90 ]; then
            print_status "warning" "  Disk usage is high (>90%)"
        elif [ "$disk_usage" -gt 80 ]; then
            print_status "warning" "  Disk usage is moderate (>80%)"
        else
            print_status "success" "  Disk usage is normal"
        fi
    fi
    
    # 6. Check memory usage
    print_status "info" "6. Checking memory usage..."
    container_id=$(docker ps -qf "name=quota-proxy")
    if [ -n "$container_id" ]; then
        mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_id" 2>/dev/null || echo "N/A")
        print_status "info" "  Container memory: $mem_usage"
    fi
    
    echo ""
    print_status "success" "=== Health check completed successfully ==="
    print_status "info" "All critical checks passed"
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        echo "Detailed information:"
        echo "- Healthz URL: $HEALTHZ_URL"
        echo "- Database path: $DB_PATH"
        echo "- Timeout: ${TIMEOUT}s"
        echo "- Verbose mode: enabled"
    fi
}

# Run main function
main "$@"
