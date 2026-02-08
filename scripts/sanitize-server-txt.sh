#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-/tmp/server.txt}"

if [[ ! -f "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

# Keep only the first ip line. Drop password or any other secrets.
# Accept: ip:1.2.3.4 | ip: 1.2.3.4 | ip=1.2.3.4 | 1.2.3.4
IP_RAW=$(grep -E '^[[:space:]]*ip[[:space:]]*[:=]' "$SRC" | head -n 1 || true)

if [[ -z "$IP_RAW" ]]; then
  # Fallback: allow a bare IPv4 on the first non-empty line.
  BARE=$(grep -E '^[[:space:]]*[0-9]{1,3}(\.[0-9]{1,3}){3}[[:space:]]*$' "$SRC" | head -n 1 || true)
  if [[ -z "$BARE" ]]; then
    echo "error: no ip line found in $SRC" >&2
    echo "hint: expected format: ip:1.2.3.4 (or ip=1.2.3.4 or a bare 1.2.3.4)" >&2
    exit 2
  fi
  IP=$(printf '%s' "$BARE" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
else
  IP=$(printf '%s' "$IP_RAW" | sed -E 's/^[[:space:]]*ip[[:space:]]*[:=][[:space:]]*//; s/[[:space:]]+//g')
fi

IP_LINE="ip:${IP}"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$IP_LINE" > "$tmp"

# Atomic replace, then lock perms.
cat "$tmp" > "$SRC"
chmod 600 "$SRC" || true

echo "ok: sanitized $SRC (kept: $IP_LINE)"
echo "note: removed any password:... lines; use SSH key auth"
