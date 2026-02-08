#!/usr/bin/env bash
set -euo pipefail

# Sync static site sources between docs/site (document source) and web/site (deploy source).
# Default direction: docs/site -> web/site
# Usage:
#   ./scripts/sync-site.sh                 # docs/site -> web/site
#   ./scripts/sync-site.sh --reverse       # web/site -> docs/site
#   ./scripts/sync-site.sh --dry-run       # print what would change

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_SITE="$ROOT_DIR/docs/site"
WEB_SITE="$ROOT_DIR/web/site"

reverse=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reverse) reverse=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help)
      sed -n '1,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$DOCS_SITE" ]]; then
  echo "Missing: $DOCS_SITE" >&2
  exit 1
fi
if [[ ! -d "$WEB_SITE" ]]; then
  echo "Missing: $WEB_SITE" >&2
  exit 1
fi

src="$DOCS_SITE"; dst="$WEB_SITE"
if [[ "$reverse" == "1" ]]; then
  src="$WEB_SITE"; dst="$DOCS_SITE"
fi

# Only sync known static assets for now.
# Keep it conservative to avoid surprises.
patterns=(
  "*.html"
  "*.txt"
  "*.xml"
  "*.md"
  "install-cn.sh"
)

mkdir -p "$dst"

echo "Sync: $src -> $dst"

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# Build file list
for pat in "${patterns[@]}"; do
  (cd "$src" && ls -1 $pat 2>/dev/null || true) | while read -r f; do
    [[ -z "$f" ]] && continue
    echo "$f" >> "$tmpfile"
  done
done

sort -u "$tmpfile" -o "$tmpfile"

while read -r f; do
  [[ -z "$f" ]] && continue
  if [[ "$dry_run" == "1" ]]; then
    if [[ ! -f "$dst/$f" ]]; then
      echo "[ADD] $f"
    elif ! cmp -s "$src/$f" "$dst/$f"; then
      echo "[UPD] $f"
    fi
  else
    if [[ ! -f "$dst/$f" ]] || ! cmp -s "$src/$f" "$dst/$f"; then
      cp -a "$src/$f" "$dst/$f"
      echo "[OK] $f"
    fi
  fi
done < "$tmpfile"

if [[ "$dry_run" == "0" ]]; then
  echo "Done."
fi
