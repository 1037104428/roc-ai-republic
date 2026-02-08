#!/usr/bin/env bash
set -euo pipefail

# Sync web/site public assets from canonical sources.
# - Keeps https://clawdrepublic.cn/install-cn.sh in sync with scripts/install-cn.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cp "$ROOT_DIR/scripts/install-cn.sh" "$ROOT_DIR/web/site/install-cn.sh"
chmod +x "$ROOT_DIR/web/site/install-cn.sh"
echo "[sync] web/site/install-cn.sh <= scripts/install-cn.sh"
