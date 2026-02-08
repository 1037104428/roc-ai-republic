#!/usr/bin/env bash
set -euo pipefail

# Verify ROC public endpoints (landing page + API healthz).
#
# Usage:
#   ./verify-roc-public.sh [--timeout N] [HOME_URL] [API_BASE_URL]
#
# Examples:
#   ./verify-roc-public.sh
#   ./verify-roc-public.sh --timeout 5
#   ./verify-roc-public.sh https://clawdrepublic.cn https://api.clawdrepublic.cn
#   ./verify-roc-public.sh --timeout 8 https://clawdrepublic.cn https://api.clawdrepublic.cn
#   curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-roc-public.sh | bash

TIMEOUT="${TIMEOUT:-10}"

args=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --timeout)
      TIMEOUT="${2:-}"
      [[ -n "$TIMEOUT" ]] || { echo "--timeout requires a value" >&2; exit 2; }
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

HOME_URL="${args[0]:-https://clawdrepublic.cn}"
API_BASE_URL="${args[1]:-https://api.clawdrepublic.cn}"

say() { printf '%s\n' "$*"; }

say "[1/2] HOME: ${HOME_URL} (timeout=${TIMEOUT}s)"
# Expect: HTTP 200/301/302 etc.
curl -fsSI -m "$TIMEOUT" "${HOME_URL}/" | head -n 5

say "[2/2] API healthz: ${API_BASE_URL}/healthz (timeout=${TIMEOUT}s)"
curl -fsS -m "$TIMEOUT" "${API_BASE_URL}/healthz" | sed -e 's/[[:space:]]\+$//' ; echo

say "OK"
