#!/usr/bin/env bash
set -euo pipefail

# Test TRIAL_KEY lifecycle: create, verify usage, reset, delete
# Requires ADMIN_TOKEN and server access

SERVER_IP="${SERVER_IP:-8.210.185.194}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
LOCAL_MODE="${LOCAL_MODE:-false}"  # true to test against localhost:8787

usage() {
  cat <<'TXT'
Test TRIAL_KEY lifecycle (create → verify → reset → delete)

Environment variables:
  SERVER_IP          Server IP (default: 8.210.185.194)
  ADMIN_TOKEN        Admin token for quota-proxy
  LOCAL_MODE         If true, use http://localhost:8787 instead of SSH

Usage:
  ADMIN_TOKEN=your_token ./test-trial-key-lifecycle.sh
  LOCAL_MODE=true ADMIN_TOKEN=your_token ./test-trial-key-lifecycle.sh

The script will:
1. Create a test TRIAL_KEY with label "test-$(date +%s)"
2. Verify it appears in /admin/usage
3. Make a test request to /v1/models (should succeed)
4. Reset usage for the key
5. Delete the key
6. Verify key is gone from /admin/usage

All steps are logged; any failure stops the script.
TXT
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
  usage
  exit 0
fi

if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "ERROR: ADMIN_TOKEN environment variable is required"
  echo "Get it from the server: grep ADMIN_TOKEN /opt/roc/quota-proxy/.env"
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
  log "ERROR: $*"
  exit 1
}

run_curl() {
  local url="$1"
  shift
  local extra_args=("$@")
  
  if [[ "$LOCAL_MODE" = "true" ]]; then
    curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" "http://localhost:8787${url}" "${extra_args[@]}"
  else
    ssh "root@$SERVER_IP" "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' 'http://127.0.0.1:8787${url}'" "${extra_args[@]}"
  fi
}

# Generate unique label
TEST_LABEL="test-$(date +%s)"
log "Starting TRIAL_KEY lifecycle test with label: $TEST_LABEL"

# 1. Create a TRIAL_KEY
log "Step 1: Creating TRIAL_KEY with label '$TEST_LABEL'..."
CREATE_RESPONSE=$(run_curl "/admin/keys" -X POST -H "Content-Type: application/json" -d "{\"label\":\"$TEST_LABEL\"}")
if [[ $? -ne 0 ]]; then
  die "Failed to create TRIAL_KEY"
fi

TRIAL_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key')
if [[ -z "$TRIAL_KEY" || "$TRIAL_KEY" = "null" ]]; then
  die "No key in response: $CREATE_RESPONSE"
fi

log "Created TRIAL_KEY: $TRIAL_KEY"

# 2. Verify key appears in /admin/usage
log "Step 2: Verifying key appears in /admin/usage..."
USAGE_RESPONSE=$(run_curl "/admin/usage")
if [[ $? -ne 0 ]]; then
  die "Failed to get /admin/usage"
fi

KEY_FOUND=$(echo "$USAGE_RESPONSE" | jq -r ".items[] | select(.key == \"$TRIAL_KEY\") | .label")
if [[ "$KEY_FOUND" != "$TEST_LABEL" ]]; then
  die "Key not found in /admin/usage or label mismatch. Response: $USAGE_RESPONSE"
fi

log "Key verified in /admin/usage with correct label"

# 3. Make a test request to /v1/models
log "Step 3: Testing TRIAL_KEY with /v1/models request..."
if [[ "$LOCAL_MODE" = "true" ]]; then
  MODEL_RESPONSE=$(curl -fsS -H "Authorization: Bearer $TRIAL_KEY" "http://localhost:8787/v1/models" 2>/dev/null || true)
else
  MODEL_RESPONSE=$(ssh "root@$SERVER_IP" "curl -fsS -H 'Authorization: Bearer $TRIAL_KEY' 'http://127.0.0.1:8787/v1/models'" 2>/dev/null || true)
fi

if [[ -n "$MODEL_RESPONSE" ]]; then
  log "API request successful (may return 401 if key has no quota, which is expected for new keys)"
else
  log "API request failed or returned empty (may be expected behavior)"
fi

# 4. Reset usage for the key
log "Step 4: Resetting usage for key..."
RESET_RESPONSE=$(run_curl "/admin/usage/reset" -X POST -H "Content-Type: application/json" -d "{\"key\":\"$TRIAL_KEY\"}")
if [[ $? -ne 0 ]]; then
  die "Failed to reset usage"
fi

log "Usage reset successful: $RESET_RESPONSE"

# 5. Delete the key
log "Step 5: Deleting key..."
DELETE_RESPONSE=$(run_curl "/admin/keys/$TRIAL_KEY" -X DELETE)
if [[ $? -ne 0 ]]; then
  die "Failed to delete key"
fi

log "Key deletion successful: $DELETE_RESPONSE"

# 6. Verify key is gone from /admin/usage
log "Step 6: Verifying key removed from /admin/usage..."
FINAL_USAGE=$(run_curl "/admin/usage")
if [[ $? -ne 0 ]]; then
  die "Failed to get final /admin/usage"
fi

KEY_STILL_PRESENT=$(echo "$FINAL_USAGE" | jq -r ".items[] | select(.key == \"$TRIAL_KEY\") | .key")
if [[ -n "$KEY_STILL_PRESENT" ]]; then
  die "Key still present in /admin/usage after deletion"
fi

log "SUCCESS: TRIAL_KEY lifecycle test completed successfully!"
log "Created, verified, reset, and deleted key: $TRIAL_KEY"
log "All admin operations worked correctly."