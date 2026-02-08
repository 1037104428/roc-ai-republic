#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-/tmp/server.txt}"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

# Keep only the first ip line. Drop password or any other secrets.
# Accept: ip:1.2.3.4 | ip: 1.2.3.4 | ip=1.2.3.4
IP_RAW=$(grep -E '^[[:space:]]*ip[[:space:]]*[:=]' "$SRC" | head -n 1 || true)
if [[ -z "$IP_RAW" ]]; then
  echo "error: no ip line found in $SRC" >&2
  echo "hint: expected format: ip:1.2.3.4 (or ip=1.2.3.4)" >&2
  exit 2
fi

IP=$(printf '%s' "$IP_RAW" | sed -E 's/^[[:space:]]*ip[[:space:]]*[:=][[:space:]]*//; s/[[:space:]]+//g')
IP_LINE="ip:${IP}"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$IP_LINE" > "$tmp"

# Atomic replace, then lock perms.
cat "$tmp" > "$SRC"
chmod 600 "$SRC" || true

echo "ok: sanitized $SRC (kept: $IP_LINE)"
echo "note: removed any password:... lines; use SSH key auth"
