#!/usr/bin/env bash
set -euo pipefail

# Trial Key Manager for quota-proxy
# Simple CLI to create, list, and check usage of trial keys
# Requires: curl, jq (optional for pretty output)

SERVER="${QUOTA_PROXY_SERVER:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
DB_PATH="${SQLITE_PATH:-/data/quota.db}"

usage() {
  cat <<'EOF'
Trial Key Manager for quota-proxy

Usage:
  ./admin-trial-key-manager.sh <command> [options]

Commands:
  create [label]          Create a new trial key with optional label
  list                    List all trial keys
  usage [key]             Show usage for a specific key (or all keys)
  delete <key>            Delete a trial key
  health                  Check quota-proxy health
  help                    Show this help

Environment variables:
  QUOTA_PROXY_SERVER      Server URL (default: http://127.0.0.1:8787)
  ADMIN_TOKEN             Admin token for authentication
  SQLITE_PATH             Path to SQLite database (for direct DB access)

Examples:
  # Create a key with label
  ADMIN_TOKEN=secret ./admin-trial-key-manager.sh create "user:alice@example.com"
  
  # List all keys
  ADMIN_TOKEN=secret ./admin-trial-key-manager.sh list
  
  # Check usage
  ADMIN_TOKEN=secret ./admin-trial-key-manager.sh usage
  
  # Health check
  ./admin-trial-key-manager.sh health
EOF
}

check_health() {
  echo "Checking quota-proxy health..."
  if curl -fsS "${SERVER}/healthz" >/dev/null 2>&1; then
    echo "✓ quota-proxy is healthy"
    return 0
  else
    echo "✗ quota-proxy is not responding"
    return 1
  fi
}

require_admin_token() {
  if [[ -z "${ADMIN_TOKEN}" ]]; then
    echo "Error: ADMIN_TOKEN environment variable is required for this command"
    exit 1
  fi
}

cmd_create() {
  require_admin_token
  local label="${1:-}"
  
  local json_payload
  if [[ -n "${label}" ]]; then
    json_payload="{\"label\":\"${label}\"}"
  else
    json_payload="{}"
  fi
  
  echo "Creating trial key${label:+ with label: ${label}}..."
  curl -sS -X POST "${SERVER}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${json_payload}" | jq -r '.key // .'
}

cmd_list() {
  require_admin_token
  echo "Listing trial keys..."
  curl -sS "${SERVER}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq .
}

cmd_usage() {
  require_admin_token
  local key="${1:-}"
  
  if [[ -n "${key}" ]]; then
    echo "Checking usage for key: ${key:0:8}..."
    curl -sS "${SERVER}/admin/usage?key=${key}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq .
  else
    echo "Checking usage for all keys..."
    curl -sS "${SERVER}/admin/usage" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq .
  fi
}

cmd_delete() {
  require_admin_token
  local key="${1:-}"
  
  if [[ -z "${key}" ]]; then
    echo "Error: Key required for delete command"
    exit 1
  fi
  
  echo "Deleting key: ${key:0:8}..."
  curl -sS -X DELETE "${SERVER}/admin/keys/${key}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq .
}

cmd_health() {
  check_health
}

# Direct database access (if SQLite path is available)
cmd_db_stats() {
  if [[ ! -f "${DB_PATH}" ]]; then
    echo "Database not found at: ${DB_PATH}"
    echo "Set SQLITE_PATH environment variable"
    return 1
  fi
  
  echo "Database statistics:"
  sqlite3 "${DB_PATH}" <<'SQL'
SELECT 
  (SELECT COUNT(*) FROM trial_keys) as total_keys,
  (SELECT COUNT(DISTINCT trial_key) FROM daily_usage) as keys_with_usage,
  (SELECT SUM(requests) FROM daily_usage WHERE day = date('now')) as today_requests;
SQL
}

# Main
main() {
  local command="${1:-help}"
  
  case "${command}" in
    create)
      cmd_create "${2:-}"
      ;;
    list)
      cmd_list
      ;;
    usage)
      cmd_usage "${2:-}"
      ;;
    delete)
      cmd_delete "${2:-}"
      ;;
    health)
      cmd_health
      ;;
    db-stats)
      cmd_db_stats
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      echo "Unknown command: ${command}"
      usage
      exit 1
      ;;
  esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi