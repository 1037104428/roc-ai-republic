#!/usr/bin/env bash
set -euo pipefail

# Run a command on the root server described by /tmp/server.txt (ip + password).
# This avoids sshpass/expect dependencies by using python3 + pexpect.
#
# Usage:
#   ./scripts/ssh-run-server-txt.sh "cd /opt/roc/quota-proxy && docker compose ps"
#
# Input format (example /tmp/server.txt):
#   ip:8.210.185.194
#   password:xxx
#
# Notes:
# - This is meant for internal ops / cron checks.
# - Do NOT commit real passwords into git.

if [[ ${1:-} == "" ]]; then
  echo "usage: $0 <remote-shell-command>" >&2
  exit 2
fi

python3 - "$1" <<'PY'
import re, sys
from pathlib import Path
import pexpect

remote_cmd = sys.argv[1]

text = Path('/tmp/server.txt').read_text(encoding='utf-8', errors='ignore')
ip_m = re.search(r'(?:\d{1,3}\.){3}\d{1,3}', text)
pass_m = re.search(r'password:(.*)', text)
if not ip_m or not pass_m:
    raise SystemExit('server.txt missing ip/password (expected: ip:... + password:...)')

ip = ip_m.group(0)
password = pass_m.group(1).strip()

cmd = f"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 root@{ip} {remote_cmd!r}"
child = pexpect.spawn(cmd, encoding='utf-8', timeout=120)
child.logfile = sys.stdout

while True:
    i = child.expect([
        r'password:',
        r'Permission denied',
        r'Connection timed out',
        r'No route to host',
        pexpect.EOF,
        pexpect.TIMEOUT,
    ])
    if i == 0:
        child.sendline(password)
        continue
    if i in (1, 2, 3):
        raise SystemExit('SSH_FAILED')
    if i == 4:
        break
    if i == 5:
        raise SystemExit('SSH_TIMEOUT')

child.close()
sys.exit(child.exitstatus or 0)
PY
