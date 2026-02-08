#!/usr/bin/env bash
set -euo pipefail

# append-progress-log.sh
# Append a timestamped line to the weekly progress markdown log.
#
# Why this exists:
# - Some cron environments hit "printf: invalid option" when the content begins with '-'.
# - This script always uses "printf --" and writes a stable, greppable record.
#
# Usage:
#   ./scripts/append-progress-log.sh "小落地：... commit=abcd123"
#   ./scripts/append-progress-log.sh --file /path/to/progress.md "..."
#   ./scripts/append-progress-log.sh --no-ts "raw line"
#   ./scripts/append-progress-log.sh --text "..."

DEFAULT_FILE="/home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md"
FILE="$DEFAULT_FILE"
WITH_TS=1

usage() {
  cat <<'EOF'
Usage:
  append-progress-log.sh [--file <path>] [--no-ts] <text>
  append-progress-log.sh [--file <path>] [--no-ts] --text "<text>"
  echo "..." | append-progress-log.sh [--file <path>] [--no-ts] --stdin

Options:
  --file <path>  Override progress log path
  --no-ts        Do not prefix with timestamp
  --text <text>  Convenience flag; same as passing <text> positionally
  --stdin        Read text from stdin (avoids shell quoting pitfalls)
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

ARGS=()
READ_STDIN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE="${2:-}"; [[ -n "$FILE" ]] || die "--file requires a value"; shift 2 ;;
    --no-ts)
      WITH_TS=0; shift ;;
    --text)
      TEXT_ARG="${2:-}"; [[ -n "$TEXT_ARG" ]] || die "--text requires a value"; ARGS+=("$TEXT_ARG"); shift 2 ;;
    --stdin)
      READ_STDIN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      ARGS+=("$1"); shift ;;
  esac
done

if [[ $READ_STDIN -eq 1 ]]; then
  if [[ ${#ARGS[@]} -ge 1 ]]; then
    die "--stdin cannot be used together with positional <text>/--text"
  fi
  # Read full stdin (preserve newlines). Trim one trailing newline if present.
  TEXT="$(cat)"
  [[ -n "$TEXT" ]] || die "--stdin: empty input"
else
  [[ ${#ARGS[@]} -ge 1 ]] || die "missing <text>"
  TEXT="${ARGS[*]}"
fi

mkdir -p "$(dirname "$FILE")"

if [[ $WITH_TS -eq 1 ]]; then
  TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf -- '[%s] %s\n' "$TS" "$TEXT" >> "$FILE"
else
  printf -- '%s\n' "$TEXT" >> "$FILE"
fi
