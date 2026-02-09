#!/usr/bin/env bash
set -euo pipefail

# Sync web/site public assets from canonical sources.
# - Keeps https://clawdrepublic.cn/install-cn.sh in sync with scripts/install-cn.sh
# - Keeps https://clawdrepublic.cn/verify-quickstart.sh in sync with scripts/verify-quickstart.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Sync install-cn.sh
cp "$ROOT_DIR/scripts/install-cn.sh" "$ROOT_DIR/web/site/install-cn.sh"
chmod +x "$ROOT_DIR/web/site/install-cn.sh"
echo "[sync] web/site/install-cn.sh <= scripts/install-cn.sh"

# Sync verify-quickstart.sh
cp "$ROOT_DIR/scripts/verify-quickstart.sh" "$ROOT_DIR/web/site/verify-quickstart.sh"
chmod +x "$ROOT_DIR/web/site/verify-quickstart.sh"
echo "[sync] web/site/verify-quickstart.sh <= scripts/verify-quickstart.sh"
