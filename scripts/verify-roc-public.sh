#!/usr/bin/env bash
set -euo pipefail

# Verify ROC public endpoints (landing page + API healthz).
# Usage:
#   ./verify-roc-public.sh [HOME_URL] [API_BASE_URL]
# Examples:
#   ./verify-roc-public.sh https://clawdrepublic.cn https://api.clawdrepublic.cn
#   curl -fsSL https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/verify-roc-public.sh | bash

HOME_URL="${1:-https://clawdrepublic.cn}"
API_BASE_URL="${2:-https://api.clawdrepublic.cn}"

say() { printf '%s\n' "$*"; }

say "[1/2] HOME: ${HOME_URL}"
# Expect: HTTP 200/301/302 etc.
curl -fsSI -m 10 "${HOME_URL}/" | head -n 5

say "[2/2] API healthz: ${API_BASE_URL}/healthz"
curl -fsS -m 10 "${API_BASE_URL}/healthz" | sed -e 's/[[:space:]]\+$//' ; echo

say "OK"
