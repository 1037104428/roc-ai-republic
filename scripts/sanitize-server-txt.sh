#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-/tmp/server.txt}"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

# Keep only the first ip:... line. Drop password or any other secrets.
IP_LINE=$(grep -E '^ip:' "$SRC" | head -n 1 || true)
if [[ -z "$IP_LINE" ]]; then
  echo "error: no 'ip:' line found in $SRC" >&2
  echo "hint: expected format: ip:1.2.3.4" >&2
  exit 2
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$IP_LINE" > "$tmp"

# Atomic replace, then lock perms.
cat "$tmp" > "$SRC"
chmod 600 "$SRC" || true

echo "ok: sanitized $SRC (kept: $IP_LINE)"
echo "note: removed any password:... lines; use SSH key auth"
